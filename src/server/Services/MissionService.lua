-- MissionService (ModuleScript, ServerScriptService.Services.MissionService)
-- Phone missions (Config.Missions). The server runs the steps, the timer and the pay.
--   Remote RequestMission("Start", id) / ("Quit")
--   Player attribute "Mission" = JSON { id, step, deadline (server time), got = { collected point indices } }
--   Player attribute "MissionsDone" = comma list of mission ids already finished today (full pay once a day)
--   Remote MissionEvent(kind, info) to the client: "Step", "Done" { Cash, XP }, "Failed" { Reason }
-- Only free-roam players who aren't wanted, racing or on a job shift can start one, and a mission fails
-- the moment its player stops being a free-roam player (joins the police, goes to prison).
-- Anti-teleport: a goal only counts once enough time has passed to drive there from the last goal
-- at MAX_TRAVEL (faster than any car with nitro). Early arrivals are ignored, not failed.
-- Crew preps (Missions.CrewPreps, the crew job behind The Big Score): MissionService.StartCrew(players,
-- id, crewId, onDone) puts a whole crew on one shared mission (CrewService checks who's free first). Each
-- of them gets the usual "Mission" attribute and events, so MissionClient draws it as it draws any
-- mission. The steps are shared: a goal counts once Missions.CrewJob.Together of them (not wanted) are at
-- it at the same time (fewer on a smaller crew: Studio's crew of one); a Collect point the same. While
-- only some of them have made it, or a wanted one is at the goal, the crew hears so (remote "CrewJob"
-- "Toast" Together / Wanted, every CREW_TOAST_GAP s at most). Being wanted doesn't fail a prep, it just
-- doesn't count. It fails for all of them on the clock, a QUIT from any of them, or one of them leaving
-- the game, the crew or free roam. A step with WithinSpeed pulls the clock down as it starts (a timed
-- getaway). Passed: each one gets the prep's Cash and XP; then onDone(passed, players).
-- Hands-on crew steps (Missions: Pickup, Deliver, Pair; owner, Nov 7 2026: "a part that they hold and grab").
-- CrewTasks builds what's in the world for the step the crew is on (a thing to grab at each Pickup point, the
-- Deliver stand, the two Pair spots) and calls back here once a prompt's hold really ran (alive, on foot, in
-- reach): MissionService.CrewAct(player, "Grab" | "Stash" | "Pair", index). Here: the player must be on this
-- prep, not wanted ("Wanted"), within Missions.CrewJob.Reach of it, and Together of the crew must be at the
-- spot ("Together"), as for a goal. A grabbed thing is carried (CrewTasks.Carry: the hand, then the back;
-- player attribute "CrewCarry" = how many) through car rides until a Deliver stand takes it; a carrier who dies
-- or respawns drops it where they last stood (grab it again). Pair: two different crew members finish the two
-- spots within PairSync seconds (Studio's crew of one: the same one may). The crew hears each grab, drop and
-- stash (CrewJob "Toast" Grabbed / Dropped / Stashed { Name, Item, Done, Total }, PairWait { Name, Action,
-- Other }, PairSync, PairTwo, NothingToStash). The "Mission" JSON then also has items = { { x, z, s = "g"
-- (on the ground) | "c" (carried) | "s" (stashed), n = name, p = the step that put it out, u = carrier's
-- UserId } }, stand = { x, z, a },
-- spots = { { x, z, a, d = done } } for MissionClient's markers.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local DataService = require(ServerScriptService.Services.DataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local Telemetry = require(ServerScriptService.Services.Telemetry)

local MissionService = {}

local MAX_TRAVEL = 300 -- studs/s: a bit above the fastest car, fully tuned, on nitro (297: Config.Garage)

local CREW_TOAST_GAP = 6 -- seconds between two "wait for your crew" / "lose the cops" toasts on a crew prep
local JOB = Missions.CrewJob or {}

-- [player] = { m, step, deadline, got = {}, holdSince, from, fromRadius, stepAt }; a crew prep's members
-- all point at one shared table that also has crew = { players }, crewId, need, onDone, tooSlow, toastAt,
-- and for the hands-on steps world (CrewTasks' run), items = { { index, name, look, step, home, pos, state =
-- "ground" | "carried" | "stashed", carrier, char, lastPos } }, stashed (count), stand = { pos, action },
-- spots = { [k] = { pos, action } }, pair = { [k] = { at, by } }, pairDone.
local active = {}
local lastEnd = {} -- [player] = os.clock()
local missionEvent, notify, crewJob

