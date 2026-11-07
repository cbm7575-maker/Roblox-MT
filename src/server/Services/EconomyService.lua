-- EconomyService (ModuleScript, ServerScriptService.Services.EconomyService)
-- The only place a player's money changes. Two amounts per player:
--   Cash    - banked money (safe; saved from step 4.1)
--   Carried - money in the robber's bag (lost on arrest, banked at a hideout)
-- Both live as player attributes (clients read them for the HUD) and Cash also shows on the leaderboard.
-- Every change carries a reason string for analytics (step 4.7).
-- 2X CASH (the daily spin wheel, Config.Spin): while the player attribute BoostCashUntil is ahead of the
-- server clock, AddCash pays the same again for reasons in Spin.DoubleCash, and BankCarried pays the
-- banked bag again. The extra is its own "spinboost:<reason>" cash (never doubled itself), and the client
-- hears of it through the BoostPaid remote (SpinClient's "2X CASH +$500" pop). AddCash still returns the
-- amount asked for, so callers that show their own pay see what they expect.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Heists = require(ReplicatedStorage.Shared.Config.Heists)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Spin = require(ReplicatedStorage.Shared.Config.Spin)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)

local EconomyService = {}

local log = {} -- recent changes (tests and later analytics)

local Telemetry = require(script.Parent.Telemetry)

local function record(player, kind, amount, reason)
	table.insert(log, { player.UserId, kind, amount, reason, os.clock() })
	if #log > 200 then
		table.remove(log, 1)
	end
	if kind == "cash+" or kind == "cash-" then
		Telemetry.Economy(player, kind == "cash+" and amount or -amount, player:GetAttribute("Cash") or 0, reason)
	end
end

function EconomyService.GetCash(player)
	return player:GetAttribute("Cash") or 0
end

function EconomyService.GetCarried(player)
	return player:GetAttribute("Carried") or 0
end

-- A whole, finite number of dollars, or nil (NaN and infinity would stick in the save forever).
local function dollars(amount)
	if type(amount) == "number" and amount == amount and math.abs(amount) ~= math.huge then
		return math.floor(amount)
	end
	return nil
end

local function setCash(player, value)
	player:SetAttribute("Cash", value)
	local ls = player:FindFirstChild("leaderstats")
	local c = ls and ls:FindFirstChild("Cash")
	if c then
		c.Value = value
	end
end

-- Loading a save (DataService): set cash directly, no reason logged.
function EconomyService.SetCash(player, value)
	setCash(player, math.max(0, dollars(value) or 0))
end

-- 2X CASH is on for this player (the spin wheel's boost).
local function boosted(player)
	local untilT = player:GetAttribute("BoostCashUntil")
	return type(untilT) == "number" and untilT > Workspace:GetServerTimeNow()
end

-- Pay the 2X CASH extra: `amount` again, as "spinboost:<what>".
local function payBoost(player, amount, what)
	setCash(player, EconomyService.GetCash(player) + amount)
	record(player, "cash+", amount, "spinboost:" .. what)
	pcall(function()
		Remotes.Event("BoostPaid"):FireClient(player, amount)
	end)
end

function EconomyService.AddCash(player, amount, reason)
	amount = dollars(amount)
	if not amount or amount <= 0 then
		return 0
	end
	setCash(player, EconomyService.GetCash(player) + amount)
	record(player, "cash+", amount, reason)
	local prefix = string.match(tostring(reason), "^([^:]+)")
	if prefix and Spin.DoubleCash[prefix] and boosted(player) then
		payBoost(player, amount, prefix)
	end
	return amount
end

-- Returns true if the player had enough and it was spent.
function EconomyService.Spend(player, amount, reason)
	amount = dollars(amount)
	if not amount or amount < 0 or EconomyService.GetCash(player) < amount then
		return false
	end
	setCash(player, EconomyService.GetCash(player) - amount)
	record(player, "cash-", amount, reason)
	return true
end

-- The bag's size: Heists.CarryLimit, +50% with the Big Duffel Bag pass.
function EconomyService.CarryLimit(player)
	local bonus = player:GetAttribute("Pass_BigDuffel") and Shop.DuffelCarryBonus or 0
	return math.floor(Heists.CarryLimit * (1 + bonus))
end

-- Put money in the bag, up to the carry limit. Returns how much actually fit.
function EconomyService.AddCarried(player, amount, reason)
	local whole = dollars(amount)
	if not whole then
		return 0
	end
	if whole <= 0 then
		return 0 -- (a negative amount would also make the clamp below throw)
	end
	local current = EconomyService.GetCarried(player)
	local fits = math.clamp(EconomyService.CarryLimit(player) - current, 0, whole)
	player:SetAttribute("Carried", current + fits)
	record(player, "bag+", fits, reason)
	return fits
end

-- Empty the bag. Returns what was in it.
function EconomyService.TakeCarried(player, reason)
	local amount = EconomyService.GetCarried(player)
	player:SetAttribute("Carried", 0)
	if amount > 0 then
		record(player, "bag-", amount, reason)
	end
	return amount
end

-- Callbacks run after a bag is banked: fn(player, amount). (TutorialService, challenges, analytics.)
local bankedListeners = {}
function EconomyService.OnBanked(fn)
	table.insert(bankedListeners, fn)
end

-- Bank the whole bag into Cash. Returns the amount banked.
function EconomyService.BankCarried(player, reason)
	local amount = EconomyService.TakeCarried(player, reason)
	if amount > 0 then
		EconomyService.AddCash(player, amount, reason)
		if boosted(player) then
			payBoost(player, amount, "bank") -- (bag money isn't in Spin.DoubleCash: it's doubled here, once)
		end
		Telemetry.Custom(player, "Banked", amount)
		for _, fn in ipairs(bankedListeners) do
			task.spawn(fn, player, amount)
		end
	end
	return amount
end

EconomyService.Log = log

function EconomyService.Init()
	local function onPlayer(player)
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Parent = ls
		ls.Parent = player
		-- Saving arrives in step 4.1; until then everyone starts at $0 each session.
		setCash(player, player:GetAttribute("Cash") or 0)
		player:SetAttribute("Carried", 0)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		if not p:FindFirstChild("leaderstats") then
			onPlayer(p)
		end
	end
end

return EconomyService
