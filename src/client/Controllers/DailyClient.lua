-- DailyClient (ModuleScript, StarterPlayerScripts.Controllers.DailyClient)
-- The login streak's calendar card (Config.Daily; DailyService pays the rewards). The card is a dark panel
-- in the upper middle of the screen (the Stamp zone's spot), ScreenGui "DailyCard" (DisplayOrder 4: over
-- the HUD, under the phone):
--   LOGIN STREAK                       (gold kicker)
--   DAY 3   +$3,000 + BONUS SPIN       (today's reward; "TOMORROW" on a first day's card)
--   [DAY 1 ✓][DAY 2 ✓][DAY 3 TODAY][DAY 4 TOMORROW][DAY 5][DAY 6][DAY 7]   (this week: cash and extra)
--   Come back tomorrow for $4,000 + 2X XP 30 MIN  ·  in 21h 14m
-- It stays Daily.CardSeconds, and a tap anywhere on it closes it sooner. When it shows:
--   * A returning player: when the server pays the day's reward (DailyReward), after any stamp on screen.
--   * A brand-new player's first day: not while the tutorial runs (that's where new players get lost).
--     Once the tutorial is done, or after Daily.TeaseAfter seconds of play, and never while wanted or over
--     another stamp. Its title is about TOMORROW: the whole point is a reason to come back.
--   * PHONE > SPIN's "SEE THE WEEK" button (DailyClient.ShowCard).
-- Reads player attributes Streak, StreakNextAt, Unlock_Streak7 (DailyService), TutorialStep, Heat,
-- TitleScreen. Telemetry is the server's (Streak_Day); this only draws.
-- API: DailyClient.ShowCard(), DailyClient.Status() -> { Streak, NextAt, NextIn, Next = tomorrow's reward,
--   Today = today's reward } (Streak nil until today's reward is paid).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Daily = require(ReplicatedStorage.Shared.Config.Daily)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local Theme = require(ReplicatedStorage.Shared.Util.Theme)
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local NotifyController = require(script.Parent:WaitForChild("NotifyController"))

local player = Players.LocalPlayer
local C = Theme.Color

local DailyClient = {}

local K = {
	WIDTH = 580, -- the card's widest (pixels; less on a narrow screen)
	TILE_GAP = 6,
	ORDER = 4, -- ScreenGui DisplayOrder (see the header)
	CHECK = 2, -- seconds between checks while a first-day card waits for its moment
}

local S = {
	last = nil, -- the last DailyReward payload
	joinedAt = os.clock(),
	firstWaiting = false, -- a first-day card waits for the tutorial (or TeaseAfter)
	shownFirst = false,
	gui = nil, card = nil, closeAt = 0, serial = 0,
}

local function money(n)
	return HUDController.Money and HUDController.Money(n) or ("$" .. tostring(n))
end

local function serverNow()
	return Workspace:GetServerTimeNow()
end

