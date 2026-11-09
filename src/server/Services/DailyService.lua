-- DailyService (ModuleScript, ServerScriptService.Services.DailyService)
-- The login streak (Config.Daily; first built for the PRD's "Daily reasons to come back", reworked Nov 9
-- 2026 into the 7-day calendar). The first join of each UTC day pays that streak day's reward: $1,000 x the
-- day up to $7,000, plus the day's extra (a 2X boost or a bonus spin at the Lucky Wheel, through
-- SpinService). Reaching day 7 unlocks the streak-only paint (player attribute "Unlock_Streak7", saved in
-- data.flags.streak7). A streak survives Daily.Grace missed UTC days; after that it starts over at day 1.
-- A player who is still in the game when a new UTC day starts is paid then (checked every DAY_CHECK s).
-- Saved in data.daily = { last = day number paid, streak = n, n = days paid in all, best = longest streak }.
-- Player attributes: Streak (today's streak day, once paid), StreakNextAt (unix seconds: when the next
-- day's reward can be had).
-- Remote DailyReward (server -> client): { Streak, Reward = Config.Daily.Reward(...), Next = tomorrow's
-- reward, NextAt, Unlocked = the paint was just unlocked, First = this is the player's first day ever,
-- Broke = the streak that just ended (more than one missed day), or nil }. DailyClient draws the card.
-- Telemetry: Streak_Day (value = the streak day), Streak_Broke (value = the streak lost), and the cash as
-- the "daily:day<n>" economy event (n = 1-7, as before).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Daily = require(ReplicatedStorage.Shared.Config.Daily)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local DataService = require(ServerScriptService.Services.DataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local Telemetry = require(ServerScriptService.Services.Telemetry)

local DailyService = {}

local DAY_CHECK = 30 -- seconds between checks for players online across midnight UTC
local PICK_WAIT = 60 -- seconds a fresh join waits for PLAY (HasPicked) before being paid anyway

local reward -- the DailyReward remote
local ready = {} -- [player] = true once the join wait is over (the day check only pays these)

-- (Started after this one: looked up when used.)
local function spinService()
	local ok, s = pcall(require, ServerScriptService.Services.SpinService)
	return ok and type(s) == "table" and s or nil
end

local function today()
	return Daily.Day(os.time())
end

local function publish(player, data)
	player:SetAttribute("Streak", tonumber(data.daily.streak) or 1)
	player:SetAttribute("StreakNextAt", Daily.NextAt(os.time()))
end

-- Pays today's reward if it isn't paid yet. Returns true if it paid.
function DailyService.PayToday(player, data)
	data.daily = type(data.daily) == "table" and data.daily or {}
	data.flags = type(data.flags) == "table" and data.flags or {}
	local d = data.daily
	local day = today()
	local streak = Daily.Advance(d.last, d.streak, day)
	if not streak then
		publish(player, data)
		return false
	end
	local first = d.last == nil
	local broke = (streak == 1 and not first and (tonumber(d.streak) or 0) > 1) and math.floor(tonumber(d.streak)) or nil
	d.last = day
	d.streak = streak
	d.n = (tonumber(d.n) or 0) + 1
	d.best = math.max(tonumber(d.best) or 0, streak)
	publish(player, data)

	local r = Daily.Reward(streak, data.flags.streak7 == true)
	EconomyService.AddCash(player, r.Cash, "daily:day" .. math.min(streak, Daily.MaxCashDay))
	local spin = spinService()
	if r.Boost and spin and spin.GrantBoost then
		spin.GrantBoost(player, data, r.Boost, r.Minutes)
	end
	if r.Spins and spin and spin.AddBonusSpins then
		spin.AddBonusSpins(player, data, r.Spins)
	end
	local unlocked = false
	if streak >= Daily.Week and not data.flags.streak7 then
		data.flags.streak7 = true
		player:SetAttribute("Unlock_Streak7", true)
		unlocked = true
	end
	Telemetry.Custom(player, "Streak_Day", streak)
	if broke then
		Telemetry.Custom(player, "Streak_Broke", broke)
	end
	task.spawn(DataService.SaveNow, player)
	reward:FireClient(player, {
		Streak = streak, Reward = r, Next = Daily.Reward(streak + 1, data.flags.streak7 == true),
		NextAt = Daily.NextAt(os.time()), Unlocked = unlocked, First = first, Broke = broke,
	})
	return true
end

function DailyService.Init()
	reward = Remotes.Event("DailyReward")
	DataService.OnLoaded(function(player, data)
		data.flags = type(data.flags) == "table" and data.flags or {}
		if data.flags.streak7 then
			player:SetAttribute("Unlock_Streak7", true)
		end
		-- Wait until they've pressed PLAY (HasPicked) so the reward isn't hidden behind the title screen.
		for _ = 1, PICK_WAIT * 2 do
			if player:GetAttribute("HasPicked") or player.Parent ~= Players then
				break
			end
			task.wait(0.5)
		end
		if player.Parent == Players and DataService.Get(player) == data then
			ready[player] = true
			DailyService.PayToday(player, data)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
	end)
	-- Midnight UTC while they play: the new day's reward, without rejoining.
	task.spawn(function()
		while true do
			task.wait(DAY_CHECK)
			local day = today()
			for player in pairs(ready) do
				local data = player.Parent == Players and DataService.Get(player)
				local d = data and type(data.daily) == "table" and data.daily
				if d and (tonumber(d.last) or -1) < day then
					local ok, err = pcall(DailyService.PayToday, player, data)
					if not ok then
						warn("[DailyService] day check: " .. tostring(err))
					end
				end
			end
		end
	end)
end

return DailyService
