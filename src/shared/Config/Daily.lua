-- Daily (ModuleScript, ReplicatedStorage.Shared.Config.Daily)
-- The login streak (DailyService pays it, DailyClient draws the calendar card, PhoneUI's SPIN page shows it).
-- Nov 9 2026, after the first ads: Day 1 retention was 1-4% against an 8% genre median, and 65% of new
-- players were gone within 5 minutes, before they ever heard of the streak, the wheel or the challenges.
-- So the streak became a reason to come back that a player sees in the first session:
--   * The first join of each UTC day (Daily.Day) pays that day's reward: $1,000 x the streak day, up to
--     $7,000 from day 7 on, plus the day's extra below. The cash is unchanged from the first streak (Nov 2).
--   * A 7-day calendar card shows the week: done days ticked, today's reward, and TOMORROW's, with a
--     countdown. Returning players see it when the reward is paid. A brand-new player's first day is
--     quiet while the tutorial runs: the card comes after the tutorial or Daily.TeaseAfter seconds of play.
--   * Days 2-7 add an extra (Extras): a 2X boost (the Lucky Wheel's boosts, play time only) or a bonus spin
--     at the Lucky Wheel (on top of the free daily spin). Day 7 also unlocks the Streak Sunset paint (once).
--     After day 7 the week starts over (day 8 is slot 1, day 9 slot 2...) and the cash stays at $7,000.
--   * Daily.Grace: a streak survives one missed UTC day. The day line is midnight UTC (evening in the
--     Americas), so "came back the next evening" can skip a UTC day; before Nov 9 that reset the streak.
--   * A player still in the game when a new UTC day starts gets the new day's reward then (no rejoin).
-- Nothing here is sold: the streak is free for everyone, so Roblox's paid random item rules don't apply.

local Daily = {}

Daily.PerDay = 1000
Daily.MaxCashDay = 7 -- the cash stops growing here ($7,000)
Daily.Week = 7 -- the calendar's length; the extras repeat after it
Daily.Grace = 1 -- missed UTC days a streak survives (0 = the old rule: miss a day, back to day 1)
Daily.TeaseAfter = 240 -- seconds of play before a brand-new player's first-day card (if the tutorial isn't done)
Daily.CardSeconds = 9 -- how long the calendar card stays up (a tap closes it sooner)

-- The extra on top of the cash, by slot (1-7). Boost = "Cash" | "XP" with Minutes; Spins = bonus spins at
-- the Lucky Wheel; Paint = the Streak Sunset paint (only the first time a player reaches day 7).
Daily.Extras = {
	[1] = nil,
	[2] = { Boost = "Cash", Minutes = 15 },
	[3] = { Spins = 1 },
	[4] = { Boost = "XP", Minutes = 30 },
	[5] = { Spins = 1 },
	[6] = { Boost = "Cash", Minutes = 30 },
	[7] = { Spins = 1, Paint = true },
}

-- The UTC day number (Config.Spin.Day is the same line) and when the next one starts (unix seconds).
function Daily.Day(t)
	return math.floor(t / 86400)
end
function Daily.NextAt(t)
	return (Daily.Day(t) + 1) * 86400
end

-- The streak after a join on UTC day `day`, when the last paid day was `last` with streak `streak`.
-- Returns the new streak, or nil when today is already paid.
function Daily.Advance(last, streak, day)
	if type(last) == "number" and last >= day then
		return nil -- (>= also covers a server clock a little behind)
	end
	if type(last) == "number" and type(streak) == "number" and streak >= 1 and day - last <= 1 + Daily.Grace then
		return streak + 1
	end
	return 1
end

-- The calendar slot (1-7) of a streak day.
function Daily.Slot(streak)
	return (math.max(1, streak) - 1) % Daily.Week + 1
end

-- What streak day `streak` pays: { Cash, Slot, Boost?, Minutes?, Spins?, Paint? }. `hasPaint` = the player
-- already unlocked the paint (then day 7 doesn't offer it again).
function Daily.Reward(streak, hasPaint)
	streak = math.max(1, math.floor(tonumber(streak) or 1))
	local slot = Daily.Slot(streak)
	local r = { Cash = Daily.PerDay * math.min(streak, Daily.MaxCashDay), Slot = slot }
	local extra = Daily.Extras[slot]
	if extra then
		r.Boost, r.Minutes, r.Spins = extra.Boost, extra.Minutes, extra.Spins
		r.Paint = extra.Paint and not hasPaint or nil
	end
	return r
end

local function money(n)
	local s = tostring(math.floor(n))
	return "$" .. s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- The reward in words: "$2,000 + 2X CASH 15 MIN". short = true gives tile lines: "$2,000", "2X CASH".
function Daily.Words(r, short)
	local extra
	if r.Boost then
		extra = "2X " .. string.upper(r.Boost) .. (short and "" or (" " .. tostring(r.Minutes) .. " MIN"))
	elseif r.Spins then
		extra = short and "+SPIN" or (r.Spins == 1 and "BONUS SPIN" or (r.Spins .. " BONUS SPINS"))
	end
	if r.Paint then
		extra = short and "PAINT" or ((extra and (extra .. " + ") or "") .. "STREAK PAINT")
	end
	if short then
		return money(r.Cash), extra or ""
	end
	return money(r.Cash) .. (extra and (" + " .. extra) or "")
end

return Daily