local function untilText(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local h, m = seconds // 3600, (seconds % 3600) // 60
	return h > 0 and (h .. "h " .. m .. "m") or (math.max(m, 1) .. "m")
end

local function hasPaint()
	return player:GetAttribute("Unlock_Streak7") == true
end

-- Streak day `dayN`'s reward as the card shows it, with `streak` = today's day. The paint is on day 7
-- unless the player had it before: once unlocked, only a day 7 of the current run (already reached) shows it.
local function rewardOf(dayN, streak)
	local owned = hasPaint() and not (dayN == Daily.Week and streak >= Daily.Week)
	return Daily.Reward(dayN, owned)
end

function DailyClient.Status()
	local streak = player:GetAttribute("Streak")
	local nextAt = player:GetAttribute("StreakNextAt")
	streak = type(streak) == "number" and streak or nil
	return {
		Streak = streak,
		NextAt = type(nextAt) == "number" and nextAt or nil,
		NextIn = type(nextAt) == "number" and math.max(0, nextAt - serverNow()) or nil,
		Today = streak and rewardOf(streak, streak) or nil,
		Next = Daily.Reward((streak or 0) + 1, hasPaint()),
	}
end

------------------------------------------------------------------ the card

local function label(parent, name, text, font, size, color, pos, dims, align)
	local l = Instance.new("TextLabel")
	l.Name = name
	Theme.Text(l, size, "Body")
	l.FontFace = font
	l.TextColor3 = color or C.Text
	l.Text = text
	l.Position = pos
	l.Size = dims
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	-- Shrinks to fit (a phone's narrow card), never past `size`.
	l.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = size
	fit.MinTextSize = 8
	fit.Parent = l
	l.Parent = parent
	return l
end

local function close(serial)
	if not S.card or (serial and serial ~= S.serial) then
		return
	end
	local card = S.card
	S.card = nil
	local t = TweenService:Create(card, TweenInfo.new(0.25), { GroupTransparency = 1 })
	t:Play()
	t.Completed:Connect(function()
		card:Destroy()
	end)
end

local function screenWidth()
	local cam = Workspace.CurrentCamera
	return cam and cam.ViewportSize.X or 1000
end

-- Draws the card for `streak` (today's day, already paid) or, with `teaser`, a first-day card about tomorrow.
local function draw(streak, nextAt, teaser, broke)
	if not S.gui then
		local sg = Instance.new("ScreenGui")
		sg.Name = "DailyCard"
		sg.ResetOnSpawn = false
		sg.IgnoreGuiInset = true
		sg.DisplayOrder = K.ORDER
		sg.Parent = player:WaitForChild("PlayerGui")
		S.gui = sg
	end
	if S.card then
		S.card:Destroy()
		S.card = nil
	end
	S.serial += 1
	local serial = S.serial
	local touch = Theme.IsTouch()
	local width = math.min(K.WIDTH, math.floor(screenWidth() * 0.94))
	local tileW = math.floor((width - 20 - K.TILE_GAP * (Daily.Week - 1)) / Daily.Week)
	local small = tileW < 70
	local tileH = small and 58 or 66
	local height = 12 + 16 + 34 + 8 + tileH + 8 + 20 + 12

	local card = Instance.new("CanvasGroup")
	card.Name = "Card"
	Theme.Panel(card, 0.18)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.new(0.5, 0, touch and 0.36 or 0.3, 0)
	card.Size = UDim2.fromOffset(width, height)
	card.GroupTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.Gold
	stroke.Transparency = 0.55
	stroke.Thickness = 1
	stroke.Parent = card

	local today = rewardOf(streak, streak)
	local tomorrow = Daily.Reward(streak + 1, hasPaint())
	local y = 12
	local kicker = "LOGIN STREAK"
	if broke then
		kicker = "YOUR " .. broke .. "-DAY STREAK ENDED  ·  NEW STREAK"
	elseif teaser then
		kicker = "LOGIN STREAK  ·  DAY 1 PAID: +" .. money(today.Cash)
	end
	label(card, "Kicker", kicker, Theme.Font.Bold, 12, broke and C.Dim or C.Gold, UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, 16))
	y += 16
	local t = label(card, "Title", "", Theme.Font.Display, small and 24 or 28, C.Text, UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, 34))
	t.RichText = true
	if teaser then
		t.Text = "COME BACK TOMORROW"
	else
		t.Text = "DAY " .. streak .. '   <font color="#' .. C.Cash:ToHex() .. '">+' .. Daily.Words(today) .. "</font>"
	end
	y += 34 + 8

	-- This week's 7 days: day (streak - slot + 1) is the week's first.
	local slot = Daily.Slot(streak)
	local first = streak - slot + 1
	for i = 1, Daily.Week do
		local dayN = first + i - 1
		local r = rewardOf(dayN, streak)
		local state = dayN < streak and "done" or dayN == streak and "today" or dayN == streak + 1 and "next" or "later"
		local tile = Instance.new("Frame")
		tile.Name = "Day" .. i
		tile.Position = UDim2.fromOffset(10 + (i - 1) * (tileW + K.TILE_GAP), y)
		tile.Size = UDim2.fromOffset(tileW, tileH)
		tile.BorderSizePixel = 0
		tile.BackgroundColor3 = state == "today" and C.Gold or state == "next" and C.PanelLight or C.Panel
		tile.BackgroundTransparency = state == "today" and 0.1 or state == "next" and 0.05 or 0.35
		Theme.Corners(tile, 4)
		if state == "next" then
			local s = Instance.new("UIStroke")
			s.Color = C.Brand
			s.Thickness = 2
			s.Parent = tile
		end
		tile.Parent = card
		local ink = state == "today" and Theme.Ink or (state == "done" and C.Dim or C.Text)
		local head = state == "today" and (teaser and "TODAY ✓" or "TODAY") or state == "next" and "TOMORROW"
			or state == "done" and ("DAY " .. dayN .. " ✓") or ("DAY " .. dayN)
		local h = label(tile, "Head", head, Theme.Font.Bold, small and 9 or 10, state == "next" and C.Brand or ink,
			UDim2.fromOffset(2, 4), UDim2.new(1, -4, 0, 12))
		if state == "today" then
			h.TextStrokeTransparency = 1
		end
		local cashText, extraText = Daily.Words(r, true)
		local c = label(tile, "Cash", cashText, Theme.Font.Display, small and 15 or 18, state == "today" and Theme.Ink or (state == "done" and C.Dim or C.Cash),
			UDim2.fromOffset(2, 18), UDim2.new(1, -4, 0, small and 20 or 24))
		local e = label(tile, "Extra", extraText, Theme.Font.Bold, small and 9 or 11, state == "today" and Theme.Ink or (state == "done" and C.Dim or C.Gold),
			UDim2.fromOffset(2, small and 38 or 44), UDim2.new(1, -4, 0, 14))
		if state == "today" then
			for _, l in ipairs({ c, e }) do
				local sh = l:FindFirstChild("Shadow")
				if sh then
					sh.Enabled = false
				end
			end
			local sh = h:FindFirstChild("Shadow")
			if sh then
				sh.Enabled = false
			end
		end
	end
	y += tileH + 8

	local foot = label(card, "Foot", "", Theme.Font.Body, small and 12 or 13, C.Dim, UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, 20))
	local function footText()
		local left = nextAt and (nextAt - serverNow()) or nil
		local when = left and left > 0 and ("  ·  unlocks in " .. untilText(left)) or ""
		if teaser then
			return "Tomorrow: +" .. Daily.Words(tomorrow) .. when .. "  ·  7 days in a row = Streak Sunset paint"
		end
		return "Come back tomorrow for +" .. Daily.Words(tomorrow) .. when
	end
	foot.Text = footText()

	-- A tap anywhere on the card closes it.
	local tap = Instance.new("TextButton")
	tap.Name = "Close"
	tap.BackgroundTransparency = 1
	tap.Text = ""
	tap.Size = UDim2.fromScale(1, 1)
	tap.ZIndex = 5
	tap.Parent = card
	tap.Activated:Connect(function()
		close(serial)
	end)

	card.Parent = S.gui
	S.card = card
	TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()
	task.spawn(function()
		local untilT = os.clock() + Daily.CardSeconds
		while S.card == card and os.clock() < untilT do
			task.wait(1)
			if foot.Parent then
				foot.Text = footText()
			end
		end
		close(serial)
	end)
