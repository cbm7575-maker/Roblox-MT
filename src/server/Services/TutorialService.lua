-- TutorialService (ModuleScript, ServerScriptService.Services.TutorialService)
-- The first-session guide (Config.Tutorial). Progress is the saved number data.flags.tutorial,
-- mirrored to the player attribute "TutorialStep" (0 = not started ... #Steps = finished).
--   * The client reports the steps it can see (sat in its car, opened the phone); the server checks
--     what it can (the bag for "rob", banking for "bank") and only ever moves forward by one.
--   * Finishing pays a one-time welcome bonus. New players then carry on with JourneyService's goals.
--   * The steps used to run phone, car, rob, bank; they now run car, rob, bank, phone. Saves from
--     before (no data.flags.tutorialOrder) are moved to the new order once, on load: a finished guide
--     stays finished, and a half-done one keeps the steps it had (the phone step just comes again last).
--     TutorialService.Migrate(data) does the same for other services that read the saved step.
-- Remote: TutorialStep(step) client -> server; "Skip" (string) ends it early without the bonus.
--   * The FirstRob funnel (Nov 8 2026: of the new players who got into a car, 2 in 3 left before robbing
--     anything, and the onboarding funnel can't say where). A recurring funnel "FirstRob" (Creator Hub >
--     Analytics > Funnels) for every player on the rob step, one run per server visit. Each step is logged
--     once and in order (reaching a later one logs any skipped before it):
--       1 InCar      the car step is done (or they joined already on the rob step)
--       2 Moving     FR.MOVED studs from where they were when the step began
--       3 NearStore  within FR.NEAR studs of a tier-1 site's Rob point (all open for a rookie)
--       4 OnFoot     within FR.AT studs of one, out of the car
--       5 Holding    began a robbery: a Rob hold or a clerk at gunpoint (HeistService -> FirstRobNote)
--       6 Robbed     the rob step is done
--     Leaving the game on the rob step logs custom event "FirstRobQuit": the last step's name in field 1
--     and the seconds spent on the step as its value.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Heists = require(ReplicatedStorage.Shared.Config.Heists)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local DataService = require(ServerScriptService.Services.DataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)

local TutorialService = {}

local ORDER_VERSION = 2 -- car, rob, bank, phone

-- Old order: 1 = phone, 2 = + car, 3 = + rob. In the new order that's 0, 1 (car) and 2 (car, rob).
local function migrate(data)
	if data.flags.tutorialOrder == ORDER_VERSION then
		return
	end
	local done = data.flags.tutorial or 0
	if done > 0 and done < #Tutorial.Steps then
		data.flags.tutorial = done - 1
	end
	data.flags.tutorialOrder = ORDER_VERSION
end

-- The same move for any loaded save (once; calling it again does nothing). JourneyService calls it
-- before reading data.flags.tutorial, so its check never depends on whose OnLoaded runs first.
function TutorialService.Migrate(data)
	data.flags = data.flags or {}
	migrate(data)
end

local function current(player)
	local data = DataService.Get(player)
	if not data then
		return nil, nil
	end
	data.flags = data.flags or {}
	migrate(data)
	return data.flags.tutorial or 0, data
end

local Telemetry = require(ServerScriptService.Services.Telemetry)

-- Onboarding funnel: 1 Joined, 2 PickedSide, then 3.. the tutorial steps (JourneyService goes on after).
local FUNNEL_OFFSET = 2

------------------------------------------------------------------ the FirstRob funnel (see the header)

local FIRST_ROB = { "InCar", "Moving", "NearStore", "OnFoot", "Holding", "Robbed" }
local FR = { MOVED = 80, NEAR = 80, AT = 20, EVERY = 1 }
local tracking = {} -- [player] = { session = id, stage = steps logged, began = os.clock(), from = Vector3 }
local robPoints -- the tier-1 Rob points' positions (sites never move), found on first use

local function reach(player, stage)
	local st = tracking[player]
	if not st then
		return
	end
	while st.stage < stage do
		st.stage += 1
		Telemetry.FunnelStep(player, "FirstRob", st.session, st.stage, FIRST_ROB[st.stage])
	end
end

local function startFirstRob(player)
	if tracking[player] then
		return
	end
	tracking[player] = { session = tostring(player.UserId) .. "-" .. tostring(os.time()), stage = 0, began = os.clock() }
	reach(player, 1)
end

-- HeistService says a rookie began a robbery ("Holding"); any FIRST_ROB step name works.
function TutorialService.FirstRobNote(player, name)
	for i, n in ipairs(FIRST_ROB) do
		if n == name then
			reach(player, i)
			return
		end
	end
end

local function rookiePoints()
	if robPoints then
		return robPoints
	end
	local list = {}
	local sites = Workspace:FindFirstChild("Heists")
	for _, site in ipairs(sites and sites:GetChildren() or {}) do
		local def = Heists.Types[site:GetAttribute("HeistId")]
		local point = def and def.Tier <= Tutorial.RookieRob.MaxTier and site:FindFirstChild("RobPoint", true)
		if point and point:IsA("BasePart") then
			table.insert(list, point.Position)
		end
	end
	if #list > 0 then
		robPoints = list -- (none yet: the city may still be loading, so look again next time)
	end
	return list
end

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Every FR.EVERY seconds: how far along the way to a store each tracked player has got.
local function watchFirstRob()
	for player, st in pairs(tracking) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local here = root.Position
			st.from = st.from or here
			if flatDistance(here, st.from) >= FR.MOVED then
				reach(player, 2)
			end
			local nearest = math.huge
			for _, point in ipairs(rookiePoints()) do
				nearest = math.min(nearest, flatDistance(here, point))
			end
			if nearest <= FR.NEAR then
				reach(player, 3)
			end
			if nearest <= FR.AT and not hum.SeatPart then
				reach(player, 4)
			end
		end
	end
end

local function set(player, data, step)
	data.flags.tutorial = step
	player:SetAttribute("TutorialStep", step)
	Telemetry.Funnel(player, FUNNEL_OFFSET + step, "Tutorial_" .. Tutorial.Steps[step].Id)
	local id = Tutorial.Steps[step].Id
	if id == "car" then
		startFirstRob(player)
	elseif id == "rob" then
		reach(player, #FIRST_ROB)
		tracking[player] = nil
	end
	if step >= #Tutorial.Steps and not data.flags.tutorialPaid then
		data.flags.tutorialPaid = true
		EconomyService.AddCash(player, Tutorial.Bonus, "tutorial")
		Remotes.Event("TutorialDone"):FireClient(player, Tutorial.Bonus)
	end
end

-- Try to complete step `step` (1-based: finishing step 1 moves progress from 0 to 1).
local function advance(player, step, fromServer)
	local done, data = current(player)
	if not data or step ~= done + 1 or step > #Tutorial.Steps then
		return
	end
	local def = Tutorial.Steps[step]
	if def.ServerOnly and not fromServer then
		return
	end
	if def.Id == "rob" and (player:GetAttribute("Carried") or 0) <= 0 and not fromServer then
		return
	end
	set(player, data, step)
end

function TutorialService.Advance(player, stepId)
	for i, def in ipairs(Tutorial.Steps) do
		if def.Id == stepId then
			advance(player, i, true)
			return
		end
	end
end

function TutorialService.Init()
	Remotes.Event("TutorialDone") -- create it now: clients wait for it at start-up
	Remotes.Event("TutorialStep").OnServerEvent:Connect(function(player, step)
		if not RateLimit.Allow(player, "Tutorial", 2, 4) then
			return
		end
		if step == "Skip" then
			local _, data = current(player)
			if data then
				data.flags.tutorial = #Tutorial.Steps
				data.flags.tutorialPaid = true -- skipping forfeits the bonus
				player:SetAttribute("TutorialStep", #Tutorial.Steps)
			end
			return
		end
		if type(step) == "number" then
			advance(player, math.floor(step), false)
		end
	end)
	EconomyService.OnBanked(function(player)
		TutorialService.Advance(player, "bank")
	end)
	DataService.OnLoaded(function(player)
		local done = current(player)
		player:SetAttribute("TutorialStep", done or 0)
		if done ~= nil and done > 0 and Tutorial.Steps[done].Id == "car" then
			startFirstRob(player) -- (back on the rob step: a new FirstRob run for this visit)
		end
		if (done or 0) == 0 then
			Telemetry.Funnel(player, 1, "Joined")
			local conn
			conn = player:GetAttributeChangedSignal("HasPicked"):Connect(function()
				if player:GetAttribute("HasPicked") then
					conn:Disconnect()
					Telemetry.Funnel(player, 2, "PickedSide")
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local st = tracking[player]
		tracking[player] = nil
		if st and st.stage > 0 then
			Telemetry.Custom(player, "FirstRobQuit_" .. FIRST_ROB[st.stage], math.floor(os.clock() - st.began))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(FR.EVERY)
			local ok, err = pcall(watchFirstRob)
			if not ok then
				warn("[TutorialService] FirstRob: " .. tostring(err))
			end
		end
	end)
end

return TutorialService
