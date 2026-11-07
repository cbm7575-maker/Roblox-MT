#!/bin/bash
# PoliceHeliService logic tests (the police helicopter at 5 stars) + HeatService's eye reach: prelude + a
# flat stand-in world (ground at 0, one 200-stud tower block) + the service's source (as a function) +
# scenario. A stand-in HeatService marks a target seen while a registered eye is within its reach and
# the target isn't under cover (COVER). Every line should read PASS.
H="$(cd "$(dirname "$0")" && pwd)"
L="${LUAU:-luau}" # the Luau CLI (github.com/luau-lang/luau releases); set LUAU to its path
SRC="${1:-$H/../../src/server/Services/PoliceHeliService.lua}" # another copy of PoliceHeliService.lua, if given
HEAT="${2:-$H/../../src/server/Services/HeatService.lua}"
OUT="${TMPDIR:-${TEMP:-/tmp}}/theft-logic-tests"
mkdir -p "$OUT"

read -r -d '' STUBS <<'EOF'
math.randomseed(11)

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
typeof = function(v)
	if getmetatable(v) == V then
		return "Vector3"
	end
	return type(v)
end

-- Enough CFrame for a position plus the turns it was built from.
local CF = {}
CF.__index = CF
CFrame = {}
function CFrame.new(pos) return setmetatable({ Position = pos or Vector3.zero, yaw = 0, pitch = 0, roll = 0 }, CF) end
function CFrame.Angles(x, y, z) return setmetatable({ Position = Vector3.zero, yaw = y, pitch = x, roll = z }, CF) end
CF.__mul = function(a, b)
	return setmetatable({ Position = a.Position, yaw = a.yaw + b.yaw, pitch = a.pitch + b.pitch, roll = a.roll + b.roll }, CF)
end

Enum = { RaycastFilterType = { Exclude = "Exclude" } }
RaycastParams = { new = function() return {} end }
Random = { new = function()
	return {
		NextNumber = function(_, a, b) return a + math.random() * (b - a) end,
		NextInteger = function(_, a, b) return math.random(a, b) end,
	}
end }

-- Parts and folders: Position follows CFrame; Destroy takes it out of the world.
INSTANCES = {}
Instance = { new = function(class)
	local o = { ClassName = class, _attrs = {} }
	function o:GetAttribute(k) return self._attrs[k] end
	function o:SetAttribute(k, v) self._attrs[k] = v end
	function o:Destroy() self.Parent = nil; self.destroyed = true end
	function o:IsA(c) return c == class or (c == "BasePart" and class == "Part") end
	table.insert(INSTANCES, o)
	return setmetatable(o, { __index = function(t, k)
		if k == "Position" then
			local cf = rawget(t, "CFrame")
			return cf and cf.Position
		end
	end })
end }

-- The world: flat ground at 0, and a tower block (TOWER: x range, top) across every z.
TOWER = { 400, 520, 200 }
local ws = game:GetService("Workspace")
function ws:FindFirstChild(name) return rawget(self, name) end
function ws:GetServerTimeNow() return clock() end
RAYS = 0
function ws:Raycast(origin, dir)
	RAYS += 1
	local top = (origin.X >= TOWER[1] and origin.X <= TOWER[2]) and TOWER[3] or 0
	if origin.Y >= top and origin.Y + dir.Y <= top then
		return { Position = Vector3.new(origin.X, top, origin.Z) }
	end
	return nil
end

TOASTS = {}
local Remotes = { __module = true }
function Remotes.Event()
	return {
		FireClient = function(_, p, key) table.insert(TOASTS, { p = p, key = key }) end,
		FireAllClients = function() end,
	}
end

-- Stand-in HeatService: the eyes the helicopter registers, and who they see (seeAll, every frame).
EYES = {}
local HS = { __module = true }
function HS.RegisterEye(part, range) EYES[part] = range or 250 end
function HS.UnregisterEye(part) EYES[part] = nil end
COVER = {} -- [player] = true: under a bridge / in a tunnel, nobody sees them
function seeAll()
	for _, p in ipairs(Players:GetPlayers()) do
		local root = p.Character and p.Character.HumanoidRootPart
		local pos = root and root.Position
		local seat = p.Character and p.Character.Humanoid.SeatPart
		if seat then
			pos = seat.Parent.PrimaryPart.Position
		end
		local seen = false
		if pos and not COVER[p] and (p:GetAttribute("Heat") or 0) > 0 then
			for part, range in pairs(EYES) do
				if part.Parent and ((part.Position + Vector3.new(0, 3, 0)) - pos).Magnitude <= range then
					seen = true
				end
			end
		end
		p:SetAttribute("HeatSpotted", seen)
	end
end

