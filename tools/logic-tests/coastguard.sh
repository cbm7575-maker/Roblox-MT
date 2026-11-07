#!/bin/bash
# AIPoliceService logic tests (the Coast Guard): prelude + a flat stand-in world with an ocean, the prison
# moat, a pier and a beach, kinematic stand-in vehicles (not CarPhysics: this checks the decisions, not
# the handling) + AIPoliceService source (as a function) + scenario. Every line should read PASS.
# Also the star ladder on land (Config.Wanted, Nov 7): head start, cars and speed by stars, and the 1-2 star
# search (seen and then lost: the patrols look round LastSeen instead of driving to the player).
H="$(cd "$(dirname "$0")" && pwd)"
L="${LUAU:-luau}" # the Luau CLI (github.com/luau-lang/luau releases); set LUAU to its path
SRC="${1:-$H/../../src/server/Services/AIPoliceService.lua}" # another copy of AIPoliceService.lua to test, if given
WANTED="${2:-$H/../../src/shared/Config/Wanted.lua}" # the real star table
OUT="${TMPDIR:-${TEMP:-/tmp}}/theft-logic-tests"
mkdir -p "$OUT"

read -r -d '' STUBS <<'EOF'
math.randomseed(7)
typeof = typeof or function(v) return type(v) end

