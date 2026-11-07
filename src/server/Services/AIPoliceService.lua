-- AIPoliceService (ModuleScript, ServerScriptService.Services.AIPoliceService)
-- AI patrol cars keep crime exciting when few players are cops.
--   * Only while fewer than 2 player cops are online and patrolling (a cop away from the keys doesn't
--     count: ArrestService.IsActiveCop). Per wanted player: 1 car at 1-2 stars (only if there are no
--     such player cops at all), then 3 cars at 3 stars, 4 at 4 and 5 at 5 (CARS_BY_STARS; owner, Nov 4:
--     "If you have 3 stars, I think there should be more cops trying to get you"; it was 2, 3 and 3).
--     From 3 stars they come SPAWN_GAP_HOT seconds apart instead of SPAWN_GAP, so they arrive as a pack.
--     Coast Guard boats keep the old count (heat - 1, max 3). At most MAX_TOTAL in the server.
--     (The police helicopter that joins at 5 stars is PoliceHeliService's.)
--   * Head start: no patrol comes until the player has been wanted (WantedSince, set by HeatService)
--     for 20 s at 1 star, 14 s at 2, 8 s at 3, 4 s at 4+ (well inside HeatService's 30 + 10 x heat s
--     escape timer, so patrols get time to search). While waiting, the player attribute
--     PoliceETA (server time) says when they'll come, so the objective banner can count down.
--   * They spawn on a road 350-600 studs away (600-900 if there's none), out of the target's sight
--     when possible, follow the RoadGraph toward the target, and switch to direct pursuit once they
--     are close or can see the target. Where no road is in either ring (e.g. out on Lighthouse Key)
--     they use the road node nearest 350 studs that is at least 150 away, so no spot is a free escape.
--   * They never go faster than 95% of the target's car, so a good driver can always escape.
--   * Rookies (Config.Tutorial.Rookie: a citizen who hasn't banked a first bag, at 1-2 stars) get patrols
--     held to 70% of their car's speed (and at least a 20 s head start at 2 stars too), so the tutorial's
--     first chase is a real chase they can win.
--   * Stuck (slow for 2 s) -> reverse and turn; upside down -> flipped back.
--   * They are cop "eyes" for HeatService, and arrest a wanted player who stays stopped (car under
--     8 studs/s, or on foot under 10) within 22 studs (and under ARREST_RISE above or below: not
--     through a floor) for about 3 seconds. They park a car length away instead of shoving the target.
--   * They leave when the target is no longer wanted, leaves, or they fall 900+ studs behind for 15 s.
--   * Reset Character is no way out: a target whose body goes down by itself with a patrol close by is
--     arrested (ArrestService.GaveUp). Further away the patrols leave and new ones find the new body.
--   * Officers (PoliceOfficerService): one rides in each car, two from 3 stars. Once the car pulls up
--     next to a suspect on foot or in a stopped car they get out and do the arresting (or the shooting)
--     on foot, and the car waits with its brakes on; they get back in when the suspect drives off. A car
--     whose officers are all down or dead stays put for GONE_WAIT seconds, then goes (a new one comes).
--     Without officers (their looks not built yet) the car arrests by itself, as it always did.
--   * Coast Guard (owner, Nov 4: wanted on the water, a cop that can drive on water comes and arrests you,
--     so the sea is no easy way out). A wanted player sitting in a boat that floats, or in the sea itself
--     where it is SEA_DEPTH+ deep, is "at sea" (atSea): the patrol cars leave, as they always did for a
--     boat, and Coast Guard boats come instead, as many as cars would and after the same head start. A boat
--     run up on the sand is not at sea: patrol cars come for it and their officers cuff the driver (sitting
--     in a beached boat used to keep every patrol away). The prison moat (6.5 deep) is too shallow for
--     them: a swimmer there still gets the patrol cars.
--     They are the Harbor Patrol boat player cops drive, named AICoastGuard (attribute CoastGuard), with
--     the AIPolice / AITarget attributes of a patrol car, so sirens, lights, minimap blips, hands up and
--     Reset Character all treat them as police. They appear in open water CG_SPAWN_DEPTH+ deep with nothing
--     over it, 350-600 studs off (then 600-900, then 150-350), and steer straight at the target, leading
--     it. Held to 95% of the target's top speed like the cars (their own top speed is CG_TOP, over every
--     boat's, so that rule decides even against the fastest one).
--     Arrest: a boat slower than CG_SLOW, or anyone in the water, within CG_ARREST_RANGE (flat) for
--     ARREST_SECONDS. A boat's driver sees the BEING CUFFED bar (PoliceOfficerService.BoatCuff: "DRIVE to
--     break free"); a swimmer gets the CoastGuardSwim toast instead (there's no swimming away from a boat).
--     The officers ride along and stay aboard. Aground away from the target: back off and turn; aground
--     CG_STRANDED s, stuck CG_STUCK_TRIES times in a row, or 900+ studs behind for 15 s: it goes and a new
--     one comes in open water. Target ashore: it waits where it is, still watching, for CG_LINGER s, then
--     goes, and the patrol cars take over. The target hears about it once a chase (Notify "CoastGuard").
-- Server-owned physics (CarPhysics) so VehicleGuard never checks them. They have to stay server-owned:
-- welding a rider in or out puts a car back on automatic ownership, the nearest player's device takes it
-- over, and the server's suspension forces reach it late, so it bounces and flips down the road (drive
-- takes it back every frame).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local CarPhysics = require(ReplicatedStorage.Shared.Util.CarPhysics)
local RoadGraph = require(ReplicatedStorage.Shared.Util.RoadGraph)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local CarBuilder = require(ServerStorage.Tools.CarBuilder)
local HeatService = require(ServerScriptService.Services.HeatService)
local Officers = require(ServerScriptService.Services.PoliceOfficerService)

local AIPoliceService = {}

local MAX_TOTAL = 8 -- (was 6: two players at 4 stars now bring 4 cars each)
local CARS_BY_STARS = { 1, 1, 3, 4, 5 } -- patrol cars per wanted player (1-2 stars: only with no player cop)
local BOATS_MAX = 3 -- Coast Guard boats per wanted player: heat - 1, at most this many
local SPAWN_MIN, SPAWN_MAX = 350, 600 -- preferred spawn distance from the target
local SPAWN_FAR = 900 -- fallback ring when no road is in the preferred band
local SPAWN_LAST = 150 -- last resort when neither ring has a road: never spawn closer than this
local GRACE = { 20, 14, 8, 4, 4 } -- head start in seconds, by stars (owner: "more time to think" after an ATM)
local LOS_TRIES = 10 -- raycasts spent looking for a spawn the target can't see
local DIRECT_RANGE = 140
local ARREST_RANGE = 22
local ARREST_RISE = 6 -- studs up or down: a target on the floor above (a storey is 14) is out of reach
local ARREST_SECONDS = 3
local LOST_RANGE = 900
local LOST_SECONDS = 15
local SPAWN_GAP = 6 -- seconds between spawns for the same target
local SPAWN_GAP_HOT = 3 -- the same from 3 stars, so the bigger pack arrives together
local GONE_WAIT = 15 -- seconds a car whose officers are all down waits before it goes

-- Coast Guard (see the header)
local CG_VEHICLE = "HarborPatrol" -- the police boat player cops drive
local CG_TOP = 180 -- studs/s: over every boat's top speed (Swordfish 175), so the 95% rule decides
local SEA_DEPTH = 8 -- studs of water under a swimmer before it's the Coast Guard's job (the ocean is 19.5)
local CG_SPAWN_DEPTH = 10 -- studs of water a Coast Guard boat appears in
local CG_ROOM = 12 -- studs of open water each way around that spot (the boat is 21 long)
local CG_SKY = 80 -- spawn rays start this high, so a pier, deck or yacht over the water rules the spot out
local CG_SPAWN_TRIES = 24 -- random spots tried per ring
local CG_PARK = 24 -- studs (flat, centre to centre): it stops this far from its target, never rams it
local CG_EASE = 120 -- studs: closer than this it slows to the target's pace (boats coast a long way)
local CG_ARREST_RANGE = 36
local CG_ARREST_RISE = 10
local CG_SLOW = 12 -- studs/s: a boat slower than this has stopped (boats drift on a little)
local CG_LINGER = 10 -- seconds it waits offshore once its target has gone ashore
local CG_STRANDED = 12 -- seconds aground (in all) before it gives up
local CG_STUCK_TRIES = 5 -- back-offs less than 20 s apart before it gives up
local SEABED_REACH = 80

local units = {} -- list of AI unit tables (u.boat = true for a Coast Guard boat)
local lastSpawnFor = {} -- [player] = os.clock()
local wantedAt = {} -- [player] = server time we first saw them wanted (only used if WantedSince is missing)
local atSeaNow = {} -- [player] = true while out on the water (manage: once a second)
local cgToldFor = {} -- [player] = the WantedSince of the chase they heard "Coast Guard on the way" in
local rng = Random.new()
local notify

local losParams = RaycastParams.new()
losParams.FilterType = Enum.RaycastFilterType.Exclude
losParams.IgnoreWater = true

-- Water probes: the first stops on the water's surface, the second goes through it to the bottom. Both
-- skip vehicles, officers and players (setWaterFilter), so only the world counts.
local waterParams = RaycastParams.new()
waterParams.FilterType = Enum.RaycastFilterType.Exclude
waterParams.IgnoreWater = false
local bedParams = RaycastParams.new()
bedParams.FilterType = Enum.RaycastFilterType.Exclude
bedParams.IgnoreWater = true

-- Player cops who are really patrolling (ArrestService.IsActiveCop): two cops away from the keys used to
-- keep every AI patrol off the whole server. (Looked up when needed, as drive does.)
local function copCount()
	local arrestService = require(ServerScriptService.Services.ArrestService)
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Side") == "Cop" and arrestService.IsActiveCop(p) then
			n += 1
		end
	end
	return n
end

local function wanted(p)
	return p.Parent == Players and p:GetAttribute("Side") == "Civilian" and (p:GetAttribute("Heat") or 0) > 0
end

local function targetInfo(p)
	local char = p.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root then
		return nil
	end
	local seat = hum.SeatPart
	local car = seat and seat.Parent
	local chassis = car and car:IsA("Model") and car.PrimaryPart -- (a home's chair sits in a Folder)
	if chassis then
		return { pos = chassis.Position, vel = chassis.AssemblyLinearVelocity, maxSpeed = car:GetAttribute("MaxSpeed") or 120, inCar = true,
			boat = car:GetAttribute("Boat") == true }
	end
	return { pos = root.Position, vel = root.AssemblyLinearVelocity, maxSpeed = 120, inCar = false }
end

-- How many units this wanted player gets: patrol cars on land, Coast Guard boats at sea (see the header).
local function desiredFor(p, cops, sea)
	if cops >= 2 then
		return 0
	end
	local heat = math.clamp(math.floor(p:GetAttribute("Heat") or 0), 0, #CARS_BY_STARS)
	if heat >= 3 then
		return sea and math.min(BOATS_MAX, heat - 1) or CARS_BY_STARS[heat]
	end
	return cops == 0 and 1 or 0
end

-- Units after this player: every one, or only Coast Guard boats (boat = true) or only cars (false).
local function unitsFor(p, boat)
	local n = 0
	for _, u in ipairs(units) do
		if u.target == p and (boat == nil or (u.boat == true) == boat) then
			n += 1
		end
	end
	return n
end

-- The water probes skip everything that moves: vehicles, officers, smoke clouds and every player.
local function setWaterFilter()
	local list = {}
	for _, name in ipairs({ "Vehicles", "NPCs", "Smoke" }) do
		local f = Workspace:FindFirstChild(name)
		if f then
			table.insert(list, f)
		end
	end
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			table.insert(list, pl.Character)
		end
	end
	waterParams.FilterDescendantsInstances = list
	bedParams.FilterDescendantsInstances = list
end

-- Straight down from (x, top, z): the water's surface height if the first thing there is water (not
-- land, a pier or a deck over it), else nil.
local function waterTop(x, top, z, reach)
	local hit = Workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -reach, 0), waterParams)
	return (hit and hit.Material == Enum.Material.Water) and hit.Position.Y or nil
end

-- How deep the water is under the surface at (x, y, z).
local function depthAt(x, y, z)
	local bed = Workspace:Raycast(Vector3.new(x, y + 0.5, z), Vector3.new(0, -SEABED_REACH, 0), bedParams)
	return bed and (y - bed.Position.Y) or SEABED_REACH
end

-- Out on the water (see the header): in a boat that floats, or in the sea itself where it's deep.
local function atSea(info)
	if info.inCar and not info.boat then
		return false -- (a car in the water is sinking: VehicleService takes it away, then they swim)
	end
	local y = waterTop(info.pos.X, info.pos.Y + 6, info.pos.Z, 20)
	if not y then
		return false
	end
	return info.boat == true or depthAt(info.pos.X, y, info.pos.Z) >= SEA_DEPTH
end

-- Open water all round (x, z), at least CG_ROOM studs each way.
local function roomAt(x, z)
	for _, o in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		if not waterTop(x + o[1] * CG_ROOM, CG_SKY, z + o[2] * CG_ROOM, CG_SKY + 40) then
			return false
		end
	end
	return true
end

-- Where a Coast Guard boat can appear for this target: deep, open water 350-600 studs off (600-900 if
-- there's none, 150-350 as a last resort). nil if there's no such water anywhere near.
local function pickWaterSpawn(info)
	for _, ring in ipairs({ { SPAWN_MIN, SPAWN_MAX }, { SPAWN_MAX, SPAWN_FAR }, { SPAWN_LAST, SPAWN_MIN } }) do
		for _ = 1, CG_SPAWN_TRIES do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(ring[1], ring[2])
			local x, z = info.pos.X + math.cos(a) * r, info.pos.Z + math.sin(a) * r
			local y = waterTop(x, CG_SKY, z, CG_SKY + 40)
			if y and depthAt(x, y, z) >= CG_SPAWN_DEPTH and roomAt(x, z) then
				return Vector3.new(x, y, z)
			end
		end
	end
	return nil
end

local function despawn(u)
	for i, x in ipairs(units) do
		if x == u then
			table.remove(units, i)
			break
		end
	end
	if u.crew then
		Officers.Remove(u.crew)
		u.crew = nil
	end
	if u.car.Parent then
		HeatService.UnregisterEye(u.car.PrimaryPart)
		u.car:Destroy()
	end
end

local function serverNow()
	return Workspace:GetServerTimeNow()
end

-- Server time when patrols may start coming for this wanted player (their head start ends).
local function arrivalTime(p)
	local since = p:GetAttribute("WantedSince")
	if typeof(since) ~= "number" then
		wantedAt[p] = wantedAt[p] or serverNow()
		since = wantedAt[p]
	end
	local stars = math.clamp(math.floor(p:GetAttribute("Heat") or 1), 1, #GRACE)
	if Tutorial.IsRookie(p) then -- first robbery: a longer head start (Config.Tutorial.Rookie)
		return since + math.max(GRACE[stars], Tutorial.Rookie.HeadStart)
	end
	return since + GRACE[stars]
end

local function setETA(p, value)
	if p:GetAttribute("PoliceETA") ~= value then
		p:SetAttribute("PoliceETA", value)
	end
end

-- A road node far enough away that the player has time to react (350-600 studs, or 600-900 if no
-- road is in that band), preferring one the target can't see from where they are.
local function pickSpawnNode(p, info)
	local flat = Vector3.new(info.pos.X, 0, info.pos.Z)
	local near, far = {}, {}
	local last, lastGap -- last resort: the node whose distance is nearest SPAWN_MIN (>= SPAWN_LAST away)
	for _, n in ipairs(RoadGraph.Nodes) do
		local d = (n - flat).Magnitude
		if d >= SPAWN_MIN and d <= SPAWN_MAX then
			table.insert(near, n)
		elseif d > SPAWN_MAX and d <= SPAWN_FAR then
			table.insert(far, n)
		end
		local gap = math.abs(d - SPAWN_MIN)
		if d >= SPAWN_LAST and (not lastGap or gap < lastGap) then
			last, lastGap = n, gap
		end
	end
	local choices = #near > 0 and near or far
	if #choices == 0 then
		-- Road nodes only sit at road ends and crossings, so a small island (Lighthouse Key) can have
		-- none in either ring. Still send a patrol, or that spot would be a guaranteed escape.
		return last
	end
	local fallback = choices[rng:NextInteger(1, #choices)]
	losParams.FilterDescendantsInstances = { Workspace.Vehicles, p.Character }
	for _ = 1, math.min(LOS_TRIES, #choices) do
		local i = rng:NextInteger(1, #choices)
		local n = table.remove(choices, i)
		local from = n + Vector3.new(0, 6, 0) -- roughly a patrol car's roof
		if Workspace:Raycast(from, info.pos - from, losParams) ~= nil then
			return n -- something blocks the view: the target won't see it appear
		end
	end
	return fallback
end

local function spawnFor(p, info)
	local node = pickSpawnNode(p, info)
	if not node then
		return
	end
	local path = RoadGraph.Path(node, info.pos)
	local nextPoint = (path and path[2]) or info.pos
	local pos = node + Vector3.new(0, 3.2, 0)
	local car = CarBuilder.Build("SunrayPatrol")
	car.Name = "AIPatrol"
	car:SetAttribute("AIPolice", true)
	car:SetAttribute("AITarget", p.UserId)
	local look = Vector3.new(nextPoint.X, pos.Y, nextPoint.Z)
	car:PivotTo(CFrame.lookAt(pos, (look - pos).Magnitude > 1 and look or pos + Vector3.new(0, 0, -1)))
	local prompt = car:FindFirstChild("DrivePrompt", true)
	if prompt then
		prompt:Destroy()
	end
	car.Parent = Workspace.Vehicles
	car.PrimaryPart:SetNetworkOwner(nil)
	HeatService.RegisterEye(car.PrimaryPart)
	local u = {
		car = car,
		target = p,
		phys = CarPhysics.New(car, {}),
		path = path,
		pathIndex = 2,
		repathAt = 0,
		stuckFor = 0,
		reverseUntil = 0,
		upsideFor = 0,
		arrestFor = 0,
		lostFor = 0,
	}
	table.insert(units, u)
	lastSpawnFor[p] = os.clock()
	local ok, crew = pcall(Officers.Board, car, (p:GetAttribute("Heat") or 0) >= 3 and 2 or 1)
	u.crew = ok and crew or nil
end

-- A Coast Guard boat for a target out on the water (see the header).
local function spawnBoatFor(p, info)
	lastSpawnFor[p] = os.clock() -- (a search that finds no water waits SPAWN_GAP before the next one too)
	local at = pickWaterSpawn(info)
	if not at then
		return
	end
	local pos = at + Vector3.new(0, 2.5, 0) -- (as a boat pad: VehicleService.padCFrame)
	local car = CarBuilder.Build(CG_VEHICLE)
	car.Name = "AICoastGuard"
	car:SetAttribute("AIPolice", true)
	car:SetAttribute("CoastGuard", true)
	car:SetAttribute("AITarget", p.UserId)
	car:SetAttribute("DisplayName", "Coast Guard")
	car:SetAttribute("MaxSpeed", CG_TOP)
	car:PivotTo(CFrame.lookAt(pos, Vector3.new(info.pos.X, pos.Y, info.pos.Z)))
	local prompt = car:FindFirstChild("DrivePrompt", true)
	if prompt then
		prompt:Destroy()
	end
	car.Parent = Workspace.Vehicles
	car.PrimaryPart:SetNetworkOwner(nil)
	HeatService.RegisterEye(car.PrimaryPart)
	local u = {
		car = car,
		target = p,
		boat = true,
		phys = CarPhysics.New(car, {}),
		stuckFor = 0,
		stucks = 0,
		lastStuckAt = -math.huge,
		reverseUntil = 0,
		upsideFor = 0,
		arrestFor = 0,
		lostFor = 0,
		strandedFor = 0,
		ashoreFor = 0,
	}
	table.insert(units, u)
	-- Officers ride along (they stay aboard: driveBoat never lets them out).
	local ok, crew = pcall(Officers.Board, car, (p:GetAttribute("Heat") or 0) >= 3 and 2 or 1)
	u.crew = ok and crew or nil
	-- Once a chase: the Coast Guard is coming.
	local since = p:GetAttribute("WantedSince") or wantedAt[p] or 0
	if cgToldFor[p] ~= since then
		cgToldFor[p] = since
		notify:FireClient(p, "CoastGuard")
	end
end

local function drive(u, dt, now)
	local car = u.car
	local chassis = car.PrimaryPart
	if not chassis or not car.Parent then
		return despawn(u)
	end
	if chassis:GetNetworkOwnershipAuto() then
		chassis:SetNetworkOwner(nil) -- (an officer got in or out: see the header)
	end
	local p = u.target
	if not wanted(p) then
		return despawn(u)
	end
	local info = targetInfo(p)
	if not info then
		-- No live body: they pressed Reset Character (or went down by themselves some other way). That
		-- used to be a free way out: every patrol vanished and the bag went home with them. So before
		-- this car goes, ArrestService gets to count it as giving up if police were close (GaveUp).
		-- Too far for that, the patrols still leave and new ones go after the new body.
		require(ServerScriptService.Services.ArrestService).GaveUp(p)
		return despawn(u)
	end
	if atSeaNow[p] or (info.boat and atSea(info)) then
		-- Road patrols can't follow anyone out to sea: the Coast Guard does (driveBoat).
		return despawn(u)
	end
	-- A boat run up on the sand is a stopped vehicle like any other: the officers walk up and cuff the
	-- driver (PoliceOfficerService.Step keeps them in the car for a boat).
	info.boat = false
	local pos = chassis.Position
	local cf = chassis.CFrame
	local toTarget = info.pos - pos
	local dist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude

	-- Gone missing?
	if dist > LOST_RANGE then
		u.lostFor += dt
		if u.lostFor > LOST_SECONDS then
			return despawn(u)
		end
	else
		u.lostFor = 0
	end
	if pos.Y < 0.2 or pos.Y < -60 then
		return despawn(u) -- drove into water or fell out of the world
	end

	-- Officers out on foot: the car waits (brakes on, lights on) until they're back in.
	if u.crew then
		local mode = Officers.Step(u.crew, dt, p, info, chassis.AssemblyLinearVelocity.Magnitude)
		if mode == "gone" then
			u.goneAt = u.goneAt or now
			if now - u.goneAt > GONE_WAIT then
				return despawn(u)
			end
		end
		if mode ~= "ride" then
			local fwd = chassis.AssemblyLinearVelocity:Dot(cf.LookVector)
			CarPhysics.Step(u.phys, dt, { Throttle = math.abs(fwd) > 1 and -math.sign(fwd) or 0, Steer = 0, SpeedScale = 1 })
			return
		end
	end

	-- Where to aim: straight at the target when close or in sight, otherwise along the roads.
	losParams.FilterDescendantsInstances = { car, p.Character, Workspace.Vehicles }
	local canSee = dist < 250 and Workspace:Raycast(pos + Vector3.new(0, 2, 0), toTarget, losParams) == nil
	local aim
	if dist < DIRECT_RANGE or canSee then
		aim = info.pos + info.vel * math.clamp(dist / 150, 0, 0.8) -- lead a moving target
	else
		if now > u.repathAt or not u.path then
			u.path = RoadGraph.Path(pos, info.pos)
			u.pathIndex = 2
			u.repathAt = now + 2
		end
		local path = u.path
		if path then
			while path[u.pathIndex] and (Vector3.new(pos.X, 0, pos.Z) - path[u.pathIndex]).Magnitude < 25 do
				u.pathIndex += 1
			end
			aim = path[u.pathIndex] or info.pos
		else
			aim = info.pos
		end
	end
	local dir = Vector3.new(aim.X - pos.X, 0, aim.Z - pos.Z)
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
	local angle = 0
	if dir.Magnitude > 0.1 and look.Magnitude > 0.1 then
		dir, look, right = dir.Unit, look.Unit, right.Unit
		angle = math.atan2(dir:Dot(right), dir:Dot(look))
	end
	local speed = chassis.AssemblyLinearVelocity:Dot(cf.LookVector)
	local throttle, steer = 1, math.clamp(angle * 2.2, -1, 1)
	if math.abs(angle) > 1.2 and speed > 45 then
		throttle = 0.15 -- slow down for sharp turns
	end
	if math.abs(angle) > 2.4 and speed < 20 then
		throttle, steer = -0.8, -steer -- target behind us: back up while turning
	end
	-- Close in smoothly: the nearer the target, the slower we want to be (no overshooting).
	local desired = math.max(12, dist * 1.3 + info.vel.Magnitude)
	if dist < 90 and speed > desired then
		throttle = -0.6
	end
	if dist < 18 then
		throttle = speed > 4 and -1 or 0 -- park a car length away; never shove the target around
	end

	-- Stuck? Back up for a moment.
	if now < u.reverseUntil then
		throttle, steer = -1, u.reverseSteer
	elseif throttle > 0.5 and math.abs(speed) < 3 then
		u.stuckFor += dt
		if u.stuckFor > 2 then
			u.stuckFor = 0
			u.reverseUntil = now + 1.3
			u.reverseSteer = angle > 0 and -1 or 1
		end
	else
		u.stuckFor = 0
	end

	-- Upside down? Put it back.
	if cf.UpVector.Y < 0.3 then
		u.upsideFor += dt
		if u.upsideFor > 3 then
			u.upsideFor = 0
			car:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 4, 0), pos + Vector3.new(0, 4, 0) + (look.Magnitude > 0 and look or Vector3.new(0, 0, -1))))
			chassis.AssemblyLinearVelocity = Vector3.zero
			chassis.AssemblyAngularVelocity = Vector3.zero
		end
	else
		u.upsideFor = 0
	end

	-- Never faster than 95% of the target's car (a rookie's: Config.Tutorial.Rookie.SpeedScale).
	local share = Tutorial.IsRookie(p) and Tutorial.Rookie.SpeedScale or 0.95
	local scale = math.min(1, (info.maxSpeed * share) / (car:GetAttribute("MaxSpeed") or 135))
	CarPhysics.Step(u.phys, dt, { Throttle = throttle, Steer = steer, SpeedScale = scale })

	-- Arrest a target who stays (nearly) stopped right next to us. Brief wiggles don't reset the
	-- timer, they only slow it down; driving off properly does. (A car with officers leaves that to them.)
	local slow = info.inCar and info.vel.Magnitude < 8 or (not info.inCar and info.vel.Magnitude < 10)
	local close = dist < ARREST_RANGE and math.abs(toTarget.Y) < ARREST_RISE -- (dist is flat: not through a floor)
	if u.crew then
		u.arrestFor = 0
	elseif close and slow then
		u.arrestFor += dt
		if u.arrestFor >= ARREST_SECONDS then
			u.arrestFor = 0
			require(ServerScriptService.Services.ArrestService).Arrest(p, nil)
		end
	else
		u.arrestFor = math.max(0, u.arrestFor - dt * (close and 0.5 or 2))
	end
end

-- A Coast Guard boat's frame (see the header): straight at the target over the water, no roads.
local function driveBoat(u, dt, now)
	local car = u.car
	local chassis = car.PrimaryPart
	if not chassis or not car.Parent then
		return despawn(u)
	end
	if chassis:GetNetworkOwnershipAuto() then
		chassis:SetNetworkOwner(nil) -- (a rider welded in: see the header)
	end
	local p = u.target
	if not wanted(p) then
		return despawn(u)
	end
	local info = targetInfo(p)
	if not info then
		-- Reset Character out at sea is giving up too, with a boat this close (as for the cars).
		require(ServerScriptService.Services.ArrestService).GaveUp(p)
		return despawn(u)
	end
	local pos = chassis.Position
	local cf = chassis.CFrame
	if pos.Y < -60 then
		return despawn(u)
	end
	local toTarget = info.pos - pos
	local dist = Vector3.new(toTarget.X, 0, toTarget.Z).Magnitude
	if dist > LOST_RANGE then
		u.lostFor += dt
		if u.lostFor > LOST_SECONDS then
			return despawn(u)
		end
	else
		u.lostFor = 0
	end
	local speed = chassis.AssemblyLinearVelocity:Dot(cf.LookVector)

	-- Target ashore: wait here (still watching) for a while, then go; the patrol cars take over.
	if not atSeaNow[p] then
		u.ashoreFor += dt
		u.arrestFor = 0
		Officers.BoatCuff(p, car, 0)
		if u.ashoreFor > CG_LINGER then
			return despawn(u)
		end
		CarPhysics.Step(u.phys, dt, { Throttle = math.abs(speed) > 1 and -math.sign(speed) or 0, Steer = 0, SpeedScale = 1 })
		return
	end
	u.ashoreFor = 0

	-- Straight at the target, leading it.
	local aim = info.pos + info.vel * math.clamp(dist / 150, 0, 0.8)
	local dir = Vector3.new(aim.X - pos.X, 0, aim.Z - pos.Z)
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
	local angle = 0
	if dir.Magnitude > 0.1 and look.Magnitude > 0.1 then
		dir, look, right = dir.Unit, look.Unit, right.Unit
		angle = math.atan2(dir:Dot(right), dir:Dot(look))
	end
	local throttle, steer = 1, math.clamp(angle * 2.2, -1, 1)
	if math.abs(angle) > 1.2 and speed > 45 then
		throttle = 0.15 -- ease off for a sharp turn
	end
	if math.abs(angle) > 2.4 and speed < 20 then
		throttle, steer = -0.8, -steer -- target behind: back round
	end
	local desired = math.max(12, dist * 1.3 + info.vel.Magnitude)
	if dist < CG_EASE and speed > desired then
		throttle = -0.6
	end
	if dist < CG_PARK then
		throttle = speed > 4 and -1 or 0 -- alongside: hold here, never ram them
	end

	-- Aground (the last step's water rays found land: CarPhysics phys.Beached) or stuck on a pier.
	local beached = u.phys.Beached == true
	if beached then
		u.strandedFor += dt
		if u.strandedFor > CG_STRANDED then
			return despawn(u) -- (a new one comes in open water)
		end
	end
	if now < u.reverseUntil then
		throttle, steer = -1, u.reverseSteer
	elseif (beached and dist > CG_ARREST_RANGE) or (throttle > 0.5 and math.abs(speed) < 3) then
		u.stuckFor += dt
		if u.stuckFor > 2 then
			u.stuckFor = 0
			u.reverseUntil = now + 1.5
			u.reverseSteer = angle > 0 and -1 or 1
			u.stucks = (now - u.lastStuckAt < 20) and u.stucks + 1 or 1
			u.lastStuckAt = now
			if u.stucks >= CG_STUCK_TRIES then
				return despawn(u)
			end
		end
	else
		u.stuckFor = 0
	end

	-- Upside down? Put it back.
	if cf.UpVector.Y < 0.3 then
		u.upsideFor += dt
		if u.upsideFor > 3 then
			u.upsideFor = 0
			car:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 4, 0), pos + Vector3.new(0, 4, 0) + (look.Magnitude > 0 and look or Vector3.new(0, 0, -1))))
			chassis.AssemblyLinearVelocity = Vector3.zero
			chassis.AssemblyAngularVelocity = Vector3.zero
		end
	else
		u.upsideFor = 0
	end

	-- Never faster than 95% of the target's boat (a swimmer counts as 120).
	local scale = math.min(1, (info.maxSpeed * 0.95) / (car:GetAttribute("MaxSpeed") or CG_TOP))
	CarPhysics.Step(u.phys, dt, { Throttle = throttle, Steer = steer, SpeedScale = scale })

	-- Arrest: a boat that stays (nearly) stopped alongside, or anyone in the water this close.
	local swimmer = not info.inCar
	local slow = swimmer or info.vel.Magnitude < CG_SLOW
	local close = dist < CG_ARREST_RANGE and math.abs(toTarget.Y) < CG_ARREST_RISE
	if close and slow then
		if swimmer and not u.toldSwim then
			u.toldSwim = true
			notify:FireClient(p, "CoastGuardSwim")
		end
		u.arrestFor += dt
		if u.arrestFor >= ARREST_SECONDS then
			u.arrestFor = 0
			Officers.BoatCuff(p, car, 0)
			require(ServerScriptService.Services.ArrestService).Arrest(p, nil)
			return
		end
	else
		u.arrestFor = math.max(0, u.arrestFor - dt * (close and 0.5 or 2))
	end
	-- The driver's BEING CUFFED bar ("DRIVE to break free").
	Officers.BoatCuff(p, car, (not swimmer and u.arrestFor > 0) and u.arrestFor / ARREST_SECONDS or 0)
end

local function manage()
	local cops = copCount()
	local t = serverNow()
	setWaterFilter()
	for _, p in ipairs(Players:GetPlayers()) do
		if wanted(p) then
			local info = targetInfo(p)
			-- Out on the water it's Coast Guard boats, on land patrol cars (each kind leaves the other's
			-- place by itself: drive / driveBoat).
			local sea = info ~= nil and atSea(info)
			atSeaNow[p] = sea or nil
			local want = desiredFor(p, cops, sea)
			local have = unitsFor(p, sea)
			local gap = (p:GetAttribute("Heat") or 0) >= 3 and SPAWN_GAP_HOT or SPAWN_GAP
			-- Head start: nobody comes until the grace time for this many stars is over.
			local arriveAt = arrivalTime(p)
			local waiting = t < arriveAt
			setETA(p, (waiting and want > 0 and unitsFor(p) == 0) and arriveAt or nil)
			if info and have < want and not waiting and #units < MAX_TOTAL and os.clock() - (lastSpawnFor[p] or 0) > gap then
				if sea then
					spawnBoatFor(p, info)
				else
					spawnFor(p, info)
				end
			elseif have > want then
				for _, u in ipairs(units) do
					if u.target == p and (u.boat == true) == sea then
						despawn(u)
						break
					end
				end
			end
		else
			wantedAt[p] = nil
			atSeaNow[p] = nil
			setETA(p, nil)
		end
	end
end

function AIPoliceService.Count()
	return #units
end

function AIPoliceService.Init()
	notify = Remotes.Event("Notify")
	RoadGraph.BuildFromWorld()
	RoadGraph.Publish()
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(manage)
			if not ok then
				warn("[AIPolice] " .. tostring(err))
			end
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for i = #units, 1, -1 do
			local u = units[i]
			if u then
				local ok, err = pcall(u.boat and driveBoat or drive, u, dt, now)
				if not ok then
					warn("[AIPolice] " .. tostring(err))
					despawn(u)
				end
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		lastSpawnFor[p] = nil
		wantedAt[p] = nil
		atSeaNow[p] = nil
		cgToldFor[p] = nil
	end)
end

return AIPoliceService