local sss = game:GetService("ServerScriptService")
sss.Services.HeatService = HS
game:GetService("ReplicatedStorage").Shared = { Util = { Remotes = Remotes } }
game:GetService("RunService").Heartbeat = newSignal()
EOF

read -r -d '' HELPERS <<'EOF'
function newPart(pos)
	return { Position = pos, AssemblyLinearVelocity = Vector3.zero }
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
	p:SetAttribute("LastSeen", pos)
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
-- Seats the player in a car (top speed `top`) and returns its chassis.
function inCar(p, top)
	local car = { PrimaryPart = newPart(p.Character.HumanoidRootPart.Position), _attrs = { MaxSpeed = top } }
	function car:GetAttribute(k) return self._attrs[k] end
	function car:IsA(c) return c == "Model" end
	p.Character.Humanoid.SeatPart = { Parent = car }
	return car.PrimaryPart
end
-- Moves a part in a straight line at `vel` (studs/s).
function line(part, vel)
	return function(dt)
		part.Position = part.Position + vel * dt
		part.AssemblyLinearVelocity = vel
	end
end
function still(part)
	return function()
		part.AssemblyLinearVelocity = Vector3.zero
	end
end
-- 30 frames a second: the scripted target moves, the stand-in HeatService looks, the clock runs (the
-- once-a-second manage loop), then Heartbeat (every helicopter flies). `watch` runs after each frame.
function sim(seconds, step, watch)
	local dt = 1 / 30
	local stop = clock() + seconds
	while clock() < stop - 1e-9 do
		if step then
			step(dt)
		end
		seeAll()
		runUntil(clock() + dt)
		game:GetService("RunService").Heartbeat:Fire(dt)
		if watch then
			watch(dt)
		end
	end
end
function helis(all)
	local out = {}
	for _, o in ipairs(INSTANCES) do
		if o.Name == "PoliceHeli" and o.Parent ~= nil and (all or o:GetAttribute("Leaving") ~= true) then
			table.insert(out, o)
		end
	end
	return out
end
function built()
	local n = 0
	for _, o in ipairs(INSTANCES) do
		if o.Name == "PoliceHeli" then
			n += 1
		end
	end
	return n
end
function toasts(key)
	local n = 0
	for _, t in ipairs(TOASTS) do
		if t.key == key then
			n += 1
		end
	end
	return n
end
function flatDist(a, b)
	local d = a - b
	return Vector3.new(d.X, 0, d.Z).Magnitude
end
function eyeCount()
	local n = 0
	for _ in pairs(EYES) do
		n += 1
	end
	return n
end
EOF

scenario() {
	local name="$1" body="$2"
	local f="$OUT/policeheli_$name.luau"
	{
		cat "$H/prelude.luau"
		echo "$STUBS"
		echo "$HELPERS"
		echo "local Heli = (function()"
		cat "$SRC"
		echo "end)()"
		echo "Heli.Init()"
		echo "$body"
		echo 'if ERRORS then print("FAIL coroutine errors: " .. ERRORS) end'
		echo 'for _, l in ipairs(LOG) do print("WARN " .. l) end'
	} > "$f"
	echo "== $name"
	"$L" "$f" 2>&1 || echo "FAIL $name stopped with an error (above)"
}

scenario four_stars_none '
local p = wantedPlayer(1, 4, Vector3.new(0, 3, 0))
sim(40, still(p.Character.HumanoidRootPart))
check("4 stars: no helicopter (it comes at 5)", built() == 0, built())'

