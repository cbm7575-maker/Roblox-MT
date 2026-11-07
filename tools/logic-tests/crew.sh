#!/bin/bash
# Saved crews and the crew job (CrewService + MissionService crew preps): prelude + stand-ins (players with
# a body, remotes that log what they send, the Missions config with its places) + both services' sources
# (as functions) + scenario. A "server restart" loads the services again on the same DataStore.
# Every line should read PASS.
H="$(cd "$(dirname "$0")" && pwd)"
L="${LUAU:-luau}" # the Luau CLI (github.com/luau-lang/luau releases); set LUAU to its path
ROOT="$H/../.."
OUT="${TMPDIR:-${TEMP:-/tmp}}/theft-logic-tests"
mkdir -p "$OUT"

read -r -d '' STUBS <<'EOF'
function task.defer(fn, ...)
	return task.delay(0, fn, ...)
end

-- Vectors (enough for distances).
local V = {}
Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V)
end
V.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	end
	return nil
end
V.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end

-- JSON as opaque strings ("json#n"): enough for attributes and the memory store.
local jsonReg, jsonN = {}, 0
local function deep(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in pairs(t) do
		c[k] = deep(v)
	end
	return c
end
services.HttpService = {
	GenerateGUID = function() return "guid" end,
	JSONEncode = function(_, v)
		jsonN += 1
		jsonReg[jsonN] = deep(v)
		return "json#" .. jsonN
	end,
	JSONDecode = function(_, s)
		local n = tonumber(string.match(tostring(s), "^json#(%d+)$"))
		if not n then
			error("bad json")
		end
		return deep(jsonReg[n])
	end,
}
HTTP = services.HttpService
function decode(s)
	return s and HTTP:JSONDecode(s) or nil
end

-- The DataStore: SetAsync / RemoveAsync too.
function STORE:SetAsync(key, value)
	task.wait(self.latency)
	self.data[key] = deep(value)
end
function STORE:RemoveAsync(key)
	task.wait(self.latency)
	self.data[key] = nil
end
STORE.latency = 0.1

-- Remotes that log what the server sends.
EVENTS = {}
local remotes = {}
local function remote(name)
	if not remotes[name] then
		local r = { OnServerEvent = newSignal(), Name = name }
		function r:FireClient(p, ...)
			table.insert(EVENTS, { name = name, p = p, args = table.pack(...) })
		end
		function r:FireAllClients(...)
			table.insert(EVENTS, { name = name, all = true, args = table.pack(...) })
		end
		remotes[name] = r
	end
	return remotes[name]
end
REMOTES = { Event = remote, OnClient = function() end }
function fire(p, name, ...)
	remote(name).OnServerEvent:Fire(p, ...)
end
-- The events `name` sent to `p` (first argument = `kind` if given).
function sent(p, name, kind)
	local out = {}
	for _, e in ipairs(EVENTS) do
		if e.name == name and e.p == p and (kind == nil or e.args[1] == kind) then
			table.insert(out, e.args)
		end
	end
	return out
end
function lastSent(p, name, kind)
	local list = sent(p, name, kind)
	return list[#list]
end

services.Workspace.GetServerTimeNow = function()
	return clock()
end
services.RunService.Heartbeat = newSignal()
local RS = services.ReplicatedStorage
RS:SetAttribute("SavesOff", false)

-- Players with a body that can be moved (y = 0) and a speed.
function newMate(id)
	local p = newPlayer(id)
	p.DisplayName = "P" .. id
	local root = { Position = Vector3.new(0, 0, 0), AssemblyLinearVelocity = Vector3.new(0, 0, 0) }
	p.Character = { HumanoidRootPart = root, FindFirstChild = function(self, n) return rawget(self, n) end }
	p:SetAttribute("Side", "Civilian")
	return p
end
function moveTo(p, x, z, speed)
	p.Character.HumanoidRootPart.Position = Vector3.new(x, 0, z)
	p.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(speed or 0, 0, 0)
end
-- A few mission ticks (MissionService ticks every 0.2 s of Heartbeat), with time moving on.
function ticks(n, gap)
	for _ = 1, n or 3 do
		runUntil(clock() + (gap or 0.25))
		services.RunService.Heartbeat:Fire(0.25)
	end
end

-- The places MapService would publish, then the Missions config (with Heists' spots) as the game loads it.
RS:SetAttribute("Places", HTTP:JSONEncode({
	{ n = "Coast Arms", x = 1000, z = 0 }, { n = "Chop Shop", x = 2000, z = 0 }, { n = "Spray & Go", x = 3000, z = 0 },
	{ n = "Hideout", x = 4000, z = 0 }, { n = "Police HQ", x = 5000, z = 0 },
}))
HEISTS = { BigScore = { VanSpot = Vector3.new(-474, 0, 1210), Street = Vector3.new(-292, 0, -940) } }
script = { Parent = { Heists = HEISTS } }
EOF

# MISSIONS_SRC, MISSION_SRC, CREW_SRC are pasted in as functions; load() makes a fresh "server".
scenario() {
	local name="$1" body="$2"
	local f="$OUT/crew_$name.luau"
	{
		cat "$H/prelude.luau"
		echo "$STUBS"
		echo "local MISSIONS = (function()"
		cat "$ROOT/src/shared/Config/Missions.lua"
		echo "end)()"
		echo "RS.Shared = { Config = { Missions = MISSIONS }, Util = { Remotes = REMOTES, RateLimit = { Allow = function() return true end } } }"
		echo "local function loadMission()"
		cat "$ROOT/src/server/Services/MissionService.lua"
		echo "end"
		echo "local function loadCrew()"
		cat "$ROOT/src/server/Services/CrewService.lua"
		echo "end"
		cat <<'EOF'
XP, OFFERS = {}, {}
local SSS = services.ServerScriptService
local function server(playersObj)
	if playersObj then
		services.Players = playersObj
		Players = playersObj
	end
	SSS.Services = {
		EconomyService = ECON,
		Telemetry = { Custom = function() end },
		DataService = { OnLoaded = function() end, Get = function() return nil end },
		ProgressService = { Event = function(p, kind, n) XP[p.UserId] = (XP[p.UserId] or 0) + n end },
		RideService = { OfferJob = function(a, b) table.insert(OFFERS, { a, b }) end },
		FindFirstChild = function(self, n) return rawget(self, n) end,
	}
	SSS.Services.MissionService = loadMission()
	SSS.Services.CrewService = loadCrew()
	SSS.Services.MissionService.Init()
	SSS.Services.CrewService.Init()
	return SSS.Services.CrewService, SSS.Services.MissionService
end
-- A fresh, empty server (new Players) on the same DataStore.
function newServer()
	local fresh = { PlayerAdded = newSignal(), PlayerRemoving = newSignal(), list = {}, _attrs = {} }
	setmetatable(fresh, { __index = getmetatable(Players) and getmetatable(Players).__index or Players })
	fresh.GetPlayers = Players.GetPlayers
	fresh.GetPlayerByUserId = Players.GetPlayerByUserId
	fresh.GetAttribute = Players.GetAttribute
	fresh.SetAttribute = Players.SetAttribute
	return server(fresh)
end
-- Two players in one crew (A invited B), at the origin.
function crewOf2(a, b)
	fire(a, "RequestCrew", "Invite", b.UserId)
	fire(b, "RequestCrew", "Accept")
	runUntil(clock() + 1)
end
local function preps(p)
	return p:GetAttribute("CrewPreps")
end
EOF
		echo "local CS, MS = server()"
		echo "$body"
		echo 'if ERRORS then print("FAIL coroutine errors: " .. ERRORS) end'
		echo 'for _, l in ipairs(LOG) do print("  log: " .. l) end'
	} > "$f"
	echo "== $name"
	"$L" "$f" 2>&1
}

scenario form_and_save '
local a, b = newMate(1), newMate(2)
join(a) join(b)
runUntil(1)
crewOf2(a, b)
local id = a:GetAttribute("Crew")
check("both in one crew", id ~= nil and b:GetAttribute("Crew") == id, id)
check("no preps done yet", preps(a) == "" and preps(b) == "")
local rec = STORE.data["c_" .. tostring(id)]
check("crew saved with both", rec and #rec.members == 2 and table.find(rec.members, 1) and table.find(rec.members, 2))
check("pointers saved", STORE.data.u_1 == id and STORE.data.u_2 == id)
check("both handed the job", #sent(a, "CrewJob", "New") == 1 and #sent(b, "CrewJob", "New") == 1)
local info = lastSent(b, "CrewJob", "New")[2]
check("job says 0 of 3", info.Done == 0 and info.Total == 3, tostring(info.Done) .. "/" .. tostring(info.Total))
runUntil(clock() + 3)
check("the heist plan is up for both (not paused)", a:GetAttribute("CrewPaused") == nil and b:GetAttribute("CrewPaused") == nil)
check("roster published", decode(a:GetAttribute("CrewRoster")) and #decode(a:GetAttribute("CrewRoster")) == 2)
'

scenario back_next_session '
local a, b = newMate(1), newMate(2)
join(a) join(b)
runUntil(1)
crewOf2(a, b)
local id = a:GetAttribute("Crew")
runUntil(clock() + 2)
leave(a) leave(b)
runUntil(clock() + 2)
-- A new server, the next day: B comes alone, then A.
newServer()
local a2, b2 = newMate(1), newMate(2)
join(b2)
runUntil(clock() + 1)
check("B is back in the saved crew", b2:GetAttribute("Crew") == id, b2:GetAttribute("Crew"))
check("B told the crew is back", #sent(b2, "CrewJob", "Back") == 1)
check("roster lists A while A is away", #decode(b2:GetAttribute("CrewRoster")) == 2)
join(a2)
runUntil(clock() + 1)
check("A is back in the same crew", a2:GetAttribute("Crew") == id)
local crews = decode(services.ReplicatedStorage:GetAttribute("Crews"))
check("both drawn as one crew here", crews[id] and #crews[id] == 2)
'

scenario prep_together '
local a, b = newMate(1), newMate(2)
join(a) join(b)
runUntil(1)
crewOf2(a, b)
runUntil(clock() + 3)
fire(a, "RequestCrew", "Prep", "PrepGear")
runUntil(clock() + 0.1)
check("both on the prep", a:GetAttribute("Mission") ~= nil and b:GetAttribute("Mission") ~= nil)
check("crew shows the prep running", a:GetAttribute("CrewPrepRun") == "PrepGear")
local m = MISSIONS.ById.PrepGear
check("places resolved from the map list", m.Steps[1].Points[1].X == 1000 and m.Steps[2].Pos.X == 4000)
-- A drives to Coast Arms alone: it does not count, and the crew hears why.
runUntil(clock() + 20)
moveTo(a, 1000, 0)
ticks(3)
local got = decode(a:GetAttribute("Mission")).got
check("one alone does not count", #got == 0, #got)
check("told to stick together", #sent(a, "CrewJob", "Toast") >= 1 and lastSent(a, "CrewJob", "Toast")[2].Key == "Together")
moveTo(b, 1000, 0)
ticks(3)
check("together it counts", #decode(a:GetAttribute("Mission")).got == 1)
for _, x in ipairs({ 2000, 3000 }) do
	runUntil(clock() + 20)
	moveTo(a, x, 0) moveTo(b, x, 0)
	ticks(3)
end
check("on to the Hideout", decode(a:GetAttribute("Mission")).step == 2)
runUntil(clock() + 20)
moveTo(a, 4000, 0) moveTo(b, 4000, 0)
ticks(3)
check("prep over for both", a:GetAttribute("Mission") == nil and b:GetAttribute("Mission") == nil)
check("both paid", (a:GetAttribute("Cash") or 0) == 1500 and (b:GetAttribute("Cash") or 0) == 1500)
check("both got XP", XP[1] == 120 and XP[2] == 120)
runUntil(clock() + 1)
check("prep marked done", preps(a) == ",PrepGear," and preps(b) == ",PrepGear,")
check("prep saved", STORE.data["c_" .. a:GetAttribute("Crew")].preps.PrepGear == true)
check("not running any more", a:GetAttribute("CrewPrepRun") == nil)
check("PrepDone told", #sent(b, "CrewJob", "PrepDone") == 1)
fire(b, "RequestCrew", "Prep", "PrepGear")
runUntil(clock() + 0.1)
check("a done prep cannot start again", b:GetAttribute("Mission") == nil and lastSent(b, "CrewJob", "Toast")[2].Key == "PrepDone")
'

scenario prep_needs_two '
local a, b = newMate(1), newMate(2)
join(a) join(b)
runUntil(1)
crewOf2(a, b)
b:SetAttribute("JobKind", "Taxi")
fire(a, "RequestCrew", "Prep", "PrepCase")
runUntil(clock() + 0.1)
check("no prep while the only crewmate is busy", a:GetAttribute("Mission") == nil)
check("told why", lastSent(a, "CrewJob", "Toast")[2].Key == "NeedMate")
b:SetAttribute("JobKind", nil)
a:SetAttribute("Heat", 2)
fire(a, "RequestCrew", "Prep", "PrepCase")
runUntil(clock() + 0.1)
check("no prep while wanted", a:GetAttribute("Mission") == nil and lastSent(a, "CrewJob", "Toast")[2].Key == "WantedStart")
a:SetAttribute("Heat", 0)
local c = newMate(3)
join(c)
runUntil(clock() + 1)
fire(c, "RequestCrew", "Prep", nil)
runUntil(clock() + 0.1)
check("no crew, no prep", lastSent(c, "CrewJob", "Toast")[2].Key == "NoCrew")
'

scenario getaway_too_slow '
local a, b = newMate(1), newMate(2)
join(a) join(b)
runUntil(1)
crewOf2(a, b)
fire(a, "RequestCrew", "Prep", "PrepGetaway")
runUntil(clock() + 0.1)
local before = decode(a:GetAttribute("Mission")).deadline
runUntil(clock() + 30)
moveTo(a, -292, -940) moveTo(b, -292, -940)
ticks(3)
local after = decode(a:GetAttribute("Mission")).deadline
-- Street (-292,-940) to the Hideout (4000,0): about 4400 studs - 85 / 40 + 30 = about 138 s.
check("the getaway clock starts", after < before and after - clock() < 150 and after - clock() > 120, after - clock())
runUntil(after + 1)
ticks(2)
check("too slow fails it", a:GetAttribute("Mission") == nil)
local failed = lastSent(a, "MissionEvent", "Failed")
check("with the getaway reason", failed and string.find(failed[2].Reason, "Too slow", 1, true) ~= nil, failed and failed[2].Reason)
check("not marked done", preps(a) == "")
check("crew can try again", a:GetAttribute("CrewPrepRun") == nil)
'

scenario mate_quits_mid_prep '
local a, b = newMate(1), newMate(2)
join(a) join(b)
runUntil(1)
crewOf2(a, b)
fire(a, "RequestCrew", "Prep", "PrepCase")
runUntil(clock() + 0.1)
leave(b)
ticks(2)
check("prep fails when a crewmate leaves the game", a:GetAttribute("Mission") == nil)
local failed = lastSent(a, "MissionEvent", "Failed")
check("and says who", failed and string.find(failed[2].Reason, "P2", 1, true) ~= nil, failed and failed[2].Reason)
check("still a crew (saved)", a:GetAttribute("Crew") ~= nil)
fire(a, "RequestCrew", "Prep", "PrepCase")
runUntil(clock() + 0.1)
check("a crew of one here cannot prep", a:GetAttribute("Mission") == nil and lastSent(a, "CrewJob", "Toast")[2].Key == "NeedMate")
'

scenario leave_breaks_it_up '
local a, b = newMate(1), newMate(2)
join(a) join(b)
runUntil(1)
crewOf2(a, b)
local id = a:GetAttribute("Crew")
runUntil(clock() + 2)
fire(a, "RequestCrew", "Leave")
runUntil(clock() + 2)
check("both out", a:GetAttribute("Crew") == nil and b:GetAttribute("Crew") == nil)
check("B told it broke up", #sent(b, "CrewJob", "Broke") == 1 and lastSent(b, "CrewJob", "Broke")[2].Name == "P1")
check("crew gone from the save", STORE.data["c_" .. id] == nil)
check("leaver pointer gone", STORE.data.u_1 == nil)
check("heist not locked by preps without a crew", CS.HeistUnlocked(b) == true)
leave(b)
runUntil(clock() + 1)
newServer()
local b2 = newMate(2)
join(b2)
runUntil(clock() + 2)
check("B is not put back in a dead crew", b2:GetAttribute("Crew") == nil)
check("stale pointer dropped", STORE.data.u_2 == "")
'

scenario three_crew_one_leaves '
local a, b, c = newMate(1), newMate(2), newMate(3)
join(a) join(b) join(c)
runUntil(1)
crewOf2(a, b)
fire(a, "RequestCrew", "Invite", 3)
fire(c, "RequestCrew", "Accept")
runUntil(clock() + 2)
local id = a:GetAttribute("Crew")
check("three in the crew", c:GetAttribute("Crew") == id and #STORE.data["c_" .. id].members == 3)
check("the new one gets the job", #sent(c, "CrewJob", "Joined") == 1)
fire(c, "RequestCrew", "Leave")
runUntil(clock() + 2)
check("two left, still a crew", a:GetAttribute("Crew") == id and b:GetAttribute("Crew") == id and c:GetAttribute("Crew") == nil)
check("save has two", #STORE.data["c_" .. id].members == 2)
check("they were told", #sent(a, "CrewJob", "Left") == 1)
'

scenario heist_gate_and_reset '
local a, b = newMate(1), newMate(2)
join(a) join(b)
runUntil(1)
crewOf2(a, b)
local ok, done, total = CS.HeistUnlocked(a)
check("locked at 0/3", ok == false and done == 0 and total == 3)
CS.Debug(a, "preps") -- (Studio only: nothing)
check("Debug is Studio only", CS.HeistUnlocked(a) == false)
-- Mark the three preps the way a passed prep does.
local id = a:GetAttribute("Crew")
for _, prep in ipairs({ "PrepGear", "PrepCase", "PrepGetaway" }) do
	fire(a, "RequestCrew", "Prep", prep)
	runUntil(clock() + 0.1)
	check(prep .. " started", MS.Active(a) and MS.Active(b))
	-- finish it: walk every step together
	local m = MISSIONS.ById[prep]
	for _, step in ipairs(m.Steps) do
		local pts = step.Points or { step.Pos }
		for _, pt in ipairs(pts) do
			runUntil(clock() + 30)
			moveTo(a, pt.X, pt.Z) moveTo(b, pt.X, pt.Z)
			ticks(5, 1.2) -- (a Hold step: 3 s stopped)
		end
	end
	runUntil(clock() + 1)
end
check("all preps done", preps(a) == ",PrepGear,PrepCase,PrepGetaway,", preps(a))
check("heist unlocked", CS.HeistUnlocked(a) == true)
check("BIG SCORE UNLOCKED told", #sent(a, "CrewJob", "Ready") == 1 and #sent(b, "CrewJob", "Ready") == 1)
CS.ScoreDone({ a, b })
runUntil(clock() + 1)
check("preps reset after a score", preps(a) == "" and CS.HeistUnlocked(a) == false)
check("reset saved", next(STORE.data["c_" .. id].preps) == nil and STORE.data["c_" .. id].scores == 1)
check("Reset told", #sent(b, "CrewJob", "Reset") == 1)
'

scenario switch_crews '
local a, b, c, d = newMate(1), newMate(2), newMate(3), newMate(4)
join(a) join(b) join(c) join(d)
runUntil(1)
crewOf2(a, b)
crewOf2(c, d)
local ab, cd = a:GetAttribute("Crew"), c:GetAttribute("Crew")
fire(a, "RequestCrew", "Invite", 3)
local card = lastSent(c, "CrewInvite")
check("invite says they would leave theirs", card and card[1].Switch == true)
fire(c, "RequestCrew", "Accept")
runUntil(clock() + 2)
check("C moved to A crew", c:GetAttribute("Crew") == ab)
check("D old crew broke up", d:GetAttribute("Crew") == nil and STORE.data["c_" .. cd] == nil)
check("C pointer moved", STORE.data.u_3 == ab)
'

scenario full_crew '
local ps = {}
for i = 1, 5 do ps[i] = newMate(i) join(ps[i]) end
runUntil(1)
crewOf2(ps[1], ps[2])
for i = 3, 4 do
	fire(ps[1], "RequestCrew", "Invite", i)
	fire(ps[i], "RequestCrew", "Accept")
	runUntil(clock() + 1)
end
check("crew of four", #STORE.data["c_" .. ps[1]:GetAttribute("Crew")].members == 4)
fire(ps[1], "RequestCrew", "Invite", 5)
runUntil(clock() + 0.1)
local last = lastSent(ps[1], "Notify")
check("a fifth is refused", last and last[1] == "CrewFull" and ps[5]:GetAttribute("Crew") == nil)
check("no crew-up offer for a full crew", CS.CanCrewUp(ps[1], ps[5]) == false)
check("crew-up offer for a stranger", CS.CanCrewUp(ps[5], ps[1]) == true)
check("none for crewmates", CS.CanCrewUp(ps[1], ps[2]) == false)
'

scenario solo_missions_unchanged '
local a = newMate(1)
join(a)
runUntil(1)
fire(a, "RequestMission", "Start", "PrepGear")
runUntil(clock() + 0.1)
check("a crew prep cannot start from JOBS", a:GetAttribute("Mission") == nil)
fire(a, "RequestMission", "Start", "PizzaRush")
runUntil(clock() + 0.1)
check("a normal mission starts", decode(a:GetAttribute("Mission")).id == "PizzaRush")
runUntil(clock() + 20)
moveTo(a, 1116, 260)
ticks(2)
check("its first goal counts alone", decode(a:GetAttribute("Mission")).step == 2)
runUntil(clock() + 20)
moveTo(a, -125, -1177)
ticks(2)
check("and it pays as before", a:GetAttribute("Mission") == nil and (a:GetAttribute("Cash") or 0) == 600, a:GetAttribute("Cash"))
'

scenario pause_and_resume '
local a, b, c = newMate(1), newMate(2), newMate(3)
join(a) join(b) join(c)
runUntil(1)
crewOf2(a, b)
local id = a:GetAttribute("Crew")
fire(a, "RequestCrew", "Pause", true)
runUntil(clock() + 1)
check("paused for the whole crew", a:GetAttribute("CrewPaused") == true and b:GetAttribute("CrewPaused") == true)
check("pause saved", STORE.data["c_" .. id].paused == true)
check("crew told who paused", lastSent(b, "CrewJob", "Paused") and lastSent(b, "CrewJob", "Paused")[2].Name == "P1")
fire(b, "RequestCrew", "Pause", false)
runUntil(clock() + 1)
check("resumed from the phone", a:GetAttribute("CrewPaused") == nil and STORE.data["c_" .. id].paused == nil)
check("crew told who resumed", lastSent(a, "CrewJob", "Resumed") and lastSent(a, "CrewJob", "Resumed")[2].Name == "P2")
fire(a, "RequestCrew", "Pause", true)
runUntil(clock() + 1)
fire(b, "RequestCrew", "Prep", "PrepCase")
runUntil(clock() + 1)
check("starting a prep un-pauses", a:GetAttribute("CrewPaused") == nil and b:GetAttribute("Mission") ~= nil)
fire(b, "RequestMission", "Quit")
runUntil(clock() + 1)
fire(a, "RequestCrew", "Pause", true)
runUntil(clock() + 1)
fire(a, "RequestCrew", "Invite", 3)
fire(c, "RequestCrew", "Accept")
runUntil(clock() + 1)
check("a new member brings the plan back", a:GetAttribute("CrewPaused") == nil and c:GetAttribute("CrewPaused") == nil)
fire(c, "RequestCrew", "Pause", true)
runUntil(clock() + 2)
leave(a) leave(b) leave(c)
runUntil(clock() + 2)
newServer()
local a2 = newMate(1)
join(a2)
runUntil(clock() + 1)
check("still paused next session", a2:GetAttribute("Crew") == id and a2:GetAttribute("CrewPaused") == true)
local d = newMate(4)
join(d)
runUntil(clock() + 1)
fire(d, "RequestCrew", "Pause", true)
runUntil(clock() + 0.1)
check("no crew: pause says so", lastSent(d, "CrewJob", "Toast")[2].Key == "NoCrew")
'

scenario progress_kept_while_paused '
local a, b = newMate(1), newMate(2)
join(a) join(b)
runUntil(1)
crewOf2(a, b)
local id = a:GetAttribute("Crew")
fire(a, "RequestCrew", "Prep", "PrepCase")
runUntil(clock() + 0.1)
for _, step in ipairs(MISSIONS.ById.PrepCase.Steps) do
	runUntil(clock() + 30)
	moveTo(a, step.Pos.X, step.Pos.Z) moveTo(b, step.Pos.X, step.Pos.Z)
	ticks(5, 1.2)
end
runUntil(clock() + 1)
check("Case the Joint done", a:GetAttribute("CrewPreps") == ",PrepCase,")
fire(b, "RequestCrew", "Pause", true)
runUntil(clock() + 2)
leave(a) leave(b)
runUntil(clock() + 2)
newServer()
local a2, b2 = newMate(1), newMate(2)
join(a2) join(b2)
runUntil(clock() + 1)
check("progress kept across pause and sessions", a2:GetAttribute("CrewPreps") == ",PrepCase," and b2:GetAttribute("CrewPaused") == true)
fire(a2, "RequestCrew", "Prep", nil)
runUntil(clock() + 0.1)
check("the next prep is the first one not done", decode(a2:GetAttribute("Mission")).id == "PrepGear")
'

# Crew calls (PHONE > CREW > INVITE EVERYONE HERE): who gets the card, who joins, when it closes.
scenario crew_call '
local a, b, c, d, x = newMate(1), newMate(2), newMate(3), newMate(4), newMate(5)
local cop, e, f = newMate(6), newMate(7), newMate(8)
cop:SetAttribute("Side", "Cop")
for _, p in ipairs({ a, b, c, d, x, cop, e, f }) do join(p) end
runUntil(1)
crewOf2(e, f)
fire(a, "RequestCrew", "Call")
runUntil(clock() + 0.1)
check("caller told it went out", lastSent(a, "Notify")[1] == "CrewCallSent")
check("caller marked as calling", type(a:GetAttribute("CrewCallUntil")) == "number")
local cb, ccop, ce = lastSent(b, "CrewCall"), lastSent(cop, "CrewCall"), lastSent(e, "CrewCall")
check("a free citizen gets the card", cb and cb[1].Eligible == true and cb[1].FromUserId == 1 and cb[1].FromName == "P1")
check("a cop gets only the chat line", ccop and ccop[1].Eligible == false)
check("someone in a crew gets only the chat line", ce and ce[1].Eligible == false)
check("not sent to the caller", #sent(a, "CrewCall") == 0)
fire(b, "RequestCrew", "CallJoin", 1)
runUntil(clock() + 1)
local id = a:GetAttribute("Crew")
check("first answer makes a crew of the two", id ~= nil and b:GetAttribute("Crew") == id)
check("both handed the crew job", #sent(a, "CrewJob", "New") == 1 and #sent(b, "CrewJob", "New") == 1)
local cj = lastSent(a, "CrewJob", "CallJoined")
check("caller hears who answered", cj and cj[2].Name == "P2")
check("still open with room left", type(a:GetAttribute("CrewCallUntil")) == "number")
fire(c, "RequestCrew", "CallJoin", 1)
fire(d, "RequestCrew", "CallJoin", 1)
runUntil(clock() + 1)
check("third and fourth join the same crew", c:GetAttribute("Crew") == id and d:GetAttribute("Crew") == id)
check("saved as a crew of four", #STORE.data["c_" .. id].members == 4)
local closed = false
for _, ev in ipairs(EVENTS) do
	if ev.name == "CrewCallClosed" and ev.all and ev.args[1].FromUserId == 1 then closed = true end
end
check("a full crew closes the call for everyone", closed and a:GetAttribute("CrewCallUntil") == nil)
fire(x, "RequestCrew", "CallJoin", 1)
runUntil(clock() + 0.5)
check("a fifth answer is too late", lastSent(x, "Notify")[1] == "CrewCallGone" and x:GetAttribute("Crew") == nil)
'

scenario crew_call_rules '
local a, b, cop = newMate(1), newMate(2), newMate(3)
cop:SetAttribute("Side", "Cop")
for _, p in ipairs({ a, b, cop }) do join(p) end
runUntil(1)
fire(cop, "RequestCrew", "Call")
runUntil(clock() + 0.1)
check("cops cannot call", lastSent(cop, "Notify")[1] == "CrewCallCivOnly" and #sent(a, "CrewCall") == 0)
fire(a, "RequestCrew", "Call")
runUntil(clock() + 0.1)
check("call sent", lastSent(a, "Notify")[1] == "CrewCallSent")
fire(a, "RequestCrew", "Call")
runUntil(clock() + 0.1)
check("one open call at a time", lastSent(a, "Notify")[1] == "CrewCallOpen")
runUntil(clock() + 61)
check("the call runs out after a minute", a:GetAttribute("CrewCallUntil") == nil)
fire(b, "RequestCrew", "CallJoin", 1)
runUntil(clock() + 0.5)
check("answering a call that ran out", lastSent(b, "Notify")[1] == "CrewCallGone" and b:GetAttribute("Crew") == nil)
fire(a, "RequestCrew", "Call")
runUntil(clock() + 0.1)
check("90 s between calls", lastSent(a, "Notify")[1] == "CrewCallWait")
runUntil(clock() + 30)
fire(a, "RequestCrew", "Call")
runUntil(clock() + 0.1)
check("a new call after the wait", lastSent(a, "Notify")[1] == "CrewCallSent")
leave(a)
runUntil(clock() + 0.5)
local closed = false
for _, ev in ipairs(EVENTS) do
	if ev.name == "CrewCallClosed" and ev.all and ev.args[1].FromUserId == 1 then closed = true end
end
check("leaving the server closes the call", closed)
crewOf2(b, newMate(9))
'

scenario crew_call_nobody '
local a, b, c = newMate(1), newMate(2), newMate(3)
for _, p in ipairs({ a, b, c }) do join(p) end
runUntil(1)
crewOf2(b, c)
fire(a, "RequestCrew", "Call")
runUntil(clock() + 0.1)
check("nobody free: refused, nothing sent", lastSent(a, "Notify")[1] == "CrewCallNobody" and #sent(b, "CrewCall") == 0)
check("no open call left behind", a:GetAttribute("CrewCallUntil") == nil)
'