end

-- Waits (up to ~20 s) for a free moment: no stamp or intro on screen, not on the title screen.
local function whenClear(fn)
	task.spawn(function()
		for _ = 1, 80 do
			local busy = player:GetAttribute("TitleScreen") == true
				or (HUDController.StampTop and HUDController.StampTop() ~= nil)
				or (HUDController.IntroUp and HUDController.IntroUp())
			if not busy then
				break
			end
			task.wait(0.25)
		end
		local ok, err = pcall(fn)
		if not ok then
			warn("[DailyClient] card: " .. tostring(err))
		end
	end)
end

function DailyClient.ShowCard()
	local st = DailyClient.Status()
	if not st.Streak then
		NotifyController.Show("Your login streak reward is on its way...", C.Gold, "info")
		return
	end
	whenClear(function()
		draw(st.Streak, st.NextAt, false, nil)
	end)
end

------------------------------------------------------------------ a first day: after the tutorial

local function tutorialDone()
	local step = player:GetAttribute("TutorialStep")
	return type(step) == "number" and step >= #Tutorial.Steps
end

local function firstDayCheck()
	if not S.firstWaiting or S.shownFirst then
		return
	end
	if not (tutorialDone() or os.clock() - S.joinedAt >= Daily.TeaseAfter) then
		return
	end
	if (tonumber(player:GetAttribute("Heat")) or 0) > 0 or player:GetAttribute("TitleScreen") == true then
		return
	end
	if (HUDController.StampTop and HUDController.StampTop() ~= nil) or (HUDController.IntroUp and HUDController.IntroUp()) then
		return
	end
	S.firstWaiting = false
	S.shownFirst = true
	local r = S.last
	draw(1, r and r.NextAt or player:GetAttribute("StreakNextAt"), true, nil)
end

local function onReward(r)
	if type(r) ~= "table" then
		return
	end
	S.last = r
	local streak = tonumber(r.Streak) or 1
	-- A brand-new player mid-tutorial: just the cash for now (a toast), the card comes later.
	if r.First and not tutorialDone() then
		S.firstWaiting = true
		task.delay(1.5, function()
			NotifyController.Show("Daily login reward: +" .. money(r.Reward and r.Reward.Cash or Daily.PerDay)
				.. ". Come back tomorrow for more!", C.Gold, "success")
		end)
		return
	end
	task.wait(1.5)
	whenClear(function()
		draw(streak, r.NextAt, r.First == true, tonumber(r.Broke))
	end)
	if r.Unlocked then
		task.delay(Daily.CardSeconds + 1, function()
			NotifyController.Show("7-day streak! Streak Sunset paint unlocked in your Garage.", C.Gold, "success")
		end)
	end
end

function DailyClient.Init()
	Remotes.OnClient("DailyReward", function(r)
		task.spawn(onReward, r)
	end)
	task.spawn(function()
		while true do
			task.wait(K.CHECK)
			local ok, err = pcall(firstDayCheck)
			if not ok then
				warn("[DailyClient] " .. tostring(err))
			end
		end
	end)
end

return DailyClient