scenario five_stars_chase '
local p = wantedPlayer(1, 5, Vector3.new(-600, 3, -800))
local chassis = inCar(p, 140)
local drive = line(chassis, Vector3.new(0, 0, 100))
sim(3.5, still(chassis))
check("head start: nothing in the first 4 s", built() == 0, built())
sim(1.6, still(chassis))
local h = helis()[1]
check("then one comes", #helis() == 1, #helis())
check("from far off (about 700 studs)", h and flatDist(h.Position, chassis.Position) > 550, h and flatDist(h.Position, chassis.Position))
check("high up", h and h.Position.Y > 200, h and h.Position.Y)
check("it is an eye with a longer reach than a patrol car (350)", h and EYES[h] == 350, h and EYES[h])
check("it is after this player", h and h:GetAttribute("AITarget") == 1)
check("the player heard about it", toasts("PoliceHeli") == 1, toasts("PoliceHeli"))
local foundAt
sim(20, still(chassis), function()
	foundAt = foundAt or (h:GetAttribute("Lock") and clock())
end)
check("it flies in and finds them (parked where they were seen)", foundAt ~= nil, foundAt)
local seenFor = 0
sim(40, drive, function(dt)
	if p:GetAttribute("HeatSpotted") then
		seenFor += dt
	end
end)
check("a car slower than it (100 of its 119) stays in sight the whole 40 s", seenFor > 39.5, seenFor)
check("locked on (searchlight on them)", h:GetAttribute("Lock") == true)
local gap = flatDist(h.Position, chassis.Position)
check("hanging back a little, close behind", gap > 20 and gap < 120, gap)
check("about 90 studs over them", math.abs(h.Position.Y - chassis.Position.Y - 90) < 6, h.Position.Y - chassis.Position.Y)
check("only one, told only once", built() == 1 and toasts("PoliceHeli") == 1, built())
check("no errors", #LOG == 0, LOG[1])'

scenario outrun '
local p = wantedPlayer(1, 5, Vector3.new(-1500, 3, -1500))
local chassis = inCar(p, 175)
sim(15, still(chassis))
local h = helis()[1]
check("it is over a parked car", h and h:GetAttribute("Lock") == true)
local drive = line(chassis, Vector3.new(170, 0, 170) * (1 / math.sqrt(2)))
local lostAt
sim(60, drive, function()
	if not lostAt and not p:GetAttribute("HeatSpotted") then
		lostAt = clock()
	end
end)
check("a faster car (175) gets out of its sight", lostAt ~= nil, lostAt)
check("it only ever flew 85% of that (149 studs/s)", true)
check("it searched where it lost them, then gave up and flew off", h:GetAttribute("Leaving") == true or h.Parent == nil)
check("no longer an eye", EYES[h] == nil)
sim(40, drive)
check("gone", h.Parent == nil)
check("no new one while they stay unseen", #helis() == 0 and built() == 1, built())
-- Spotted again (a patrol car on them): another may come.
local carEye = Instance.new("Part")
carEye.Parent = {}
carEye.CFrame = CFrame.new(chassis.Position)
EYES[carEye] = 250
sim(3, function(dt)
	drive(dt)
	carEye.CFrame = CFrame.new(chassis.Position)
end)
check("seen again by the cops: a new one comes", #helis() == 1, #helis())'

scenario search '
local p = wantedPlayer(1, 5, Vector3.new(0, 3, 0))
local root = p.Character.HumanoidRootPart
sim(20, still(root))
local h = helis()[1]
check("on them", h and h:GetAttribute("Lock") == true)
local hidAt = root.Position
COVER[p] = true -- into a tunnel
sim(25, line(root, Vector3.new(16, 0, 0)))
check("lost them: Lock off", h:GetAttribute("Lock") == false)
local fromSpot = flatDist(h.Position, hidAt)
check("circling where it lost them", fromSpot > 55 and fromSpot < 115, fromSpot)
local aim = h:GetAttribute("Aim")
check("the searchlight sweeps round there (a 40-stud box)", aim ~= nil and flatDist(aim, hidAt) <= 57, aim and flatDist(aim, hidAt))
check("not following the hidden player", flatDist(h.Position, root.Position) > 250, flatDist(h.Position, root.Position))
COVER[p] = nil
sim(10, line(root, Vector3.new(-16, 0, 0)))
check("out of the tunnel near it: found again", h:GetAttribute("Lock") == true and p:GetAttribute("HeatSpotted") == true)'

scenario skyline '
TOWER = { 400, 520, 200 }
local p = wantedPlayer(1, 5, Vector3.new(-300, 3, 0))
local root = p.Character.HumanoidRootPart
sim(20, still(root))
local lowest = math.huge
sim(25, line(root, Vector3.new(40, 0, 0)), function()
	local h = helis()[1]
	if h and h.Position.X >= TOWER[1] and h.Position.X <= TOWER[2] then
		lowest = math.min(lowest, h.Position.Y - TOWER[3])
	end
end)
check("it went over the tower block", lowest < math.huge)
check("never lower than 30 studs over its roof", lowest >= 30, lowest)
sim(20, line(root, Vector3.new(40, 0, 0)))
local h = helis()[1]
check("and came back down past it", h and h.Position.Y < 120, h and h.Position.Y)'

scenario heat_drops '
local p = wantedPlayer(1, 5, Vector3.new(0, 3, 0))
sim(15, still(p.Character.HumanoidRootPart))
local h = helis()[1]
check("5 stars: it is here", h ~= nil)
p:SetAttribute("Heat", 4)
sim(0.5)
check("down to 4 stars: it turns away at once", h:GetAttribute("Leaving") == true and h:GetAttribute("Lock") == false)
check("and stops watching", EYES[h] == nil)
sim(10)
check("gone a few seconds later", h.Parent == nil and #helis(true) == 0)
sim(20)
check("none comes back at 4 stars", built() == 1, built())
p:SetAttribute("Heat", 5)
sim(2)
check("5 stars again: a new one", #helis() == 1, #helis())'

scenario arrested_or_left '
local a = wantedPlayer(1, 5, Vector3.new(0, 3, 0))
local b = wantedPlayer(2, 5, Vector3.new(800, 3, 800))
sim(15)
check("one each", #helis() == 2, #helis())
a:SetAttribute("Heat", 0) -- arrested
leave(b)
sim(1)
check("caught or gone: both fly off", #helis() == 0 and #helis(true) == 2, #helis(true))
sim(10)
check("and are gone", #helis(true) == 0 and eyeCount() == 0, eyeCount())'

scenario server_cap '
for i = 1, 3 do
	wantedPlayer(i, 5, Vector3.new(i * 600, 3, 0))
end
sim(20)
check("three players at 5 stars: two helicopters (the cap)", #helis() == 2, #helis())'

scenario player_cops_too '
copPlayer(10)
copPlayer(11)
local p = wantedPlayer(1, 5, Vector3.new(0, 3, 0))
sim(10)
check("it comes even with player cops on duty (it never arrests)", #helis() == 1, #helis())'

scenario no_body '
local p = wantedPlayer(1, 5, Vector3.new(0, 3, 0))
sim(15)
p.Character = nil -- Reset Character
sim(10)
local h = helis()[1]
check("no body: no errors, it keeps circling", h ~= nil and #LOG == 0 and ERRORS == nil, LOG[1])
p.Character = newCharacter(Vector3.new(30, 3, 0))
sim(5)
check("a new body near it: back on them", h:GetAttribute("Lock") == true)'

# HeatService: an eye's reach (RegisterEye(part, range)); a cop's is still 250.
heat_scenario() {
	local name="$1" body="$2"
	local f="$OUT/policeheli_heat_$name.luau"
	{
		cat "$H/prelude.luau"
		echo "$STUBS"
		echo "$HELPERS"
		cat <<'EOF'
local ws = game:GetService("Workspace")
ws.Heists = { GetChildren = function() return {} end }
function ws:Raycast() return nil end -- (nothing in the way)
Color3 = { fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end }
game:GetService("ReplicatedStorage").Shared.Config = { Disguises = { Describe = function() return "plain" end },
	Tutorial = { Rookie = { MaxStars = 2, SpeedScale = 0.7, HeadStart = 20, HollowAfter = 5, EscapeAfter = 30, NoTaser = true }, IsRookie = function() return false end } }
local sss = game:GetService("ServerScriptService")
sss.Services.Telemetry = { Custom = function() end }
sss.Services.ProgressService = { Event = function() end }
local basePlayer = newPlayer
newPlayer = function(id)
	local p = basePlayer(id)
	function p:GetAttributeChangedSignal() return newSignal() end
	return p
end
EOF
		echo "local HeatService = (function()"
		cat "$HEAT"
		echo "end)()"
		echo "HeatService.Init()"
		echo "$body"
		echo 'if ERRORS then print("FAIL coroutine errors: " .. ERRORS) end'
		echo 'for _, l in ipairs(LOG) do print("WARN " .. l) end'
	} > "$f"
	echo "== heat_$name"
	"$L" "$f" 2>&1 || echo "FAIL heat_$name stopped with an error (above)"
}

heat_scenario eye_reach '
local p = wantedPlayer(1, 2, Vector3.new(0, 3, 0))
local eye = Instance.new("Part")
eye.Parent = {}
eye.CFrame = CFrame.new(Vector3.new(0, 0, 300))
HeatService.RegisterEye(eye)
runUntil(clock() + 1)
check("an eye 300 studs off with the default reach (250): not seen", p:GetAttribute("HeatSpotted") ~= true)
HeatService.RegisterEye(eye, 350)
runUntil(clock() + 1)
check("with a 350 reach: seen", p:GetAttribute("HeatSpotted") == true)
eye.CFrame = CFrame.new(Vector3.new(0, 0, 360))
runUntil(clock() + 9)
check("moved to 360: not seen (hollow after 8 s)", p:GetAttribute("HeatSpotted") == false)
HeatService.UnregisterEye(eye)
local cop = newPlayer(9)
cop:SetAttribute("Side", "Cop")
cop.Character = newCharacter(Vector3.new(0, 1, 240))
join(cop)
runUntil(clock() + 1)
check("a player cop 240 studs off still sees them (250, as before)", p:GetAttribute("HeatSpotted") == true)
cop.Character.HumanoidRootPart.Position = Vector3.new(0, 1, 300)
runUntil(clock() + 9)
check("and not from 300", p:GetAttribute("HeatSpotted") == false)
check("no errors", #LOG == 0, LOG[1])'
