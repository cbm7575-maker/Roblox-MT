#!/bin/bash
# The login streak's 7-day calendar (Nov 9 2026): prelude + spin.sh's stubs + the real Config.Daily,
# Config.Spin, EconomyService, SpinService and DailyService, then scenarios on a virtual clock.
# (The virtual clock starts at unix 1700000000, which is 6,400 s before a UTC midnight.)
# Every line should read PASS.
H="$(cd "$(dirname "$0")" && pwd)"
L="${LUAU:-luau}" # the Luau CLI (github.com/luau-lang/luau releases); set LUAU to its path
SRC="$H/../../src"
OUT="${TMPDIR:-${TEMP:-/tmp}}/theft-logic-tests"
mkdir -p "$OUT"

# spin.sh's stand-ins (Remotes, DataService, Telemetry, Garage, Combat...), reused as they are.
eval "$(sed -n "/^STUBS='/,/^'\$/p" "$H/spin.sh")"

scenario() {
	local name="$1" body="$2"
	local f="$OUT/daily_$name.luau"
	{
		cat "$H/prelude.luau"
		echo "$STUBS"
		echo "script = { Parent = rs.Shared.Config }"
		echo "local Spin = (function()"; cat "$SRC/shared/Config/Spin.lua"; echo "end)()"
		echo "rs.Shared.Config.Spin = Spin"
		echo "local Daily = (function()"; cat "$SRC/shared/Config/Daily.lua"; echo "end)()"
		echo "rs.Shared.Config.Daily = Daily"
		echo "script = { Parent = sss.Services }"
		echo "local EconomyService = (function()"; cat "$SRC/server/Services/EconomyService.lua"; echo "end)()"
		echo "sss.Services.EconomyService = EconomyService"
		echo "local SpinService = (function()"; cat "$SRC/server/Services/SpinService.lua"; echo "end)()"
		echo "sss.Services.SpinService = SpinService"
		echo "local DailyService = (function()"; cat "$SRC/server/Services/DailyService.lua"; echo "end)()"
		# Main's order: DailyService starts before SpinService.
		echo "DailyService.Init()"
		echo "SpinService.Init()"
		echo 'SpinService.InRange = function(p) return not FAR[p] end'
		echo 'local DAY = 86400'
		echo 'local MIDNIGHT = (math.floor(1700000000 / DAY) + 1) * DAY - 1700000000 -- virtual seconds to the first UTC midnight'
		echo 'local function cash(p) return p:GetAttribute("Cash") or 0 end'
		echo 'local nextId = 0'
		echo '-- A join (after PLAY) with this save: a fresh player object each time, like a real rejoin.'
		echo 'local function joinWith(data) nextId += 1 local p = newPlayer(nextId) p:SetAttribute("Cash", 0) p:SetAttribute("HasPicked", true) join(p) load(p, data) runUntil(clock() + 0.5) return p end'
		echo 'local function gone(p) leave(p) PROFILES[p] = nil end'
		echo 'local function lastReward() local r = lastFired("DailyReward") return r and r[2] end'
		echo 'local function rewards() return FIRED.DailyReward and #FIRED.DailyReward or 0 end'
		echo '-- Move the clock to `hours` past the start of UTC day number `n` after the first midnight (n = 0: that midnight).'
		echo 'local function toDay(n, hours) runUntil(MIDNIGHT + n * DAY + (hours or 1) * 3600) end'
		echo "$body"
		echo 'if ERRORS then print("FAIL coroutine errors: " .. ERRORS) end'
		echo 'if #LOG > 0 then print("warnings: " .. table.concat(LOG, " | ")) end'
	} > "$f"
	echo "== $name"
	"$L" "$f" 2>&1
}

scenario config '
check("same day: nothing", Daily.Advance(100, 3, 100) == nil and Daily.Advance(101, 3, 100) == nil)
check("next day: +1", Daily.Advance(99, 3, 100) == 4)
check("one missed day (grace): +1", Daily.Advance(98, 3, 100) == 4)
check("two missed days: day 1", Daily.Advance(97, 3, 100) == 1)
check("first ever: day 1", Daily.Advance(nil, nil, 100) == 1)
check("old save without a streak number: day 1", Daily.Advance(99, nil, 100) == 1)
local cashOk = true
for d = 1, 20 do
	if Daily.Reward(d).Cash ~= 1000 * math.min(d, 7) then cashOk = false end