local function now()
	return Workspace:GetServerTimeNow()
end

local function today()
	return math.floor(os.time() / 86400)
end

local function doneToday(player)
	local data = DataService.Get(player)
	if not data then
		return {}
	end
	data.flags = data.flags or {}
	local rec = data.flags.missions
	if not rec or (rec.day or 0) < today() then
		rec = { day = today(), done = {} }
		data.flags.missions = rec
	end
	return rec.done
end

local function publishDone(player)
	local list = {}
	for id in pairs(doneToday(player)) do
		table.insert(list, id)
	end
	player:SetAttribute("MissionsDone", table.concat(list, ","))
end

local function round(n)
	return math.floor(n + 0.5)
end

local function publish(player)
	local s = active[player]
	if not s then
		player:SetAttribute("Mission", nil)
		return
	end
	local got = {}
	for i in pairs(s.got) do
		table.insert(got, i)
	end
	local data = { id = s.m.Id, step = s.step, deadline = s.deadline, got = got }
	-- The hands-on steps' things, where they are (see the header).
	if s.items then
		data.items = {}
		for i, it in ipairs(s.items) do
			data.items[i] = { x = round(it.pos.X), z = round(it.pos.Z), n = it.name, p = it.step,
				s = it.state == "ground" and "g" or (it.state == "carried" and "c" or "s"),
				u = it.carrier and it.carrier.UserId or nil }
		end
	end
	if s.stand then
		data.stand = { x = round(s.stand.pos.X), z = round(s.stand.pos.Z), a = s.stand.action }
	end
	if s.spots then
		data.spots = {}
		for k, spot in ipairs(s.spots) do
			data.spots[k] = { x = round(spot.pos.X), z = round(spot.pos.Z), a = spot.action, d = (s.pair and s.pair[k]) ~= nil }
		end
	end
	player:SetAttribute("Mission", HttpService:JSONEncode(data))
end

-- A CrewJob toast for one crew member, or for the whole crew of a prep (CrewClient has the words).
local function sayTo(p, key, extra)
	if p.Parent ~= Players then
		return
	end
	local info = { Key = key }
	for k, v in pairs(extra or {}) do
		info[k] = v
	end
	crewJob:FireClient(p, "Toast", info)
end

local function sayAll(s, key, extra)
	for _, p in ipairs(s.crew) do
		sayTo(p, key, extra)
	end
end

local function publishCrew(s)
	for _, p in ipairs(s.crew) do
		if p.Parent == Players then
			publish(p)
		end
	end
end

-- How many things `p` carries on this prep (the CrewCarry attribute says so too).
local function carriedBy(s, p)
	local n = 0
	for _, it in ipairs(s.items or {}) do
		if it.state == "carried" and it.carrier == p then
			n += 1
		end
	end
	return n
end

local function setCarry(p, n)
	if p.Parent == Players then
		p:SetAttribute("CrewCarry", n > 0 and n or nil)
	end
end

-- A crew prep is over, for every one of them (see the header).
local function finishCrew(s, ok, reason)
	if s.over then
		return
	end
	s.over = true
	if s.world then
		local okClear, err = pcall(s.world.Clear, s.world)
		if not okClear then
			warn("[MissionService] crew tasks clear: " .. tostring(err))
		end
	end
	for _, p in ipairs(s.crew) do
		if active[p] == s then
			active[p] = nil
		end
		lastEnd[p] = os.clock()
		setCarry(p, 0)
		if p.Parent == Players then
			publish(p)
			if ok then
				EconomyService.AddCash(p, s.m.Cash, "crewprep:" .. s.m.Id)
				local okXP, err = pcall(require(ServerScriptService.Services.ProgressService).Event, p, "Mission", s.m.XP)
				if not okXP then
					warn("[MissionService] crew prep XP: " .. tostring(err))
				end
				Telemetry.Custom(p, "CrewPrep_" .. s.m.Id, s.m.Cash)
				missionEvent:FireClient(p, "Done", { Name = s.m.Name, Cash = s.m.Cash, XP = s.m.XP, First = true, Crew = true })
			else
				missionEvent:FireClient(p, "Failed", { Name = s.m.Name, Reason = reason, Crew = true })
			end
		end
	end
	if s.onDone then
		task.spawn(s.onDone, ok == true, s.crew)
	end
