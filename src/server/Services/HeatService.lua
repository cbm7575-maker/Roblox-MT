-- HeatService (ModuleScript, ServerScriptService.Services.HeatService)
-- The wanted system: cops only know what they've seen.
--   Heat 1-5 (player attribute "Heat") comes from crimes; only citizens get heat.
--   HeatSpotted = true while a cop (player or AI "eye") can see you: within 250 studs and a clear
--     line of sight. Cops then see your exact position (attribute LastSeen follows you). An eye can be
--     given a longer reach (RegisterEye(part, range)): the police helicopter's (PoliceHeliService).
--   Not seen for a while -> hollow stars: cops only see a search circle around LastSeen. Not seen for
--     longer -> heat gone ("You lost the cops!"). How long, by stars, is Config.Wanted (HollowAfter,
--     EscapeAfter): 5 s / 30 s at 1 star, 6 / 40 at 2, then 8 s and 60, 70, 80 s at 3, 4, 5 (since Nov 7;
--     it was 8 s and 30 + 10 x heat at every level).
--   Rookies (Config.Tutorial.Rookie: no bag banked yet, 1-2 stars) get the shorter of those and theirs.
--   EscapeFrom / EscapeAt (server times, GetServerTimeNow) are set only while the stars are hollow: when
--     the unseen clock started (the last sighting or crime report) and when it will let you go. The
--     HUD's LOSING THEM meter fills from one to the other; both clear the moment you're seen again.
--   A heist site with an active alarm is a hot zone: a wanted player within 60 studs is spotted.
--   At 4+ stars LastSeen updates every 20 s even while hollow (the helicopter-style ping). It moves the
--     cops' search circle only: the real helicopter (PoliceHeliService) searches where it last saw you.
--   WantedSince (server time, GetServerTimeNow) is set when heat goes from 0 to more, and cleared
--     with the heat. AIPoliceService uses it for the head start before patrols come.
-- Bounty for arresting someone = $500 per paid star + 25% of their carried cash. Stars that cost the
--   wanted player nothing pay no bounty and no arrest XP: fight stars (CombatStars, CombatService) and
--   breakout / hot-car stars (NoBountyStars, counted here). Both are trimmed as the heat goes down.
-- Chase radar (MinimapClient's cop blips and screen arrows): ReplicatedStorage attribute ChaseRadar =
--   "On" (AI patrols the whole chase, player cops only while seen), "Seen" (every cop only while a cop
--   sees you) or "Off". RADAR below picks it; "Split" = each live server picks On or Off at random, so
--   escape rates with and without the radar can be compared in the same week (Studio always gets On).
-- Analytics: every chase end is logged (value = stars) as ChaseEnd_<how>_<radar>_<PvP|AI>, e.g.
--   ChaseEnd_Escaped_On_AI (with _Rookie on the end for a rookie's gentle chase). <how> = Escaped (unseen timer, disguise, respray or banking at the Hideout),
--   Arrested or Left (quit while wanted); PvP = a player cop was on the server at some point in the chase.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local Disguises = require(ReplicatedStorage.Shared.Config.Disguises)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local Wanted = require(ReplicatedStorage.Shared.Config.Wanted)
local Telemetry = require(ServerScriptService.Services.Telemetry)

local HeatService = {}

-- Suspect Card (attributes on the wanted player, shown to cops):
--   SuspectOutfit - their look (hat + mask) when a camera or cop last saw them on foot
--   SuspectCar    - their car and its colour when a cop last saw them driving
-- Changing the look at a wardrobe or respraying the car while unseen clears that clue (DisguiseService).
local COLOR_WORDS = {
	{ "pink", Color3.fromRGB(255, 62, 165) }, { "cyan", Color3.fromRGB(34, 225, 255) },
	{ "purple", Color3.fromRGB(123, 47, 255) }, { "orange", Color3.fromRGB(255, 138, 61) },
	{ "yellow", Color3.fromRGB(255, 214, 10) }, { "mint", Color3.fromRGB(110, 242, 196) },
	{ "white", Color3.fromRGB(240, 240, 245) }, { "black", Color3.fromRGB(22, 22, 28) },
	{ "grey", Color3.fromRGB(128, 128, 136) }, { "red", Color3.fromRGB(220, 40, 50) },
	{ "blue", Color3.fromRGB(40, 70, 200) }, { "green", Color3.fromRGB(70, 150, 70) },
}
function HeatService.ColorWord(c)
	local best, bestD = "grey", math.huge
	for _, w in ipairs(COLOR_WORDS) do
		local o = w[2]
		local d = (c.R - o.R) ^ 2 + (c.G - o.G) ^ 2 + (c.B - o.B) ^ 2
		if d < bestD then
			best, bestD = w[1], d
		end
	end
	return best
end

function HeatService.LookOf(player)
	return Disguises.Describe(player:GetAttribute("LookHat"), player:GetAttribute("LookMask"))
end

local function noteClues(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local car = hum and hum.SeatPart and hum.SeatPart.Parent
	if car and car.PrimaryPart and car:GetAttribute("NCVehicle") then
		local text = (car:GetAttribute("DisplayName") or car.Name) .. " (" .. HeatService.ColorWord(car.PrimaryPart.Color) .. ")"
		if player:GetAttribute("SuspectCar") ~= text then
			player:SetAttribute("SuspectCar", text)
		end
	else
		local look = HeatService.LookOf(player)
		if player:GetAttribute("SuspectOutfit") ~= look then
			player:SetAttribute("SuspectOutfit", look)
		end
	end
end

local SIGHT_RANGE = 250
local HOT_ZONE = 60
local PING_EVERY = 20
local CHECK_EVERY = 0.5
-- Chase radar mode (see the header): "On", "Seen", "Off" or "Split". After a week or so of Split data,
-- set the winner here.
local RADAR = "On"

local lastSeenAt = {} -- [player] = os.clock()
local lastPing = {} -- [player] = os.clock()
local pvpChase = {} -- [player] = true once a player cop has been on the server during this chase
local eyes = {} -- [BasePart] = studs it sees: extra eyes (AI police cars, the police helicopter)

local notify, feed

local function now()
	return Workspace:GetServerTimeNow()
end

local function rootOf(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart")
end

function HeatService.GetHeat(player)
	return player:GetAttribute("Heat") or 0
end

-- Seconds unseen before the heat goes, and before the stars go hollow (Config.Wanted, by stars). A rookie
-- (Config.Tutorial.Rookie, before their first bag is banked) gets the shorter of that and theirs.
local function escapeFor(player, heat)
	local after = Wanted.For(heat).EscapeAfter
	return Tutorial.IsRookie(player) and math.min(after, Tutorial.Rookie.EscapeAfter) or after
end
local function hollowFor(player, heat)
	local after = Wanted.For(heat).HollowAfter
	return Tutorial.IsRookie(player) and math.min(after, Tutorial.Rookie.HollowAfter) or after
end

-- The LOSING THEM meter's two ends (see the header); from = nil clears them. os.clock and server time
-- meet here, so drifts under a quarter second are ignored (no attribute spam every tick).
local function setEscape(player, from, at)
	local oldAt, oldFrom = player:GetAttribute("EscapeAt"), player:GetAttribute("EscapeFrom")
	if from == nil then
		if oldAt ~= nil or oldFrom ~= nil then
			player:SetAttribute("EscapeFrom", nil)
			player:SetAttribute("EscapeAt", nil)
		end
	elseif typeof(oldAt) ~= "number" or typeof(oldFrom) ~= "number" or math.abs(oldAt - at) > 0.25
		or math.abs(oldFrom - from) > 0.25 then
		player:SetAttribute("EscapeFrom", from) -- before EscapeAt, so the meter never sees half a pair
		player:SetAttribute("EscapeAt", at)
	end
end

-- Stars that earn a bounty and arrest XP. Fight stars (CombatStars, set by CombatService) and
-- breakout / hot-car stars (NoBountyStars) don't, so friends can't stage them and arrest each
-- other for cash.
function HeatService.PaidStars(player)
	local free = (player:GetAttribute("CombatStars") or 0) + (player:GetAttribute("NoBountyStars") or 0)
	return math.max(0, HeatService.GetHeat(player) - free)
end

function HeatService.Bounty(player)
	return 500 * HeatService.PaidStars(player) + math.floor((player:GetAttribute("Carried") or 0) * 0.25)
end

-- Reasons whose stars cost the wanted player nothing yet (an empty bag): they pay no bounty.
-- carjack: taking a street car (CarjackService), so friends can't jack cars to be arrested for cash.
local NO_BOUNTY = { breakout = true, carboost = true, carjack = true, street_race = true }

-- A crime was seen (store camera, witness): add heat and mark where it happened.
function HeatService.Add(player, amount, reason)
	if player:GetAttribute("Side") ~= "Civilian" then
		return
	end
	local before = HeatService.GetHeat(player)
	local heat = math.clamp(before + amount, 0, 5)
	if before <= 0 and heat > 0 then
		player:SetAttribute("WantedSince", now()) -- set before Heat so both arrive together
	end
	player:SetAttribute("Heat", heat)
	if NO_BOUNTY[reason] and heat > before then
		player:SetAttribute("NoBountyStars", (player:GetAttribute("NoBountyStars") or 0) + heat - before)
	end
	lastSeenAt[player] = os.clock()
	local root = rootOf(player)
	if root then
		player:SetAttribute("LastSeen", root.Position)
	end
	player:SetAttribute("HeatReason", reason)
	-- The store camera (or the prison guards) saw what they look like.
	noteClues(player)
	-- A rookie's first chase: tell them the cops are going easy and what to do (Config.Tutorial.Rookie).
	if before <= 0 and heat > 0 and notify and Tutorial.IsRookie(player) then
		notify:FireClient(player, "RookieChase")
	end
end

-- How each chase ended, for analytics (reasons passed to Clear; "role" = switched side, not logged).
local CHASE_END = {
	escaped = "Escaped", disguise = "Escaped", spray = "Escaped", hideout = "Escaped", arrested = "Arrested",
}

-- One chase-end event, split by this server's radar mode (the attribute, so a live change in a Studio
-- test is logged right too) and whether player cops were in it.
local function logChaseEnd(player, how, heat)
	local radar = tostring(ReplicatedStorage:GetAttribute("ChaseRadar") or "On")
	-- (_Rookie: a first-robbery chase with the gentle AI police, Config.Tutorial.Rookie.)
	Telemetry.Custom(player, "ChaseEnd_" .. how .. "_" .. radar .. (pvpChase[player] and "_PvP" or "_AI")
		.. (Tutorial.IsRookie(player) and "_Rookie" or ""), heat)
end

function HeatService.Clear(player, reason)
	local heat = HeatService.GetHeat(player)
	if heat > 0 and CHASE_END[reason] then
		logChaseEnd(player, CHASE_END[reason], heat)
	end
	player:SetAttribute("Heat", 0)
	player:SetAttribute("HeatSpotted", false)
	player:SetAttribute("LastSeen", nil)
	player:SetAttribute("SuspectOutfit", nil)
	player:SetAttribute("SuspectCar", nil)
	player:SetAttribute("WantedSince", nil)
	setEscape(player, nil)
	lastSeenAt[player] = nil
	lastPing[player] = nil
	pvpChase[player] = nil
end

-- Escape XP and the "lose the cops" challenges leave fight stars out, like the bounty does (friends
-- could otherwise stage fights for them). CombatStars is still set here: it's trimmed after Clear.
local function escapeStars(player, heat)
	return math.max(0, heat - (player:GetAttribute("CombatStars") or 0))
end

-- Drop some heat (disguise change, respray). Reaching 0 counts as losing the cops.
function HeatService.Reduce(player, amount, reason)
	local before = HeatService.GetHeat(player)
	local heat = math.max(0, before - amount)
	if heat == 0 then
		local paid = escapeStars(player, before)
		if paid > 0 then
			require(game:GetService("ServerScriptService").Services.ProgressService).Event(player, "Escape", paid)
		end
		HeatService.Clear(player, reason)
		notify:FireClient(player, "LostTheCops")
	else
		player:SetAttribute("Heat", heat)
	end
end

-- range: how far this eye sees (studs); a cop's SIGHT_RANGE if left out.
function HeatService.RegisterEye(part, range)
	eyes[part] = type(range) == "number" and range > 0 and range or SIGHT_RANGE
end

function HeatService.UnregisterEye(part)
	eyes[part] = nil
end

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.IgnoreWater = true

local function canSee(fromPos, target, range)
	local toTarget = target.Position - fromPos
	if toTarget.Magnitude > (range or SIGHT_RANGE) then
		return false
	end
	local hit = Workspace:Raycast(fromPos, toTarget, losParams)
	return hit == nil or hit.Instance:IsDescendantOf(target.Parent)
end

local function tick()
	-- Everything that isn't a wall: characters and cars never block sight.
	local exclude = { Workspace:FindFirstChild("Vehicles") }
	local copEyes = {} -- { position, range }
	local playerCops = false
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
		if p:GetAttribute("Side") == "Cop" then
			playerCops = true
			local root = rootOf(p)
			if root then
				table.insert(copEyes, { root.Position + Vector3.new(0, 2, 0), SIGHT_RANGE })
			end
		end
	end
	for part, range in pairs(eyes) do
		if part.Parent then
			table.insert(copEyes, { part.Position + Vector3.new(0, 3, 0), range })
		else
			eyes[part] = nil
		end
	end
	losParams.FilterDescendantsInstances = exclude

	local alarms = {}
	for _, site in ipairs(Workspace.Heists:GetChildren()) do
		if now() < (site:GetAttribute("AlarmUntil") or 0) then
			table.insert(alarms, site:GetPivot().Position)
		end
	end

	local clock = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local heat = HeatService.GetHeat(player)
		if heat > 0 and playerCops and player:GetAttribute("Side") == "Civilian" then
			pvpChase[player] = true -- analytics only (logChaseEnd)
		end
		local root = heat > 0 and rootOf(player)
		if root then
			local spotted = false
			for _, eye in ipairs(copEyes) do
				if canSee(eye[1], root, eye[2]) then
					spotted = true
					break
				end
			end
			if not spotted then
				for _, pos in ipairs(alarms) do
					if (root.Position - pos).Magnitude < HOT_ZONE then
						spotted = true
						break
					end
				end
			end
			if spotted then
				lastSeenAt[player] = clock
				player:SetAttribute("LastSeen", root.Position)
				noteClues(player)
				if not player:GetAttribute("HeatSpotted") then
					player:SetAttribute("HeatSpotted", true)
				end
				setEscape(player, nil) -- seen: the LOSING THEM meter snaps back
			else
				-- (Heat set straight on the attribute has no sighting yet: its unseen clock starts now.)
				lastSeenAt[player] = lastSeenAt[player] or clock
				local since = clock - lastSeenAt[player]
				if player:GetAttribute("HeatSpotted") and since > hollowFor(player, heat) then
					player:SetAttribute("HeatSpotted", false)
				end
				if since > escapeFor(player, heat) then
					local paid = escapeStars(player, heat)
					if paid > 0 then
						require(game:GetService("ServerScriptService").Services.ProgressService).Event(player, "Escape", paid)
						player:SetAttribute("Evasions", (player:GetAttribute("Evasions") or 0) + 1)
					end
					HeatService.Clear(player, "escaped")
					notify:FireClient(player, "LostTheCops")
					feed:FireAllClients("Escaped", { Name = player.DisplayName })
				else
					-- Hollow stars: publish the meter's ends (the same sum as the check above, so the
					-- meter fills exactly when the heat goes). A new crime or a lost star moves them.
					if not player:GetAttribute("HeatSpotted") then
						local from = now() - since
						setEscape(player, from, from + escapeFor(player, heat))
					end
					if heat >= 4 and clock - (lastPing[player] or 0) > PING_EVERY then
						lastPing[player] = clock
						player:SetAttribute("LastSeen", root.Position)
					end
				end
			end
		elseif heat > 0 and player:GetAttribute("Side") ~= "Civilian" then
			HeatService.Clear(player, "role")
		end
	end
end

-- A couple of fallbacks (HideoutService, HeistService) set the Heat attribute directly, so
-- WantedSince (and clearing the LOSING THEM meter and the chase's timers at 0) also follow the
-- attribute itself.
local function watchWanted(player)
	player:GetAttributeChangedSignal("Heat"):Connect(function()
		local heat = player:GetAttribute("Heat") or 0
		if heat > 0 and player:GetAttribute("WantedSince") == nil then
			player:SetAttribute("WantedSince", now())
		elseif heat <= 0 and player:GetAttribute("WantedSince") ~= nil then
			player:SetAttribute("WantedSince", nil)
		end
		if heat <= 0 then
			setEscape(player, nil)
			lastSeenAt[player] = nil -- a stale sighting must not end the next chase early
			pvpChase[player] = nil
		end
		-- No-bounty stars go when the heat goes (CombatService trims CombatStars the same way).
		local free = player:GetAttribute("NoBountyStars")
		if free and free > heat then
			player:SetAttribute("NoBountyStars", heat > 0 and heat or nil)
		end
	end)
end

function HeatService.Init()
	notify = Remotes.Event("Notify")
	feed = Remotes.Event("Feed")
	-- This server's chase radar, read by every client's MinimapClient.
	local radarMode = RADAR
	if radarMode == "Split" then
		radarMode = RunService:IsStudio() and "On" or (Random.new():NextNumber() < 0.5 and "On" or "Off")
	end
	ReplicatedStorage:SetAttribute("ChaseRadar", radarMode)
	Players.PlayerAdded:Connect(watchWanted)
	for _, p in ipairs(Players:GetPlayers()) do
		watchWanted(p)
	end
	task.spawn(function()
		while true do
			task.wait(CHECK_EVERY)
			local ok, err = pcall(tick)
			if not ok then
				warn("[HeatService] " .. tostring(err))
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		local heat = HeatService.GetHeat(p)
		if heat > 0 and p:GetAttribute("Side") == "Civilian" then
			logChaseEnd(p, "Left", heat) -- quit mid-chase
		end
		lastSeenAt[p] = nil
		lastPing[p] = nil
		pvpChase[p] = nil
	end)
end

return HeatService
