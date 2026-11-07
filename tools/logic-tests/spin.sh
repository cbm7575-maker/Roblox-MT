#!/bin/bash
# The daily spin at the Lucky Wheel and the rookie chase: prelude + stubs + the real Config.Spin,
# Config.Tutorial, EconomyService and SpinService (each as a function), then scenarios on a virtual clock.
# (The wheel's model isn't built here: SpinService.Init's build fails without Instance and is caught; the
# spin logic runs on its own state. SpinService.InRange is stood in for: every player is at the podium.)
# Every line should read PASS.
H="$(cd "$(dirname "$0")" && pwd)"
L="${LUAU:-luau}" # the Luau CLI (github.com/luau-lang/luau releases); set LUAU to its path
SRC="$H/../../src"
OUT="${TMPDIR:-${TEMP:-/tmp}}/theft-logic-tests"
mkdir -p "$OUT"

STUBS='
Enum = { AnalyticsEconomyFlowType = { Source = "Source", Sink = "Sink" } }
local ws = game:GetService("Workspace")
function ws:GetServerTimeNow() return 1700000000 + clock() end
Random = { new = function() return { NextInteger = function(_, a, b) return FORCE or math.random(a, b) end,
	NextNumber = function() return JITTER or 0.5 end } end }
Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
Color3 = { fromRGB = function(r, g, b) return { r, g, b } end, new = function(r, g, b) return { r, g, b } end }
FIRED = {} -- [remote name] = { { player, payload }, ... }
FAR = {} -- [player] = true: away from the podium
local plainPlayer = newPlayer
function newPlayer(id) local p = plainPlayer(id) p.DisplayName = "Player" .. id return p end
local remotes = {}
local Remotes = { __module = true }
function Remotes.Event(name)
	remotes[name] = remotes[name] or { OnServerEvent = newSignal(),
		FireClient = function(_, p, v) FIRED[name] = FIRED[name] or {} table.insert(FIRED[name], { p, v }) end,
		FireAllClients = function(_, k, v) FIRED[name] = FIRED[name] or {} table.insert(FIRED[name], { k, v }) end }
	return remotes[name]
