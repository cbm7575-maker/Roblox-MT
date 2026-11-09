-- HeistService (ModuleScript, ServerScriptService.Services.HeistService)
-- Runs every heist site in Workspace.Heists (models with a HeistId attribute and a RobPoint part).
--   * Rotation: Heists.OpenCount heist TYPES are open at a time; each stays open 4-6 minutes, then
--     another takes its place. The bank is a server event every 15 minutes with a warning first.
--     A type leaving the rotation (or the bank event ending) shuts its sites for NEW holds only: a hold
--     already running finishes and is paid, unless somebody else emptied that site first.
--   * Robbing: hold the Rob prompt for the type's Hold time. The server times the hold itself
--     (PromptButtonHoldBegan -> Triggered), checks side, distance and on-foot, then pays into the bag.
--   * Each robbed site cools down; the alarm reaches cops after the head start (Heists.AlarmDelay).
--   * Rookie robbery (Config.Tutorial.RookieRob / CanRookieRob): a citizen who hasn't banked a first bag
--     and has an empty bag may rob any tier-1 site, open or shut, with the shorter rookie hold (at the till
--     or at a clerk's gunpoint). A shut site robbed that way stays exactly as it was for everyone else
--     (onRobbed's `personal`: no cooldown, no prep or LastRobbedBy change); an open one is robbed as usual.
--     Each hold a rookie starts is noted for TutorialService's FirstRob funnel.
--   * Rank-locked heists (MinRank, e.g. the bank): the rank check comes first on both prompts, so a
--     low-rank player who taps the "Rank 3 needed" prompt (HeistClient relabels it) is told why.
--   * Prep (bank fuse box, yacht panel): the main hold only has to START inside the prep window, so
--     the prep is checked when the hold begins (a vault hold already running keeps it). A fresh prep
--     is protected from other crews for PREP_LOCK seconds (time to walk to the vault); after that
--     anyone may redo it. Nobody can refresh their own live prep, so no one can hold the panel
--     forever. Tapping a locked panel says why (HeistClient relabels it "Done" / "Taken").
--     Until the player's crew has a live prep, HeistClient shows the vault's Rob prompt locked on that
--     player's device ("Cut the power first", no hold, the panel marked in gold), from the attributes
--     below. A tap on it still lands here: the check below stays the real one, and its answer
--     (NeedPrep_<type>) goes through prepRefused, so mashing E on the locked prompt can't stack toasts.
--   * Big heists (Heists.BigTier: Coastal Bank, Sea Dream) are crew work. The helpers are the robber's
--     Civilian crewmates within Heists.BigCrewRange studs when the robbery pays (cops and prisoners
--     don't count). Each of them and the robber add 1 to the saved stat "BigHeists" (player attribute,
--     DataService), which unlocks the heist-locked cars (Config.Vehicles UnlockHeists, checked by
--     GarageService).
--   * Crew cuts (big heists with 1+ helpers): the pot is the payout as worked out for the robber (night,
--     the robber's VIP, CrewService.BonusFor) x (1 + Heists.CrewShareBonus per helper). Everyone gets
--     floor(pot / (1 + helpers)) in their own bag, and each bag can fill up on its own. Each helper also
--     gets the heist's heat (they were there) and a HeistResult of their own. Only the robber gets the
--     heist XP, the Heists count and the challenge progress (ProgressService.Event is called for the
--     robber alone). Solo robberies and tier 1-2 heists pay exactly what they always did.
--   * HeistResult to the robber: { Type, Payout (what fit), BagFull, LeftBehind (what didn't), Wanted,
--     Crew (1 + helpers) }. A helper's has the same fields plus Cut = true and From (the robber's
--     DisplayName).
--   * Store clerks (Heists.Types[...].Clerk: Glow Mart, Fuel Stop, Sparkle & Co.): a shop assistant
--     behind the counter, for everyone to see (one of PedService's looks, anchored, in Workspace.NPCs
--     with NPCKind = "Clerk", AimTarget and Site; their pose is the model attribute Pose, which
--     HeistClient shows with PoseClient). A robber pointing a gun at them (HeistClient: RequestStoreRob)
--     starts it: the server checks a gun in hand, 24 studs, facing them, an open store and an idle
--     clerk. Hands up, "Okay, okay! Don't shoot!", a bag filled for Clerk.Fill seconds while the robber
--     stays within Clerk.Range (StoreRob "Start" / "Done" / "Fail" to the robber), then the usual
--     robbery (onRobbed) with the Clerk.Bonus on top. A silent alarm with chance Clerk.Alarm when it
--     starts. Shot or punched (CombatService -> HeistService.NPCHit) they go down for CLERK_DOWN seconds
--     (a star for the attacker; a robbery in progress fails), then a new clerk takes over. Without a gun
--     the till's Rob prompt works as before (HeistClient hides it from gun owners while a clerk stands).
--   * Club Nova's drill (Heists.Types.ClubNova.Drill): the Rob prompt sets the drill (Drill.Start s; the
--     alarm and a star at once), the robber keeps within Drill.Range while it runs (DrillBy / DrillDoneAt),
--     then the same prompt empties the safe (Drill.Grab s) for them alone. HeistClient labels each stage.
-- Site attributes (read by clients): Robbable, ReopenAt, AlarmUntil (server time, GetServerTimeNow),
--   MinRank (free-roam rank needed, if any), PrepUntil / PrepBy / PrepLockUntil (the live prep),
--   ClerkUp (a clerk stands behind the counter), DrillBy (UserId) / DrillDoneAt (server time).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Heists = require(ReplicatedStorage.Shared.Config.Heists)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local EconomyService = require(ServerScriptService.Services.EconomyService)

local HeistService = {}

local sitesByType = {} -- [typeId] = { site models }
local typeOpen = {} -- [typeId] = true while open in rotation
local typeCloseAt = {} -- [typeId] = server time it leaves the rotation
local typeRestUntil = {} -- [typeId] = server time before which it can't reopen
local holdStart = {} -- [site] = { [userId] = { t = os.clock(), prepOk = prep was theirs when the hold began, open = the site was robbable then } }
local rng = Random.new()
local PREP_LOCK = 45 -- seconds a fresh prep can't be redone by another crew (capped at the window)
local prepToastAt = {} -- [userId] = os.clock() of the last "PrepTaken" / "PrepAlreadyDone" toast

local feed, notify, heistResult, storeRob
local clerks = {} -- [site] = { model, root, hum, site, state = "Idle" | "Robbed" | "Down", robber, token, downAt }
local CLERK_DOWN = 20 -- seconds a clerk who was shot or punched lies there before a new one takes over
local CLERK_REACH = 24 -- studs: how close the gun must be when the robbery starts
local npcFolder

local function now()
	return Workspace:GetServerTimeNow()
end

-- HeatService is optional until step 2.4; this keeps heists working either way.
local function addHeat(player, amount)
	local ok, HeatService = pcall(require, ServerScriptService.Services:FindFirstChild("HeatService"))
	if ok and HeatService and HeatService.Add then
		HeatService.Add(player, amount, "heist")
	else
		player:SetAttribute("Heat", math.min(5, (player:GetAttribute("Heat") or 0) + amount))
	end
end

local function siteRobbable(site)
	local typeId = site:GetAttribute("HeistId")
	return typeOpen[typeId] == true and now() >= (site:GetAttribute("ReopenAt") or 0)
end

-- A rookie began a robbery (a Rob hold, or a clerk filling their bag): one step of TutorialService's
-- FirstRob funnel. Required here, not at the top: TutorialService needn't load before this file.
local function noteRookieHold(player)
	pcall(function()
		require(ServerScriptService.Services.TutorialService).FirstRobNote(player, "Holding")
	end)
end

-- True while this site's prep was done by this player or their crew and its window is still open.
local function prepIsMine(site, player)
	local by = site:GetAttribute("PrepBy")
	local mine = by ~= nil and (by == player:GetAttribute("Crew") or by == "u" .. player.UserId)
	return mine and (site:GetAttribute("PrepUntil") or 0) >= now()
end

-- Why a prep panel (or a vault still waiting for its prep) said no; at most one toast every 3 s, so
-- tapping the panel or the locked vault can't stack them.
local function prepRefused(player, key)
	local t = os.clock()
	if t - (prepToastAt[player.UserId] or -math.huge) >= 3 then
		prepToastAt[player.UserId] = t
		notify:FireClient(player, key)
	end
end

local function refreshSite(site)
	-- The prompt stays enabled on the server; each client shows it only to robbers when the site is
	-- Robbable (HeistClient). Triggered re-checks everything here.
	local robbable = siteRobbable(site)
	if site:GetAttribute("Robbable") ~= robbable then
		site:SetAttribute("Robbable", robbable)
	end
end

local function setTypeOpen(typeId, open)
	typeOpen[typeId] = open or nil
	for _, site in ipairs(sitesByType[typeId] or {}) do
		site:SetAttribute("TypeOpen", open)
		refreshSite(site)
	end
end

-- Keep OpenCount rotating heist types open.
local function rotate()
	local t = now()
	local openCount = 0
	for typeId, def in pairs(Heists.Types) do
		if not def.Event and typeOpen[typeId] then
			if t >= (typeCloseAt[typeId] or math.huge) then
				setTypeOpen(typeId, false)
				typeRestUntil[typeId] = t + 90
			else
				openCount += 1
			end
		end
	end
	local candidates = {}
	for typeId, def in pairs(Heists.Types) do
		if not def.Event and not typeOpen[typeId] and sitesByType[typeId] and t >= (typeRestUntil[typeId] or 0) then
			table.insert(candidates, typeId)
		end
	end
	while openCount < Heists.OpenCount and #candidates > 0 do
		local typeId = table.remove(candidates, rng:NextInteger(1, #candidates))
		typeCloseAt[typeId] = t + rng:NextInteger(240, 360)
		setTypeOpen(typeId, true)
		openCount += 1
		feed:FireAllClients("HeistOpen", { Type = typeId })
	end
	for _, sites in pairs(sitesByType) do
		for _, site in ipairs(sites) do
			refreshSite(site)
		end
	end
end

-- The bank opens as a server-wide event.
local function bankLoop()
	local sites = sitesByType.CoastalBank
	if not sites then
		return
	end
	local first = game:GetService("RunService"):IsStudio() and 90 or Heists.BankEvery
	local opensAt = now() + first
	ReplicatedStorage:SetAttribute("BankOpensAt", opensAt)
	while true do
		task.wait(1)
		local t = now()
		if not typeOpen.CoastalBank and t >= opensAt - Heists.BankWarning and not ReplicatedStorage:GetAttribute("BankWarned") then
			ReplicatedStorage:SetAttribute("BankWarned", true)
			feed:FireAllClients("BankSoon", { OpensAt = opensAt })
		end
		if not typeOpen.CoastalBank and t >= opensAt then
			typeCloseAt.CoastalBank = t + Heists.BankOpenFor
			for _, site in ipairs(sites) do
				site:SetAttribute("ReopenAt", 0)
			end
			setTypeOpen("CoastalBank", true)
			feed:FireAllClients("BankOpen", {})
		elseif typeOpen.CoastalBank and (t >= typeCloseAt.CoastalBank or not siteRobbable(sites[1])) then
			setTypeOpen("CoastalBank", false)
			opensAt = t + Heists.BankEvery
			ReplicatedStorage:SetAttribute("BankOpensAt", opensAt)
			ReplicatedStorage:SetAttribute("BankWarned", false)
		end
	end
end

-- One more big heist for this player (only once their save has loaded, or the load would overwrite it).
local function addBigHeist(p, typeId)
	if not p:GetAttribute("DataLoaded") then
		return
	end
	local n = (p:GetAttribute("BigHeists") or 0) + 1
	p:SetAttribute("BigHeists", n)
	require(ServerScriptService.Services.Telemetry).Custom(p, "BigHeist_" .. typeId, n)
end

-- The robber's helpers on a big heist: every Civilian crewmate within BigCrewRange studs of them right
-- now (on the fuse box, at the door). Cops and prisoners don't count. Empty for a robber with no crew.
local function bigHelpers(player)
	local helpers = {}
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local crew = require(ServerScriptService.Services.CrewService).CrewOf(player)
	if not root or not crew then
		return helpers
	end
	for _, mate in ipairs(crew.members) do
		local r = mate ~= player and mate:GetAttribute("Side") == "Civilian" and mate.Character
			and mate.Character:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - root.Position).Magnitude <= Heists.BigCrewRange then
			table.insert(helpers, mate)
		end
	end
	return helpers
end

-- The robber and every helper get the credit.
local function creditBigHeist(player, typeId, helpers)
	addBigHeist(player, typeId)
	for _, mate in ipairs(helpers) do
		addBigHeist(mate, typeId)
	end
end

-- A helper's cut of a big heist: into their own bag (it may not all fit), the heist's heat, and a
-- result stamp of their own. No XP: that stays with the robber.
local function payCut(mate, robber, typeId, def, cut, crewSize)
	local fits = EconomyService.AddCarried(mate, cut, "heistcut:" .. typeId)
	require(ServerScriptService.Services.Telemetry).Custom(mate, "HeistCut_" .. typeId, fits)
	addHeat(mate, def.Heat)
	heistResult:FireClient(mate, {
		Type = typeId, Payout = fits, BagFull = fits < cut, LeftBehind = cut - fits,
		Wanted = (mate:GetAttribute("Heat") or 0) > 0, Crew = crewSize, Cut = true, From = robber.DisplayName,
	})
end

-- personal: a rookie robbing a site that's shut for everyone else (Tutorial.RookieRob): they're paid as
-- usual, but the site is left as it was (no cooldown, no prep or LastRobbedBy change).
local function onRobbed(player, site, def, mult, personal)
	local typeId = site:GetAttribute("HeistId")
	local big = def.Tier == Heists.BigTier
	local payout = math.floor(rng:NextInteger(def.Payout[1], def.Payout[2]) * (mult or 1)) -- (mult: a clerk's bonus)
	-- Neon nights: heists pay 25% more after dark (WorldService sets IsNight).
	if Workspace:GetAttribute("IsNight") then
		payout = math.floor(payout * 1.25)
	end
	if player:GetAttribute("Pass_VIP") then
		payout = math.floor(payout * (1 + Shop.VIPCashBonus))
	end
	-- Crewmate nearby +20%, friend in the server +10% (CrewService).
	local bonus = require(ServerScriptService.Services.CrewService).BonusFor(player)
	if bonus > 0 then
		payout = math.floor(payout * (1 + bonus))
	end
	-- Big heist with crew helping: the pot grows by CrewShareBonus per helper and is split evenly (the
	-- helpers are looked for once, here, so the cuts and the BigHeists credit go to the same people).
	local helpers = big and bigHelpers(player) or {}
	local crewSize = 1 + #helpers
	if #helpers > 0 then
		local pot = payout * (1 + (Heists.CrewShareBonus or 0.5) * #helpers)
		payout = math.floor(pot / crewSize)
	end
	local fits = EconomyService.AddCarried(player, payout, "heist:" .. typeId)
	require(game:GetService("ServerScriptService").Services.ProgressService).Event(player, "Heist", def.Tier)
	require(ServerScriptService.Services.Telemetry).Custom(player, "Heist_" .. typeId, fits)
	addHeat(player, def.Heat)
	player:SetAttribute("Heists", (player:GetAttribute("Heists") or 0) + 1)
	if big then
		creditBigHeist(player, typeId, helpers)
	end
	if not personal then
		site:SetAttribute("ReopenAt", now() + def.Cooldown)
		site:SetAttribute("PrepUntil", nil)
		site:SetAttribute("PrepBy", nil)
		site:SetAttribute("PrepLockUntil", nil)
		site:SetAttribute("LastRobbedBy", player.UserId)
		refreshSite(site)
	end
	heistResult:FireClient(player, {
		Type = typeId, Payout = fits, BagFull = fits < payout, LeftBehind = payout - fits,
		Wanted = (player:GetAttribute("Heat") or 0) > 0, Crew = crewSize,
	})
	for _, mate in ipairs(helpers) do
		payCut(mate, player, typeId, def, payout, crewSize)
	end
	feed:FireAllClients("HeistStarted", { Type = typeId, Site = site.Name })
	-- Head start, then the alarm goes out to the cops.
	task.delay(Heists.AlarmDelay, function()
		if site.Parent then
			site:SetAttribute("AlarmUntil", now() + Heists.AlarmSeconds)
			feed:FireAllClients("HeistAlarm", { Type = typeId, Site = site.Name, Position = site:GetPivot().Position })
		end
	end)
end

------------------------------------------------------------------ store clerks

local function alarmNow(site)
	site:SetAttribute("AlarmUntil", now() + Heists.AlarmSeconds)
	feed:FireAllClients("HeistAlarm", { Type = site:GetAttribute("HeistId"), Site = site.Name, Position = site:GetPivot().Position })
end

-- Which way this store's counter faces the shop floor: the LookVector of a "Counter" part next to the
-- till (Art.HeistFronts builds every counter in the store's own frame, whose -Z faces the street). nil
-- without a counter (an ATM, or the art isn't built): no clerk then.
local function counterFront(point)
	for _, part in ipairs(Workspace:GetPartBoundsInRadius(point.Position, 14)) do
		if part.Name == "Counter" and part:IsA("BasePart") then
			local look = Vector3.new(part.CFrame.LookVector.X, 0, part.CFrame.LookVector.Z)
			if look.Magnitude > 0.5 then
				return look.Unit
			end
		end
	end
	return nil
end

local function clerkPose(c, pose)
	if c.model.Parent then
		c.model:SetAttribute("Pose", pose) -- (HeistClient poses it on every device with PoseClient)
	end
end

-- A speech bubble over the clerk's head for everyone, for `seconds`.
local function clerkSay(c, text, seconds)
	local head = c.model:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = head:FindFirstChild("Say")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "Say"
		gui.Size = UDim2.fromOffset(220, 34)
		gui.StudsOffset = Vector3.new(0, 2.6, 0)
		gui.MaxDistance = 80
		gui.AlwaysOnTop = true
		gui.Parent = head
		local l = Instance.new("TextLabel")
		l.Name = "Text"
		l.Size = UDim2.fromScale(1, 1)
		l.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		l.BackgroundTransparency = 0.05
		l.TextColor3 = Color3.fromRGB(20, 20, 28)
		l.Font = Enum.Font.GothamBold
		l.TextScaled = true
		l.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = l
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
		pad.Parent = l
	end
	gui.Text.Text = text
	gui.Enabled = true
	c.sayToken = (c.sayToken or 0) + 1
	local token = c.sayToken
	task.delay(seconds, function()
		if c.sayToken == token and gui.Parent then
			gui.Enabled = false
		end
	end)
end

-- A clerk behind this store's counter: one of PedService's looks, standing still and anchored, facing
-- the shop floor. nil when the looks aren't built yet or the store has no counter (tried again later).
local function spawnClerk(site)
	local point = site:FindFirstChild("RobPoint", true)
	local templates = ReplicatedStorage:FindFirstChild("PedTemplates")
	local list = templates and templates:GetChildren() or {}
	local front = point and point:IsA("BasePart") and counterFront(point)
	if not front or #list == 0 then
		return nil
	end
	local spot = point.Position - front * 3.2 -- (behind the till: the counter is 3 deep)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { npcFolder }
	local hit = Workspace:Raycast(spot + Vector3.new(0, 4, 0), Vector3.new(0, -12, 0), params)
	local floorY = hit and hit.Position.Y or (point.Position.Y - point.Size.Y / 2)
	local model = list[rng:NextInteger(1, #list)]:Clone()
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not hum or not root then
		model:Destroy()
		return nil
	end
	hum.BreakJointsOnDeath = false
	local y = floorY + hum.HipHeight + root.Size.Y / 2
	local at = Vector3.new(spot.X, y, spot.Z)
	model:PivotTo(CFrame.lookAt(at, at + front))
	root.Anchored = true
	model.Name = "Clerk"
	model:SetAttribute("NPCKind", "Clerk")
	model:SetAttribute("AimTarget", true)
	model:SetAttribute("Site", site.Name)
	model.Parent = npcFolder
	pcall(function()
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local anim = Instance.new("Animation")
		anim.AnimationId = "rbxassetid://507766388" -- (Roblox's stock R15 idle)
		local track = animator:LoadAnimation(anim)
		track.Looped = true
		track:Play()
	end)
	local c = { model = model, root = root, hum = hum, site = site, state = "Idle", token = 0 }
	clerks[site] = c
	site:SetAttribute("ClerkUp", true)
	return c
end

-- Every second: a clerk for every clerk store, and a new one where the last went down CLERK_DOWN ago.
local function tendClerks()
	for typeId, sites in pairs(sitesByType) do
		if Heists.Types[typeId].Clerk then
			for _, site in ipairs(sites) do
				local c = clerks[site]
				if c and (not c.model.Parent or (c.state == "Down" and os.clock() - c.downAt >= CLERK_DOWN)) then
					c.token += 1
					c.model:Destroy()
					clerks[site] = nil
					c = nil
				end
				if not c then
					site:SetAttribute("ClerkUp", false)
					spawnClerk(site)
				end
			end
		end
	end
end

-- RequestStoreRob(site): the robber points a gun at that store's clerk (see the header).
local function onStoreRob(player, site)
	if not RateLimit.Allow(player, "StoreRob", 1, 2) then
		return
	end
	if typeof(site) ~= "Instance" or site.Parent ~= Workspace.Heists then
		return
	end
	local def = Heists.Types[site:GetAttribute("HeistId")]
	local cfg = def and def.Clerk
	local c = clerks[site]
	if not cfg or not c or c.state ~= "Idle" or not c.model.Parent then
		return
	end
	if player:GetAttribute("Side") ~= "Civilian" then
		return
	end
	-- A store that's shut for everyone else can still be a rookie's (Tutorial.RookieRob): theirs alone.
	local personal = not siteRobbable(site)
	if personal and not Tutorial.CanRookieRob(player, def.Tier) then
		return
	end
	if def.MinRank and (player:GetAttribute("CivRank") or 1) < def.MinRank then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root or hum.SeatPart then
		return
	end
	local gun = false
	for _, t in ipairs(char:GetChildren()) do
		gun = gun or (t:IsA("Tool") and t:GetAttribute(Combat.ToolAttribute or "NCCombat") == "Gun")
	end
	local to = c.root.Position - root.Position
	local flatTo = Vector3.new(to.X, 0, to.Z)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if not gun or flatTo.Magnitude > CLERK_REACH or flatTo.Magnitude < 0.5 or look.Magnitude < 0.1 or look.Unit:Dot(flatTo.Unit) < 0.6 then
		return
	end
	-- Hands up, and the bag gets filled.
	c.state, c.robber = "Robbed", player
	c.token += 1
	local token = c.token
	clerkPose(c, "HandsUp")
	clerkSay(c, "Okay, okay! Don't shoot!", 2.5)
	storeRob:FireClient(player, "Start", site, cfg.Fill)
	if Tutorial.CanRookieRob(player) then
		noteRookieHold(player)
	end
	if rng:NextNumber() < (cfg.Alarm or 0) then
		alarmNow(site) -- (the silent alarm under the counter)
	end
	task.spawn(function()
		local started = os.clock()
		local half = false
		while true do
			task.wait(0.25)
			if c.token ~= token or c.state ~= "Robbed" then
				return -- (shot, punched: NPCHit told the robber)
			end
			local r = player.Parent == Players and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local h = r and player.Character:FindFirstChildOfClass("Humanoid")
			local why
			if not h or h.Health <= 0 then
				why = "StoreRobOff"
			elseif h.SeatPart or player:GetAttribute("Side") ~= "Civilian" or (r.Position - c.root.Position).Magnitude > cfg.Range then
				why = "StoreRobLeft"
			end
			if why then
				c.state, c.robber = "Idle", nil
				clerkPose(c, "Cower")
				clerkSay(c, "Help! Police!", 2)
				task.delay(4, function()
					if c.token == token and c.state == "Idle" then
						clerkPose(c, nil)
					end
				end)
				if player.Parent == Players then
					storeRob:FireClient(player, "Fail", site, why)
				end
				return
			end
			local p = (os.clock() - started) / cfg.Fill
			if p >= 0.5 and not half then
				half = true
				clerkSay(c, "Here, here! It's all there!", 2)
			end
			if p >= 1 and not personal and now() < (site:GetAttribute("ReopenAt") or 0) then
				-- Somebody emptied the till while the bag was being filled (a crewmate holding Rob): nothing left.
				-- (A rookie's store that was shut for everyone else is theirs alone: never emptied under them.)
				c.state, c.robber = "Idle", nil
				clerkPose(c, nil)
				storeRob:FireClient(player, "Fail", site, "StoreRobOff")
				return
			end
			if p >= 1 then
				c.state, c.robber = "Idle", nil
				onRobbed(player, site, def, 1 + (cfg.Bonus or 0), personal)
				storeRob:FireClient(player, "Done", site)
				clerkPose(c, "Cower")
				task.delay(6, function()
					if c.token == token and c.state == "Idle" then
						clerkPose(c, nil)
					end
				end)
				return
			end
		end
	end)
end

------------------------------------------------------------------ Club Nova's drill

-- May this player empty the drilled safe now? (They set the drill, and it has finished.)
local function drillReady(site, player)
	local doneAt = site:GetAttribute("DrillDoneAt")
	return site:GetAttribute("DrillBy") == player.UserId and doneAt ~= nil and now() >= doneAt
end

local function clearDrill(site)
	site:SetAttribute("DrillBy", nil)
	site:SetAttribute("DrillDoneAt", nil)
end

local function startDrill(player, site, def, point)
	local drill = def.Drill
	local doneAt = now() + drill.Time
	site:SetAttribute("DrillBy", player.UserId)
	site:SetAttribute("DrillDoneAt", doneAt)
	alarmNow(site) -- (a drill is loud)
	addHeat(player, 1)
	Remotes.Event("HeistPrep"):FireClient(player, {
		Title = "DRILLING", Text = "Hold the room for " .. drill.Time .. " seconds, then grab the cash.",
	})
	task.spawn(function()
		local away = 0
		while site:GetAttribute("DrillBy") == player.UserId and site:GetAttribute("DrillDoneAt") == doneAt do
			task.wait(0.5)
			local t = now()
			if t >= doneAt + drill.Expire then
				clearDrill(site) -- (never emptied: the cash is gone)
				return
			elseif t < doneAt then
				local r = player.Parent == Players and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local h = r and player.Character:FindFirstChildOfClass("Humanoid")
				if not h or h.Health <= 0 or player:GetAttribute("Side") ~= "Civilian" or (r.Position - point.Position).Magnitude > drill.Range then
					away += 0.5
				else
					away = 0
				end
				if away >= drill.Leave then
					clearDrill(site)
					if player.Parent == Players then
						notify:FireClient(player, "DrillJammed")
					end
					return
				end
			end
		end
	end)
end

local function hookSite(site)
	local typeId = site:GetAttribute("HeistId")
	local def = Heists.Types[typeId]
	local point = site:FindFirstChild("RobPoint", true)
	if not def or not point then
		warn("[HeistService] site " .. site.Name .. " is missing a type or a RobPoint")
		return
	end
	sitesByType[typeId] = sitesByType[typeId] or {}
	table.insert(sitesByType[typeId], site)
	holdStart[site] = {}

	local prompt = point:FindFirstChild("RobPrompt") or Instance.new("ProximityPrompt")
	prompt.Name = "RobPrompt"
	prompt.ActionText = def.Drill and "Set the drill" or "Rob"
	prompt.ObjectText = def.Display
	prompt.HoldDuration = def.Drill and def.Drill.Start or def.Hold -- (HeistClient labels the drill's stages)
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Enabled = true
	prompt.Parent = point

	-- Prep step (bank fuse box, yacht alarm panel): must be done first, by you or a crewmate.
	if def.Prep then
		local prep = def.Prep
		local panel = site:FindFirstChild("PrepPanel") or Instance.new("Part")
		panel.Name = "PrepPanel"
		panel.Anchored = true
		panel.CanCollide = false
		panel.Size = Vector3.new(3, 4, 0.8)
		panel.CFrame = CFrame.lookAt(prep.Pos, prep.Pos + prep.Facing)
		panel.Color = Color3.fromRGB(40, 44, 60)
		panel.Material = Enum.Material.Metal
		panel.Parent = site
		local light = panel:FindFirstChild("Light") or Instance.new("Part")
		light.Name = "Light"
		light.Anchored = true
		light.CanCollide = false
		light.Size = Vector3.new(2.2, 0.5, 0.2)
		light.CFrame = panel.CFrame * CFrame.new(0, 1.2, -0.5)
		light.Material = Enum.Material.Neon
		light.Color = Color3.fromRGB(255, 60, 60)
		light.Parent = panel
		local pp = panel:FindFirstChild("PrepPrompt") or Instance.new("ProximityPrompt")
		pp.Name = "PrepPrompt"
		pp.ActionText = prep.Action
		pp.ObjectText = prep.Object
		pp.HoldDuration = prep.Hold
		pp.MaxActivationDistance = 10
		pp.RequiresLineOfSight = false
		pp.KeyboardKeyCode = Enum.KeyCode.E
		pp.Parent = panel
		local prepStart = {}
		pp.PromptButtonHoldBegan:Connect(function(player)
			prepStart[player.UserId] = os.clock()
		end)
		pp.Triggered:Connect(function(player)
			local began = prepStart[player.UserId]
			prepStart[player.UserId] = nil
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if player:GetAttribute("Side") ~= "Civilian" or not root or (root.Position - panel.Position).Magnitude > 16 then
				return
			end
			-- On foot only, like the vault itself. (PromptGate hides this prompt from anyone seated; this is
			-- for a hold begun just before sitting down, and for clients that skip the gate.)
			local hum = player.Character:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then
				return
			end
			if hum.SeatPart then
				if RateLimit.Allow(player, "GetOutFirstToast", 1 / 3, 1) then
					notify:FireClient(player, "GetOutFirst")
				end
				return
			end
			-- Rank first: a tap on the relabelled "Rank 3 needed" prompt explains why.
			if def.MinRank and (player:GetAttribute("CivRank") or 1) < def.MinRank then
				notify:FireClient(player, "BankNeedsRank")
				return
			end
			if not siteRobbable(site) then
				return
			end
			-- Checked before the hold time so a tap on the relabelled "Done" / "Taken" prompt explains.
			-- Your own live prep can't be refreshed (that would keep the panel locked forever); another
			-- crew's is off limits only while it's fresh, then anyone may take it over.
			if (site:GetAttribute("PrepUntil") or 0) > now() then
				if prepIsMine(site, player) then
					prepRefused(player, "PrepAlreadyDone")
					return
				end
				if now() < (site:GetAttribute("PrepLockUntil") or 0) then
					prepRefused(player, "PrepTaken")
					return
				end
			end
			if not began or os.clock() - began < prep.Hold - 0.4 then
				return
			end
			site:SetAttribute("PrepUntil", now() + prep.Window)
			site:SetAttribute("PrepLockUntil", now() + math.min(PREP_LOCK, prep.Window))
			site:SetAttribute("PrepBy", player:GetAttribute("Crew") or ("u" .. player.UserId))
			light.Color = Color3.fromRGB(110, 242, 196)
			Remotes.Event("HeistPrep"):FireClient(player, { Text = prep.Done })
			task.delay(prep.Window, function()
				if (site:GetAttribute("PrepUntil") or 0) <= now() then
					light.Color = Color3.fromRGB(255, 60, 60)
				end
			end)
		end)
	end

	prompt.PromptButtonHoldBegan:Connect(function(player)
		holdStart[site][player.UserId] = {
			t = os.clock(), prepOk = def.Prep ~= nil and prepIsMine(site, player), open = siteRobbable(site),
		}
		if Tutorial.CanRookieRob(player) then
			noteRookieHold(player)
		end
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		task.defer(function()
			holdStart[site][player.UserId] = nil
		end)
	end)
	prompt.Triggered:Connect(function(player)
		local began = holdStart[site][player.UserId]
		holdStart[site][player.UserId] = nil
		if player:GetAttribute("Side") ~= "Civilian" then
			return
		end
		if def.MinRank and (player:GetAttribute("CivRank") or 1) < def.MinRank then
			notify:FireClient(player, "BankNeedsRank")
			return
		end
		-- The hold only has to start inside the prep window, so what was true then counts (for a hold
		-- that really just ran its length), or a prep a crewmate finished during the hold. (Before the
		-- prep, HeistClient makes this prompt a tap that brings this answer: at most one every 3 s.)
		local prepAtStart = began ~= nil and began.prepOk and os.clock() - began.t < def.Hold + 5
		if def.Prep and not prepAtStart and not prepIsMine(site, player) then
			prepRefused(player, "NeedPrep_" .. typeId)
			return
		end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if not hum or hum.Health <= 0 or not root then
			return
		end
		if hum.SeatPart then
			-- Sitting in a car (a hold begun just before sitting down): say so, not nothing.
			if RateLimit.Allow(player, "GetOutFirstToast", 1 / 3, 1) then
				notify:FireClient(player, "GetOutFirst")
			end
			return
		end
		if (root.Position - point.Position).Magnitude > 16 then
			return
		end
		-- The server times the hold; a client that skips it gets nothing. (Club Nova: setting the drill, or
		-- emptying the safe once it's done, each has its own time. A rookie's tier-1 hold is shorter:
		-- Tutorial.RookieRob, which HeistClient puts on the prompt for them.)
		local drill = def.Drill
		local grabbing = drill ~= nil and drillReady(site, player)
		local rookie = not drill and Tutorial.CanRookieRob(player, def.Tier)
		local need = drill and (grabbing and drill.Grab or drill.Start)
			or (rookie and math.min(def.Hold, Tutorial.RookieRob.Hold) or def.Hold)
		if not began or os.clock() - began.t < need - 0.4 then
			return
		end
		if drill then
			if grabbing then
				clearDrill(site)
				onRobbed(player, site, def)
			elseif site:GetAttribute("DrillBy") ~= nil then
				notify:FireClient(player, "DrillBusy")
			elseif siteRobbable(site) then
				startDrill(player, site, def, point)
			end
			return
		end
		-- A store shuts for NEW holds only. Its type could leave the rotation (or the bank event end) in
		-- the middle of a hold, and the robber got nothing and no reason why: a hold that began while the
		-- site was open, and really just ran its length, is still paid. The site's own cooldown counts
		-- as always, so a second robber on a till somebody just emptied goes home with nothing.
		-- The clerk is filling a bag for someone at gunpoint: the till is theirs.
		local c = clerks[site]
		if c and c.state == "Robbed" then
			return
		end
		local openAtStart = began.open and os.clock() - began.t < def.Hold + 5
		local shut = not siteRobbable(site) and not (openAtStart and now() >= (site:GetAttribute("ReopenAt") or 0))
		-- Shut for everyone else, but a rookie's to rob all the same (and left as it was: `personal`).
		if shut and not rookie then
			return
		end
		onRobbed(player, site, def, nil, shut)
	end)
	site:SetAttribute("HeistType", typeId)
	site:SetAttribute("Display", def.Display)
	site:SetAttribute("MinRank", def.MinRank) -- nil for heists anyone can do
	refreshSite(site)
end

-- A player shot or punched a store clerk (CombatService routes hits on NPCKind "Clerk" here). They go
-- down for CLERK_DOWN seconds; a robbery in progress is off. Returns true if it counted.
function HeistService.NPCHit(model, attacker, damage, dir, kind)
	local c
	for _, x in pairs(clerks) do
		if x.model == model then
			c = x
			break
		end
	end
	if not c or c.state == "Down" or typeof(attacker) ~= "Instance" or not attacker:IsA("Player")
		or attacker:GetAttribute("Side") ~= "Civilian" then
		return false
	end
	local robber = c.state == "Robbed" and c.robber or nil
	c.state, c.robber, c.downAt = "Down", nil, os.clock()
	c.token += 1
	c.site:SetAttribute("ClerkUp", false)
	clerkPose(c, nil)
	c.model:SetAttribute("AimTarget", nil)
	c.model:SetAttribute("NPCKind", nil)
	if robber and robber.Parent == Players then
		storeRob:FireClient(robber, "Fail", c.site, "StoreRobClerkDown")
	end
	local push = typeof(dir) == "Vector3" and Vector3.new(dir.X, 0, dir.Z) or Vector3.zero
	push = push.Magnitude > 0.05 and push.Unit or -c.root.CFrame.LookVector
	c.root.Anchored = false
	pcall(function()
		require(ReplicatedStorage.Shared.Util.Ragdoll).Start(c.model, push * 12 + Vector3.new(0, 8, 0), { NoCap = true })
	end)
	if kind ~= "Punch" then
		c.hum.Health = 0
	end
	local ok, combat = pcall(require, ServerScriptService.Services:FindFirstChild("CombatService"))
	if ok and type(combat) == "table" and type(combat.CrimeHeat) == "function" then
		pcall(combat.CrimeHeat, attacker, 1, "hurt_clerk", kind ~= "Punch")
	end
	return true
end

function HeistService.IsAlarmActive(site)
	return now() < (site:GetAttribute("AlarmUntil") or 0)
end

function HeistService.Init()
	feed = Remotes.Event("Feed")
	notify = Remotes.Event("Notify")
	heistResult = Remotes.Event("HeistResult")
	storeRob = Remotes.Event("StoreRob")
	Remotes.Event("HeistPrep")
	npcFolder = Workspace:FindFirstChild("NPCs")
	if not npcFolder then
		npcFolder = Instance.new("Folder")
		npcFolder.Name = "NPCs"
		npcFolder.Parent = Workspace
	end
	Remotes.Event("RequestStoreRob").OnServerEvent:Connect(onStoreRob)
	for _, site in ipairs(Workspace.Heists:GetChildren()) do
		if site:GetAttribute("HeistId") then
			hookSite(site)
		end
	end
	task.spawn(function()
		while true do
			rotate()
			task.wait(Heists.RotateEvery)
		end
	end)
	-- Cooldowns end on their own; re-check sites every second so prompts re-enable on time.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, sites in pairs(sitesByType) do
				for _, site in ipairs(sites) do
					refreshSite(site)
				end
			end
			local ok, err = pcall(tendClerks)
			if not ok then
				warn("[HeistService] clerks: " .. tostring(err))
			end
		end
	end)
	task.spawn(bankLoop)
	Players.PlayerRemoving:Connect(function(player)
		for _, map in pairs(holdStart) do
			map[player.UserId] = nil
		end
		prepToastAt[player.UserId] = nil
	end)
end

return HeistService
