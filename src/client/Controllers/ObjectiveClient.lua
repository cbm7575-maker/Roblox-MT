-- ObjectiveClient (ModuleScript, StarterPlayerScripts.Controllers.ObjectiveClient)
-- One "what do I do now?" strip for crime moments, and it points the GPS for you. It follows your
-- state, most urgent first:
--   1. In prison                 -> "Find the vent in the yard" (GPS to the vent)
--   2. Wanted (Heat > 0)         -> "Lose the cops", what comes after it (bank the bag first; else "Then
--                                   the Chop Shop (Docks)" for a hot car or a jacked car it buys, or
--                                   "Then sell a car: Chop Shop (Docks)" while the goal chain's chop goal
--                                   is up), and an escape line: whether they can see you, the patrols'
--                                   head start (PoliceETA from AIPoliceService) or how long to stay
--                                   hidden (EscapeAt from HeatService; a guess, "ABOUT 0:32", without
--                                   it). The GPS is left alone, so a Hideout or Chop Shop route set by
--                                   the robbery / theft stays up.
--   3. Cash in your bag          -> "Bank $X at the Hideout" (GPS to the Hideout)
--   4. Driving a boosted hot car -> "Take it to the Chop Shop", "At the Docks..." (GPS to the Chop Shop)
--   5. Driving a jacked car      -> "Joyride, or sell it", "Chop Shop (Docks) pays $350" (no GPS of its
--                                   own: it only keeps the suggested Chop Shop route while you drive
--                                   it), or just "Joyride" for a car the Chop Shop won't buy
--                                   (JackSellable = false: taken right by the Chop Shop)
-- The words are kept short enough for one line each on a 667 px-wide phone (about 26 characters for a
-- title after its tag, 38 for a second line; with the SHOW ME chip below about 6 and 8 fewer, which
-- the Chop Shop lines are written for): the strip never wraps and cuts the rest with "...".
-- SHOW ME for the Chop Shop: whenever the strip's next step is the Chop Shop (the WANTED, HOT CAR and
-- JACKED lines above that name it; a bag comes first and keeps its Hideout route), a SHOW ME chip with
-- its key cap sits at the strip's right end (button "ShowMe": "GO" on a narrow strip; no cap and
-- Theme.Touch big on touch screens) and it, J or gamepad L3 routes the GPS there. Shown even when the
-- GPS is already on it (the jack's suggestion usually is, and while wanted the readout is hidden: the
-- escape line has the Banner zone). It's the goal pill's own button and shortcut (TutorialClient),
-- which step aside with the pill while this strip has the Goal zone: right after a jack this strip
-- always has it (a street jack gives a star, then you're at the wheel), so the chop goal's SHOW ME and
-- J were out of reach just when they were needed. A route asked for this way is the player's own
-- (never cleared by an objective of ours; GPSClient drops it on arrival), and a toast says "GPS set".
-- Also: whenever you steal a hot car (BoostStolenAt changes, CarBoostService sets it on every theft)
-- a stamp says where to take it and the GPS is set. Jacking a car (Carjacked from CarjackService)
-- stamps "CAR JACKED" (or "CAR ALARM", in red) with its Chop Shop price, and routes the GPS to the Chop
-- Shop only as a suggestion: never over a target the player picked themselves, never over the route of
-- the objective on screen (e.g. the Hideout for a bag), never with cash in the bag, and not for a car
-- the Chop Shop won't buy.
-- Hidden during races, job shifts and missions (they have their own banners), for cops, and while the
-- first-join title screen is up (local attribute TitleScreen, set by TeamUI). Hidden too while you're on
-- the Big Score's roster (player attribute BigScore): BigScoreClient draws that heist's strip in this same
-- Goal zone, so Active() stays true meanwhile and the tutorial's goal keeps out of its way as well. Not in
-- prison, though (a prisoner stays on that roster): the vent strip comes first there.
-- Look and place ("street" HUD, Theme; re-placed when the screen size or input type changes):
--   * Frame "Banner" (the name MinimapClient / SoundClient look for) sits in the GOAL zone, top centre:
--     a slim flat dark strip with a thin colour bar at its left edge, a small Display tag in the colour
--     that means something (PRISON orange; WANTED white, red and blinking while a cop can see you; BAG,
--     HOT CAR and JACKED gold: a goal with a reward), one line of white words (bag cash and car values in
--     gold) and a dim second line. TutorialClient's goal / guide steps aside while it shows (Changed).
--   * Frame "Escape" (only while wanted) sits in the BANNER zone under it: text straight on the screen
--     with a soft shadow, a small word and a big Display value, both in the colour that means
--     something: "STAY HIDDEN 0:32" (dim word, white time), "PATROLS ARRIVE IN 0:12" (police blue),
--     "SEEN  BREAK LINE OF SIGHT" (red). The stars themselves are HUDController's (Status zone), so
--     they aren't repeated here.
--   Each steps aside while a HUDController stamp would draw over it (HUDController.StampTop; on phones
--   the Stamp zone reaches into the Banner zone, so the escape line steps aside for every stamp there),
--   then comes back; `active` stays true meanwhile. StampTop is in zone coordinates (y = 0 at the very
--   top of the screen), so the pieces are measured from this ScreenGui's own corner.
-- GPS rule: a target this module set is cleared when its objective ends; a target the player picked
-- themselves (GPSClient.Target() isn't the name we set, or they asked for it with the strip's SHOW ME)
-- is never cleared, and the jack's Chop Shop suggestion never goes over it (a SHOW ME press does).
-- Must start after HUDController and GPSClient in ClientMain's ORDER.
--   ObjectiveClient.Active() -> true while there is an objective (shown, or stepped aside for a stamp),
--     or the Big Score's strip has the Goal zone
--   ObjectiveClient.Changed  -> event(active), fired when that flips (TutorialClient listens)
--   ObjectiveClient.RouteTo(placeName) -> point the GPS at a place from MapService's "Places" list,
--     as ours; returns true if the route is set (HeistClient: "bank it at the Hideout (GPS set)").
--   ObjectiveClient.SetGoalPlace(show) -> TutorialClient: where the current free-roam goal's SHOW ME
--     points (Config.Journey Show), or nil; the chop goal ("Chop Shop") makes the Chop Shop a next step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local Theme = require(ReplicatedStorage.Shared.Util.Theme)
local Wanted = require(ReplicatedStorage.Shared.Config.Wanted)
local GPSClient = require(script.Parent:WaitForChild("GPSClient"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local NotifyController = require(script.Parent:WaitForChild("NotifyController"))

local player = Players.LocalPlayer

local ObjectiveClient = {}

local C = Theme.Color

local UPDATE_EVERY = 0.25
local HOT_CAR_NEAR = 300 -- a parked hot car of ours this close still counts ("get back in")
local GPS_SKIP = 60 -- no route to a place you're already standing next to
local VENT_NAME = "Prison vent"
local HIDEOUT = "Hideout"
local CHOP_SHOP = "Chop Shop"

-- Inside the strip (pixels): the colour bar, then the words.
local ACCENT_X, ACCENT_W = 7, 3
local TEXT_X = 18

-- The SHOW ME chip (see the header): the same look and shortcut as TutorialClient's goal pill.
local K = {}
K.WHERE = { [CHOP_SHOP] = "Chop Shop (Docks)" } -- how the strip names a place: the place and its district
K.SHOW_KEYS = { keyboard = "J", gamepad = "L3" } -- the chip's key cap (touch: none)
K.SHOW_KEYCODES = { [Enum.KeyCode.J] = true, [Enum.KeyCode.ButtonL3] = true }
K.CHIP_H = 30 -- pixels (Theme.Touch on touch screens: it may stand out of the thinner phone strip)
K.CHIP_TEXT = 13
K.CHIP_PAD = 10 -- left of the chip's word, and right of it without a key cap
K.CHIP_GAP = 8 -- between the words and the chip
K.WORDS_RIGHT = 10 -- the words' right margin without the chip
K.COMPACT_W = 320 -- a strip narrower than this says "GO" (as TutorialClient's goal strip does)

local changed = Instance.new("BindableEvent")
ObjectiveClient.Changed = changed.Event

local gui, banner, accent, titleLabel, detailLabel
local chip, chipPad, chipKey -- the SHOW ME chip, its padding and key cap
local chipLayout -- what the chip was last laid out for (layoutChip redoes it only when that changes)
local wordsRight = K.WORDS_RIGHT -- the words' right margin now (more while the chip shows)
local goalPlace -- where the tutorial's current goal points (SetGoalPlace), or nil
local escape, escWord, escValue
local tagSize = 17 -- the Display tag's text size (place() sets it from the words' size)
local active = false
local current -- the objective on screen (table) or nil
local mine -- name of the GPS target this module set (nil = none of ours)
local setAt = 0 -- os.clock() when we last set it
local retried = false -- already put back a route that got wiped right after we set it
local pending -- GPS place name waiting for a position (the vent streams in a moment later)
local lastSeenAt = 0 -- os.clock() guess of when the cops last saw us
local lastHeat = 0
local blink = false
local ventPart, ventSearchAt = nil, 0
local placesRaw, placesList = nil, {}

local function places()
	local raw = ReplicatedStorage:GetAttribute("Places")
	if raw ~= placesRaw then
		placesRaw = raw
		local ok, list = pcall(function()
			return HttpService:JSONDecode(raw or "[]")
		end)
		placesList = (ok and type(list) == "table") and list or {}
	end
	return placesList
end

local function myPos()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or nil
end

local function flatDistance(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- The nearest place with this name from MapService's list (works even when it isn't streamed in).
local function placePos(name)
	local here = myPos()
	local best, bestD
	for _, p in ipairs(places()) do
		local x, z = tonumber(p.x), tonumber(p.z)
		if p.n == name and x and z then
			local pos = Vector3.new(x, 0, z)
			local d = here and flatDistance(pos, here) or 0
			if not bestD or d < bestD then
				best, bestD = pos, d
			end
		end
	end
	return best
end

-- The breakout vent (Workspace.City.Landmarks.PrisonVent), once it's streamed in.
local function ventPos()
	if ventPart and ventPart.Parent then
		return ventPart.Position
	end
	ventPart = nil
	if os.clock() < ventSearchAt then
		return nil
	end
	ventSearchAt = os.clock() + 2 -- the deep search below isn't free: at most every 2 s
	local city = Workspace:FindFirstChild("City")
	local landmarks = city and city:FindFirstChild("Landmarks")
	local found = landmarks and landmarks:FindFirstChild("PrisonVent")
	if not found and city then
		found = city:FindFirstChild("PrisonVent", true)
	end
	if found and found:IsA("BasePart") then
		ventPart = found
		return found.Position
	end
	return nil
end

local function gpsPos(name)
	if name == VENT_NAME then
		return ventPos()
	end
	return placePos(name)
end

local function setGps(name, pos)
	GPSClient.SetTarget(name, pos)
	mine = name
	setAt = os.clock()
end

-- Clear the GPS only if the target on it is still the one we set.
local function clearMine()
	if mine and GPSClient.Target() == mine then
		GPSClient.Clear()
	end
	mine = nil
end

function ObjectiveClient.RouteTo(name)
	local pos = gpsPos(name)
	if not pos then
		return false
	end
	local here = myPos()
	if here and flatDistance(pos, here) < GPS_SKIP then
		return false -- already there
	end
	return (pcall(setGps, name, pos))
end

function ObjectiveClient.Active()
	return active
end

function ObjectiveClient.SetGoalPlace(show)
	goalPlace = type(show) == "string" and show or nil
end

-- SHOW ME on the strip (the chip, J, gamepad L3): the GPS to the strip's next place right away. The
-- player asked for it, so it's theirs, not ours: no objective of ours clears it (GPSClient drops it on
-- arrival), and a route of ours still waiting is dropped. A toast says so every time (the route may
-- have been up already, and while wanted the readout is hidden under the escape line).
local function showMe()
	local name = current and current.route
	local pos = name and gpsPos(name)
	if not pos then
		return
	end
	local here = myPos()
	if here and flatDistance(pos, here) < GPS_SKIP then
		return -- already there
	end
	if pcall(GPSClient.SetTarget, name, pos) then
		mine, pending = nil, nil
		NotifyController.Show("GPS set: " .. (K.WHERE[name] or name), C.Gold, "info")
	end
end

-- "touch", "gamepad" or "keyboard": which key cap the chip shows (TutorialClient's test).
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

local function isMyHotCar(car)
	return car ~= nil and car:GetAttribute("HotCar") == true and car:GetAttribute("ThiefUserId") == player.UserId
end

-- "driving" at the wheel of our stolen hot car, "jacked" at the wheel of a car we jacked (CarjackService
-- marks it Jacked), "nearby" when our hot car is parked close by, else nil.
local function hotCarState()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local car = seat and seat.Parent
	if seat and seat.Name == "DriverSeat" and isMyHotCar(car) then
		return car:GetAttribute("Jacked") == true and "jacked" or "driving", car
	end
	if player:GetAttribute("BoostDelivery") ~= true then
		return nil
	end
	local here = myPos()
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if not here or not vehicles then
		return nil
	end
	for _, c in ipairs(vehicles:GetChildren()) do
		if isMyHotCar(c) and c:GetAttribute("Jacked") ~= true and c.PrimaryPart
			and flatDistance(c.PrimaryPart.Position, here) < HOT_CAR_NEAR then
			return "nearby", c
		end
	end
	return nil
end

-- On the Big Score's roster, out of prison: BigScoreClient's strip has the Goal zone.
local function bigScore()
	return player:GetAttribute("BigScore") ~= nil and player:GetAttribute("Side") ~= "Prisoner"
end

-- Races, job shifts, missions and the Big Score have their own banners.
local function busy()
	return player:GetAttribute("RacingId") ~= nil or player:GetAttribute("JobKind") ~= nil
		or player:GetAttribute("Mission") ~= nil or bigScore()
end

local function colorText(color, text)
	return string.format('<font color="#%s">%s</font>', color:ToHex(), text)
end

-- A small tag in the condensed Display face, inside rich text.
local function tagText(color, text)
	return string.format('<font face="Oswald" weight="bold" size="%d" color="#%s">%s</font>', tagSize,
		color:ToHex(), text)
end

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Guess when the cops last saw us, for the "stay hidden" countdown when HeatService hasn't published
-- EscapeAt (it drops the heat Config.Wanted EscapeAfter seconds after the last sighting).
local function trackSightings()
	local heat = player:GetAttribute("Heat") or 0
	if heat <= 0 then
		lastHeat = 0
		return
	end
	if player:GetAttribute("HeatSpotted") == true or heat > lastHeat then
		lastSeenAt = os.clock() -- seen right now, or a new crime was just reported
	end
	lastHeat = heat
end

-- What should the player do right now? nil = nothing to say.
-- Fields: key, tag, color (the tag and the strip's colour bar), title (rich text), detail (rich text,
-- the dim second line), escape ({ word, value, color } for the escape line, wanted only), gps (place
-- to route to), keep (set of our GPS targets worth keeping while this shows), flash, route (the place
-- the words name as the next step: SHOW ME / J routes there).
local function compute()
	if busy() then
		return nil
	end
	local side = player:GetAttribute("Side")
	if side == "Prisoner" then
		return {
			key = "prison", tag = "PRISON", color = C.Orange,
			title = "Find the vent in the yard",
			detail = "Pry it open, swim off. Or wait it out.",
			gps = VENT_NAME,
		}
	end
	if side ~= "Civilian" then
		return nil
	end
	local heat = player:GetAttribute("Heat") or 0
	local carried = player:GetAttribute("Carried") or 0
	local hot, car = hotCarState()
	-- A jacked car the Chop Shop won't buy (taken right by it) never suggests selling it.
	local sellable = hot == "jacked" and car:GetAttribute("JackSellable") ~= false
	local chopShop = K.WHERE[CHOP_SHOP]
	if heat > 0 then
		local spotted = player:GetAttribute("HeatSpotted") == true
		-- What comes after losing them. A bag comes first (it has its own Hideout route). Then a car the
		-- Chop Shop buys (a hot car, or a jacked one: a joyride first, but this is where it sells), or the
		-- goal chain's chop goal: named with its district, with SHOW ME, since this strip covers the goal.
		local nextStep, route
		if carried > 0 then
			nextStep = "Then bank your bag at the Hideout"
		elseif hot == "driving" or hot == "nearby" or sellable then
			nextStep, route = "Then the " .. chopShop, CHOP_SHOP
		elseif goalPlace == CHOP_SHOP and hot == nil then
			nextStep, route = "Then sell a car: " .. chopShop, CHOP_SHOP
		else
			nextStep = "Get out of sight and stay there"
		end
		local line
		local eta = player:GetAttribute("PoliceETA")
		local t = Workspace:GetServerTimeNow()
		if spotted then
			line = { word = "SEEN", value = "BREAK LINE OF SIGHT", color = C.Danger }
		elseif typeof(eta) == "number" and eta > t then
			line = { word = "PATROLS ARRIVE IN", value = clock(eta - t), color = C.Police }
		else
			local escapeAt = player:GetAttribute("EscapeAt") -- HeatService's exact escape time (server time)
			local exact = typeof(escapeAt) == "number"
			local left = exact and (escapeAt - t) or (lastSeenAt + Wanted.For(heat).EscapeAfter - os.clock())
			line = { word = "STAY HIDDEN", value = left > 1 and ((exact and "" or "ABOUT ") .. clock(left)) or nil,
				color = C.Dim }
		end
		return {
			key = "wanted", tag = "WANTED", color = spotted and C.Danger or C.Text, flash = spotted,
			title = "Lose the cops",
			detail = nextStep,
			escape = line,
			keep = { [HIDEOUT] = true, [CHOP_SHOP] = true },
			route = route,
		}
	end
	if carried > 0 then
		-- (The bag first: its route is the Hideout, so no SHOW ME for the Chop Shop here, just where it is.)
		return {
			key = "bank", tag = "BAG", color = C.Gold,
			title = "Bank " .. colorText(C.Gold, HUDController.Money(carried)) .. " at the Hideout",
			detail = (hot == "driving" and ("Or the hot car: " .. chopShop))
				or (sellable and ("Or sell the car: " .. chopShop))
				or "Follow the GPS to the Hideout pad.",
			gps = HIDEOUT,
		}
	end
	if hot == "jacked" and not sellable then
		return {
			key = "joyride", tag = "JACKED", color = C.Gold,
			title = "Joyride",
			detail = "Too close to the Chop Shop to sell.",
		}
	elseif hot == "jacked" then
		local value = car:GetAttribute("HotValue")
		return {
			key = "jacked", tag = "JACKED", color = C.Gold,
			title = "Joyride, or sell it",
			detail = type(value) == "number"
				and (chopShop .. " pays " .. colorText(C.Gold, HUDController.Money(value)))
				or "The Chop Shop is at the Docks.",
			keep = { [CHOP_SHOP] = true },
			route = CHOP_SHOP,
		}
	end
	if hot == "driving" then
		local value = car:GetAttribute("HotValue")
		return {
			key = "boost", tag = "HOT CAR", color = C.Gold,
			title = "Take it to the Chop Shop",
			detail = type(value) == "number" and ("At the Docks. Worth " .. colorText(C.Gold, HUDController.Money(value)))
				or "At the Docks. Lose any cops first.",
			gps = CHOP_SHOP,
			route = CHOP_SHOP,
		}
	elseif hot == "nearby" then
		return {
			key = "boostCar", tag = "HOT CAR", color = C.Gold,
			title = "Get back in your hot car",
			detail = "Then the " .. chopShop,
			keep = { [CHOP_SHOP] = true },
			route = CHOP_SHOP,
		}
	end
	return nil
end

local function textLabel(parent, name, kind)
	local l = Instance.new("TextLabel")
	l.Name = name
	Theme.Text(l, 14, kind)
	l.RichText = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = parent
	return l
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Objective"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- the zone map's coordinates (y = 0 is the very top of the screen)
	gui.Parent = player:WaitForChild("PlayerGui")

	-- The strip (Goal zone): flat dark panel, colour bar, tag + words, dim second line.
	banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.Visible = false
	Theme.Panel(banner)
	banner.Parent = gui

	accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Position = UDim2.fromOffset(ACCENT_X, 7)
	accent.Size = UDim2.new(0, ACCENT_W, 1, -14)
	accent.BackgroundColor3 = C.Text
	accent.BorderSizePixel = 0
	accent.Parent = banner
	Theme.Corners(accent, 1)

	titleLabel = textLabel(banner, "Title", "Bold")
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	detailLabel = textLabel(banner, "Detail", "Body")
	detailLabel.TextColor3 = C.Dim
	detailLabel.TextTruncate = Enum.TextTruncate.AtEnd
	detailLabel.AnchorPoint = Vector2.new(0, 1)

	-- SHOW ME, at the right end: a small flat chip, its word on the left and the key cap on the right
	-- (TutorialClient's goal pill button, so it reads as the same thing). Hidden until a step wants it.
	chip = Instance.new("TextButton")
	chip.Name = "ShowMe"
	Theme.Button(chip, "Quiet")
	chip.BackgroundColor3 = C.PanelLight
	chip.BackgroundTransparency = 0.15
	chip.TextSize = K.CHIP_TEXT
	chip.Text = "SHOW ME"
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.Position = UDim2.new(1, -6, 0.5, 0)
	chip.Visible = false
	chip.Parent = banner
	chipPad = Instance.new("UIPadding")
	chipPad.PaddingLeft = UDim.new(0, K.CHIP_PAD)
	chipPad.Parent = chip
	chipKey = Theme.Key(chip, K.SHOW_KEYS.keyboard)
	chipKey.AnchorPoint = Vector2.new(1, 0.5)
	chip.Activated:Connect(showMe)

	-- The escape line (Banner zone): words straight on the screen, centred, a small word and a big value.
	escape = Instance.new("Frame")
	escape.Name = "Escape"
	escape.BackgroundTransparency = 1
	escape.Visible = false
	escape.Parent = gui
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Padding = UDim.new(0, 10)
	row.Parent = escape
	escWord = textLabel(escape, "Word", "Bold")
	escWord.LayoutOrder = 1
	escValue = textLabel(escape, "Value", "Display")
	escValue.LayoutOrder = 2
	for _, l in ipairs({ escWord, escValue }) do
		l.RichText = false
		l.AutomaticSize = Enum.AutomaticSize.X
		l.Size = UDim2.new(0, 0, 1, 0)
	end
end

-- Put both pieces in their zones and size the words for this screen (phones get the smaller layout).
local function place()
	local touch = Theme.IsTouch()
	Theme.Place(banner, "Goal", touch)
	Theme.Place(escape, "Banner", touch)
	local titleSize, detailSize = touch and 14 or 15, 13
	tagSize = titleSize + 2 -- Oswald is condensed: a size up reads as the same height
	titleLabel.TextSize = titleSize
	titleLabel.Position = UDim2.fromOffset(TEXT_X, touch and 3 or 5)
	titleLabel.Size = UDim2.new(1, -(TEXT_X + wordsRight), 0, titleSize + 4)
	detailLabel.TextSize = detailSize
	detailLabel.Position = UDim2.new(0, TEXT_X, 1, touch and -3 or -5)
	detailLabel.Size = UDim2.new(1, -(TEXT_X + wordsRight), 0, detailSize + 3)
	escWord.TextSize = touch and 13 or 14
	escValue.TextSize = touch and 20 or 24
	chipLayout = nil -- (the strip's width or the device changed: the chip is laid out again)
end

-- The SHOW ME chip on (or off), with the word and key cap for this input and strip width, and the
-- words' room beside it. Laid out again only when one of those changes. The cap sits in the chip's right
-- padding; without one (touch) the word is centred and the chip is at least Theme.Touch big.
local function layoutChip(on)
	local touch = Theme.IsTouch()
	local mode = inputMode()
	local stripW = banner.AbsoluteSize.X
	local words = (stripW > 0 and stripW < K.COMPACT_W) and "GO" or "SHOW ME"
	local key = on and (mode .. "|" .. words .. "|" .. tostring(touch)) or "off"
	if key == chipLayout then
		return
	end
	chipLayout = key
	chip.Visible = on
	wordsRight = K.WORDS_RIGHT
	if on then
		local cap = K.SHOW_KEYS[mode]
		local padRight = K.CHIP_PAD
		chip.Text = words
		chip.TextXAlignment = cap and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
		chipKey.Visible = cap ~= nil
		if cap then
			local capW = math.max(22, 10 + utf8.len(cap) * 9) -- (as wide as its characters)
			chipKey.Text = cap
			chipKey.Size = UDim2.fromOffset(capW, 22)
			chipKey.Position = UDim2.new(1, capW + 6, 0.5, 0) -- 8 px in from the chip's right edge
			padRight = capW + 14
		end
		chipPad.PaddingRight = UDim.new(0, padRight)
		local textW = math.ceil(TextService:GetTextSize(words, K.CHIP_TEXT, Enum.Font.GothamBold, Vector2.new(1000, 100)).X)
		local w, h = K.CHIP_PAD + textW + padRight, K.CHIP_H
		if touch then
			w, h = math.max(w, Theme.Touch), Theme.Touch
		end
		chip.Size = UDim2.fromOffset(w, h)
		wordsRight = 6 + w + K.CHIP_GAP
	end
	titleLabel.Size = UDim2.new(1, -(TEXT_X + wordsRight), 0, titleLabel.Size.Y.Offset)
	detailLabel.Size = UDim2.new(1, -(TEXT_X + wordsRight), 0, detailLabel.Size.Y.Offset)
end

local function render(obj)
	local color = obj.color
	if obj.flash then
		blink = not blink
		color = blink and C.Text or obj.color
	end
	titleLabel.Text = tagText(color, obj.tag) .. "   " .. obj.title
	detailLabel.Text = obj.detail or ""
	accent.BackgroundColor3 = color
	local line = obj.escape
	if line then
		escWord.Text = line.word
		escWord.TextColor3 = line.color
		-- The big value carries the meaning too: red to break the line of sight, police blue for the
		-- patrols' head start; the plain "stay hidden" countdown is white beside its dim word.
		escValue.Text = line.value or ""
		escValue.TextColor3 = line.color == C.Dim and C.Text or line.color
		escValue.Visible = line.value ~= nil
	end
end

-- A new objective (or none): drop the old objective's route unless the new one wants or keeps it,
-- and queue the new one's route.
local function startObjective(obj)
	pending = nil
	retried = false
	local want = obj and obj.gps
	local keep = obj and obj.keep
	if mine and mine ~= want and not (keep and keep[mine]) then
		clearMine()
	end
	if want then
		pending = want
	end
end

local function tryPending()
	if not pending then
		return
	end
	local pos = gpsPos(pending)
	if not pos then
		return -- position not known yet (not streamed in): try again next update
	end
	local here = myPos()
	if here and flatDistance(pos, here) < GPS_SKIP then
		pending = nil
		return -- already there
	end
	-- Only drop the pending route once it's really set (if GPSClient hasn't built its pillar yet the
	-- call errors, and we try again next update instead of losing the route).
	if pcall(setGps, pending, pos) then
		pending = nil
	end
end

-- Would a stamp starting at y = stampTop draw over this piece? (Stamps sit in the upper middle.)
-- StampTop is in zone coordinates (y = 0 at the very top of the screen), but AbsolutePosition starts
-- under the top bar whatever IgnoreGuiInset says, so the piece is measured from our ScreenGui's corner
-- (right whichever way Roblox counts it, as MinimapClient and SoundClient do).
local function covered(frame, stampTop)
	if stampTop == nil then
		return false
	end
	local top = frame.AbsolutePosition.Y - gui.AbsolutePosition.Y
	return stampTop < top + frame.AbsoluteSize.Y
end

local function update()
	trackSightings()
	local obj = compute()
	if (obj and obj.key) ~= (current and current.key) then
		startObjective(obj)
	end
	current = obj
	-- GPSClient clears the route when your side changes (e.g. going to prison). If that wiped the
	-- route we set a moment ago, put it back once.
	if mine and obj and obj.gps == mine and not retried and GPSClient.Target() == nil and os.clock() - setAt < 1.5 then
		retried = true
		pending = mine
	end
	tryPending()
	if obj then
		render(obj)
	end
	local nowActive = obj ~= nil
	-- Off on the title screen; stepped aside while a big stamp ("+$900 in your bag", "HOT CAR STOLEN")
	-- draws over it. `active` stays true meanwhile, so the tutorial's goal stays hidden too.
	local shown = nowActive and player:GetAttribute("TitleScreen") ~= true
	local stampTop = HUDController.StampTop and HUDController.StampTop()
	local stripOn = shown and not covered(banner, stampTop)
	local escapeOn = shown and obj.escape ~= nil and not covered(escape, stampTop)
	if banner.Visible ~= stripOn then
		banner.Visible = stripOn
	end
	-- SHOW ME whenever the words name a next place, even with the GPS already on it: the jack's own
	-- suggestion usually is, and while wanted its readout is hidden, so the key on screen is what says
	-- "this is where, press J".
	layoutChip(stripOn and obj.route ~= nil)
	if escape.Visible ~= escapeOn then
		escape.Visible = escapeOn
	end
	-- The Big Score's strip counts too (our own strip stays hidden: compute() said nothing above).
	nowActive = nowActive or bigScore()
	if nowActive ~= active then
		active = nowActive
		changed:Fire(active)
	end
end

function ObjectiveClient.Init()
	build()
	place()
	-- Re-place when the screen changes size or the device's input changes (a mouse plugged into a tablet).
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	UserInputService:GetPropertyChangedSignal("MouseEnabled"):Connect(place)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(place)
	-- The SHOW ME shortcut (J / gamepad L3) while the strip's next step is a place, even while a stamp
	-- has the strip stepped aside. TutorialClient's pill answers the same keys only while it shows, and
	-- it steps aside whenever this strip is active, so the two never both answer.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not K.SHOW_KEYCODES[input.KeyCode] then
			return
		end
		if current and current.route and player:GetAttribute("TitleScreen") ~= true then
			showMe()
		end
	end)
	-- Stars go hollow HollowAfter s after the last sighting (Config.Wanted), so that's when they last saw us.
	player:GetAttributeChangedSignal("HeatSpotted"):Connect(function()
		if player:GetAttribute("HeatSpotted") ~= true then
			lastSeenAt = os.clock() - Wanted.For(player:GetAttribute("Heat")).HollowAfter
		end
	end)
	-- Just stole a hot car: say where it goes and route there right away.
	player:GetAttributeChangedSignal("BoostStolenAt"):Connect(function()
		if player:GetAttribute("BoostStolenAt") ~= nil and player:GetAttribute("Side") == "Civilian" then
			local routed = ObjectiveClient.RouteTo(CHOP_SHOP)
			HUDController.Stamp("HOT CAR STOLEN", "Take it to the Chop Shop at the Docks" .. (routed and " (GPS set)" or ""), C.Gold)
		end
	end)
	-- Just jacked a car: stamp it, and suggest the Chop Shop on the GPS, but never over a target the player
	-- picked (then theirs stays), never over the route of the objective on screen (the Hideout for a bag,
	-- the vent...), never with cash in the bag, and not for a car the Chop Shop won't buy. Not routed, the
	-- strip's SHOW ME (J) is there for it.
	Remotes.OnClient("Carjacked", function(info)
		if type(info) ~= "table" then
			return
		end
		local title = info.Alarm and "CAR ALARM" or "CAR JACKED"
		local color = info.Alarm and C.Danger or C.Text
		if info.Sellable == false then
			HUDController.Stamp(title, "Joyride: too close to the Chop Shop to sell it", color)
			return
		end
		local value = tonumber(info.Value)
		local sell = "sell it at the " .. K.WHERE[CHOP_SHOP] .. (value and (" for " .. HUDController.Money(value)) or "")
		local gpsTarget = GPSClient.Target()
		local free = (gpsTarget == nil or gpsTarget == mine) and not (current and current.gps)
			and (player:GetAttribute("Carried") or 0) <= 0
		local routed = free and ObjectiveClient.RouteTo(CHOP_SHOP)
		HUDController.Stamp(title, "Joyride, or " .. sell .. (routed and " (GPS set)" or ""), color)
	end)
	task.spawn(function()
		while true do
			-- Wait first: the first update then runs after every controller's Init (GPS included).
			task.wait(UPDATE_EVERY)
			local ok, err = pcall(update)
			if not ok then
				warn("[ObjectiveClient] " .. tostring(err))
			end
		end
	end)
end

return ObjectiveClient