end
function lastFired(name) local l = FIRED[name] return l and l[#l] end
local RateLimit = { __module = true, Allow = function() return true end }
EVENTS = {}
TELEMETRY = { __module = true, Custom = function(p, name, v) table.insert(EVENTS, name) end, Economy = function() end }
VEHICLES = { __module = true, ById = { SolanaGT = { Id = "SolanaGT", DisplayName = "Solana GT" } } }
COMBAT = { __module = true, Guns = {
	Pistol = { Id = "Pistol", Name = "Coast 9", Rank = 1 }, SMG = { Id = "SMG", Name = "Squall", Rank = 1 },
	Shotgun = { Id = "Shotgun", Name = "Gatorbite", Rank = 1 }, Rifle = { Id = "Rifle", Name = "Tarpon Carbine", Rank = 5 } } }
function COMBAT.RankOk(p, gun) return (p:GetAttribute("CivRank") or 1) >= gun.Rank end
local rs = game:GetService("ReplicatedStorage")
rs.Shared = { Config = { Heists = { __module = true, CarryLimit = 22000 }, Shop = { __module = true, DuffelCarryBonus = 0.5 },
	Vehicles = VEHICLES, Combat = COMBAT }, Util = { Remotes = Remotes, RateLimit = RateLimit } }
PROFILES = {}
SAVES = 0
local loaded = {}
local DS = { __module = true }
function DS.Get(p) return PROFILES[p] end
function DS.OnLoaded(fn) table.insert(loaded, fn) end
function DS.SaveNow(p) SAVES += 1 return true end
function load(p, data) PROFILES[p] = data for _, fn in ipairs(loaded) do task.spawn(fn, p, data) end end
OWNED_CARS = {}
local GARAGE = { __module = true }
function GARAGE.Owns(p, id) return OWNED_CARS[id] == true end
function GARAGE.Give(p, id) if OWNED_CARS[id] then return false end OWNED_CARS[id] = true return true end
local COMBATSVC = { __module = true }
function COMBATSVC.GiveGun(p, id)
	local d = PROFILES[p] d.gear = d.gear or { guns = {} }
	if d.gear.guns[id] then return false end
	d.gear.guns[id] = true return true
end
local sss = game:GetService("ServerScriptService")
sss.Services.DataService = DS
sss.Services.Telemetry = TELEMETRY
sss.Services.GarageService = GARAGE
sss.Services.CombatService = COMBATSVC
'

scenario() {
	local name="$1" body="$2"
	local f="$OUT/spin_$name.luau"
	{
		cat "$H/prelude.luau"
		echo "$STUBS"
		echo "script = { Parent = rs.Shared.Config }"
		echo "local Spin = (function()"; cat "$SRC/shared/Config/Spin.lua"; echo "end)()"
		echo "rs.Shared.Config.Spin = Spin"
		echo "local Tutorial = (function()"; cat "$SRC/shared/Config/Tutorial.lua"; echo "end)()"
		echo "script = { Parent = sss.Services }"
		echo "local EconomyService = (function()"; cat "$SRC/server/Services/EconomyService.lua"; echo "end)()"
		echo "sss.Services.EconomyService = EconomyService"
		echo "local SpinService = (function()"; cat "$SRC/server/Services/SpinService.lua"; echo "end)()"
		echo "SpinService.Init()"
		echo 'SpinService.InRange = function(p) return not FAR[p] end'
		echo 'local function spin(p) return SpinService.SpinAt(p) end'
		echo 'local TURN = Spin.Wheel.Lead + Spin.Seconds -- the prize is paid this long after a spin starts'
		echo 'local FREE = TURN + Spin.Wheel.ShowResult + 0.5 -- and the wheel is free again after this'
		echo 'local function cash(p) return p:GetAttribute("Cash") or 0 end'
		echo 'local function fresh(id) local p = newPlayer(id or 1) p:SetAttribute("Cash", 0) join(p) load(p, {}) runUntil(clock() + 0.1) return p end'
		echo "$body"
		echo 'if ERRORS then print("FAIL coroutine errors: " .. ERRORS) end'
		echo 'if #LOG > 0 then print("warnings: " .. table.concat(LOG, " | ")) end'
	} > "$f"
	echo "== $name"
	"$L" "$f" 2>&1
}

scenario config '
check("18 slices", #Spin.Slices == 18, #Spin.Slices)
check("the car is 1 in 18", Spin.Count("Car") == 1)
local total = Spin.Count("Car") + Spin.Count("Gun") + Spin.Count("Boost") + Spin.Count("Cash")
check("every slice counted once", total == 18, total)
check("cash slices: 4x1000, 3x2500, 2x5000, 1x10000", Spin.Count("Cash", 1000) == 4 and Spin.Count("Cash", 2500) == 3 and Spin.Count("Cash", 5000) == 2 and Spin.Count("Cash", 10000) == 1)
local same = 0
for i, s in ipairs(Spin.Slices) do
	local n = Spin.Slices[i % #Spin.Slices + 1]
	if s.Kind == n.Kind and s.Cash == n.Cash and s.Boost == n.Boost then same += 1 end
end
check("no prize sits next to itself", same == 0, same)
check("labels", Spin.Label(Spin.Slices[1]) == "SOLANA GT" and Spin.Label({ Kind = "Cash", Cash = 10000 }) == "$10,000" and Spin.Label({ Kind = "Cash", Cash = 2500 }) == "$2,500")
check("daily cash never doubled", not Spin.DoubleCash.daily and not Spin.DoubleCash.product and not Spin.DoubleCash.spin and not Spin.DoubleCash.tutorial and not Spin.DoubleCash.journey)'

scenario first_spin_pays_when_the_wheel_stops '
local p = fresh()
check("ready on join", p:GetAttribute("SpinReady") == true)
FORCE = 2 -- $1,000
spin(p)
local r = lastFired("SpinResult")
check("answer names the slice", r and r[2].Slice == 2 and r[2].Plan.Kind == "Cash" and r[2].Plan.Cash == 1000)
check("used at once", p:GetAttribute("SpinReady") == false and type(p:GetAttribute("SpinNextAt")) == "number")
check("saved before the answer (pending)", PROFILES[p].spin.pending ~= nil and SAVES >= 1)
runUntil(clock() + TURN - 0.5)
check("not paid while it turns", cash(p) == 0, cash(p))
runUntil(clock() + 1)
check("paid when it stops", cash(p) == 1000, cash(p))
check("pending cleared", PROFILES[p].spin.pending == nil)
check("a second spin the same day is refused", spin(p) == false and lastFired("Notify")[2] == "SpinUsed")
runUntil(clock() + 10)
check("...and pays nothing", cash(p) == 1000, cash(p))
check("$1,000 is no feed post", FIRED.Feed == nil)
local nextAt = p:GetAttribute("SpinNextAt")
check("next spin at the next UTC midnight", nextAt % 86400 == 0 and nextAt > os.time() and nextAt - os.time() <= 86400)
runUntil(nextAt - 1700000000 + 40)
check("ready again after midnight (online)", p:GetAttribute("SpinReady") == true)
FORCE = 13 -- $10,000
spin(p)
runUntil(clock() + FREE)
check("second day pays", cash(p) == 11000, cash(p))
check("$10,000 goes on the city feed", lastFired("Feed") and lastFired("Feed")[1] == "WheelWin" and lastFired("Feed")[2].Prize == "$10,000")'

scenario car_slice '
local p = fresh()
FORCE = 1
spin(p)
check("plan: the car, not owned", lastFired("SpinResult")[2].Plan.Kind == "Car" and lastFired("SpinResult")[2].Plan.Owned == false)
runUntil(clock() + FREE)
check("car given", OWNED_CARS.SolanaGT == true and cash(p) == 0)
check("telemetry Spin_Car", table.find(EVENTS, "Spin_Car") ~= nil)
local q = fresh(2)
spin(q)
runUntil(clock() + FREE)
check("already owned: $25,000 instead", cash(q) == Spin.CarFallback, cash(q))
check("plan said so", lastFired("SpinResult")[2].Plan.Owned == true)'

scenario gun_slice '
local p = fresh()
PROFILES[p].gear = { guns = { Pistol = true } }
FORCE = 5
spin(p)
check("plan: the next gun (SMG)", lastFired("SpinResult")[2].Plan.Gun == "SMG")
runUntil(clock() + FREE)
check("SMG given", PROFILES[p].gear.guns.SMG == true and cash(p) == 0)
local q = fresh(2)
PROFILES[q].gear = { guns = { Pistol = true, SMG = true, Shotgun = true } }
spin(q)
runUntil(clock() + FREE)
check("rank 1 with every rank-1 gun: $5,000 (no Rifle)", cash(q) == Spin.GunFallback and not PROFILES[q].gear.guns.Rifle, cash(q))
local r = fresh(3)
r:SetAttribute("CivRank", 5)
PROFILES[r].gear = { guns = { Pistol = true, SMG = true, Shotgun = true } }
spin(r)
runUntil(clock() + FREE)
check("rank 5: the Rifle", PROFILES[r].gear.guns.Rifle == true and cash(r) == 0)'

scenario double_cash '
local p = fresh()
FORCE = 7 -- 2X CASH
spin(p)
runUntil(clock() + FREE)
local left = SpinService.BoostLeft(p, "Cash")
check("2X CASH on for 30 minutes", left > 1790 and left <= 1800, left)
EconomyService.AddCash(p, 300, "taxi")
check("a taxi fare pays double", cash(p) == 600, cash(p))
check("the client hears of the extra", lastFired("BoostPaid") and lastFired("BoostPaid")[2] == 300)
EconomyService.AddCash(p, 1000, "daily:day1")
check("the daily streak is not doubled", cash(p) == 1600, cash(p))
EconomyService.AddCash(p, 5000, "product:Cash1")
check("a Robux cash pack is not doubled", cash(p) == 6600, cash(p))
EconomyService.AddCash(p, 500, "bizjob:wash")
check("reason with a colon still matches its prefix", cash(p) == 7600, cash(p))
EconomyService.AddCarried(p, 2000, "heist")
check("the bag is not doubled going in", EconomyService.GetCarried(p) == 2000)
EconomyService.BankCarried(p, "hideout")
check("banking the bag pays double", cash(p) == 11600 and EconomyService.GetCarried(p) == 0, cash(p))
runUntil(clock() + 1815)
EconomyService.AddCash(p, 300, "taxi")
check("after 30 minutes it is over", cash(p) == 11900, cash(p))
check("the boost is switched off and out of the save", p:GetAttribute("BoostCashUntil") == nil and PROFILES[p].spin.boosts.Cash == nil)'

scenario left_mid_spin_paid_next_join '
local p = fresh()
FORCE = 8 -- $5,000
spin(p)
runUntil(clock() + 2)
leave(p)
runUntil(clock() + 10)
check("not paid while gone", cash(p) == 0)
local data = PROFILES[p]
check("prize waits in the save", data.spin.pending ~= nil and data.spin.pending.plan.Cash == 5000)
p.Parent = Players
join(p)
load(p, data)
runUntil(clock() + 1)
check("paid on the next join", cash(p) == 5000, cash(p))
check("and only once", data.spin.pending == nil)
check("still used for today", p:GetAttribute("SpinReady") == false)'

scenario boosts_count_play_time_only '
local p = fresh()
FORCE = 3 -- 2X XP
spin(p)
runUntil(clock() + FREE)
runUntil(clock() + 600)
local saved = PROFILES[p].spin.boosts.XP
check("about 20 minutes saved after 10 played", saved and saved >= 1190 and saved <= 1200, saved)
leave(p)
local data = PROFILES[p]
runUntil(clock() + 4800) -- 80 minutes offline
p.Parent = Players
join(p)
load(p, data)
runUntil(clock() + 0.1)
local left = SpinService.BoostLeft(p, "XP")
check("offline time does not count", left >= 1185 and left <= 1200, left)
FORCE = 9 -- 2X XP again, just after midnight while the first one still runs
runUntil(6440)
check("new day: ready", p:GetAttribute("SpinReady") == true)
spin(p)
runUntil(clock() + FREE)
check("a second win adds on", SpinService.BoostLeft(p, "XP") > 1800, SpinService.BoostLeft(p, "XP"))'

scenario rookie_chase '
local p = newPlayer(1)
check("not loaded: no rookie", Tutorial.IsRookie(p) == false)
p:SetAttribute("Side", "Civilian")
p:SetAttribute("TutorialStep", 2)
p:SetAttribute("Heat", 1)
check("robbed, not banked, 1 star: rookie", Tutorial.IsRookie(p) == true)
p:SetAttribute("Heat", 3)
check("3 stars: normal cops", Tutorial.IsRookie(p) == false)
p:SetAttribute("Heat", 2)
check("2 stars: rookie", Tutorial.IsRookie(p) == true)
p:SetAttribute("TutorialStep", 3)
check("banked once: normal cops", Tutorial.IsRookie(p) == false)
p:SetAttribute("TutorialStep", 0)
p:SetAttribute("Side", "Cop")
check("a cop is never a rookie robber", Tutorial.IsRookie(p) == false)
check("gentler than normal", Tutorial.Rookie.SpeedScale < 0.95 and Tutorial.Rookie.HeadStart >= 20 and Tutorial.Rookie.EscapeAfter < 40)
check("a patrol still shows up before an unseen rookie is clear", Tutorial.Rookie.HeadStart < Tutorial.Rookie.EscapeAfter)'

scenario wheel_one_at_a_time '
local p, q = fresh(1), fresh(2)
FORCE = 2
check("first player spins", spin(p) == true)
check("busy while it turns", SpinService.WheelState().Busy == true)
check("second player waits", spin(q) == false and lastFired("Notify")[1] == q and lastFired("Notify")[2] == "WheelBusy")
check("and keeps their spin", q:GetAttribute("SpinReady") == true)
runUntil(clock() + TURN + 0.5)
check("still busy while the result shows", SpinService.WheelState().Busy == true and spin(q) == false)
runUntil(clock() + Spin.Wheel.ShowResult)
check("free again", SpinService.WheelState().Busy == false)
FORCE = 7
check("now the second player spins", spin(q) == true)
runUntil(clock() + FREE)
check("both paid", cash(p) == 1000 and SpinService.BoostLeft(q, "Cash") > 0)
check("the wheel rests on the last slice won", Spin.SliceAt(SpinService.WheelState().Angle) == 7, SpinService.WheelState().Angle)'

scenario out_of_range '
local p = fresh()
FAR[p] = true
check("too far from the podium: refused", spin(p) == false and lastFired("Notify")[2] == "WheelTooFar")
check("the spin is kept", p:GetAttribute("SpinReady") == true and (PROFILES[p].spin.day == nil))
FAR[p] = nil
check("at the podium: spins", spin(p) == true)'

scenario car_on_the_feed '
local p = fresh()
FORCE = 1
spin(p)
runUntil(clock() + FREE)
check("the car goes on the feed", lastFired("Feed") and lastFired("Feed")[2].Prize == "a Solana GT" and lastFired("Feed")[2].Name ~= nil)
local q = fresh(2)
FIRED.Feed = nil
spin(q)
runUntil(clock() + FREE)
check("an owned car ($25,000 instead) does not", FIRED.Feed == nil)
check("prize words", SpinService.PrizeWords({ Kind = "Boost", Boost = "XP" }) == "2X XP" and SpinService.PrizeWords({ Kind = "Gun", GunName = "Squall" }) == "A FREE SQUALL")'

scenario turn_maths '
local ok, worst = true, 0
for from = 0, 359, 37 do
	for i = 1, #Spin.Slices do
		for _, j in ipairs({ -Spin.Jitter, 0, Spin.Jitter }) do
			local to = Spin.Target(from, i, j, Spin.Turns)
			if Spin.SliceAt(to % 360) ~= i or to - from < 360 * Spin.Turns or to - from >= 360 * (Spin.Turns + 1) then
				ok = false
			end
		end
	end
end
check("every slice, every start, either side of its middle: stops on it after 5 to 6 turns", ok)
check("eases: starts at from, ends at to", Spin.AngleAt(10, 1810, 6, 0) == 10 and Spin.AngleAt(10, 1810, 6, 6) == 1810 and Spin.AngleAt(10, 1810, 6, 3) > 910)'
