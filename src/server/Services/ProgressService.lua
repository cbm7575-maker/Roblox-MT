-- ProgressService (ModuleScript, ServerScriptService.Services.ProgressService)
-- XP, ranks and daily challenges (Config.Progression).
--   ProgressService.Event(player, kind, amount)   called by the gameplay services:
--     Heist (tier), Bank (dollars), Escape (stars), RaceFinish (1 = under par), Stunt, Drift (points),
--     TaxiFare, CarBoost, Arrest (stars), SpikeHit, TaserHit, PatrolMinute; and, with no XP of their own,
--     Carjack, ChopSale, BuyCar, Paint, BuyHome, Tune, PropSmash (for the listeners below; Tune's amount =
--     stages bought; PropSmash = one piece of street furniture knocked over with a car, PropService)
--   ProgressService.OnEvent(fn)   fn(player, kind, amount) after every event (JourneyService's goals)
--   Saved: data.xp = { civilian, cop }, data.daily.ch = { day, list = { { id, p, done } } }.
--   Player attributes (for the HUD and perks): CivXP, CivRank, CopXP, CopRank, Title,
--     Unlock_CivRank10, Unlock_CopRank10, Unlock_Rank20, and "Challenges" (JSON for the phone).
--   Remotes to the client: RankUp { Side, Rank, Unlock }, ChallengeDone { Text, Cash, XP }.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local DataService = require(ServerScriptService.Services.DataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local Telemetry = require(ServerScriptService.Services.Telemetry)

local ProgressService = {}

local XP = Progression.XP
local CIV_KINDS = { Heist = true, Bank = true, Escape = true, RaceFinish = true, Stunt = true, Drift = true, TaxiFare = true,
	CarBoost = true, Mission = true }

local rankUp, challengeDone

local function today()
	return math.floor(os.time() / 86400)
end

local function sideKey(side)
	return side == "cop" and "cop" or "civilian"
end

-- Perks and unlock flags that depend on rank.
local function applyRankPerks(player, civRank, copRank)
	player:SetAttribute("CivRank", civRank)
	player:SetAttribute("CopRank", copRank)
	player:SetAttribute("Unlock_CivRank10", civRank >= 10 or nil)
	player:SetAttribute("Unlock_CopRank10", copRank >= 10 or nil)
	player:SetAttribute("Unlock_Rank20", (civRank >= 20 or copRank >= 20) or nil)
	player:SetAttribute("SpikeMax", copRank >= 3 and 3 or 2)
	local title
	if player:GetAttribute("Side") == "Cop" then
		title = copRank >= 15 and Progression.Titles.cop[15] or nil
	else
		title = civRank >= 15 and Progression.Titles.civ[15] or nil
	end
	player:SetAttribute("Title", title)
end

local function refresh(player, data)
	local civ, cop = data.xp.civilian or 0, data.xp.cop or 0
	player:SetAttribute("CivXP", civ)
	player:SetAttribute("CopXP", cop)
	applyRankPerks(player, Progression.RankFor(civ), Progression.RankFor(cop))
end

local function addXP(player, data, side, amount)
	amount = math.floor(amount)
	if amount <= 0 then
		return
	end
	-- 2X XP from the daily spin wheel (SpinService sets BoostXPUntil, in server time).
	local boostUntil = player:GetAttribute("BoostXPUntil")
	if type(boostUntil) == "number" and boostUntil > workspace:GetServerTimeNow() then
		amount *= 2
	end
	local key = sideKey(side)
	local before = Progression.RankFor(data.xp[key] or 0)
	data.xp[key] = (data.xp[key] or 0) + amount
	local after = Progression.RankFor(data.xp[key])
	refresh(player, data)
	if after > before then
		local unlocks = Progression.Unlocks[side == "cop" and "cop" or "civ"]
		for r = before + 1, after do
			rankUp:FireClient(player, { Side = side == "cop" and "Cop" or "Civilian", Rank = r, Unlock = unlocks[r] })
		end
		Telemetry.Custom(player, (side == "cop" and "CopRank" or "CivRank") .. "_" .. after, after)
	end
end

-- Today's challenges (3 per player per day: 2 free roam + 1 police, picked from the pool).
local function challenges(player, data)
	data.daily = data.daily or {}
	local ch = data.daily.ch
	local day = today()
	if not ch or (ch.day or 0) < day then -- "<" so a server clock a little behind never rebuilds today's list
		local rng = Random.new(player.UserId * 31 + day)
		local civ, cop = {}, {}
		for _, c in ipairs(Progression.Challenges) do
			table.insert(c.Side == "Cop" and cop or civ, c.Id)
		end
		local function take(list)
			return table.remove(list, rng:NextInteger(1, #list))
		end
		ch = { day = day, list = {} }
		for _, id in ipairs({ take(civ), take(civ), take(cop) }) do
			table.insert(ch.list, { id = id, p = 0, done = false })
		end
		data.daily.ch = ch
	end
	return ch
end

local function publishChallenges(player, ch)
	player:SetAttribute("Challenges", HttpService:JSONEncode(ch.list))
end

local BYID = {}
for _, c in ipairs(Progression.Challenges) do
	BYID[c.Id] = c
end

local function progressChallenges(player, data, kind, amount)
	local ch = challenges(player, data)
	local changed = false
	for _, entry in ipairs(ch.list) do
		local def = BYID[entry.id]
		if def and not entry.done and def.Kind == kind then
			entry.p = math.min(def.Goal, entry.p + amount)
			changed = true
			if entry.p >= def.Goal then
				entry.done = true
				local reward = Progression.ChallengeReward
				EconomyService.AddCash(player, reward.Cash, "challenge:" .. def.Id)
				addXP(player, data, def.Side == "Cop" and "cop" or "civ", reward.XP)
				challengeDone:FireClient(player, { Text = def.Text, Cash = reward.Cash, XP = reward.XP })
				Telemetry.Custom(player, "Challenge_" .. def.Id, 1)
			end
		end
	end
	if changed then
		publishChallenges(player, ch)
	end
end

local eventListeners = {}
function ProgressService.OnEvent(fn)
	table.insert(eventListeners, fn)
end

function ProgressService.Event(player, kind, amount)
	amount = amount or 1
	local data = DataService.Get(player)
	if not data then
		return
	end
	data.xp = data.xp or {}
	local side = CIV_KINDS[kind] and "civ" or "cop"
	local xp = 0
	if kind == "Heist" then
		xp = XP.Heist * math.max(amount, 1)
		progressChallenges(player, data, "Heist", 1)
	elseif kind == "Bank" then
		xp = XP.Bank * math.floor(amount / 250)
		if amount >= 5000 then
			progressChallenges(player, data, "BankBig", 1)
		end
	elseif kind == "Escape" then
		xp = XP.Escape * math.max(amount, 1)
		if amount >= 2 then
			progressChallenges(player, data, "EscapeBig", 1)
		end
	elseif kind == "RaceFinish" then
		xp = XP.RaceFinish + (amount == 1 and XP.RaceUnderPar or 0)
		if amount == 1 then
			progressChallenges(player, data, "RaceUnderPar", 1)
		end
	elseif kind == "Stunt" then
		xp = XP.Stunt
		progressChallenges(player, data, "Stunt", 1)
	elseif kind == "Drift" then
		xp = XP.Drift * math.floor(amount / 250)
		progressChallenges(player, data, "DriftPoints", amount)
	elseif kind == "TaxiFare" then
		xp = XP.TaxiFare
		progressChallenges(player, data, "TaxiFare", 1)
	elseif kind == "CarBoost" then
		xp = XP.CarBoost
		progressChallenges(player, data, "CarBoost", 1)
	elseif kind == "Arrest" then
		xp = XP.Arrest + XP.ArrestPerStar * amount
		progressChallenges(player, data, "Arrest", 1)
		if amount >= 3 then
			progressChallenges(player, data, "ArrestBig", 1)
		end
	elseif kind == "SpikeHit" then
		xp = XP.SpikeHit
		progressChallenges(player, data, "SpikeHit", 1)
	elseif kind == "TaserHit" then
		xp = XP.TaserHit
		progressChallenges(player, data, "TaserHit", 1)
	elseif kind == "Mission" then
		xp = amount -- missions pass their XP directly
	elseif kind == "FloridaMoment" then
		xp = 30
		side = player:GetAttribute("Side") == "Cop" and "cop" or "civ"
	elseif kind == "PatrolMinute" then
		xp = XP.PatrolMinute
		progressChallenges(player, data, "PatrolMinute", 1)
	end
	addXP(player, data, side, xp)
	-- Own threads: a listener's error never reaches the service that reported the event.
	for _, fn in ipairs(eventListeners) do
		task.spawn(fn, player, kind, amount)
	end
end

function ProgressService.Init()
	rankUp = Remotes.Event("RankUp")
	challengeDone = Remotes.Event("ChallengeDone")
	EconomyService.OnBanked(function(player, amount)
		ProgressService.Event(player, "Bank", amount)
	end)
	DataService.OnLoaded(function(player, data)
		data.xp = data.xp or {}
		refresh(player, data)
		publishChallenges(player, challenges(player, data))
		-- Titles follow the side you're playing.
		player:GetAttributeChangedSignal("Side"):Connect(function()
			refresh(player, data)
		end)
	end)
	-- A new day rolls the challenges over for players who stay online past midnight UTC.
	task.spawn(function()
		local lastDay = today()
		while true do
			task.wait(60)
			if today() ~= lastDay then
				lastDay = today()
				for _, p in ipairs(Players:GetPlayers()) do
					local data = DataService.Get(p)
					if data then
						publishChallenges(p, challenges(p, data))
					end
				end
			end
		end
	end)
end

return ProgressService
