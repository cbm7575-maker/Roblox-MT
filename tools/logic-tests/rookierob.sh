#!/bin/bash
# Rookie robbery + the FirstRob funnel (Nov 8 2026): prelude + robberbots.sh's maths and Instance stand-ins
# (cut out of that file between its "maths" and "the world" markers) + a small world of four heist sites
# + the real Config.Heists, Config.Tutorial, TutorialService and HeistService (each as a function) +
# scenarios on a virtual clock. Checks who may rob what and when, what it pays, what the site is left as,
# and which FirstRob funnel steps get logged. Looks, prompts on screen and GPS are Studio's job
# (launch/25-ROOKIE-ROBBERY.md). Every line should read PASS.
H="$(cd "$(dirname "$0")" && pwd)"
L="${LUAU:-luau}" # the Luau CLI (github.com/luau-lang/luau releases); set LUAU to its path
SRC="$H/../../src"
OUT="${TMPDIR:-${TEMP:-/tmp}}/theft-logic-tests"
mkdir -p "$OUT"

MOCKS="$(sed -n '/^------------------------------------------------------------------ maths$/,/^------------------------------------------------------------------ the world$/p' "$H/robberbots.sh" | sed '$d')"
if [ -z "$MOCKS" ]; then
	echo "FAIL could not cut the stand-ins out of robberbots.sh (its markers moved?)"
	exit 1
fi

read -r -d '' WORLD <<'EOF'
function task.defer(fn, ...) return task.delay(0, fn, ...) end -- (the prelude has none)
-- Prompts have their hold and trigger signals.
local plainNew = new
function new(class, props)
	local o = plainNew(class, props)
	if class == "ProximityPrompt" then
		for _, s in ipairs({ "PromptButtonHoldBegan", "PromptButtonHoldEnded", "Triggered" }) do
			rawset(o, s, newSignal())
		end
	end
	return o
end

local WS = new("Workspace")
WS.Name = "Workspace"
local HeistsFolder = new("Folder", { Name = "Heists", Parent = WS })
function WS:GetServerTimeNow() return clock() end
function WS:Raycast(origin, dir)
	if dir.Y < -1 and origin.Y >= 0 and origin.Y + dir.Y <= 0 then
		return { Position = Vector3.new(origin.X, 0, origin.Z), Instance = WS }
	end
	return nil
end
COUNTERS = {}
function WS:GetPartBoundsInRadius(pos, r)
	local out = {}
	for _, c in ipairs(COUNTERS) do
		if (c.Position - pos).Magnitude <= r then
			table.insert(out, c)
		end
	end
	return out
end
function WS:GetPartBoundsInBox() return {} end

SITES = {}
local function site(id, name, x, z, counter)
	local m = new("Model", { Name = name, Parent = HeistsFolder })
	m:SetAttribute("HeistId", id)
	local point = new("Part", { Name = "RobPoint", Parent = m })
	point.Position = Vector3.new(x, 3, z)
	rawset(m, "PrimaryPart", point)
	SITES[name] = m
	if counter then -- a counter beside the till, facing +Z (the clerk stands at z - 3.2)
		local c = new("Part", { Name = "Counter", Parent = m })
		c.CFrame = CFrame.lookAt(Vector3.new(x, 2, z - 1), Vector3.new(x, 2, z + 5))
		table.insert(COUNTERS, c)
	end
	return m
end
site("ATM", "ATM1", 300, 0)
site("GlowMart", "GlowMart", 0, 600, true)
site("FuelStop", "FuelStop", -600, 0)
site("SparkleCo", "SparkleCo", 0, -600)

