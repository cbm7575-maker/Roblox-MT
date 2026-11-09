-- Telemetry (ModuleScript, ServerScriptService.Services.Telemetry)
-- Roblox Analytics (Creator Hub > Analytics) in one place. Every call is pcall-wrapped: analytics
-- must never break gameplay.
--   Telemetry.Economy(player, amount, balance, reason)  cash in (+) or out (-), from EconomyService
--   Telemetry.Funnel(player, step, name)                 onboarding funnel (first session)
--   Telemetry.FunnelStep(player, funnel, session, step, name)  a recurring funnel's step (its own chart
--                                                        under Analytics > Funnels, one run per session id)
--   Telemetry.Custom(player, name, value)                gameplay events (heists, arrests, escapes...)
-- Economy transaction types come from the reason prefix (see TYPES).
-- Roblox keeps 100 custom event names per experience and groups economy item SKUs past 100 as
-- "Other", so ids never go into a name: "CivRank_5" is logged as event "CivRank" with "5" in custom
-- field 1, and "tune:Palmetto:Engine2" as item "tune" with "Palmetto:Engine2" in custom field 1.

local AnalyticsService = game:GetService("AnalyticsService")

local Telemetry = {}

-- Custom field 1 for an id (customFields is keyed by the enum item's name).
local function field(value)
	local ok, name = pcall(function()
		return Enum.AnalyticsCustomFieldKeys.CustomField01.Name
	end)
	return { [ok and name or "CustomField01"] = value }
end

-- Transaction type names (looked up safely: a renamed enum item must not break the economy).
local function kind(name)
	local ok, value = pcall(function()
		return Enum.AnalyticsEconomyTransactionType[name].Name
	end)
	return ok and value or name
end
local GAMEPLAY = kind("Gameplay")
local TYPES = { -- reason prefix -> transaction type
	product = kind("IAP"),
	buycar = kind("Shop"),
	paint = kind("Shop"),
	rims = kind("Shop"),
	underglow = kind("Shop"),
	tutorial = kind("Onboarding"),
	daily = kind("TimedReward"),
	spin = kind("TimedReward"), -- the daily spin wheel's cash (SpinService)
}

function Telemetry.Economy(player, amount, balance, reason)
	reason = tostring(reason or "other")
	if reason == "debug" or amount == 0 then
		return
	end
	local prefix, item = reason:match("^([^:]+):?(.*)$")
	local transaction = TYPES[prefix] or GAMEPLAY
	pcall(function()
		AnalyticsService:LogEconomyEvent(player,
			amount > 0 and Enum.AnalyticsEconomyFlowType.Source or Enum.AnalyticsEconomyFlowType.Sink,
			"Cash", math.abs(amount), balance, transaction, prefix, item ~= "" and field(item) or nil)
	end)
end

function Telemetry.Funnel(player, step, name)
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function Telemetry.FunnelStep(player, funnel, session, step, name)
	pcall(function()
		AnalyticsService:LogFunnelStepEvent(player, funnel, session, step, name)
	end)
end

function Telemetry.Custom(player, name, value)
	local base, id = tostring(name):match("^([^_]+)_(.+)$")
	pcall(function()
		if base then
			AnalyticsService:LogCustomEvent(player, base, value or 1, field(id))
		else
			AnalyticsService:LogCustomEvent(player, name, value or 1)
		end
	end)
end

return Telemetry
