-- ShopClient (ModuleScript, StarterPlayerScripts.Controllers.ShopClient)
-- Purchase moments (pass unlocked, cash pack delivered), the [VIP] chat tag
-- for any player with the VIP pass (TextChatService prefix, local display only), and a one-time toast
-- when the shop is free for you (player attribute "ShopFree" = "Studio" | "Owner", set by ShopService:
-- Studio tests, and the game's owner in a live server). It builds no screens
-- of its own: the moments are HUDController stamps and toasts, in the Theme's colours (gold = a reward
-- or unlock, green = cash), and the chat tags use the same two (gold [VIP], quiet grey rank title).
-- The SHOP page itself lives in the phone (PhoneUI).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local Theme = require(ReplicatedStorage.Shared.Util.Theme)
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local NotifyController = require(script.Parent:WaitForChild("NotifyController"))

local player = Players.LocalPlayer

local ShopClient = {}

local C = Theme.Color
local VIP_HEX = "#" .. C.Gold:ToHex()
local TITLE_HEX = "#" .. C.Dim:ToHex()
local told = false -- the free-shop toast has been shown (once a session)

-- Tell a tester / the owner once that PHONE > SHOP is free for them (after the join stamps and toasts).
local function freeNote()
	local free = player:GetAttribute("ShopFree")
	if told or (free ~= "Studio" and free ~= "Owner") then
		return
	end
	told = true
	task.delay(8, function()
		NotifyController.Show(free == "Owner" and "Your game: every pass is on, and cash packs are free in PHONE > SHOP."
			or "Studio test: everything in PHONE > SHOP is free and instant.", C.Gold, "info")
	end)
end

function ShopClient.Init()
	player:GetAttributeChangedSignal("ShopFree"):Connect(freeNote)
	freeNote()
	Remotes.OnClient("PassGranted", function(key)
		for _, pass in ipairs(Shop.Passes) do
			if pass.Key == key then
				HUDController.Stamp(string.upper(pass.Name) .. " UNLOCKED", pass.Perk, C.Gold)
			end
		end
	end)
	Remotes.OnClient("CashPackGranted", function(cash)
		HUDController.Stamp("CASH DELIVERED", "+" .. HUDController.Money(cash), C.Cash)
	end)
	-- (The daily streak reward's card moved to DailyClient, Nov 9 2026.)
	TextChatService.OnIncomingMessage = function(message)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local sender = source and Players:GetPlayerByUserId(source.UserId)
		local prefix = message.PrefixText
		if sender and sender:GetAttribute("Title") then
			prefix = '<font color="' .. TITLE_HEX .. '">[' .. sender:GetAttribute("Title") .. ']</font> ' .. prefix
		end
		if sender and sender:GetAttribute("Pass_VIP") then
			prefix = '<font color="' .. VIP_HEX .. '">[VIP]</font> ' .. prefix
		end
		props.PrefixText = prefix
		return props
	end
end

return ShopClient