------------------------------------------------------------------ services
FIRED = {} -- [remote] = { { a, b }, ... }
local remotes = {}
local Remotes = { Event = function(name)
	remotes[name] = remotes[name] or {
		OnServerEvent = newSignal(),
		FireClient = function(_, p, a, b) FIRED[name] = FIRED[name] or {} table.insert(FIRED[name], { p, a, b }) end,
		FireAllClients = function(_, a, b) FIRED[name] = FIRED[name] or {} table.insert(FIRED[name], { a, b }) end,
	}
	return remotes[name]
end }
function remote(name) return Remotes.Event(name) end
local RateLimit = { Allow = function() return true end }
BANKED = {}
local Econ = {}
function Econ.AddCarried(p, n) p:SetAttribute("Carried", (p:GetAttribute("Carried") or 0) + n) return n end
function Econ.AddCash(p, n) p:SetAttribute("Cash", (p:GetAttribute("Cash") or 0) + n) return n end
function Econ.OnBanked(fn) table.insert(BANKED, fn) end
FUNNEL, ONBOARD, CUSTOM = {}, {}, {}
local Telemetry = {
	FunnelStep = function(p, funnel, session, step, name)
		table.insert(FUNNEL, { p = p, funnel = funnel, session = session, step = step, name = name })
	end,
	Funnel = function(p, step, name) table.insert(ONBOARD, { p = p, step = step, name = name }) end,
	Custom = function(p, name, v) table.insert(CUSTOM, { p = p, name = name, v = v }) end,
	Economy = function() end,
}
PROFILES = {}
local loadedFns = {}
local DataService = { Get = function(p) return PROFILES[p] end, OnLoaded = function(fn) table.insert(loadedFns, fn) end }
function loadSave(p, tutorial)
	PROFILES[p] = { flags = { tutorial = tutorial, tutorialOrder = 2 } }
	for _, fn in ipairs(loadedFns) do
		task.spawn(fn, p, PROFILES[p])
	end
end
local Heat = { Add = function(p, n) p:SetAttribute("Heat", math.min(5, (p:GetAttribute("Heat") or 0) + n)) end }
local Crew = { BonusFor = function() return 0 end, CrewOf = function() return nil end }
local Progress = { Event = function() end }
local Services = { EconomyService = Econ, Telemetry = Telemetry, DataService = DataService, HeatService = Heat,
	CrewService = Crew, ProgressService = Progress }
function Services:FindFirstChild(n) return rawget(self, n) end

local PlayersSvc = new("Players")
rawset(PlayersSvc, "PlayerRemoving", newSignal())
rawset(PlayersSvc, "PlayerAdded", newSignal())
function PlayersSvc:GetPlayers() return self:GetChildren() end

local RS = new("ReplicatedStorage")
Shared = { Config = { Shop = { VIPCashBonus = 0.25 }, Combat = { ToolAttribute = "NCCombat" } },
	Util = { Remotes = Remotes, RateLimit = RateLimit, Ragdoll = { Start = function() end } } }
rawset(RS, "Shared", Shared)
-- One shop assistant look for the clerks.
local templates = new("Folder", { Name = "PedTemplates", Parent = RS })
local look = new("Model", { Name = "Look1", Parent = templates })
new("Part", { Name = "HumanoidRootPart", Parent = look })
new("Part", { Name = "Head", Parent = look })
new("Humanoid", { Name = "Humanoid", Parent = look })
local SSS = new("ServerScriptService")
rawset(SSS, "Services", Services)
local SERVICES = { Players = PlayersSvc, ReplicatedStorage = RS, ServerScriptService = SSS, Workspace = WS,
	RunService = { IsStudio = function() return false end } }
game = { GetService = function(_, n) return SERVICES[n] end }
typeof = function(v)
	local mt = getmetatable(v)
	if mt and rawget(mt, "__type") then
		return mt.__type
	end
	return type(v)
end

------------------------------------------------------------------ helpers
local uid = 100
-- A citizen at pos: tutorial steps done (0 = new ... 4 = finished), bag (Carried).
function citizen(step, pos, carried, side)
	uid += 1
	local p = new("Player", { Name = "P" .. uid, DisplayName = "P" .. uid, UserId = uid, Parent = PlayersSvc })
	p:SetAttribute("Side", side or "Civilian")
	p:SetAttribute("TutorialStep", step)
	p:SetAttribute("Carried", carried or 0)
	local char = new("Model", { Name = p.Name })
	local root = new("Part", { Name = "HumanoidRootPart", Parent = char })
	root.Position = pos
	new("Humanoid", { Name = "Humanoid", Parent = char })
	rawset(p, "Character", char)
	return p
end
function at(name, dz) -- a spot beside a site's Rob point
	local pos = SITES[name].RobPoint.Position
	return Vector3.new(pos.X, 3, pos.Z + (dz or 4))