-- Vectors and a yaw-only CFrame (enough for the AI's steering).
local V = {}
Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
end
V.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	end
	return rawget(V, k)
end
V.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then
		a, b = b, a
	end
	return Vector3.new(a.X * b, a.Y * b, a.Z * b)
end
V.__div = function(a, b) return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
V.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
V.Dot = function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
Vector3.zero = Vector3.new(0, 0, 0)
local baseTypeof = typeof
typeof = function(v) -- (as Roblox's: these stand-in vectors read as "Vector3")
	if type(v) == "table" and getmetatable(v) == V then
		return "Vector3"
	end
	return baseTypeof(v)
end

CFrame = {}
local function cfOf(pos, look)
	look = Vector3.new(look.X, 0, look.Z)
	look = look.Magnitude > 1e-6 and look.Unit or Vector3.new(0, 0, -1)
	return { Position = pos, LookVector = look, RightVector = Vector3.new(-look.Z, 0, look.X), UpVector = Vector3.new(0, 1, 0) }
end
function CFrame.lookAt(pos, at) return cfOf(pos, at - pos) end
function CFrame.new(pos) return cfOf(pos or Vector3.zero, Vector3.new(0, 0, -1)) end

Enum = {
	Material = { Water = "Water", Sand = "Sand", Grass = "Grass", Mud = "Mud", WoodPlanks = "WoodPlanks" },
	RaycastFilterType = { Exclude = "Exclude" },
}
RaycastParams = { new = function() return {} end }
Random = { new = function()
	return {
		NextNumber = function(_, a, b) return a + math.random() * (b - a) end,
		NextInteger = function(_, a, b) return math.random(a, b) end,
	}
end }

-- The world, as straight-down rays meet it (top first). Ocean as CityGen's: surface -1.5, bed -21.
-- Prison moat: surface -1.5, bed -8. A pier over the ocean. Land west of the ocean, flat at 0.
local function inBox(x, z, b) return x >= b[1] and x <= b[2] and z >= b[3] and z <= b[4] end
OCEAN = { 1500, 2900, -2400, 2400 }
MOAT = { -1900, -950, 850, 1900 }
PIER = { 1550, 1670, 1100, 1200 }
LAND = { -2000, 1500, -2000, 2000 }
function column(x, z)
	local out = {}
	if inBox(x, z, PIER) then
		table.insert(out, { 2, Enum.Material.WoodPlanks })
	end
	if inBox(x, z, OCEAN) then
		table.insert(out, { -1.5, Enum.Material.Water, true })
		table.insert(out, { -21, Enum.Material.Sand })
	elseif inBox(x, z, MOAT) then
		table.insert(out, { -1.5, Enum.Material.Water, true })
		table.insert(out, { -8, Enum.Material.Mud })
	elseif inBox(x, z, LAND) then
		table.insert(out, { 0, Enum.Material.Grass })
	end
	return out
end
local ws = game:GetService("Workspace")
ws.Vehicles = { Name = "Vehicles" }
function ws:FindFirstChild(name) return rawget(self, name) end
function ws:GetServerTimeNow() return clock() end
function ws:Raycast(origin, dir, params)
	if math.abs(dir.X) > 1e-6 or math.abs(dir.Z) > 1e-6 or dir.Y >= 0 then
		-- Sight lines: nothing stands in the way in this flat world, unless BLIND (buildings in between).
		return BLIND and { Position = origin, Instance = {} } or nil
	end
	local bottom = origin.Y + dir.Y
	for _, s in ipairs(column(origin.X, origin.Z)) do
		local y, water = s[1], s[3] == true
		-- (a ray that starts under the surface never meets the water, as in Roblox)
		if y <= origin.Y and y >= bottom and not (water and params.IgnoreWater) then
			return { Position = Vector3.new(origin.X, y, origin.Z), Material = s[2], Normal = Vector3.new(0, 1, 0),
				Distance = origin.Y - y, Instance = {} }
		end
	end
	return nil
end

function newPart(pos, look)
	local p = { Position = pos, AssemblyLinearVelocity = Vector3.zero, AssemblyAngularVelocity = Vector3.zero }
	p.CFrame = cfOf(pos, look or Vector3.new(0, 0, -1))
	function p:SetNetworkOwner() end
	function p:GetNetworkOwnershipAuto() return false end
	return p
end
function setPose(part, pos, look)
	part.Position = pos
	part.CFrame = cfOf(pos, look or part.CFrame.LookVector)
end

-- Vehicles
BUILT = {}
local TOPS = { HarborPatrol = 140, SunrayPatrol = 135, Splash = 110, Marlin = 140 }
local BOATS = { HarborPatrol = true, Splash = true, Marlin = true }
function newModel(id, pos)
	local m = { Name = id, Id = id, _attrs = {} }
	function m:GetAttribute(k) return self._attrs[k] end
	function m:SetAttribute(k, v) self._attrs[k] = v end
	m.PrimaryPart = newPart(pos or Vector3.zero)
	m:SetAttribute("Boat", BOATS[id] == true)
	m:SetAttribute("MaxSpeed", TOPS[id] or 120)
	function m:IsA(c) return c == "Model" end
	function m:FindFirstChild(name)
		return name == "DrivePrompt" and { Destroy = function() end } or nil
	end
	function m:PivotTo(cf)
		self.spawnPos = self.spawnPos or cf.Position
		setPose(self.PrimaryPart, cf.Position, cf.LookVector)
	end
	function m:Destroy() self.Parent = nil end
	return m
end
local CB = { __module = true }
function CB.Build(id)
	local m = newModel(id)
	table.insert(BUILT, m)
	return m
end

-- Kinematic stand-in for CarPhysics: throttle, brake, steer, top speed x SpeedScale. A boat floats on
-- water and only crawls on land (phys.Beached); a car over water sinks (y below 0.2).
local CP = { __module = true }
function CP.New(car) return { Car = car, speed = 0, Beached = false } end
function CP.Step(phys, dt, input)
	local car = phys.Car
	local ch = car.PrimaryPart
	local boat = car:GetAttribute("Boat") == true
	local top = (car:GetAttribute("MaxSpeed") or 120) * (input.SpeedScale or 1)
	local th = input.Throttle or 0
	local s = phys.speed
	if th > 0 then
		if s < 0 then
			s += 80 * th * dt
		elseif s < top then
			s = math.min(top, s + 60 * th * dt)
		else
			s = math.max(top, s - 40 * dt)
		end
	elseif th < 0 then
		s = math.max(-30, s + 80 * th * dt)
	else
		s = s > 0 and math.max(0, s - 10 * dt) or math.min(0, s + 10 * dt)
	end
	if phys.Beached then
		s = math.clamp(s, -10, 10)
	end
	local look = ch.CFrame.LookVector
	local right = ch.CFrame.RightVector
	local turn = (input.Steer or 0) * 1.9 * math.min(1, math.abs(s) / 15) * (s >= 0 and 1 or -1) * dt
	look = look * math.cos(turn) + right * math.sin(turn)
	local pos = ch.Position + look * s * dt
	local top1 = column(pos.X, pos.Z)[1]
	local y = pos.Y
	if top1 then
		if boat then
			y = top1[1] + 2.5
		else
			y = top1[3] and -5 or top1[1] + 3.2
		end
	end
	phys.Beached = boat and not (top1 and top1[3] == true)
	setPose(ch, Vector3.new(pos.X, y, pos.Z), look)
	ch.AssemblyLinearVelocity = look * s
	phys.speed = s
	phys.FwdSpeed = s
end

local RG = { __module = true, Nodes = {} }
for x = -1800, 1400, 200 do
	for z = -1800, 1800, 200 do
		table.insert(RG.Nodes, Vector3.new(x, 0, z))
	end
end
function RG.Path(a, b) return { Vector3.new(a.X, 0, a.Z), Vector3.new(b.X, 0, b.Z) } end
function RG.BuildFromWorld() end
function RG.Publish() end

TOASTS = {}
local Remotes = { __module = true }
function Remotes.Event()
	return { FireClient = function(_, p, key) table.insert(TOASTS, key) end }
end

local HS = { __module = true }
function HS.RegisterEye() end
function HS.UnregisterEye() end
function HS.GetHeat(p) return p:GetAttribute("Heat") or 0 end

CUFF = {} -- [player] = the fullest BEING CUFFED bar a Coast Guard boat sent
STEP_BOAT = {} -- info.boat as the officers saw it (PoliceOfficerService.Step)
BOARD_CREW = false
local OFF = { __module = true }
function OFF.Board() return BOARD_CREW and {} or nil end
STEP_SEARCH = nil -- the last `searching` the officers were told (PoliceOfficerService.Step)
function OFF.Step(_, _, _, info, _, searching)
	table.insert(STEP_BOAT, info ~= nil and info.boat == true)
	STEP_SEARCH = searching == true
	return "ride"
end
function OFF.Remove() end
function OFF.BoatCuff(p, _, frac)
	if type(frac) == "number" then
		CUFF[p] = math.max(CUFF[p] or 0, frac)
	end
end

ARRESTS = 0
local AS = { __module = true }
function AS.IsActiveCop(p) return p:GetAttribute("Side") == "Cop" end
function AS.Arrest(p)
	ARRESTS += 1
	p:SetAttribute("Heat", 0)
end
function AS.GaveUp() end

local sss = game:GetService("ServerScriptService")
sss.Services.HeatService = HS
sss.Services.PoliceOfficerService = OFF
sss.Services.ArrestService = AS
game:GetService("ReplicatedStorage").Shared = { Util = { CarPhysics = CP, RoadGraph = RG, Remotes = Remotes },
	Config = { Tutorial = { Rookie = { MaxStars = 2, SpeedScale = 0.7, HeadStart = 20, HollowAfter = 5, EscapeAfter = 30, NoTaser = true }, IsRookie = function() return false end } } } -- (players here are never rookies: tools/logic-tests/spin.sh tests that)
game:GetService("RunService").Heartbeat = newSignal()
local SS = { Tools = { CarBuilder = CB } }
local baseGetService = game.GetService
game.GetService = function(self, name)
	if name == "ServerStorage" then
		return SS
	end
	return baseGetService(self, name)
end
EOF

read -r -d '' HELPERS <<'EOF'
-- 30 frames a second: the scripted target moves, the clock runs (the once-a-second manage loop), then
-- Heartbeat (every unit drives).
function sim(seconds, step)
	local dt = 1 / 30
	local stop = clock() + seconds
	while clock() < stop - 1e-9 do
		if step then
			step(dt)
		end
		runUntil(clock() + dt)
		game:GetService("RunService").Heartbeat:Fire(dt)
	end
end
local function alive(name)
	local n = 0
	for _, m in ipairs(BUILT) do
		if m.Name == name and m.Parent ~= nil then
			n += 1
		end
	end
	return n
end
function coastGuards() return alive("AICoastGuard") end
function patrols() return alive("AIPatrol") end
function built(id)
	local n = 0
	for _, m in ipairs(BUILT) do
		if m.Id == id then
			n += 1
		end
	end
	return n
end
function firstCG()
	for _, m in ipairs(BUILT) do
		if m.Name == "AICoastGuard" then
			return m
		end
	end
end
function toasts(key)
	local n = 0
	for _, k in ipairs(TOASTS) do
		if k == key then
			n += 1
		end
	end
	return n
end
function flatDist(a, b)
	local d = a - b
	return Vector3.new(d.X, 0, d.Z).Magnitude
end
function newCharacter(pos)
	local root = newPart(pos)
	local hum = { Health = 100, SeatPart = nil }
	local ch = { Humanoid = hum, HumanoidRootPart = root }
	function ch:FindFirstChildOfClass(c) return c == "Humanoid" and hum or nil end
	function ch:FindFirstChild(n) return n == "HumanoidRootPart" and root or nil end
	return ch
end
function wantedPlayer(id, heat, pos)
	local p = newPlayer(id)
	p:SetAttribute("Side", "Civilian")
	p:SetAttribute("Heat", heat)
	p:SetAttribute("WantedSince", clock())
	p.Character = newCharacter(pos)
	join(p)
	return p
end
function copPlayer(id)
	local p = newPlayer(id)
	p:SetAttribute("Side", "Cop")
	p.Character = newCharacter(Vector3.new(-1000, 3, -1000))
	join(p)
	return p
end
function inBoat(p, id, pos)
	local m = newModel(id, pos)
	p.Character.Humanoid.SeatPart = { Parent = m }
	return m
end
-- Moves a part round a circle at `speed` studs/s.
function circle(part, center, radius, speed)
	local a = 0
	return function(dt)
		a += speed / radius * dt
		local pos = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local vel = Vector3.new(-math.sin(a), 0, math.cos(a)) * speed
		setPose(part, pos, vel)
		part.AssemblyLinearVelocity = vel
	end
end
-- Moves a part in a straight line.
function line(part, vel)
	return function(dt)
		setPose(part, part.Position + vel * dt, vel)
		part.AssemblyLinearVelocity = vel
	end
end
EOF

scenario() {
	local name="$1" body="$2"
	local f="$OUT/coastguard_$name.luau"
	{
		cat "$H/prelude.luau"
		echo "$STUBS"
		echo 'game:GetService("ReplicatedStorage").Shared.Config.Wanted = (function()'
		cat "$WANTED"
		echo "end)()"
		echo "$HELPERS"
		echo "local AIPolice = (function()"
		cat "$SRC"
		echo "end)()"
		echo "AIPolice.Init()"
		echo "$body"
		echo 'if ERRORS then print("FAIL coroutine errors: " .. ERRORS) end'
		echo 'for _, l in ipairs(LOG) do print("WARN " .. l) end'
	} > "$f"
	echo "== $name"
	"$L" "$f" 2>&1 || echo "FAIL $name stopped with an error (above)"
}

scenario boat_at_sea '
local p = wantedPlayer(1, 2, Vector3.new(2200, 1, 0))
local boat = inBoat(p, "Splash", Vector3.new(2600, 1, 0))
local move = circle(boat.PrimaryPart, Vector3.new(2200, 1, 0), 400, 100)
sim(10, move)
check("head start (2 stars: 14 s): nobody yet, countdown shown",
	coastGuards() == 0 and patrols() == 0 and type(p:GetAttribute("PoliceETA")) == "number")
sim(12, move)
check("then a Coast Guard boat comes", coastGuards() == 1, coastGuards())
check("no patrol car for a boat at sea", built("SunrayPatrol") == 0, built("SunrayPatrol"))
local cg = firstCG()
local at = cg and cg.spawnPos
local okSpot = at ~= nil and at.X >= OCEAN[1] + 12 and at.X <= OCEAN[2] - 12 and math.abs(at.Y - 1) < 0.01
	and not (at.X >= PIER[1] - 12 and at.X <= PIER[2] + 12 and at.Z >= PIER[3] - 12 and at.Z <= PIER[4] + 12)
check("it appeared on open, deep water", okSpot, at and (at.X .. ", " .. at.Y .. ", " .. at.Z))
check("the player heard about it once", toasts("CoastGuard") == 1, toasts("CoastGuard"))
local nearest = math.huge
sim(40, function(dt)
	move(dt)
	nearest = math.min(nearest, flatDist(cg.PrimaryPart.Position, boat.PrimaryPart.Position))
end)
check("it keeps up (inside the 250-stud sight range)", nearest < 250, nearest)
check("never cuffs a boat at full speed", ARRESTS == 0 and (CUFF[p] or 0) == 0, ARRESTS)
check("still the one boat (2 stars)", coastGuards() == 1 and patrols() == 0, coastGuards())
sim(25, function() boat.PrimaryPart.AssemblyLinearVelocity = Vector3.zero end)
check("stopped at sea: the Coast Guard arrests them", ARRESTS == 1, ARRESTS)
check("with the BEING CUFFED bar filling first", (CUFF[p] or 0) > 0.9, CUFF[p])
sim(2)
check("and leaves once they are caught", coastGuards() == 0, coastGuards())
check("still told only once", toasts("CoastGuard") == 1)'

scenario more_stars_more_boats '
local p = wantedPlayer(1, 4, Vector3.new(2200, 1, 0))
local boat = inBoat(p, "Marlin", Vector3.new(2600, 1, 0))
local move = circle(boat.PrimaryPart, Vector3.new(2200, 1, 0), 400, 120)
sim(30, move)
check("4 stars: three Coast Guard boats", coastGuards() == 3, coastGuards())
check("no cars", built("SunrayPatrol") == 0)'

scenario swimmer_far_out '
local p = wantedPlayer(1, 1, Vector3.new(2300, -2.5, 300))
local swim = line(p.Character.HumanoidRootPart, Vector3.new(0, 0, 14))
sim(18, swim)
check("head start (1 star: 20 s): nobody yet", coastGuards() == 0 and patrols() == 0)
sim(40, swim)
check("the Coast Guard comes for a swimmer far out", built("HarborPatrol") >= 1, built("HarborPatrol"))
check("and pulls them out (arrest)", ARRESTS == 1, ARRESTS)
check("swimmer told", toasts("CoastGuardSwim") == 1, toasts("CoastGuardSwim"))
check("no cuff bar for a swimmer (no DRIVE to break free)", (CUFF[p] or 0) == 0, CUFF[p])
check("no patrol car sent into the sea", built("SunrayPatrol") == 0, built("SunrayPatrol"))'

scenario moat_swimmer '
local p = wantedPlayer(1, 1, Vector3.new(-1425, -2.5, 1375))
sim(30)
check("the prison moat is too shallow for the Coast Guard", built("HarborPatrol") == 0, built("HarborPatrol"))
check("patrol cars come instead, as before", built("SunrayPatrol") >= 1, built("SunrayPatrol"))'

scenario goes_ashore '
local p = wantedPlayer(1, 2, Vector3.new(2200, 1, 0))
local boat = inBoat(p, "Splash", Vector3.new(2600, 1, 0))
local move = circle(boat.PrimaryPart, Vector3.new(2200, 1, 0), 400, 100)
sim(22, move)
check("Coast Guard out", coastGuards() == 1, coastGuards())
local root = p.Character.HumanoidRootPart
p.Character.Humanoid.SeatPart = nil
setPose(root, Vector3.new(1300, 3, -300))
local walk = line(root, Vector3.new(0, 0, 16))
sim(5, walk)
check("ashore: the boat waits offshore a while", coastGuards() == 1, coastGuards())
sim(8, walk)
check("then it goes", coastGuards() == 0, coastGuards())
check("patrol cars take over on land", built("SunrayPatrol") >= 1, built("SunrayPatrol"))'

scenario beached_boat '
local p = wantedPlayer(1, 2, Vector3.new(1300, 3, 200))
inBoat(p, "Splash", Vector3.new(1300, 2.5, 200)) -- run up on the sand, sitting still
sim(45)
check("a boat on the sand gets patrol cars, not the Coast Guard", built("SunrayPatrol") >= 1 and built("HarborPatrol") == 0,
	built("SunrayPatrol") .. " cars, " .. built("HarborPatrol") .. " boats")
check("and they arrest the driver (they used to keep away)", ARRESTS == 1, ARRESTS)'

scenario beached_boat_officers '
BOARD_CREW = true
local p = wantedPlayer(1, 2, Vector3.new(1300, 3, 200))
inBoat(p, "Splash", Vector3.new(1300, 2.5, 200))
sim(30)
local sawBoat = false
for _, b in ipairs(STEP_BOAT) do sawBoat = sawBoat or b end
check("officers asked about it", #STEP_BOAT > 0, #STEP_BOAT)
check("they treat a beached boat as a stopped car (may get out and cuff)", not sawBoat)'

scenario land_to_sea '
local p = wantedPlayer(1, 2, Vector3.new(1300, 3, -600))
local root = p.Character.HumanoidRootPart
sim(22, line(root, Vector3.new(0, 0, 16)))
check("on land: a patrol car", patrols() == 1 and coastGuards() == 0, patrols())
local boat = inBoat(p, "Splash", Vector3.new(2000, 1, 0))
local move = circle(boat.PrimaryPart, Vector3.new(2200, 1, 0), 200, 100)
sim(1.5, move)
check("out to sea: the car leaves", patrols() == 0, patrols())
sim(8, move)
check("and the Coast Guard comes", coastGuards() == 1, coastGuards())'

scenario two_player_cops '
copPlayer(10)
copPlayer(11)
local p = wantedPlayer(1, 2, Vector3.new(2200, 1, 0))
local boat = inBoat(p, "Splash", Vector3.new(2600, 1, 0))
sim(40, circle(boat.PrimaryPart, Vector3.new(2200, 1, 0), 400, 100))
check("two cops patrolling: no AI boats (they have the Harbor Patrol)", built("HarborPatrol") == 0, built("HarborPatrol"))'

# More patrol cars from 3 stars (owner, Nov 4): 3 at 3 stars, 4 at 4, 5 at 5, 3 s apart.
scenario more_stars_more_cars '
local p = wantedPlayer(1, 3, Vector3.new(200, 3, 0))
local run = circle(p.Character.HumanoidRootPart, Vector3.new(0, 3, 0), 200, 60)
sim(7, run)
check("head start (3 stars: 8 s): nobody yet", patrols() == 0, patrols())
sim(6, run)
check("then they come 3 s apart (not 6): two by 13 s", patrols() == 2, patrols())
sim(4, run)
check("3 stars: three patrol cars (was two)", patrols() == 3, patrols())
sim(6, run)
check("and no more than three", patrols() == 3, patrols())
p:SetAttribute("Heat", 4)
sim(4, run)
check("4 stars: four", patrols() == 4, patrols())
p:SetAttribute("Heat", 5)
sim(4, run)
check("5 stars: five", patrols() == 5, patrols())
p:SetAttribute("Heat", 2)
sim(6, run)
check("back down to 2 stars: one car again", patrols() == 1, patrols())
check("nobody arrested a runner", ARRESTS == 0, ARRESTS)'

scenario server_cap '
local a = wantedPlayer(1, 5, Vector3.new(200, 3, 0))
local b = wantedPlayer(2, 5, Vector3.new(-600, 3, 600))
local ra = circle(a.Character.HumanoidRootPart, Vector3.new(0, 3, 0), 200, 60)
local rb = circle(b.Character.HumanoidRootPart, Vector3.new(-800, 3, 600), 200, 60)
sim(40, function(dt) ra(dt) rb(dt) end)
check("two players at 5 stars: 8 cars in all (the server cap)", patrols() == 8, patrols())'

scenario one_cop_on_duty '
copPlayer(10)
local p = wantedPlayer(1, 2, Vector3.new(200, 3, 0))
local run = circle(p.Character.HumanoidRootPart, Vector3.new(0, 3, 0), 200, 60)
sim(30, run)
check("2 stars with a player cop on duty: no AI car (as before)", built("SunrayPatrol") == 0, built("SunrayPatrol"))
p:SetAttribute("Heat", 3)
sim(12, run)
check("3 stars with one player cop: three cars", patrols() == 3, patrols())
copPlayer(11)
sim(5, run)
check("a second player cop on duty: the AI cars go", patrols() == 0, patrols())'

# ---------------------------------------------------------------- the star ladder (Config.Wanted, Nov 7)

scenario head_start_by_stars '
local a = wantedPlayer(1, 1, Vector3.new(-1500, 3, -1500))
local b = wantedPlayer(2, 2, Vector3.new(-1500, 3, 1500))
local c = wantedPlayer(3, 3, Vector3.new(1000, 3, -1500))
local d = wantedPlayer(4, 4, Vector3.new(1000, 3, 1500))
sim(2)
local function wait(p) return (p:GetAttribute("PoliceETA") or 0) - p:GetAttribute("WantedSince") end
check("1 star: patrols arrive 20 s after the crime", math.abs(wait(a) - 20) < 0.01, wait(a))
check("2 stars: 14 s", math.abs(wait(b) - 14) < 0.01, wait(b))
check("3 stars: 8 s", math.abs(wait(c) - 8) < 0.01, wait(c))
check("4 stars: 4 s", math.abs(wait(d) - 4) < 0.01, wait(d))'

# One wanted runner on foot (top speed 120): how fast the patrol drives at each star level.
scenario speed_by_stars '
local function topSpeed(heat)
	local p = wantedPlayer(heat, heat, Vector3.new(-600 + heat * 500, 3, -1500))
	local run = line(p.Character.HumanoidRootPart, Vector3.new(0, 0, 60))
	local fastest = 0
	sim(45, function(dt)
		run(dt)
		for _, m in ipairs(BUILT) do
			if m.Name == "AIPatrol" and m.Parent ~= nil and m._attrs.AITarget == p.UserId then
				fastest = math.max(fastest, m.PrimaryPart.AssemblyLinearVelocity.Magnitude)
			end
		end
	end)
	p:SetAttribute("Heat", 0)
	sim(2)
	return fastest
end
local one = topSpeed(1)
check("1 star: the patrol tops out at 80% of the runner (96)", one > 90 and one <= 96.01, one)
local two = topSpeed(2)
check("2 stars: 88% (105.6)", two > 100 and two <= 105.61, two)
local three = topSpeed(3)
check("3 stars: 95% (114), as before", three > 108 and three <= 114.01, three)'

# 1 star, on land: the first car is sent to the player; seen and then lost, it searches where they were
# last seen, and no new car comes; seen again, the chase is back on.
scenario one_star_search '
BOARD_CREW = true
local p = wantedPlayer(1, 1, Vector3.new(0, 3, 0))
local run = circle(p.Character.HumanoidRootPart, Vector3.new(0, 3, 0), 200, 50)
sim(21, run)
check("after the head start one car comes", patrols() == 1, patrols())
local car
for _, m in ipairs(BUILT) do
	if m.Name == "AIPatrol" then
		car = m
	end
end
local nearest = math.huge
sim(25, function(dt)
	run(dt)
	nearest = math.min(nearest, flatDist(car.PrimaryPart.Position, p.Character.HumanoidRootPart.Position))
end)
check("before any sighting it is sent to where the player is", nearest < 150, nearest)
check("its officers are told it is not searching", STEP_SEARCH == false, STEP_SEARCH)
-- Seen, then lost: LastSeen is where the cops last saw them, far from where they are now.
p:SetAttribute("HeatSpotted", true)
sim(1, run)
local decoy = Vector3.new(-1200, 3, -1200) -- (dry land: not the prison moat)
p:SetAttribute("LastSeen", decoy)
p:SetAttribute("HeatSpotted", false)
BLIND = true -- (round a corner: out of sight of every car)
local fastest = 0
sim(40, function(dt)
	run(dt)
	fastest = math.max(fastest, car.PrimaryPart.AssemblyLinearVelocity.Magnitude)
end)
check("lost: it searches round LastSeen", flatDist(car.PrimaryPart.Position, decoy) < 300,
	flatDist(car.PrimaryPart.Position, decoy))
check("not where the player really is", flatDist(car.PrimaryPart.Position, p.Character.HumanoidRootPart.Position) > 800)
check("at a searching pace (70% of 96)", fastest <= 67.3, fastest)
check("its officers are told to stay in", STEP_SEARCH == true, STEP_SEARCH)
check("over 900 studs off for 15 s and more, it still searches (never lost)", car.Parent ~= nil and patrols() == 1)
check("and no second car was sent", built("SunrayPatrol") == 1, built("SunrayPatrol"))
car:Destroy()
sim(10, run)
check("its car gone while searching: nobody new comes", patrols() == 0 and built("SunrayPatrol") == 1, patrols())
-- Seen again (a new sighting): the chase is back on, and a new car is sent to them.
BLIND = false
p:SetAttribute("HeatSpotted", true)
sim(30, run)
local back
for _, m in ipairs(BUILT) do
	if m.Name == "AIPatrol" and m.Parent ~= nil then
		back = m
	end
end
check("seen again: a car is sent", back ~= nil, patrols())
check("and it comes for them", back ~= nil and flatDist(back.PrimaryPart.Position, p.Character.HumanoidRootPart.Position) < 150,
	back and flatDist(back.PrimaryPart.Position, p.Character.HumanoidRootPart.Position))
check("nobody arrested a runner", ARRESTS == 0, ARRESTS)'

# 2 stars searches too; a new crime reported while searching (LastSeen moves) moves the search there.
scenario two_star_search_moves '
local p = wantedPlayer(1, 2, Vector3.new(0, 3, 0))
local run = circle(p.Character.HumanoidRootPart, Vector3.new(0, 3, 0), 200, 50)
sim(16, run)
p:SetAttribute("HeatSpotted", true)
sim(1, run)
p:SetAttribute("LastSeen", Vector3.new(-1200, 3, -1200))
p:SetAttribute("HeatSpotted", false)
BLIND = true
sim(35, run)
local car
for _, m in ipairs(BUILT) do
	if m.Name == "AIPatrol" and m.Parent ~= nil then
		car = m
	end
end
check("2 stars: lost, it searches round LastSeen", car ~= nil and flatDist(car.PrimaryPart.Position, Vector3.new(-1200, 3, -1200)) < 300,
	car and flatDist(car.PrimaryPart.Position, Vector3.new(-1200, 3, -1200)))
p:SetAttribute("LastSeen", Vector3.new(1000, 3, -1000))
sim(40, run)
check("a new report moves the search there", car ~= nil and flatDist(car.PrimaryPart.Position, Vector3.new(1000, 3, -1000)) < 300,
	car and flatDist(car.PrimaryPart.Position, Vector3.new(1000, 3, -1000)))'

# From 3 stars the patrols always know where the player is (as before Nov 7).
scenario three_stars_no_search '
BOARD_CREW = true
local p = wantedPlayer(1, 3, Vector3.new(0, 3, 0))
local run = circle(p.Character.HumanoidRootPart, Vector3.new(0, 3, 0), 200, 50)
sim(20, run)
p:SetAttribute("HeatSpotted", true)
sim(1, run)
p:SetAttribute("LastSeen", Vector3.new(-1200, 3, -1200))
p:SetAttribute("HeatSpotted", false)
BLIND = true
sim(30, run)
local far = 0
for _, m in ipairs(BUILT) do
	if m.Name == "AIPatrol" and m.Parent ~= nil then
		far = math.max(far, flatDist(m.PrimaryPart.Position, p.Character.HumanoidRootPart.Position))
	end
end
check("3 stars: three cars", patrols() == 3, patrols())
check("hollow stars at 3: every car still comes for the player", far < 250, far)
check("officers never told to search", STEP_SEARCH == false, STEP_SEARCH)'

# A 1-star boat at sea: the Coast Guard searches round LastSeen once it has lost them.
scenario boat_search '
local p = wantedPlayer(1, 1, Vector3.new(2200, 1, 0))
local boat = inBoat(p, "Splash", Vector3.new(2200, 1, -400))
local move = circle(boat.PrimaryPart, Vector3.new(2200, 1, 0), 400, 60)
sim(30, move)
check("1 star at sea: a Coast Guard boat", coastGuards() == 1, coastGuards())
p:SetAttribute("HeatSpotted", true)
sim(1, move)
local decoy = Vector3.new(2700, 1, 1800)
p:SetAttribute("LastSeen", decoy)
p:SetAttribute("HeatSpotted", false)
BLIND = true
sim(40, move)
local cg = firstCG()
check("lost at sea: it searches round LastSeen", cg ~= nil and flatDist(cg.PrimaryPart.Position, decoy) < 250,
	cg and flatDist(cg.PrimaryPart.Position, decoy))
check("never arrested anyone", ARRESTS == 0, ARRESTS)'