end

local function finish(player, ok, reason)
	local s = active[player]
	if not s then
		return
	end
	if s.crew then
		finishCrew(s, ok, reason == "Quit" and (player.DisplayName .. " quit the prep") or reason)
		return
	end
	active[player] = nil
	lastEnd[player] = os.clock()
	publish(player)
	if not ok then
		missionEvent:FireClient(player, "Failed", { Name = s.m.Name, Reason = reason })
		return
	end
	local done = doneToday(player)
	local first = not done[s.m.Id]
	done[s.m.Id] = true
	local cash = math.floor(s.m.Cash * (first and 1 or Missions.RepeatShare))
	local xp = math.floor(s.m.XP * (first and 1 or Missions.RepeatShare))
	EconomyService.AddCash(player, cash, "mission:" .. s.m.Id)
	require(ServerScriptService.Services.ProgressService).Event(player, "Mission", xp)
	Telemetry.Custom(player, "Mission_" .. s.m.Id, cash)
	publishDone(player)
	missionEvent:FireClient(player, "Done", { Name = s.m.Name, Cash = cash, XP = xp, First = first })
end

local function inBoat(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	return seat ~= nil and seat.Parent:GetAttribute("Boat") == true
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- Too soon to be here? Arriving sooner than the straight-line gap from the last goal (or the start
-- spot) at MAX_TRAVEL means a teleport, so the arrival doesn't count yet.
local function tooSoon(s, target, radius)
	if not s.from then
		-- Started inside a home and still indoors (tick sets the start spot at the door): nothing counts yet.
		return true
	end
	local gap = math.max(0, (flat(target) - s.from).Magnitude - s.fromRadius - radius)
	return os.clock() - s.stepAt < gap / MAX_TRAVEL
end

-- Tell the whole crew something about the goal (CrewClient has the words), not too often.
local function crewToast(s, key)
	if os.clock() - (s.toastAt or 0) < CREW_TOAST_GAP then
		return
	end
	s.toastAt = os.clock()
	for _, p in ipairs(s.crew) do
		if p.Parent == Players then
			crewJob:FireClient(p, "Toast", { Key = key })
		end
	end
end

-- How many of `list` ({ pos, slow }) are within `radius` of `target` (only the slow ones, for a Hold).
local function countNear(list, target, radius, slowOnly)
	local n = 0
	for _, sp in ipairs(list) do
		if (sp.pos - flat(target)).Magnitude <= radius and (not slowOnly or sp.slow) then
			n += 1
		end
	end
	return n
end

-- Where the crew is: { pos, slow } for the ones who aren't wanted, and the same for the wanted ones.
local function crewSpots(s)
	local spots, wanted = {}, {}
	for _, p in ipairs(s.crew) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and not p:GetAttribute("InHome") then
			local spot = { pos = flat(root.Position), slow = root.AssemblyLinearVelocity.Magnitude < 10 }
			table.insert((p:GetAttribute("Heat") or 0) > 0 and wanted or spots, spot)
		end
	end
	return spots, wanted
end

------------------------------------------------------------------ hands-on crew steps (see the header)

-- The Radius of the step that put this thing out (the crew must be that close to it to grab it).
local function itemRadius(s, it)
	local step = s.m.Steps[it.step]
	return step and step.Radius or 40
end

-- The world for the step the crew has just reached: things to grab, the stand, the pair spots.
local function enterStep(s)
	local step = s.m.Steps[s.step]
	local world = s.world
	if not step or not world then
		return
	end
	if s.spots then
		world:ClearPair()
		s.spots, s.pair, s.pairDone = nil, nil, nil
	end
	if step.Kind == "Pickup" then
		s.items = s.items or {}
		for i, point in ipairs(step.Points or {}) do
			local def = (step.Items and (step.Items[i] or step.Items[1])) or { Name = "Package", Look = "Case" }
			local pos = world:Spot(point, 12) or point
			local it = { name = def.Name, look = def.Look, step = s.step, home = pos, pos = pos, state = "ground" }
			table.insert(s.items, it)
			it.index = #s.items
			world:Item(it.index, it.look, it.name, pos)
		end
	elseif step.Kind == "Deliver" then
		local pos = world:Spot(step.Pos, 14) or step.Pos
		s.stand = { pos = pos, action = step.Action or "Stash" }
		world:Stand(pos, s.stand.action, step.Look)
	elseif step.Kind == "Pair" then
		s.spots, s.pair, s.pairDone = {}, {}, nil
		for k, def in ipairs(step.Spots or {}) do
			local want = step.Pos + (def.Offset or Vector3.new(0, 0, 0))
			local pos = world:Spot(want, 5) or want
			s.spots[k] = { pos = pos, action = def.Action or "Hold" }
			world:PairSpot(k, pos, s.spots[k].action, def.Look, step.Seconds or 3)
		end
	end
	if step.Kind ~= "Deliver" and s.stand then
		s.stand = nil
		world:ClearStand()
	end
end

-- `it` goes into `p`'s hands (or onto their back, past the first).
local function carry(s, it, p)
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	it.state, it.carrier, it.char = "carried", p, p.Character
	it.lastPos = root and root.Position or it.pos
	local n = carriedBy(s, p)
	if s.world then
		s.world:Carry(it.index, p, n)
	end
	setCarry(p, n)
end

-- A carried thing back on the ground, where its carrier last stood (or where it was, if there's no ground
-- there: the sea, a home's inside off the map).
local function drop(s, it)
	local p = it.carrier
	local at = it.lastPos and s.world and s.world:Spot(it.lastPos, 10) or nil
	it.state, it.carrier, it.char = "ground", nil, nil
	it.pos = at or it.home
	if s.world then
		s.world:Item(it.index, it.look, it.name, it.pos)
	end
	if p then
		setCarry(p, carriedBy(s, p))
	end
	sayAll(s, "Dropped", { Name = p and p.DisplayName or "", Item = it.name })
end

-- (see the header) A crew member's hold on one of the prep's things. True when it counted.
local function act(s, p, kind, index)
	local step = s.m.Steps[s.step]
	if s.over or not step then
		return false
	end
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	if (p:GetAttribute("Heat") or 0) > 0 then
		sayTo(p, "Wanted")
		return false
	end
	local here = flat(root.Position)
	local reach = JOB.Reach or 12
	local spots = crewSpots(s)
	if not s.from and not p:GetAttribute("InHome") then
		s.from, s.fromRadius, s.stepAt = here, 0, os.clock()
	end
	if kind == "Grab" then
		local it = s.items and s.items[index]
		if not it or it.state ~= "ground" or (here - flat(it.pos)).Magnitude > reach then
			return false
		end
		local radius = itemRadius(s, it)
		if countNear(spots, it.pos, radius, false) < s.need then
			sayTo(p, "Together")
			return false
		end
		if tooSoon(s, it.pos, radius) then
			return false
		end
		carry(s, it, p)
		s.from, s.fromRadius, s.stepAt = flat(it.pos), radius, os.clock()
		local done, total = 0, 0
		for _, other in ipairs(s.items) do
			if other.step == it.step then
				total += 1
				if other.state ~= "ground" then
					done += 1
				end
			end
		end
		publishCrew(s)
		sayAll(s, "Grabbed", { Name = p.DisplayName, Item = it.name, Done = done, Total = total })
		return true
	elseif kind == "Stash" then
		if step.Kind ~= "Deliver" or not s.stand or (here - flat(s.stand.pos)).Magnitude > reach then
			return false
		end
		if carriedBy(s, p) == 0 then
			sayTo(p, "NothingToStash")
			return false
		end
		if countNear(spots, step.Pos, step.Radius, false) < s.need then
			sayTo(p, "Together")
			return false
		end
		if tooSoon(s, step.Pos, step.Radius) then
			return false
		end
		s.stashed = s.stashed or 0
		for _, it in ipairs(s.items) do
			if it.state == "carried" and it.carrier == p then
				s.stashed += 1
				it.state, it.carrier, it.char = "stashed", nil, nil
				it.pos = s.stand.pos
				if s.world then
					s.world:Stash(it.index, s.stashed)
				end
			end
		end
		setCarry(p, 0)
		publishCrew(s)
		sayAll(s, "Stashed", { Name = p.DisplayName, Done = s.stashed, Total = #s.items })
		return true
	elseif kind == "Pair" then
		local spot = s.spots and s.spots[index]
		if step.Kind ~= "Pair" or not spot or s.pairDone or (here - flat(spot.pos)).Magnitude > reach then
			return false
		end
		if countNear(spots, step.Pos, step.Radius, false) < s.need then
			sayTo(p, "Together")
			return false
		end
		if tooSoon(s, step.Pos, step.Radius) then
			return false
		end
		local otherIndex = index == 1 and 2 or 1
		local other = s.pair[otherIndex]
		s.pair[index] = { at = os.clock(), by = p }
		if s.world then
			s.world:PairLight(index, true)
		end
		if other and os.clock() - other.at <= (JOB.PairSync or 6) then
			if other.by ~= p or s.need <= 1 then
				s.pairDone = true -- (the tick moves the crew on)
			else
				-- The same one did both: it takes two.
				s.pair[otherIndex] = nil
				if s.world then
					s.world:PairLight(otherIndex, false)
				end
				sayTo(p, "PairTwo")
			end
		else
			local otherSpot = s.spots[otherIndex]
			sayAll(s, "PairWait", { Name = p.DisplayName, Action = spot.action, Other = otherSpot and otherSpot.action or "" })
		end
		publishCrew(s)
		return true
	end
	return false
end

-- Carried things whose carrier died or respawned go back on the ground; a Pair hold that's too old clears.
local function tickHands(s)
	for _, it in ipairs(s.items or {}) do
		if it.state == "carried" then
			local p = it.carrier
			local char = p and p.Character
			local root = char and char == it.char and char:FindFirstChild("HumanoidRootPart")
			local hum = root and char.FindFirstChildOfClass and char:FindFirstChildOfClass("Humanoid")
			if root and (not hum or hum.Health > 0) then
				if not p:GetAttribute("InHome") then
					it.lastPos = root.Position
				end
			else
				drop(s, it)
				publishCrew(s)
			end
		end
	end
	if s.pair and not s.pairDone then
		for k, held in pairs(s.pair) do
			if os.clock() - held.at > (JOB.PairSync or 6) then
				s.pair[k] = nil
				if s.world then
					s.world:PairLight(k, false)
				end
				sayAll(s, "PairSync")
				publishCrew(s)
			end
		end
	end
end

-- One crew prep (see the header). Runs once per tick for the shared state, whoever's entry finds it.
local function tickCrew(s)
	for _, p in ipairs(s.crew) do
		local why
		if p.Parent ~= Players then
			why = p.DisplayName .. " left the game"
		elseif p:GetAttribute("Side") ~= "Civilian" then
			why = p.DisplayName .. (p:GetAttribute("Side") == "Cop" and " joined the police" or " got locked up")
		elseif p:GetAttribute("Crew") ~= s.crewId then
			why = p.DisplayName .. " left the crew"
		end
		if why then
			finishCrew(s, false, why)
			return
		end
	end
	if now() > s.deadline then
		finishCrew(s, false, s.tooSlow or "Time's up")
		return
	end
	-- Where the crew is: the ones who aren't wanted count, the wanted ones only get a "lose the cops" toast.
	local spots, wanted = crewSpots(s)
	tickHands(s)
	if not s.from then
		-- (nobody had a body outside a home at the start: travel is timed from the first one out)
		local first = spots[1] or wanted[1]
		if not first then
			return
		end
		s.from, s.fromRadius, s.stepAt = first.pos, 0, os.clock()
	end
	local step = s.m.Steps[s.step]
	local advance, short, wantedThere = false, false, false
	if step.Kind == "Goto" or step.Kind == "Hold" then
		local hold = step.Kind == "Hold"
		local n = countNear(spots, step.Pos, step.Radius, hold)
		local ready = n >= s.need and not tooSoon(s, step.Pos, step.Radius)
		short = n > 0 and n < s.need
		wantedThere = countNear(wanted, step.Pos, step.Radius, false) > 0
		if hold then
			if ready then
				s.holdSince = s.holdSince or os.clock()
				advance = os.clock() - s.holdSince >= step.Seconds
			else
				s.holdSince = nil
			end
		else
			advance = ready
		end
	elseif step.Kind == "Collect" then
		local changed, all = false, true
		for i, point in ipairs(step.Points) do
			if not s.got[i] then
				local n = countNear(spots, point, step.Radius, false)
				if n >= s.need and not tooSoon(s, point, step.Radius) then
					s.got[i] = true
					changed = true
					s.from, s.fromRadius, s.stepAt = flat(point), step.Radius, os.clock()
				else
					short = short or (n > 0 and n < s.need)
					wantedThere = wantedThere or countNear(wanted, point, step.Radius, false) > 0
					all = false
				end
			end
		end
		advance = all
		if changed and not all then
			for _, p in ipairs(s.crew) do
				publish(p)
				missionEvent:FireClient(p, "Collected", {})
			end
		end
	elseif step.Kind == "Pickup" then
		-- (the grabs themselves come through CrewAct; here: is everything this step put out carried yet?)
		local any = false
		advance = true
		for _, it in ipairs(s.items or {}) do
			if it.step == s.step then
				any = true
				if it.state == "ground" then
					advance = false
					local n = countNear(spots, it.pos, step.Radius, false)
					short = short or (n > 0 and n < s.need)
					wantedThere = wantedThere or countNear(wanted, it.pos, step.Radius, false) > 0
				end
			end
		end
		advance = advance and any
	elseif step.Kind == "Deliver" then
		advance = s.items ~= nil and #s.items > 0
		for _, it in ipairs(s.items or {}) do
			advance = advance and it.state == "stashed"
		end
		local n = countNear(spots, step.Pos, step.Radius, false)
		short = n > 0 and n < s.need
		wantedThere = countNear(wanted, step.Pos, step.Radius, false) > 0
	elseif step.Kind == "Pair" then
		advance = s.pairDone == true
		local n = countNear(spots, step.Pos, step.Radius, false)
		short = n > 0 and n < s.need
		wantedThere = countNear(wanted, step.Pos, step.Radius, false) > 0
	end
	if advance then
		s.step += 1
		s.holdSince = nil
		s.got = {}
		if step.Pos then
			s.from, s.fromRadius = flat(step.Pos), step.Radius
		end
		s.stepAt = os.clock()
		local nextStep = s.m.Steps[s.step]
		if not nextStep then
			finishCrew(s, true)
			return
		end
		if nextStep.WithinSpeed and nextStep.Pos then
			-- A timed leg: the clock jumps down to what this trip allows (straight-line, from the last goal).
			local gap = math.max(0, (flat(nextStep.Pos) - s.from).Magnitude - s.fromRadius - nextStep.Radius)
			s.deadline = math.min(s.deadline, now() + math.ceil(gap / nextStep.WithinSpeed + (nextStep.WithinSlack or 0)))
			s.tooSlow = nextStep.TooSlow
		end
		local okStep, errStep = pcall(enterStep, s)
		if not okStep then
			warn("[MissionService] crew step: " .. tostring(errStep))
		end
		for _, p in ipairs(s.crew) do
			publish(p)
			missionEvent:FireClient(p, "Step", { Text = nextStep.Text })
		end
	elseif short then
		crewToast(s, "Together")
	elseif wantedThere then
		crewToast(s, "Wanted")
	end
end

local function tick()
	local t = now()
	local seen = {}
	for player, s in pairs(active) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if s.crew then
			if not seen[s] then
				seen[s] = true
				tickCrew(s)
			end
		elseif not player.Parent then
			active[player] = nil
		elseif t > s.deadline then
			finish(player, false, "Time's up")
		elseif player:GetAttribute("Side") ~= "Civilian" then
			-- Switching to police mid-mission left the banner, timer and markers up, and the new cop could
			-- finish it for a free-roam player's pay. Missions are free-roam only, so it ends here (prison too).
			finish(player, false, player:GetAttribute("Side") == "Cop" and "You joined the police" or "You're in prison")
		elseif (player:GetAttribute("Heat") or 0) > 0 then
			finish(player, false, "You're wanted")
		elseif root then
			local step = s.m.Steps[s.step]
			local here = flat(root.Position)
			local advance = false
			if not s.from and not player:GetAttribute("InHome") then
				-- No character when the mission started, or it started inside a home (which sits far off the
				-- map, so we wait for the player to step out of the door): travel is timed from here.
				s.from, s.fromRadius, s.stepAt = here, 0, os.clock()
			end
			if step.Kind == "Goto" then
				advance = (here - flat(step.Pos)).Magnitude <= step.Radius and (not s.m.NeedsBoat or inBoat(player))
					and not tooSoon(s, step.Pos, step.Radius)
			elseif step.Kind == "Hold" then
				local inside = (here - flat(step.Pos)).Magnitude <= step.Radius and root.AssemblyLinearVelocity.Magnitude < 10
					and not tooSoon(s, step.Pos, step.Radius)
				if inside then
					s.holdSince = s.holdSince or os.clock()
					advance = os.clock() - s.holdSince >= step.Seconds
				else
					s.holdSince = nil
				end
			elseif step.Kind == "Collect" then
				local changed = false
				for i, p in ipairs(step.Points) do
					if not s.got[i] and (here - flat(p)).Magnitude <= step.Radius and not tooSoon(s, p, step.Radius) then
						s.got[i] = true
						changed = true
						-- The next point is timed from this one.
						s.from, s.fromRadius, s.stepAt = flat(p), step.Radius, os.clock()
					end
				end
				local all = true
				for i in ipairs(step.Points) do
					all = all and s.got[i] == true
				end
				advance = all
				if changed and not all then
					publish(player)
					missionEvent:FireClient(player, "Collected", {})
				end
			end
			if advance then
				s.step += 1
				s.holdSince = nil
				s.got = {}
				-- The next goal is timed from this one (a Collect step already set its last point).
				if step.Pos then
					s.from, s.fromRadius = flat(step.Pos), step.Radius
				end
				s.stepAt = os.clock()
				if s.step > #s.m.Steps then
					finish(player, true)
				else
					publish(player)
					missionEvent:FireClient(player, "Step", { Text = s.m.Steps[s.step].Text })
				end
			end
		end
	end
end

local function onRequest(player, action, id)
	if not RateLimit.Allow(player, "Mission", 1, 2) or type(action) ~= "string" then
		return
	end
	if action == "Quit" then
		finish(player, false, "Quit")
		return
	end
	if action ~= "Start" or type(id) ~= "string" then
		return
	end
	local m = Missions.ById[id]
	if not m or m.Crew then
		return -- (crew preps start from the CREW app, through CrewService)
	end
	if active[player] then
		-- START on the phone during a mission closed the phone and nothing happened: say why.
		notify:FireClient(player, "MissionBusy")
		return
	end
	if player:GetAttribute("Side") ~= "Civilian" then
		-- Police were told to "finish what you're doing and lose any heat", which they can't do: missions
		-- are free-roam only, so say that instead.
		notify:FireClient(player, "MissionCivOnly")
		return
	end
	if (player:GetAttribute("Heat") or 0) > 0 or player:GetAttribute("RacingId") or player:GetAttribute("JobKind")
		or player:GetAttribute("BigScore") then -- (on a Big Score crew: BigScoreService)
		notify:FireClient(player, "MissionBusy")
		return
	end
	if lastEnd[player] and os.clock() - lastEnd[player] < Missions.Cooldown then
		notify:FireClient(player, "MissionCooldown")
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	-- A home's inside sits far off the map: a mission started there timed the first trip from out there,
	-- so the first goal didn't count for half a minute or more. Indoors the start spot is unknown instead
	-- (tick sets it at the door once the player steps out).
	local known = root and not player:GetAttribute("InHome")
	active[player] = { m = m, step = 1, deadline = now() + m.TimeLimit, got = {},
		from = known and flat(root.Position) or nil, fromRadius = 0, stepAt = os.clock() }
	publish(player)
	missionEvent:FireClient(player, "Started", { Name = m.Name, Text = m.Steps[1].Text })
end

function MissionService.Active(player)
	return active[player] ~= nil
end

-- (see the header) Crew prep `id` for these players, who CrewService has checked are one crew (crewId),
-- here, in free roam and free. onDone(passed, players) runs as it ends. True when it started.
function MissionService.StartCrew(players, id, crewId, onDone)
	local m = Missions.ById[id]
	if not m or not m.Crew or type(players) ~= "table" or #players == 0 then
		return false
	end
	for _, p in ipairs(players) do
		if active[p] or p.Parent ~= Players then
			return false
		end
	end
	Missions.Resolve(m)
	local from
	for _, p in ipairs(players) do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if root and not p:GetAttribute("InHome") then
			from = flat(root.Position)
			break
		end
	end
	local s = {
		m = m, step = 1, deadline = now() + m.TimeLimit, got = {}, from = from, fromRadius = 0, stepAt = os.clock(),
		crew = table.clone(players), crewId = crewId, onDone = onDone,
		need = math.min(#players, (Missions.CrewJob and Missions.CrewJob.Together) or 2),
	}
	-- The hands-on steps need their things in the world (CrewTasks); without it such a prep can't be done.
	local handsOn = false
	for _, step in ipairs(m.Steps) do
		if step.Kind == "Pickup" or step.Kind == "Deliver" or step.Kind == "Pair" then
			handsOn = true
		end
	end
	if handsOn then
		local okWorld, world = pcall(function()
			return require(ServerScriptService.Services:FindFirstChild("CrewTasks")).Run(crewId, function(p, kind, index)
				if active[p] ~= s then
					sayTo(p, "NotYourJob")
					return false
				end
				return act(s, p, kind, index)
			end)
		end)
		if not okWorld or not world then
			warn("[MissionService] crew tasks: " .. tostring(world))
			return false
		end
		s.world = world
		local okStep, errStep = pcall(enterStep, s)
		if not okStep then
			warn("[MissionService] crew step: " .. tostring(errStep))
			pcall(world.Clear, world)
			return false
		end
	end
	for _, p in ipairs(players) do
		active[p] = s
		publish(p)
		missionEvent:FireClient(p, "Started", { Name = m.Name, Text = m.Steps[1].Text })
	end
	return true
end

-- (see the header) A crew member's prompt hold on a hands-on step's thing ("Grab" item index, "Stash",
-- "Pair" spot index), already checked by CrewTasks. True when it counted.
function MissionService.CrewAct(player, kind, index)
	local s = active[player]
	if not s or not s.crew then
		return false
	end
	return act(s, player, kind, index)
end

-- What `player` carries on their crew prep right now (0 when none): CrewTasks and tests ask.
function MissionService.Carrying(player)
	local s = active[player]
	return s and s.crew and carriedBy(s, player) or 0
end

function MissionService.Init()
	missionEvent = Remotes.Event("MissionEvent")
	notify = Remotes.Event("Notify")
	crewJob = Remotes.Event("CrewJob")
	Remotes.Event("RequestMission").OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(p)
		local s = active[p]
		if s and s.crew then
			-- (at once, not on the next tick: a crew of one leaving would leave the prep's things in the world)
			finishCrew(s, false, p.DisplayName .. " left the game")
		end
		active[p] = nil
		lastEnd[p] = nil
	end)
	DataService.OnLoaded(function(p)
		publishDone(p)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			acc = 0
			tick()
		end
	end)
end

return MissionService