end
function moveTo(p, pos) p.Character.HumanoidRootPart.Position = pos end
function sim(s) runUntil(clock() + s) end
-- Hold a site's Rob prompt for `seconds`, then let the prompt trigger (as Roblox does once the client's
-- hold runs out). Returns the cash put in the bag.
function hold(p, name, seconds)
	local before = p:GetAttribute("Carried") or 0
	local pr = SITES[name]:FindFirstChild("RobPrompt", true)
	pr.PromptButtonHoldBegan:Fire(p)
	sim(seconds)
	pr.Triggered:Fire(p)
	pr.PromptButtonHoldEnded:Fire(p)
	sim(0.1)
	return (p:GetAttribute("Carried") or 0) - before
end
function shut(name, seconds) -- the site's cooldown runs (as if somebody robbed it just now)
	SITES[name]:SetAttribute("ReopenAt", clock() + (seconds or 120))
	sim(1.1) -- (HeistService's once-a-second pass)
end
function steps(p)
	local out = {}
	for _, f in ipairs(FUNNEL) do
		if f.p == p then
			table.insert(out, f.step .. f.name)
		end
	end
	return table.concat(out, " ")
end
function customs(p, base)
	local out = {}
	for _, c in ipairs(CUSTOM) do
		if c.p == p and string.sub(c.name, 1, #base) == base then
			table.insert(out, c.name .. "=" .. tostring(c.v))
		end
	end
	return table.concat(out, " ")
end
EOF

scenario() {
	local name="$1" pre="$2" body="$3"
	local f="$OUT/rookierob_$name.luau"
	{
		cat "$H/prelude.luau"
		echo "$MOCKS"
		echo "$WORLD"
		echo 'Shared.Config.Heists = (function()'
		cat "$SRC/shared/Config/Heists.lua"
		echo 'end)()'
		echo 'Shared.Config.Tutorial = (function()'
		cat "$SRC/shared/Config/Tutorial.lua"
		echo 'end)()'
		echo 'Heists, Tutorial = Shared.Config.Heists, Shared.Config.Tutorial'
		echo 'TS = (function()'
		cat "$SRC/server/Services/TutorialService.lua"
		echo 'end)()'
		echo 'rawset(game:GetService("ServerScriptService").Services, "TutorialService", TS)'
		echo 'HS = (function()'
		cat "$SRC/server/Services/HeistService.lua"
		echo 'end)()'
		echo "$pre"
		echo 'TS.Init()'
		echo 'HS.Init()'
		echo 'sim(1.5)'
		echo "$body"
		echo 'if ERRORS then print("FAIL coroutine errors: " .. ERRORS) end'
		echo 'for _, l in ipairs(LOG) do print("WARN " .. l) end'
	} > "$f"
	echo "== $name"
	"$L" "$f" 2>&1 || echo "FAIL $name stopped with an error (above)"
}

scenario rule '' '
local function p(step, carried, side) return citizen(step, Vector3.new(0, 3, 0), carried, side) end
check("new player (step 0), empty bag: rookie", Tutorial.CanRookieRob(p(0)) == true)
check("on the rob step: rookie", Tutorial.CanRookieRob(p(1), 1) == true)
check("rob step done, bag lost (arrested): rookie again", Tutorial.CanRookieRob(p(2, 0)) == true)
check("bag in hand: not a rookie robbery", Tutorial.CanRookieRob(p(2, 1200)) == false)
check("banked once (step 3): not a rookie", Tutorial.CanRookieRob(p(3)) == false)
check("finished guide (step 4): not a rookie", Tutorial.CanRookieRob(p(4)) == false)
check("save not loaded yet: not a rookie", Tutorial.CanRookieRob(p(nil)) == false)
check("a cop: not a rookie", Tutorial.CanRookieRob(p(1, 0, "Cop")) == false)
check("tier 2 is never a rookie store", Tutorial.CanRookieRob(p(1), 2) == false)
check("hold is at most 5 s", Tutorial.RookieRob.Hold == 5)'

scenario shut_store '' '
local r = citizen(1, at("ATM1"))
local v = citizen(4, at("ATM1", -4))
shut("ATM1", 120)
local reopen = SITES.ATM1:GetAttribute("ReopenAt")
check("the ATM is shut for everyone", SITES.ATM1:GetAttribute("Robbable") == false)
check("a veteran gets nothing from it, even holding 12 s", hold(v, "ATM1", 12) == 0)
check("a rookie robs it in 5 s: $900", hold(r, "ATM1", 5) == 900, r:GetAttribute("Carried"))
check("it stays exactly as it was for everyone else", SITES.ATM1:GetAttribute("ReopenAt") == reopen
	and SITES.ATM1:GetAttribute("LastRobbedBy") == nil and SITES.ATM1:GetAttribute("Robbable") == false)
check("the rookie is wanted (a chase follows)", (r:GetAttribute("Heat") or 0) >= 1)
check("a second go with the bag full: nothing", hold(r, "ATM1", 12) == 0)'

scenario hold_times '' '
local r = citizen(1, at("ATM1"))
shut("ATM1", 300)
check("a 4 s hold is too short", hold(r, "ATM1", 4) == 0)
check("a 4.7 s hold is enough (5 s, minus the usual 0.4 s slack)", hold(r, "ATM1", 4.7) == 900)
local v = citizen(4, at("GlowMart"))
check("a veteran on an open store still needs its full 8 s", hold(v, "GlowMart", 5) == 0)
check("...and gets it at 8 s", hold(v, "GlowMart", 8) == 1200)'

scenario open_store '' '
local r = citizen(1, at("GlowMart"))
check("Glow Mart is open", SITES.GlowMart:GetAttribute("Robbable") == true)
check("a rookie robs an open store in 5 s", hold(r, "GlowMart", 5) == 1200)
check("an open store robbed by a rookie cools down for everyone, as usual",
	(SITES.GlowMart:GetAttribute("ReopenAt") or 0) > clock() and SITES.GlowMart:GetAttribute("LastRobbedBy") == r.UserId)'

scenario bag_and_tiers '' '
local b = citizen(1, at("ATM1"), 500)
shut("ATM1", 120)
check("a rookie with a bag in hand: the shut ATM gives nothing", hold(b, "ATM1", 12) == 0)
local r = citizen(1, at("SparkleCo"))
shut("SparkleCo", 200)
check("a shut tier-2 store is shut for a rookie too", hold(r, "SparkleCo", 14) == 0)
SITES.SparkleCo:SetAttribute("ReopenAt", 0)
sim(1.1)
check("open tier 2: no rookie short hold (5 s)", hold(r, "SparkleCo", 5) == 0)
local paid = hold(r, "SparkleCo", 14)
check("open tier 2: the usual 14 s hold pays", paid >= 4000 and paid <= 6000, paid)'

scenario rotation_closed 'Heists.OpenCount = 0' '
local r = citizen(1, at("FuelStop"))
local v = citizen(4, at("FuelStop", -4))
check("nothing in the rotation: Fuel Stop is shut", SITES.FuelStop:GetAttribute("Robbable") == false)
check("a veteran gets nothing", hold(v, "FuelStop", 10) == 0)
check("a rookie still gets their first robbery", hold(r, "FuelStop", 5) == 1500)
check("it stays shut for the rest", SITES.FuelStop:GetAttribute("Robbable") == false)'

scenario clerk_at_gunpoint '' '
sim(2) -- (the clerk comes on the once-a-second pass)
check("a clerk stands at the Glow Mart", SITES.GlowMart:GetAttribute("ClerkUp") == true)
shut("GlowMart", 200)
local clerk
for _, m in ipairs(game:GetService("Workspace").NPCs:GetChildren()) do
	if m:GetAttribute("Site") == "GlowMart" then clerk = m end
end
local cpos = clerk.HumanoidRootPart.Position
local function gunman(step)
	local p = citizen(step, Vector3.new(cpos.X, 3, cpos.Z - 12))
	p.Character.HumanoidRootPart.CFrame = CFrame.lookAt(p.Character.HumanoidRootPart.Position, cpos)
	local gun = new("Tool", { Name = "Coast 9", Parent = p.Character })
	gun:SetAttribute("NCCombat", "Gun")
	return p
end
local v = gunman(4)
remote("RequestStoreRob").OnServerEvent:Fire(v, SITES.GlowMart)
sim(8)
check("a veteran can not hold up a shut store", (v:GetAttribute("Carried") or 0) == 0)
local r = gunman(1)
loadSave(r, 1) -- (on the rob step: the FirstRob funnel is watching)
remote("RequestStoreRob").OnServerEvent:Fire(r, SITES.GlowMart)
sim(8)
check("a rookie holds up the shut store: $1,200 + 25%", r:GetAttribute("Carried") == 1500, r:GetAttribute("Carried"))
check("the store is left shut, its cooldown untouched", SITES.GlowMart:GetAttribute("Robbable") == false
	and SITES.GlowMart:GetAttribute("LastRobbedBy") == nil)
check("the hold-up counts as Holding in FirstRob", string.find(steps(r), "5Holding") ~= nil, steps(r))'

scenario funnel_all_steps '' '
local p = citizen(0, Vector3.new(0, 3, -300))
loadSave(p, 0)
sim(0.5)
remote("TutorialStep").OnServerEvent:Fire(p, 1) -- (sat in the car)
sim(1.5)
check("car step: InCar", steps(p) == "1InCar", steps(p))
local seat = new("Part", { Name = "DriverSeat" })
rawset(p.Character.Humanoid, "SeatPart", seat)
moveTo(p, Vector3.new(150, 3, -150))
sim(1.5)
check("drove off: Moving", steps(p) == "1InCar 2Moving", steps(p))
moveTo(p, at("ATM1", 40))
sim(1.5)
check("pulled up near the ATM: NearStore, not OnFoot while seated", steps(p) == "1InCar 2Moving 3NearStore", steps(p))
rawset(p.Character.Humanoid, "SeatPart", nil)
moveTo(p, at("ATM1"))
sim(1.5)
check("got out beside it: OnFoot", string.find(steps(p), "4OnFoot$") ~= nil, steps(p))
shut("ATM1", 120)
check("robbed the shut ATM", hold(p, "ATM1", 5) == 900)
check("began the hold: Holding", string.find(steps(p), "5Holding$") ~= nil, steps(p))
remote("TutorialStep").OnServerEvent:Fire(p, 2) -- (the client sees the bag)
sim(0.5)
check("rob step done: Robbed, all six in order", steps(p) == "1InCar 2Moving 3NearStore 4OnFoot 5Holding 6Robbed", steps(p))
check("the onboarding funnel still logs Tutorial_rob as step 4", ONBOARD[#ONBOARD].step == 4 and ONBOARD[#ONBOARD].name == "Tutorial_rob")
local sessions = {}
for _, f in ipairs(FUNNEL) do sessions[f.session] = true end
local n = 0 for _ in pairs(sessions) do n += 1 end
check("one FirstRob run, one session id", n == 1 and FUNNEL[1].funnel == "FirstRob")
game:GetService("Players").PlayerRemoving:Fire(p)
sim(0.1)
check("leaving after the robbery: no FirstRobQuit", customs(p, "FirstRobQuit") == "")'

scenario funnel_quit '' '
local p = citizen(0, Vector3.new(0, 3, -300))
loadSave(p, 0)
sim(0.5)
remote("TutorialStep").OnServerEvent:Fire(p, 1)
sim(1.5) -- (the watcher notes where the step began)
moveTo(p, Vector3.new(0, 3, -150))
sim(30)
game:GetService("Players").PlayerRemoving:Fire(p)
sim(0.1)
local quit = customs(p, "FirstRobQuit")
local secs = tonumber(string.match(quit, "^FirstRobQuit_Moving=(%d+)$") or "")
check("left on the way: FirstRobQuit, last step Moving, ~31 s on the step", secs ~= nil and secs >= 30 and secs <= 33, quit)
local q = citizen(1, Vector3.new(0, 3, -300))
loadSave(q, 1) -- (rejoined on the rob step)
sim(1.5)
check("rejoining on the rob step starts a run: InCar", steps(q) == "1InCar", steps(q))
local w = citizen(4, Vector3.new(0, 3, -300))
loadSave(w, 4)
sim(1.5)
check("a finished guide is never tracked", steps(w) == "")'
