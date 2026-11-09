-- TutorialClient (ModuleScript, StarterPlayerScripts.Controllers.TutorialClient)
-- What to do next: the first-session guide (Config.Tutorial) and then, for new players, the "Road to
-- the Coast" goals (Config.Journey, counted by JourneyService): free-roam goals once the guide is done,
-- police goals on the police side. One frame, "Next" (ScreenGui "Tutorial"; SoundClient looks for it
-- by name; its buttons "ShowMe" and "Skip"), with two looks ("street" HUD, Theme zones; re-placed when
-- the screen size or input type changes):
--   * a GOAL (Journey): a slim flat strip in the GOAL zone, top centre. The X at its left end, a small
--     gold "GOAL 2/12" tag, the reward in gold right after it (so a long goal cut short on a phone never
--     loses it), up to two lines of white words, and a compact SHOW ME button with its key cap at the
--     right ("GO" on a strip narrower than COMPACT_W). A goal with a target ends its words with the
--     amount, dim (banked cash toward a buy "$6,400 / $10,000", XP toward a rank, or a count), and draws
--     a thin gold bar along the strip's bottom edge (green once there's enough cash).
--   * a GUIDE step (Tutorial): console-style help in the SUBTITLE zone, bottom centre: the step's key
--     cap (Theme.Key: F, E or P on a keyboard, X or D-PAD DOWN on a gamepad; none on touch, where the
--     words name the button), white words with the key words in gold and a dim "2/4", then SHOW ME and
--     the X at the right end (on phones the left end is where the thumbstick starts). HELP below words
--     each step for the input in use; a step Id it doesn't know shows its Config text. The bank step
--     with an empty bag and no cops (an arrest, a rejoin) shows the rob step again until there's a bag.
-- SHOW ME routes the GPS there (OPEN when it's a phone app); its key cap shows the shortcut, J on a
-- keyboard and L3 on a gamepad (SHOW_KEYS). The first time a guide step shows, the GPS is routed for
-- the player the same way (never the phone's apps), and the first time any step or goal shows with
-- words too long for its two lines (small phones), a toast says them whole. While a buy goal is still
-- short of cash the button reads EARN and points at the nearest store to rob instead. The X skips the
-- guide (forfeiting the welcome bonus) or hides the goals; either takes a second, separate tap (a quick
-- double-tap doesn't count).
-- Watches for the guide steps it can see and tells the server (TutorialService checks them); goals are
-- counted on the server only. The guide's last step (open the phone) lands on GARAGE: the phone is
-- switched to it as it opens. Stamps for a finished guide or goal (cinematic, HUDController.Stamp, in
-- gold) wait until the phone is put away (it draws over them).
-- The frame steps aside while ObjectiveClient's strip (same Goal zone) has something more urgent to
-- say (and its SHOW ME and J with it), so the current goal's place is handed to ObjectiveClient on every
-- refresh (ObjectiveClient.SetGoalPlace): for the chop goal ("Sell a stolen car at the Chop Shop") its
-- strip names the Chop Shop and the Docks and has a SHOW ME of its own (J / L3, a tap on touch screens).
-- That's the strip you're looking at right after goal 1's jack (WANTED, then JACKED at the wheel), when
-- this pill's SHOW ME used to be out of reach. The frame also steps aside while a HUDController stamp
-- would draw over the goal strip (short screens; StampTop is in zone coordinates, so the strip is
-- measured from this ScreenGui's corner), while ImpactClient's KNOCKED DOWN
-- caption uses the Subtitle zone (guide line only; ScreenGui "ImpactFx", frame "KnockedDown"), while
-- InteractClient's "Get out first" hint overlaps it, during races, job shifts and missions (their own
-- banners), and on the first-join title screen (local attribute TitleScreen, set by TeamUI).
-- The guide line also steps aside while a ROB button (a heist's Rob or prep prompt) is on screen
-- (ProximityPromptService's PromptShown / PromptHidden): the prompt lands in the same lower middle of the
-- screen, and on a phone the line's SHOW ME sat right on top of the ROB button (Studio test, Nov 8 2026:
-- launch/25).
-- SHOW ME never picks a heist the player's rank can't rob yet (the bank needs rank 3), nor a bigger
-- heist than the step asks for (Config ShowTier / ShowMaxTier).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local Journey = require(ReplicatedStorage.Shared.Config.Journey)
local Heists = require(ReplicatedStorage.Shared.Config.Heists)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local Theme = require(ReplicatedStorage.Shared.Util.Theme)
local GPSClient = require(script.Parent:WaitForChild("GPSClient"))
local PhoneUI = require(script.Parent:WaitForChild("PhoneUI"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local NotifyController = require(script.Parent:WaitForChild("NotifyController"))

local player = Players.LocalPlayer

local TutorialClient = {}

local C = Theme.Color

-- Layout inside the frame (pixels). The frame itself is the zone (Theme.Place): Goal or Subtitle.
local SKIP_W = 36 -- the X (Theme.Touch wide on touch screens)
local BUTTON_H = 30 -- SHOW ME (Theme.Touch tall on touch screens; it may stand out of a thinner strip)
local BUTTON_TEXT = 13
local BUTTON_PAD = 10 -- left of the button's word, and right of it without a key cap
local COMPACT_W = { goal = 320, guide = 360 } -- narrower than this, SHOW ME says "GO" (small phones)
local BAR_H = 3 -- a goal's bar, along the strip's bottom edge
local GAP = 8
local SHOW_KEYS = { keyboard = "J", gamepad = "L3" } -- the SHOW ME shortcut's cap (touch: none)
local SHOW_KEYCODES = { [Enum.KeyCode.J] = true, [Enum.KeyCode.ButtonL3] = true }
local SKIP_CONFIRM = 3 -- seconds to tap the X again
local SKIP_MIN_GAP = 0.6 -- a second tap sooner than this is a double-tap, not a confirm

-- The guide's steps as console help, per input ("keyboard", "gamepad", "touch", or "all"): key = the
-- cap shown before the words (nil: none), text = the words, {braces} = key words, in gold. The keys
-- are the game's own: F / gamepad X gets in (InteractClient), E / X holds a Rob prompt (HeistService),
-- P / gamepad D-pad down opens the phone (PhoneUI), the HUD's CAR tile brings your car (HUDController;
-- no gamepad button is bound to it). A step Id missing here shows its Config text as it is.
local HELP = {
	car = {
		keyboard = { key = "F", text = "Get in your {car}: walk up to it (no car? click {CAR})" },
		gamepad = { key = "X", text = "Get in your {car}: walk up to it" },
		touch = { text = "Walk up to your {car} and tap {GET IN} (no car? tap {CAR})" },
	},
	rob = {
		keyboard = { key = "E", text = "Hold to rob a {store} with an OPEN sign" },
		gamepad = { key = "X", text = "Hold to rob a {store} with an OPEN sign" },
		touch = { text = "Rob a {store} with an OPEN sign: hold {ROB}" },
	},
	bank = {
		all = { text = "Lose the cops, then bank your bag at the {Hideout}" },
	},
	phone = {
		keyboard = { key = "P", text = "Open your {PHONE}: your cars live in {GARAGE}" },
		gamepad = { key = "D-PAD DOWN", text = "Open your {PHONE}: your cars live in {GARAGE}" },
		touch = { text = "Tap {PHONE}: your cars live in {GARAGE}" },
	},
}

local gui, pill, textLabel, showButton, showPad, showKey, guideKey, skip, bar, barFill
local buttonW = 0 -- SHOW ME's width now (sizeButton)
local lastMode -- the input mode the key caps were drawn for
local lastSent = 0
local skipArmedAt = -math.huge
local Objective -- ObjectiveClient, once found (loaded without blocking Init)
local robShown = {} -- [prompt] = true while a heist's Rob / prep prompt is on screen (robPromptUp)
local ROB_PROMPTS = { RobPrompt = true, PrepPrompt = true } -- (HeistService's names)
local introduced = {} -- [def] = true: steps and goals already routed / told in a toast this session

local money = HUDController.Money

local function number(n)
	return string.sub(money(n), 2) -- "1,000" (Money without the $)
end

-- Goal texts are plain words: keep "&", "<" and ">" from being read as rich text.
local function escape(s)
	return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function colorText(color, text)
	return string.format('<font color="#%s">%s</font>', color:ToHex(), text)
end

-- A small tag in the condensed Display face, inside rich text.
local function tagText(color, text, size)
	return string.format('<font face="Oswald" weight="bold" size="%d" color="#%s">%s</font>', size, color:ToHex(), text)
end

-- HELP's words: escaped, {key words} in gold.
local function helpText(text)
	return (escape(text):gsub("{(.-)}", function(word)
		return colorText(C.Gold, word)
	end))
end

-- "touch", "gamepad" or "keyboard": which key caps to show (the same test as InteractClient's).
local function inputMode()
	if Theme.IsTouch() then
		return "touch"
	end
	if string.sub(UserInputService:GetLastInputType().Name, 1, 7) == "Gamepad" then
		return "gamepad"
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "touch"
	end
	return "keyboard"
end

-- Pixel width of a word in the bold UI face (close enough for sizing a button).
local function textWidth(text, size)
	return math.ceil(TextService:GetTextSize(text, size, Enum.Font.GothamBold, Vector2.new(1000, 100)).X)
end

-- Are the frame's words taller than its lines have room for (cut off with "...")? Measured in the bold
-- UI face like textWidth: a little wider than the words' own, so a near miss counts as cut off.
local function cutOff()
	local room = textLabel.AbsoluteSize
	local box = Vector2.new(math.max(room.X, 1), 1000)
	return TextService:GetTextSize(textLabel.ContentText, textLabel.TextSize, Enum.Font.GothamBold, box).Y > room.Y
end

-- A key cap, as wide as its characters (Theme.Key counts bytes, so "↓"-style keys would be too wide).
local function sizeKey(key, text)
	key.Text = text
	key.Size = UDim2.fromOffset(math.max(22, 10 + utf8.len(text) * 9), 22)
	return key.Size.X.Offset
end

-- Heist tiers by their map name ("Sparkle & Co." -> 2), for goals that want a bigger job.
local TIER_BY_NAME = {}
for _, def in pairs(Heists.Types) do
	TIER_BY_NAME[def.Display] = def.Tier
end

-- The guide's rob step (its number in Config.Tutorial), shown again while the bank step has no bag.
local ROB_STEP
for i, def in ipairs(Tutorial.Steps) do
	if def.Id == "rob" then
		ROB_STEP = i
	end
end

local function places()
	local ok, list = pcall(function()
		return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("Places") or "[]")
	end)
	return ok and list or {}
end

-- Heists this player can't rob yet (rank-locked, e.g. the Coastal Bank), by their map name.
local function lockedHeistNames()
	local rank = player:GetAttribute("CivRank") or 1
	local locked = {}
	for _, def in pairs(Heists.Types) do
		if def.MinRank and rank < def.MinRank then
			locked[def.Display] = true
		end
	end
	return locked
end

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- The nearest wanted robber's last known spot (HeatService's LastSeen), for the police goals.
local function nearestWanted(here)
	local best, bestD
	for _, p in ipairs(Players:GetPlayers()) do
		local seen = p:GetAttribute("LastSeen")
		if p ~= player and p:GetAttribute("Side") == "Civilian" and (p:GetAttribute("Heat") or 0) > 0
			and typeof(seen) == "Vector3" then
			local d = flatDistance(seen, here)
			if not bestD or d < bestD then
				best, bestD = seen, d
			end
		end
	end
	return best
end

-- The nearest place on MapService's list that match(place) accepts.
local function nearestPlace(here, match)
	local best, bestD
	for _, p in ipairs(places()) do
		if match(p) then
			local d = flatDistance(Vector3.new(p.x, 0, p.z), here)
			if not bestD or d < bestD then
				best, bestD = p, d
			end
		end
	end
	return best
end

-- The nearest heist that's open right now, of tier lo to hi, that the player's rank allows (never send
-- a new player to a heist they don't have the rank for). A rookie's tier-1 sites are always open for them
-- (Tutorial.RookieRob), so their first robbery is the nearest store or ATM, never one across town.
local function nearestHeist(here, lo, hi)
	local open = {}
	for id in string.gmatch(ReplicatedStorage:GetAttribute("OpenHeists") or "", "[^,]+") do
		open[id] = true
	end
	local locked = lockedHeistNames()
	return nearestPlace(here, function(p)
		local tier = TIER_BY_NAME[p.n] or 1 -- (an ATM's map name is "ATM #2": tier 1)
		local openForMe = open[p.id] == true or Tutorial.CanRookieRob(player, tier)
		return p.c == "Heist" and openForMe and not locked[p.n] and tier >= lo and tier <= hi
	end)
end

-- The biggest heist tier without a prep job (below the Coastal Bank / Sea Dream).
local SOLO_TIER = Heists.BigTier - 1

-- A buy goal that's still short of cash: its button earns (def.Earn) instead of going to the shop.
local function earning(def)
	return def.Cash ~= nil and def.Earn ~= nil and (player:GetAttribute("Cash") or 0) < def.Cash
end

local function showMe(def)
	local target, lo, hi = def.Show, def.ShowTier or 1, def.ShowMaxTier
	if earning(def) then
		local short = def.Cash - (player:GetAttribute("Cash") or 0)
		NotifyController.Show(money(short) .. " to go: rob a store, then bank the bag at the Hideout", C.Gold, "money")
		target, lo, hi = def.Earn, 1, SOLO_TIER
	end
	if target == "Garage" or target == "Goals" then
		PhoneUI.Open(target)
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local here = root and root.Position or Vector3.zero
	if target == "Wanted" then
		local seen = nearestWanted(here)
		if seen then
			GPSClient.SetTarget("Wanted robber", Vector3.new(seen.X, 0, seen.Z))
		else
			NotifyController.Show("Nobody's wanted right now. Keep patrolling!", C.Police, "police")
		end
		return
	end
	local best
	if target == "OpenHeist" then
		-- Up to ShowMaxTier (by default the biggest without a prep job); a lower ShowMaxTier is only a
		-- preference: with none of those open, anything up to that default.
		local default = math.max(lo, SOLO_TIER)
		best = nearestHeist(here, lo, hi or default)
		if not best and hi and hi < default then
			best = nearestHeist(here, lo, default)
		end
	elseif target == "Stunt" or target == "Race" then
		best = nearestPlace(here, function(p)
			return p.g == target -- MapService's group: the nearest of them (boat races are "BoatRace")
		end)
	else
		best = nearestPlace(here, function(p)
			return p.n == target
		end)
	end
	if best then
		GPSClient.SetTarget(best.n, Vector3.new(best.x, 0, best.z))
	else
		NotifyController.Show("Nothing open right now. Check again in a moment!", C.Gold)
	end
end

-- What to show now: { def, tag, step = the guide step's number, again = true for the rob step shown
-- again } for the guide, or { def, tag, chain = "civ" / "cop" } for a goal; nil for nothing.
local function currentGoal()
	local side = player:GetAttribute("Side")
	if side == "Civilian" then
		local done = player:GetAttribute("TutorialStep")
		if type(done) ~= "number" then
			return nil
		end
		if done < #Tutorial.Steps then
			-- The bank step with nothing in the bag and no cops to lose would wait forever (an arrest
			-- empties the bag, and so does rejoining): show the rob step again until there's a bag to bank.
			-- The server still has the guide at the bank step and finishes it when that bag is banked.
			local step = done + 1
			if Tutorial.Steps[step].Id == "bank" and ROB_STEP and (player:GetAttribute("Carried") or 0) <= 0
				and (player:GetAttribute("Heat") or 0) <= 0 then
				step = ROB_STEP
			end
			return { def = Tutorial.Steps[step], tag = string.format("%d/%d", step, #Tutorial.Steps),
				step = step, again = step ~= done + 1 }
		end
		local j = player:GetAttribute("JourneyStep")
		local def = type(j) == "number" and Journey.Civ[j + 1]
		if def then
			return { def = def, tag = string.format("GOAL %d/%d", j + 1, #Journey.Civ), chain = "civ" }
		end
	elseif side == "Cop" then
		local j = player:GetAttribute("JourneyCopStep")
		local def = type(j) == "number" and Journey.Cop[j + 1]
		if def then
			return { def = def, tag = string.format("GOAL %d/%d", j + 1, #Journey.Cop), chain = "cop" }
		end
	end
	return nil
end

-- A goal's bar: how full (0-1) and the words beside it, or nil for goals without one.
local function barFor(goal)
	local def = goal.def
	if not goal.chain then
		return nil
	end
	if def.Cash then
		local cash = player:GetAttribute("Cash") or 0
		return cash / def.Cash, money(cash) .. " / " .. money(def.Cash)
	elseif def.Kind == "CivRank" or def.Kind == "CopRank" then
		local xp = player:GetAttribute(def.Kind == "CivRank" and "CivXP" or "CopXP") or 0
		local need = math.max(1, Progression.XPFor(def.Goal))
		return xp / need, number(xp) .. " / " .. number(need) .. " XP"
	elseif def.Goal > 1 then
		local done = player:GetAttribute(goal.chain == "cop" and "JourneyCopProgress" or "JourneyProgress") or 0
		return done / def.Goal, number(done) .. " / " .. number(def.Goal) .. (def.Unit and (" " .. def.Unit) or "")
	end
	return nil
end

local function onShowMe()
	local goal = currentGoal()
	if goal and goal.def.Show then
		showMe(goal.def)
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Tutorial"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- the zone map's coordinates (y = 0 is the very top of the screen)
	gui.Parent = player:WaitForChild("PlayerGui")

	pill = Instance.new("Frame")
	pill.Name = "Next"
	pill.Visible = false
	Theme.Panel(pill)
	pill.Parent = gui

	textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	Theme.Text(textLabel, 14, "Body")
	textLabel.RichText = true
	textLabel.TextWrapped = true -- two lines at most; the rest is cut with "..."
	textLabel.TextTruncate = Enum.TextTruncate.AtEnd
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Center
	textLabel.Parent = pill

	-- The guide step's key cap, left of the words (hidden on touch and for steps without a key).
	guideKey = Theme.Key(pill, "F")
	guideKey.AnchorPoint = Vector2.new(0, 0.5)
	guideKey.Visible = false

	-- A goal's bar: a thin line along the strip's bottom edge (only for goals with a target; the amount
	-- ends the words).
	bar, barFill = Theme.Bar(pill, C.Gold)
	bar.Visible = false
	barFill.Size = UDim2.fromScale(0, 1)

	-- SHOW ME: a small flat chip, its word on the left and the shortcut's key cap on the right.
	showButton = Instance.new("TextButton")
	showButton.Name = "ShowMe"
	Theme.Button(showButton, "Quiet")
	showButton.BackgroundColor3 = C.PanelLight
	showButton.BackgroundTransparency = 0.15
	showButton.TextSize = BUTTON_TEXT
	showButton.TextXAlignment = Enum.TextXAlignment.Left
	showButton.Text = "SHOW ME"
	showButton.AnchorPoint = Vector2.new(1, 0.5)
	showButton.Parent = pill
	showPad = Instance.new("UIPadding")
	showPad.PaddingLeft = UDim.new(0, BUTTON_PAD)
	showPad.Parent = showButton
	showKey = Theme.Key(showButton, SHOW_KEYS.keyboard)
	showKey.AnchorPoint = Vector2.new(1, 0.5)
	showButton.Activated:Connect(onShowMe)

	-- The X: left end of the goal strip (top of the screen), right end of the guide line (phones start
	-- the thumbstick on the left, and a stray tap must never end the guide).
	skip = Instance.new("TextButton")
	skip.Name = "Skip"
	Theme.Text(skip, 15, "Body")
	skip.TextColor3 = C.Dim
	skip.AutoButtonColor = false
	skip.Text = "X" -- (the font has no multiplication-sign glyph)
	skip.Parent = pill
	skip.Activated:Connect(function()
		local goal = currentGoal()
		if not goal then
			return
		end
		-- Skipping the guide forfeits the welcome bonus, and hiding the goals drops their rewards, so
		-- either takes a second tap, after the warning has had a moment to be read.
		local since = os.clock() - skipArmedAt
		if since < SKIP_MIN_GAP then
			return -- the second half of a double-tap
		end
		if since > SKIP_CONFIRM then
			skipArmedAt = os.clock()
			if goal.chain then
				NotifyController.Show("Tap X again to hide your goals (and their rewards)", C.Gold, "warning")
			else
				NotifyController.Show("Tap X again to skip the guide (and its " .. money(Tutorial.Bonus) .. " bonus)", C.Gold, "warning")
			end
			return
		end
		skipArmedAt = -math.huge
		if goal.chain then
			Remotes.Event("JourneyStep"):FireServer("Hide")
		else
			Remotes.Event("TutorialStep"):FireServer("Skip")
			if player:GetAttribute("JourneyStep") ~= nil then
				NotifyController.Show("Guide skipped. Goals with cash rewards come next (X hides those too)", C.Gold, "info")
			end
		end
		pill.Visible = false
	end)
end

-- SHOW ME's word and key cap; sets buttonW (never under Theme.Touch on touch screens). The cap sits in
-- the button's right padding; without one the word is centred.
local function sizeButton(words, mode, touch)
	showButton.Text = words
	local cap = SHOW_KEYS[mode]
	local right = BUTTON_PAD
	showKey.Visible = cap ~= nil
	showButton.TextXAlignment = cap and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
	if cap then
		local capW = sizeKey(showKey, cap)
		right = capW + 14
		showKey.Position = UDim2.new(1, capW + 6, 0.5, 0) -- 8 px in from the button's right edge
	end
	showPad.PaddingRight = UDim.new(0, right)
	buttonW = BUTTON_PAD + textWidth(words, BUTTON_TEXT) + right
	if touch then
		buttonW = math.max(buttonW, Theme.Touch)
	end
end

-- Place the frame in its zone and lay out what's inside for this look ("goal" or "guide").
local function layout(look, touch, hasBar, capW)
	Theme.Place(pill, look == "goal" and "Goal" or "Subtitle", touch)
	local h = pill.Size.Y.Offset -- the zone's height
	local skipW = touch and Theme.Touch or SKIP_W
	local buttonH = touch and Theme.Touch or BUTTON_H
	showButton.Size = UDim2.fromOffset(buttonW, buttonH)
	skip.Size = UDim2.fromOffset(skipW, math.max(h, touch and Theme.Touch or 0))
	if look == "goal" then
		pill.BackgroundTransparency = Theme.PanelAlpha
		skip.AnchorPoint = Vector2.new(0, 0.5)
		skip.Position = UDim2.new(0, 0, 0.5, 0)
		showButton.Position = UDim2.new(1, -6, 0.5, 0)
		local left = skipW + 2
		local right = showButton.Visible and (buttonW + 6 + GAP) or 12
		textLabel.TextWrapped = true -- two lines at most (the zone's height)
		if hasBar then
			-- The words fill the strip down to its thin bar along the bottom edge.
			textLabel.Position = UDim2.fromOffset(left, 0)
			textLabel.Size = UDim2.new(1, -(left + right), 1, -(BAR_H + 1))
			bar.Position = UDim2.new(0, left, 1, -(BAR_H + 1))
			bar.Size = UDim2.new(1, -(left + right), 0, BAR_H)
		else
			textLabel.Position = UDim2.fromOffset(left, 2)
			textLabel.Size = UDim2.new(1, -(left + right), 1, -4)
		end
	else
		-- Help line: [key] words ... [SHOW ME] [X]
		pill.BackgroundTransparency = 0.5
		skip.AnchorPoint = Vector2.new(1, 0.5)
		skip.Position = UDim2.new(1, 0, 0.5, 0)
		showButton.Position = UDim2.new(1, -(skipW + 2), 0.5, 0)
		local left = 14
		if capW then
			guideKey.Position = UDim2.new(0, 14, 0.5, 0)
			left = 14 + capW + 10
		end
		local right = skipW + 2 + (showButton.Visible and (buttonW + GAP) or 4)
		textLabel.TextWrapped = true
		textLabel.Position = UDim2.fromOffset(left, 2)
		textLabel.Size = UDim2.new(1, -(left + right), 1, -4)
	end
end

-- Do two on-screen boxes overlap? (Both guis ignore the top inset, so they share coordinates.)
local function overlaps(a, b)
	local ap, as, bp, bs = a.AbsolutePosition, a.AbsoluteSize, b.AbsolutePosition, b.AbsoluteSize
	return ap.X < bp.X + bs.X and bp.X < ap.X + as.X and ap.Y < bp.Y + bs.Y and bp.Y < ap.Y + as.Y
end

-- InteractClient's "Get out first" hint, while it shows on top of this frame.
local function exitHintOver()
	local playerGui = player:FindFirstChild("PlayerGui")
	local interact = playerGui and playerGui:FindFirstChild("Interact")
	local hint = interact and interact:FindFirstChild("GetOutHint")
	return hint ~= nil and hint:IsA("GuiObject") and hint.Visible and overlaps(hint, pill)
end

-- ImpactClient's KNOCKED DOWN caption (ScreenGui "ImpactFx", frame "KnockedDown"): it shares the
-- Subtitle zone with the guide line for the ~2.5 s you're down.
local function knockCaptionUp()
	local playerGui = player:FindFirstChild("PlayerGui")
	local fx = playerGui and playerGui:FindFirstChild("ImpactFx")
	local caption = fx and fx:FindFirstChild("KnockedDown")
	return caption ~= nil and caption:IsA("GuiObject") and caption.Visible
end

-- Is a heist's ROB button on screen right now? Exactly what Roblox shows (in reach, enabled, the closest
-- prompt; never while seated: PromptGate), so the line never hides with no button there to take its place.
-- (A prompt destroyed while it showed is dropped here, in case its PromptHidden never came.)
local function robPromptUp()
	for prompt in pairs(robShown) do
		if prompt.Parent and prompt.Enabled then
			return true
		end
		robShown[prompt] = nil
	end
	return false
end

local function refresh()
	local goal = currentGoal()
	-- Where the goal's SHOW ME points, for ObjectiveClient's strip (it covers this pill and its button).
	if Objective ~= nil and type(Objective.SetGoalPlace) == "function" then
		Objective.SetGoalPlace(goal and goal.chain == "civ" and goal.def.Show or nil)
	end
	-- Out of the way during races, job shifts and missions (their own banners), and on the title screen.
	local busy = player:GetAttribute("RacingId") ~= nil or player:GetAttribute("JobKind") ~= nil
		or player:GetAttribute("Mission") ~= nil or player:GetAttribute("TitleScreen") == true
	-- ObjectiveClient's strip ("Lose the cops", "Bank your $900...") is more urgent (and uses the Goal zone).
	local objective = Objective ~= nil and Objective.Active() == true
	if not goal then
		pill.Visible = false
		return
	end
	local def = goal.def
	local touch = Theme.IsTouch()
	local mode = inputMode()
	lastMode = mode
	local look = goal.chain and "goal" or "guide"
	local screenW = gui.AbsoluteSize.X
	local zone = Theme.Zone(look == "goal" and "Goal" or "Subtitle", touch)
	local compact = (zone.Size.X.Scale * screenW + zone.Size.X.Offset) < COMPACT_W[look]
	local textSize = look == "goal" and (touch and 13 or 14) or (touch and 14 or 16)
	textLabel.TextSize = textSize

	-- The button's word (and key cap).
	showButton.Visible = def.Show ~= nil
	local words
	if goal.chain and earning(def) then
		words = "EARN" -- not enough saved yet: to the nearest store instead of the shop
	elseif def.Show == "Garage" or def.Show == "Goals" then
		words = "OPEN"
	else
		words = compact and "GO" or "SHOW ME"
	end
	sizeButton(words, mode, touch)

	-- The words, the bar, the guide's key cap.
	local fill, amount = barFor(goal)
	local hasBar = fill ~= nil
	local capW
	local whole -- the words in full, for the toast when they're cut off
	if look == "goal" then
		guideKey.Visible = false
		-- Tag, reward, words, amount: a goal too long for two lines on a phone loses its last words (or
		-- its amount: the bar still shows how far along it is), never the reward.
		local reward = (def.Reward or 0) > 0 and (colorText(C.Gold, "+" .. money(def.Reward)) .. "  ") or ""
		textLabel.Text = tagText(C.Gold, goal.tag, textSize + 2) .. "  " .. reward .. escape(def.Text)
			.. (hasBar and ("  " .. colorText(C.Dim, amount)) or "")
		whole = goal.tag .. ": " .. def.Text
	else
		local help = HELP[def.Id]
		local h = help and (help[mode] or help.all)
		guideKey.Visible = h ~= nil and h.key ~= nil
		if guideKey.Visible then
			capW = sizeKey(guideKey, h.key)
		end
		local counter = "   " .. colorText(C.Dim, goal.tag)
		textLabel.Text = (h and helpText(h.text) or escape(def.Text)) .. counter
		whole = h and (string.gsub(h.text, "[{}]", "")) or def.Text
	end
	bar.Visible = hasBar
	if hasBar then
		fill = math.clamp(fill, 0, 1)
		barFill.Size = UDim2.fromScale(fill, 1)
		barFill.BackgroundColor3 = fill >= 1 and C.Cash or C.Gold -- green: enough saved, go buy it
	end
	layout(look, touch, hasBar, capW)

	-- A big stamp ("GOAL COMPLETE") drawing over the goal strip on a short screen: step aside until it's
	-- gone (the guide line sits at the bottom, under the stamps). StampTop is in zone coordinates and
	-- AbsolutePosition starts under the top bar whatever IgnoreGuiInset says, so the strip is measured
	-- from our own ScreenGui's corner. The KNOCKED DOWN caption takes the guide line's Subtitle zone for
	-- a moment. "Get out first" is the more urgent instruction (it comes up right as goal 1 says to go JACK).
	-- Standing at a ROB button, the button itself is the instruction: the guide line (bottom centre, where
	-- the prompt lands) steps aside so nothing covers it.
	local stampTop = HUDController.StampTop and HUDController.StampTop()
	local covered = look == "goal" and stampTop ~= nil
		and stampTop < pill.AbsolutePosition.Y - gui.AbsolutePosition.Y + pill.AbsoluteSize.Y
	pill.Visible = player:GetAttribute("HasPicked") == true and not busy and not objective and not covered
		and not (look == "guide" and (knockCaptionUp() or robPromptUp())) and not exitHintOver()

	-- The first time a step or goal is on screen, not under the phone (once a session): words cut off by
	-- the two lines (small phones) are said whole in a toast, and a guide step routes the GPS the way
	-- SHOW ME does, so a new player has a route without finding the button (never the phone's apps:
	-- opening it is the step). Not the rob step shown again (it can blink up as a bag is banked).
	if pill.Visible and not goal.again and not introduced[def] and not PhoneUI.IsOpen() then
		introduced[def] = true
		if cutOff() then
			NotifyController.Show(whole, C.Gold, "info")
		end
		if goal.step and def.Show and def.Show ~= "Garage" and def.Show ~= "Goals" then
			showMe(def)
		end
	end
end

-- Is this guide step complete, as far as this device can tell?
local function reached(def)
	if def.Id == "phone" then
		return PhoneUI.IsOpen()
	elseif def.Id == "car" then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		return hum and hum.SeatPart and hum.SeatPart.Name == "DriverSeat"
	elseif def.Id == "rob" then
		return (player:GetAttribute("Carried") or 0) > 0
	end
	return false
end

-- The guide's phone step lands on GARAGE: when the phone opens on that step (P, the PHONE button),
-- switch it to GARAGE. Deferred, so PhoneUI.Open has finished showing its home screen first; it runs
-- before the next frame draws, so the phone just slides up on GARAGE. (PhoneUI's gui "Phone", frame
-- "Body"; if that's ever renamed the step still completes, on the home screen.)
local function watchPhone()
	local phoneGui = player:WaitForChild("PlayerGui"):WaitForChild("Phone", 10)
	local body = phoneGui and phoneGui:WaitForChild("Body", 10)
	if not body then
		return
	end
	body:GetPropertyChangedSignal("Visible"):Connect(function()
		local goal = body.Visible and currentGoal()
		if goal and not goal.chain and goal.def.Id == "phone" then
			task.defer(PhoneUI.Open, "Garage")
		end
	end)
end

-- Step aside the moment the KNOCKED DOWN caption comes, and come back as it goes, instead of at the
-- next half-second check. ImpactClient builds its ScreenGui on the first knock-down, frame after gui.
local function watchCaption()
	local playerGui = player:WaitForChild("PlayerGui")
	local function watch(fx)
		local caption = fx.Name == "ImpactFx" and fx:WaitForChild("KnockedDown", 5)
		if caption and caption:IsA("GuiObject") then
			caption:GetPropertyChangedSignal("Visible"):Connect(refresh)
		end
	end
	playerGui.ChildAdded:Connect(function(child)
		if child.Name == "ImpactFx" then
			task.spawn(watch, child)
		end
	end)
	local fx = playerGui:FindFirstChild("ImpactFx")
	if fx then
		watch(fx)
	end
end

local function playSuccess()
	pcall(function()
		require(script.Parent:WaitForChild("SoundClient")).Play("Success")
	end)
end

-- The phone (DisplayOrder 5) draws over HUD stamps, and the guide's last step and the paint goal both
-- finish with it open: stamp once it's put away (20 s at most), then run after().
local function stampLater(title, sub, color, after)
	task.spawn(function()
		local waited = 0
		while PhoneUI.IsOpen() and waited < 20 do
			waited += task.wait(0.25)
		end
		HUDController.Stamp(title, sub, color)
		refresh() -- step aside for the stamp now, not at the next check
		if after then
			after()
		end
	end)
end

function TutorialClient.Init()
	build()
	refresh()
	-- Re-place when the screen changes size or the device's input changes; redraw the key caps when the
	-- player switches between keyboard and gamepad.
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
	UserInputService:GetPropertyChangedSignal("MouseEnabled"):Connect(refresh)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(refresh)
	UserInputService.LastInputTypeChanged:Connect(function()
		if inputMode() ~= lastMode then
			refresh()
		end
	end)
	-- The SHOW ME shortcut (J / gamepad L3), only while its button is on screen. (While ObjectiveClient's
	-- strip covers the pill, that strip answers J for its own next place: never both at once.)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not SHOW_KEYCODES[input.KeyCode] then
			return
		end
		if pill.Visible and showButton.Visible then
			onShowMe()
		end
	end)
	for _, a in ipairs({ "TutorialStep", "Side", "HasPicked", "RacingId", "JobKind", "Mission", "JourneyStep",
		"JourneyProgress", "JourneyCopStep", "JourneyCopProgress", "Cash", "CivXP", "CopXP", "TitleScreen" }) do
		player:GetAttributeChangedSignal(a):Connect(refresh)
	end
	task.spawn(watchPhone)
	task.spawn(watchCaption)
	-- A ROB button coming on screen or going: the guide line steps aside / comes back at once.
	ProximityPromptService.PromptShown:Connect(function(prompt)
		if ROB_PROMPTS[prompt.Name] then
			robShown[prompt] = true
			refresh()
		end
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if robShown[prompt] then
			robShown[prompt] = nil
			refresh()
		end
	end)
	-- Hide while an objective strip shows (never wait forever for it inside Init).
	task.spawn(function()
		local module = script.Parent:WaitForChild("ObjectiveClient", 10)
		if not module then
			return
		end
		local ok, mod = pcall(require, module)
		if ok and type(mod) == "table" and mod.Changed and mod.Active then
			Objective = mod
			mod.Changed:Connect(refresh)
			refresh()
		end
	end)
	Remotes.OnClient("TutorialDone", function(bonus)
		-- The last step is opening the phone, so this waits for it to be put away.
		stampLater("WELCOME TO PORT SOLANA", "+" .. money(tonumber(bonus) or 0) .. " welcome bonus", C.Gold, function()
			task.delay(3, function()
				if player:GetAttribute("JourneyStep") ~= nil then
					NotifyController.Show("Next up: goals with cash rewards, at the top of the screen", C.Gold, "success")
				else
					NotifyController.Show("Try races, stunt jumps, drifting and taxi shifts: PHONE > GPS > FUN", C.Text)
				end
			end)
		end)
	end)
	Remotes.OnClient("JourneyDone", function(info)
		if type(info) ~= "table" then
			return
		end
		local index, total = tonumber(info.Index) or 0, tonumber(info.Total) or 0
		local reward = tonumber(info.Reward) or 0
		local paid = reward > 0 and ("+" .. money(reward) .. "  ·  ") or ""
		playSuccess() -- right away; the stamp may wait for the phone (the paint goal ends in GARAGE)
		if total > 0 and index >= total then
			stampLater(info.Cop and Journey.Finished.Cop or Journey.Finished.Civ, paid .. "every goal done", C.Gold)
		else
			stampLater("GOAL COMPLETE", paid .. string.format("%d/%d done", index, total), C.Gold)
		end
		refresh()
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(function()
				refresh() -- also notices a stamp coming and going
				local goal = currentGoal()
				if goal and goal.step and not goal.def.ServerOnly and reached(goal.def) and os.clock() - lastSent > 1 then
					lastSent = os.clock()
					Remotes.Event("TutorialStep"):FireServer(goal.step)
				end
			end)
			if not ok then
				warn("[TutorialClient] " .. tostring(err))
			end
		end
	end)
end

return TutorialClient