end
check("cash: $1,000 x day, $7,000 from day 7 on", cashOk)
check("slots repeat every 7", Daily.Slot(1) == 1 and Daily.Slot(7) == 7 and Daily.Slot(8) == 1 and Daily.Slot(14) == 7 and Daily.Slot(15) == 1)
local r2, r3, r4, r7 = Daily.Reward(2), Daily.Reward(3), Daily.Reward(4), Daily.Reward(7)
check("day 2: 2X CASH 15 min", r2.Boost == "Cash" and r2.Minutes == 15 and not r2.Spins)
check("day 3: a bonus spin", r3.Spins == 1 and not r3.Boost)
check("day 4: 2X XP 30 min", r4.Boost == "XP" and r4.Minutes == 30)
check("day 7: spin + paint", r7.Spins == 1 and r7.Paint == true)
check("day 7 with the paint owned: no paint", Daily.Reward(7, true).Paint == nil)
check("day 1 and day 8: cash only", not Daily.Reward(1).Boost and not Daily.Reward(1).Spins and not Daily.Reward(8).Boost and not Daily.Reward(8).Spins and Daily.Reward(8).Cash == 7000)
check("words", Daily.Words(r2) == "$2,000 + 2X CASH 15 MIN" and Daily.Words(r3) == "$3,000 + BONUS SPIN" and Daily.Words(r7) == "$7,000 + BONUS SPIN + STREAK PAINT" and Daily.Words(Daily.Reward(1)) == "$1,000", Daily.Words(r7))
local c, e = Daily.Words(r2, true)
check("short words", c == "$2,000" and e == "2X CASH", c .. "|" .. e)
check("next at midnight UTC", Daily.NextAt(1700000000) % 86400 == 0 and Daily.NextAt(1700000000) > 1700000000)
check("the streak cash is never doubled by 2X CASH", not Spin.DoubleCash.daily)'

scenario first_day_then_day_two '
local data = {}
local p = joinWith(data)
check("day 1 paid", cash(p) == 1000, cash(p))
local r = lastReward()
check("payload: streak 1, first, tomorrow is $2,000 + 2X CASH", r and r.Streak == 1 and r.First == true and r.Next.Cash == 2000 and r.Next.Boost == "Cash")
check("attributes", p:GetAttribute("Streak") == 1 and p:GetAttribute("StreakNextAt") == Daily.NextAt(os.time()))
check("saved", data.daily.last == Daily.Day(os.time()) and data.daily.streak == 1 and data.daily.n == 1)
check("no boost on day 1", p:GetAttribute("BoostCashUntil") == nil)
check("telemetry Streak_Day", table.find(EVENTS, "Streak_Day") ~= nil)
gone(p)
local p1 = joinWith(data)
check("same-day rejoin pays nothing", cash(p1) == 0 and rewards() == 1, rewards())
check("...but the streak still shows", p1:GetAttribute("Streak") == 1)
gone(p1)
toDay(0, 20)
local p2 = joinWith(data)
check("day 2 paid", cash(p2) == 2000, cash(p2))
check("day 2: 2X CASH for 15 min of play", math.abs(SpinService.BoostLeft(p2, "Cash") - 900) < 2, SpinService.BoostLeft(p2, "Cash"))
check("boost saved", data.spin and data.spin.boosts and data.spin.boosts.Cash == 900)
r = lastReward()
check("payload day 2, not first", r.Streak == 2 and r.First == false and r.Next.Spins == 1)'

scenario grace_and_reset '
local data = { daily = { last = Daily.Day(1700000000), streak = 4 } } -- an old-style save, paid today
local p = joinWith(data)
check("already paid today", cash(p) == 0 and p:GetAttribute("Streak") == 4)
gone(p)
toDay(1, 5) -- skipped one whole UTC day
p = joinWith(data)
check("one missed day keeps the streak (day 5)", data.daily.streak == 5 and cash(p) == 5000, data.daily.streak)
gone(p)
toDay(4, 5) -- two missed days
p = joinWith(data)
local r = lastReward()
check("two missed days: back to day 1", data.daily.streak == 1 and cash(p) == 1000, data.daily.streak)
check("payload says which streak ended", r.Broke == 5 and r.First == false, r.Broke)
check("Streak_Broke logged", table.find(EVENTS, "Streak_Broke") ~= nil)
check("best kept", data.daily.best == 5, data.daily.best)'

scenario bonus_spins '
local data = { daily = { last = Daily.Day(1700000000) - 1, streak = 2 } } -- yesterday was day 2
local p = joinWith(data)
check("day 3 paid", cash(p) == 3000 and data.daily.streak == 3, cash(p))
check("a bonus spin is waiting", p:GetAttribute("SpinBonus") == 1 and data.spin.bonus == 1)
check("spin ready", p:GetAttribute("SpinReady") == true)
FORCE = 2 -- $1,000
check("first spin (the free daily one)", SpinService.SpinAt(p) == true)
runUntil(clock() + 20)
check("the bonus is still there after the daily spin", data.spin.bonus == 1 and p:GetAttribute("SpinReady") == true, data.spin.bonus)
check("the spin answer counted it", lastFired("SpinResult")[2].Bonus == 1)
FORCE = 6 -- $1,000
check("second spin (the bonus)", SpinService.SpinAt(p) == true)
runUntil(clock() + 20)
check("bonus used", data.spin.bonus == nil and p:GetAttribute("SpinBonus") == nil and p:GetAttribute("SpinReady") == false)
check("both paid", cash(p) == 5000, cash(p))
check("third spin refused", SpinService.SpinAt(p) == false and lastFired("Notify")[2] == "SpinUsed")
check("Spin_Bonus logged", table.find(EVENTS, "Spin_Bonus") ~= nil)
gone(p)
-- A bonus kept for another day: the daily spin is used first, then the bonus.
local data2 = { daily = { last = Daily.Day(1700000000) - 1, streak = 2 } }
local q = joinWith(data2)
gone(q)
toDay(0, 3)
local q2 = joinWith(data2)
check("day 4 the next day: the old bonus is still waiting", data2.spin.bonus == 1 and q2:GetAttribute("SpinBonus") == 1)
check("day 4: 2X XP", math.abs(SpinService.BoostLeft(q2, "XP") - 1800) < 2)'

scenario day_seven_paint_and_week_two '
local data = { daily = { last = Daily.Day(1700000000) - 1, streak = 6 } }
local p = joinWith(data)
local r = lastReward()
check("day 7 pays $7,000", cash(p) == 7000, cash(p))
check("paint unlocked", data.flags.streak7 == true and p:GetAttribute("Unlock_Streak7") == true and r.Unlocked == true)
check("day 7 reward lists the paint", r.Reward.Paint == true and r.Reward.Spins == 1)
check("tomorrow: day 8, $7,000, cash only", r.Next.Cash == 7000 and r.Next.Slot == 1 and not r.Next.Spins and not r.Next.Boost)
gone(p)
data.daily.last -= 0
toDay(0, 2)
p = joinWith(data)
check("day 8: $7,000", cash(p) == 7000 and data.daily.streak == 8)
gone(p)
local d14 = { daily = { last = Daily.Day(1700000000) - 1 + 1, streak = 13 }, flags = { streak7 = true } }
d14.daily.last = Daily.Day(os.time()) - 1
p = joinWith(d14)
r = lastReward()
check("day 14 (slot 7) with the paint owned: spin, no paint", r.Streak == 14 and r.Reward.Spins == 1 and not r.Reward.Paint and not r.Unlocked)'

scenario online_across_midnight '
local data = {}
local p = joinWith(data)
check("day 1 on join", cash(p) == 1000)
runUntil(MIDNIGHT + 45) -- they keep playing past midnight UTC
check("day 2 paid without rejoining", cash(p) == 3000 and data.daily.streak == 2, cash(p))
check("two rewards in all", rewards() == 2, rewards())
runUntil(MIDNIGHT + 400)
check("paid once, not again", rewards() == 2 and cash(p) == 3000)'

scenario waits_for_play '
local data = {}
nextId += 1
local p = newPlayer(nextId) p:SetAttribute("Cash", 0)
join(p) load(p, data) runUntil(clock() + 5)
check("not paid behind the title screen", cash(p) == 0 and rewards() == 0)
p:SetAttribute("HasPicked", true)
runUntil(clock() + 1)
check("paid after PLAY", cash(p) == 1000 and rewards() == 1)'
