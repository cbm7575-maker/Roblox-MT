-- PhoneUI (ModuleScript, StarterPlayerScripts.Controllers.PhoneUI)
-- The in-game phone (the PHONE tile or P; a tap or click anywhere around it puts it away), drawn as a
-- modern smartphone in the flat "street" look
-- (Shared.Util.Theme): a slim dark body with a thin bezel and small corners, a status bar (the game's
-- clock from Lighting.ClockTime, your cash in a small island, signal bars and a battery drawn from
-- frames), a home screen (a dark wallpaper, a big clock when the screen is tall enough, and a grid of
-- flat square app icons: a white glyph drawn from frames on a coloured tile, a small label under it),
-- app pages with a clean header (back chevron, the title in the Display font) and list rows separated
-- by thin lines, flat buttons, and a home bar at the bottom (on a page: back to the home screen; on the
-- home screen: puts the phone away).
-- Raising it: the phone comes up from the lower right, tilted like a phone in a hand, and settles
-- upright in K.Raise seconds; putting it away is the reverse (K.Lower). A turned frame can't clip what
-- is inside it, so the page is hidden and the glass stays dark while the phone moves, and the screen
-- lights up once it is upright. While it is up your character holds a phone and looks down at it, legs
-- still walking (PoseClient's "PhoneLook", shown to everyone; not while seated, and nothing happens if
-- that controller isn't there).
-- Sizes: the phone is laid out at a fixed design width (K.W) and a UIScale ("Fit") shrinks it on small
-- screens (0.7 on a phone). Tap targets are at least Theme.Touch REAL pixels tall after that scale
-- (touchHeight) and text at least K.MinText real pixels (textPx), so pages measure their rows from those
-- two instead of fixed numbers, and rows with sentences in them size themselves to their words. A new
-- screen size draws the open page again.
-- Its right edge stays left of the HUD's Buttons zone (bodyRight), so the PHONE / CAR tiles stay usable.
-- Putting it away by tapping around it: nothing is laid over the screen for that, so every HUD button
-- works as before whether the phone is up or not. A quick tap or click (K.TapTime, K.TapSlop) that no
-- GUI took (the street, the sky, a plain label) and that lands outside the phone's body closes it; taps
-- on the phone itself (S.phoneTouchAt), drags (thumbstick, camera) and long presses never do.
-- Apps:
--   GARAGE    your cars for your current role (bought, starter, game-pass and cop-rank cars): DELIVER
--             (spawn), STYLE: paint and rims are owned per car (a new colour $500 / rim style $1,500
--             once on that car, then switching back is free; the car's stock paint and chrome rims are
--             always owned; pass and unlock ones are free once you have them), underglow $3,000 once
--             per car, then free colour swaps (Config.Garage's STYLE notes; GarageService charges by the
--             same Garage.StyleCost). Thumb-sized swatches with a caption under each: its price, OWNED,
--             STOCK, FREE, ON (the one fitted: white ring) or what unlocks it (padlock). A swatch that
--             costs money takes two taps: the first arms it (green ring, AGAIN, "TAP AGAIN TO BUY"
--             above the grid, for K.StyleArmTime seconds), only the second sends the request, so one
--             tap never spends anything. Boats have no STYLE (their hulls keep the factory colours).
--             TUNE (a strip on every land car that isn't a police car, so the page is two taps from
--             the home screen; it reads SPEED + SOUND on a stock car): AUTO TUNE on top (shows its
--             total and what it buys, second tap confirms), bars for top speed / acceleration /
--             braking / grip / nitro (white = stock, pink = tuned; each bar is scaled to THIS car,
--             from 70% of stock to fully tuned, so every stage is a step you can see; the numbers on
--             the right stay absolute), the exhaust picker right under them so both halves of
--             "faster and better sounding" are on the first screen (sound only: bought once per car,
--             then free swaps), then the five upgrade tracks with stage pips, the next gain and its
--             price.
--             Exhausts: tapping a chip only ever plays its rev (the fitted one too, to compare), as
--             often as you like, and never costs anything. A chip that isn't bought yet is then
--             offered on the BUY button in the picker's head row ("BUY $8,000" over "RACE", for
--             EXHAUST_PICK_TIME seconds; the chip gets a thin pink line): that button is the only
--             thing that pays for an exhaust, so listening again can't buy one by mistake. A chip
--             bought earlier fits with one tap (free).
--             Buying an upgrade works like a tuning shop: the first tap turns the button green (TAP
--             AGAIN) and shows the gain before you pay, as a see-through pink piece on the bars and
--             the new number in pink; the second tap sends it and the button reads FITTING... until
--             the server answers (a refusal or no answer puts it back). Then the engine revs in the
--             car's own exhaust note (SoundClient.PreviewExhaust), a toast shows, the row flashes
--             and the bars glide to their new length. Prices, gains and the plan AUTO TUNE shows
--             come from Config.Garage, the same helpers GarageService charges with. Each request
--             says what the button showed (the stage, or the stages AUTO TUNE started from), so a
--             second try after a slow answer never buys the next, dearer thing (GarageService).
--             Theme's see-through black can't be seen on the phone's near-black screen, so the page's
--             quiet buttons and its stat panel use Theme's lighter panel colour (lift / tuneButton;
--             every other page's quiet buttons get the same look from flat) and a bar's empty part is
--             dim grey, like an empty stage pip. The page's code sits in one block between the "TUNE
--             page" banner and placePos and keeps its own constants and state as locals, so it can be
--             worked on by itself. Its text floor is K.TuneMinText real pixels, not K.MinText: its
--             chips and columns were measured for that.
--   AUTONEON  browse every car and boat (class, four small stat bars, price or lock); buying happens in
--             person, so each row's button routes you to AutoNeon Motors (cars) or Marina Boat Sales
--   HOME      homes for sale (HouseClient): price, garage size, distance, GPS to the door, GO HOME
--   GPS       races, stunts, jobs, services and heist sites (open ones marked): sets a road route
--   JOBS      police duty, an optional job (GO ON DUTY / GO OFF DUTY: RequestTeam; TeamService checks
--             heat, the cooldown and the cop cap and says why in a toast; the phone goes away when the
--             switch lands), the three street jobs, and the phone missions. Everyone joins free roam.
--   SHOP      every game pass and cash pack with its Robux price (Config.Shop's until the item has a
--             real Id, then read live from Roblox): OWNED, BUY (Roblox's prompt), SOON ("Coming soon"
--             while the Id is 0) or FREE in Studio and for the game's owner (player attribute
--             "ShopFree", ShopService: RequestShopFree, checked on the server); cash packs add cash
--             only (they can't skip heist locks, cop ranks or passes)
--   GOALS     both ranks with their XP bars and next unlock, and today's challenges
--   EMPIRE    player businesses (BusinessClient; only while BusinessesOn): your Empire rank, your businesses
--             (register, GPS, COLLECT from the phone at Empire 5+), businesses for sale, and coming soon
--   SPIN      the daily spin (SpinClient): today's spin or when the next comes, the 2X boosts running, and
--             GPS TO THE LUCKY WHEEL (the wheel downtown where the spin happens; sets the GPS and puts the
--             phone away). A red dot on the tile while a spin is ready.
--   CREW      INVITE FRIENDS (Roblox's own invite pop-up, hidden when Roblox says this player can't send
--             invites), THE BIG SCORE (the crew heist, BigScoreService: one line on whether you could
--             start it right now, worked out here from your crew, rank, cooldown and whether another
--             crew is on it, its countdown kept fresh in place; START, or QUIT with a second tap while
--             you're on it), crew invites for players here, friends in other servers of the game with JOIN
--             (FriendsService teleports), and the play-together bonus and Squad paint progress
--   SETTINGS  radio and sound volume, performance mode, passive mode (and the key list on a keyboard)
-- Under the apps, HOW TO PLAY opens a guide to every feature: topic chips at the top jump to short
-- sections with GPS and OPEN buttons (a page opened from it goes Back to it; put away on it, it reopens
-- there for a while). Touch players see their on-screen buttons instead of keys, and the street-car lines
-- only show once CarjackService runs. The button pulses the first time the home screen shows each
-- session. Where a number the guide quotes lives in a shared config, it's read from there.
-- Hidden vehicles (Config.Vehicles Hidden = true: street-only cars) never show in any list here.
-- The server decides everything (GarageService, VehicleService); this only sends requests.
-- Gamepad / keyboard UI navigation: a redraw keeps the selection on the same button (show finds its
-- twin on the new page), and a new page, or the phone opening while something else is selected,
-- moves it to the page's first button; Close lets go of it. Two-press buys (TUNE) need that: the first
-- press redraws the page. Gamepad B, while a phone button is selected and you aren't seated, goes Back
-- (or puts the phone away on the home screen). Gamepad D-pad down raises the phone, and puts it away
-- while none of its buttons is selected; raised that way on foot, the selection goes to the page's first
-- button (not in a car: B gets out there). Never while the dressing room is open (WardrobeUI).
-- PhoneUI.Open(pageName?, arg?): pageName is one of PAGES' keys ("Garage", "Shop", "Goals"...; none =
-- the home screen). "Tune" and "Custom" open on one car's page: arg = its vehicle id (the dealer's
-- TUNE IT button uses PhoneUI.Open("Tune", id)). On a phone that is already up, Open just changes the
-- page. PhoneUI.Close(), Toggle(), IsOpen() (false from the moment it is put away; "Body" stays Visible
-- a moment longer while it slides out). PhoneUI.Refresh(pageName) redraws that page if it's the one up.
-- Names other code and the Studio test tools use (keep them): ScreenGui "Phone" > "PhoneButton" (the
-- HUD tile, HUDController.ZoneButton) and "Body" (OfferClient, MinimapClient, AmbienceClient,
-- DealerClient and TutorialClient watch its Visible) > "Fit", "Back", "HomeBar" and "Screen" > the page.
-- Home screen: "Apps".<page key>, "Guide", "GuideHint". Pages: "List".<row>.<button>: Garage
-- List.<carId>.Deliver / Style / Tune; STYLE List.Paint / Rims / Underglow > Frame.Swatch<n> and Status
-- (Paint's Swatch1 is the car's stock colour, so paint i is Swatch<i + 1>; Rims and Underglow start at 1);
-- JOBS List.Duty.Duty; TUNE List.AutoTune, List.Stats, List.ExhaustHead.BuyExhaust, List.Exhausts.<key>, List.<track>; AUTONEON
-- and SHOP List.<id>.Buy; HOME List.MyHome.GoHome, List.<homeId>.Go; GPS "Tabs".<Activity|Heist|Service>,
-- List.<place>.Go; JOBS List.<missionId>.Start; CREW List.InviteFriends, List.BigScore.Start / Quit, List.<UserId>.Invite,
-- List.Friend<UserId>.Join, List.Leave, List.PlayTogether; SETTINGS List.Music.Music<1-5>,
-- List.Effects.Effects<1-5>, List.Performance.Toggle, List.Passive.Toggle; guide List.Topics.<section>,
-- List.<section>.
-- This file is big: a Luau function (the top of a file counts as one) may hold 200 locals at most, so
-- constants live in K, widget references in ui, state in S and crew, widget builders in W and pages in
-- PAGES (the TUNE block keeps its own locals). Count the top-level locals before adding one.

local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Shop = require(ReplicatedStorage.Shared.Config.Shop)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Garage = require(ReplicatedStorage.Shared.Config.Garage)
local Heists = require(ReplicatedStorage.Shared.Config.Heists)
local Housing = require(ReplicatedStorage.Shared.Config.Housing)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Activities = require(ReplicatedStorage.Shared.Config.Activities)
local Teams = require(ReplicatedStorage.Shared.Config.Teams)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local Theme = require(ReplicatedStorage.Shared.Util.Theme)
local NotifyController = require(script.Parent:WaitForChild("NotifyController"))
local GPSClient = require(script.Parent:WaitForChild("GPSClient"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))

local player = Players.LocalPlayer

local PhoneUI = {}

local C = Theme.Color
local money = HUDController.Money

-- Every number and colour the phone is built from.
local K = {
	W = 360, -- the phone's design width (the UIScale "Fit" fits it to the screen)
	Bezel = 7, -- from the body's edge to the glass
	Inset = 20, -- from the body's edge to the page ("Screen": 320 design pixels wide)
	Status = 30, -- height of the status bar
	MinText = 13, -- smallest text, in real pixels (textPx)
	TuneMinText = 12, -- ...on the TUNE page (see the header)
	Raise = 0.25, -- seconds the phone takes to come up
	Lower = 0.18, -- ...and to go away
	Tilt = 7, -- degrees it leans (clockwise) on its way
	Drop = 0.85, -- how far below its resting place it starts, as a share of the screen's height
	Slip = 36, -- ...and how far to the right of it, in pixels
	Round = 22, -- the body's corner radius
	Wake = 0.15, -- seconds the dark screen takes to light up once the phone is upright
	ResumeFor = 600, -- seconds HOW TO PLAY reopens where it was put away (BACK or the home bar on the guide forget it)

	-- The phone's own colours (Theme has no names for them).
	Case = Color3.fromRGB(18, 19, 23),
	Edge = Color3.fromRGB(72, 76, 86),
	Glass = Color3.fromRGB(9, 11, 15),
	WallTop = Color3.fromRGB(34, 22, 54), -- the home screen's wallpaper, top...
	WallFoot = Color3.fromRGB(8, 34, 44), -- ...and foot
	Card = Color3.fromRGB(21, 24, 30),
	Ink = Color3.fromRGB(12, 14, 18), -- dark words on a white or gold button

	StudsToMph = 0.626, -- same as the speed gauge (DriveUI)
	StyleArmTime = 4, -- seconds a STYLE swatch that costs money waits for its second tap
	TapTime = 0.4, -- a tap around the phone that puts it away: released within this many seconds...
	TapSlop = 16, -- ...having moved at most this many pixels (more is a drag: thumbstick, camera)
	DutyWait = 10, -- seconds after GO ON / OFF DUTY in which a side change puts the phone away

	-- CREW page
	FriendsFresh = 30, -- seconds a friends list is reused (Roblox caches it about that long too)
	MaxFriendRows = 8,
	JoinWait = 8, -- seconds a JOIN button shows JOINING... (the teleport or the server's refusal comes first)

	GpsTabs = { { "Activity", "FUN" }, { "Heist", "HEISTS" }, { "Service", "PLACES" } },
	-- GPS fallbacks for the dealerships until DealershipService's entries reach the Places list.
	Dealers = {
		Cars = { Name = "AutoNeon Motors", Pos = Vector3.new(-150, 0, -537) },
		Boats = { Name = "Marina Boat Sales", Pos = Vector3.new(1678, 0, 1096) },
	},
	-- The home screen, in order: the label, the PAGES key (also the tile's Name and its glyph in W.glyph)
	-- and the tile's colour; Show (optional) = a function: the tile is only there while it says true.
	Apps = {
		{ Name = "GARAGE", Page = "Garage", Color = Color3.fromRGB(226, 62, 110) },
		{ Name = "AUTONEON", Page = "Dealer", Color = Color3.fromRGB(38, 140, 210) },
		{ Name = "GPS", Page = "GPS", Color = Color3.fromRGB(46, 160, 96) },
		{ Name = "JOBS", Page = "Jobs", Color = Color3.fromRGB(208, 132, 38) },
		{ Name = "SHOP", Page = "Shop", Color = Color3.fromRGB(136, 98, 222) },
		{ Name = "GOALS", Page = "Goals", Color = Color3.fromRGB(200, 150, 32) },
		-- The daily spin at the Lucky Wheel (SpinClient); Badge: a dot on the tile while today's spin is unused.
		{ Name = "SPIN", Page = "Spin", Color = Color3.fromRGB(232, 168, 28), Badge = function()
			return player:GetAttribute("SpinReady") == true
		end },
		{ Name = "CREW", Page = "Crew", Color = Color3.fromRGB(30, 160, 150) },
		{ Name = "HOME", Page = "Home_", Color = Color3.fromRGB(224, 104, 58) },
		-- Empire (BusinessClient): only while the feature runs in this server (Show; see Config.Businesses.Live).
		{ Name = "EMPIRE", Page = "Empire", Color = Color3.fromRGB(196, 150, 40), Show = function()
			return ReplicatedStorage:GetAttribute("BusinessesOn") == true
		end },
		{ Name = "SETTINGS", Page = "Settings", Color = Color3.fromRGB(98, 106, 120) },
	},
}

-- The phone's lasting pieces (build): gui, openButton, fit, glass, wall, clock, island, cash, icons and
-- chevron (the UIScales of the status glyphs and the back chevron), back, title, titleCap, headRule,
-- screen, homeBar, cover.
local ui = {}
local phone -- the phone's body (frame "Body"): Visible while it is up or sliding

-- What the phone is doing.
local S = {
	open = false, -- up (or on its way up): what IsOpen answers
	anim = 0, -- counts raises and lowers, so a finished slide knows if it is still the latest
	sliding = false, -- on its way up or down right now
	tweens = {}, -- the tweens of that slide (stopSlide)
	back = nil, -- the PAGES key Back goes to, or nil on the home screen
	minText = K.MinText, -- the text floor of the page being drawn (show sets it)
	gpsTab = "Activity",
	fromGuide = false, -- the page on screen was opened from HOW TO PLAY: its Back goes to the guide
	guideScroll = nil, -- the guide's scroll position while one of its OPEN pages is showing
	guideResume = nil, -- { Pos, At = os.clock() }: where the guide was when the phone was put away on it
	guideHinted = false, -- the HOW TO PLAY button has had its once-a-session pulse
	posed = false, -- the character is holding its phone (PoseClient)
	styleArm = nil, -- { key = "Paints:<carId>:<index>", at = os.clock() }: the STYLE swatch waiting for its second tap
	dutyAskedAt = -math.huge, -- when JOBS last asked to go on / off duty
	phoneTouchAt = -math.huge, -- the last tap or click that began on the phone itself (never puts it away)
	taps = {}, -- [touch InputObject or "Mouse"] = { pos, at }: taps around the open phone not yet let go
}

local current = "Home" -- the PAGES key on screen (show keeps it)
local detailId -- car shown on the Garage detail pages (STYLE and TUNE)

local W = {} -- the phone's widget builders
local PAGES = {} -- [page key] = the function that draws that page into ui.screen
local show -- forward declaration: show(pageKey) draws a page

------------------------------------------------------------------ small helpers

local function sfx(name)
	pcall(function()
		require(script.Parent:WaitForChild("SoundClient")).Play(name)
	end)
end

-- The phone is drawn at a fixed design size and shrunk by a UIScale on small screens, so a tap target
-- needs this many design pixels to still be Theme.Touch real pixels tall.
local function touchHeight()
	return math.ceil(Theme.Touch / math.max(ui.fit.Scale, 0.5))
end

-- Text needs the same care: at the phone's 0.7 scale a 13 px label would be 9 real pixels. Every label
-- is at least K.MinText real pixels (S.minText: the page being drawn may have its own floor); sizes
-- already bigger than that stay as they are, so a PC (scale 1-1.1) sees exactly the sizes asked for.
local function textPx(px)
	return math.max(px, math.ceil(S.minText / math.max(ui.fit.Scale, 0.5)))
end

-- A label in the Theme fonts at a fixed size (px, raised by textPx on small screens: lay out with
-- textPx(px) too). onPanel = true adds Theme's soft shadow (text over the wallpaper or a see-through
-- panel); text on the page's dark screen or on a button goes without.
local function themeText(parent, text, size, pos, px, kind, color, align, onPanel)
	px = textPx(px)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos or UDim2.new()
	l.BackgroundTransparency = 1
	l.FontFace = Theme.Font[kind or "Body"]
	l.TextSize = px
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = text
	if onPanel then
		Theme.Text(l, px, kind)
	end
	l.TextColor3 = color or C.Text
	l.Parent = parent
	return l
end

-- Theme.Button as it looks on the phone's own screen. kind: "Primary" (white), "Quiet", "Danger", or
-- "Confirm" (a buy button waiting for its second tap: cash green). Theme's quiet button is see-through
-- black, made to sit over the street; on the phone's near-black screen it couldn't be told from the
-- page, so here it is Theme's lighter panel colour (the same look as the TUNE page's lift).
local function flat(b, kind)
	Theme.Button(b, kind == "Confirm" and "Primary" or kind)
	if kind == "Confirm" then
		b.BackgroundColor3 = C.Cash
	elseif kind == nil or kind == "Quiet" then
		b.BackgroundColor3 = C.PanelLight
		b.BackgroundTransparency = 0.2
	end
	return b
end

-- A flat button as wide as its parent. Its words are labels laid on top (taps pass through them),
-- coloured with the button's own TextColor3.
local function themeButton(parent, name, height, order, kind, onTap)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.new(1, 0, 0, height)
	b.LayoutOrder = order
	b.Text = ""
	flat(b, kind)
	b.Parent = parent
	b.Activated:Connect(function()
		sfx("Click")
		onTap()
	end)
	return b
end

-- Stage pips: `have` of `max` little squares filled.
local function pips(parent, pos, have, max, color)
	local f = Instance.new("Frame")
	f.Name = "Pips"
	f.BackgroundTransparency = 1
	f.Position = pos
	f.Size = UDim2.fromOffset(max * 14 - 4, 10)
	f.Parent = parent
	for i = 1, max do
		local p = Instance.new("Frame")
		p.Name = "Pip" .. i
		p.Size = UDim2.fromOffset(10, 10)
		p.Position = UDim2.fromOffset((i - 1) * 14, 0)
		p.BorderSizePixel = 0
		p.BackgroundColor3 = i <= have and color or C.Dim
		p.BackgroundTransparency = i <= have and 0 or 0.75
		Theme.Corners(p, 2)
		p.Parent = f
	end
	return f
end

-- Same rules as GarageService.Owns: the saved list ("OwnedCars"), a game pass, or a high enough cop rank.
local function owned()
	local set = {}
	for id in string.gmatch(player:GetAttribute("OwnedCars") or "", "[^,]+") do
		set[id] = true
	end
	local copRank = player:GetAttribute("CopRank") or 0
	for _, def in ipairs(Vehicles.List) do
		if def.Hidden then
			continue -- street-only cars are never owned
		end
		if (def.Pass and player:GetAttribute("Pass_" .. def.Pass)) or (def.UnlockCopRank and copRank >= def.UnlockCopRank) then
			set[def.Id] = true
		end
	end
	return set
end

local function customOf(id)
	local s = player:GetAttribute("Custom_" .. id)
	if not s then
		return 0, 0, 0
	end
	local a, b, c = string.match(s, "(%d+),(%d+),?(%d*)")
	return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

-- Paints and rims bought for this car (GarageService mirrors "Style_<id>" = "3,5;2"), as sets with
-- string keys: the shape Garage.StyleCost takes.
local function styleOf(id)
	local text = player:GetAttribute("Style_" .. id)
	local paints, rims = {}, {}
	if type(text) == "string" then
		local p, r = string.match(text, "^([%d,]*);([%d,]*)$")
		for n in string.gmatch(p or "", "%d+") do
			paints[n] = true
		end
		for n in string.gmatch(r or "", "%d+") do
			rims[n] = true
		end
	end
	return paints, rims
end

local function canDrive(def)
	local side = player:GetAttribute("Side") or "Civilian"
	return (def.Police == true) == (side == "Cop")
end

------------------------------------------------------------------ widgets (the phone's flat look)

-- A see-through frame to hold other pieces.
function W.frame(parent, name, order)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.LayoutOrder = order or 0
	f.Parent = parent
	return f
end

-- A solid block (a line, a tile, one piece of a glyph): pixels from its parent's corner, r = corner radius.
function W.block(parent, name, x, y, w, h, color, r, z)
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color or C.Text
	f.BorderSizePixel = 0
	f.ZIndex = z or 1
	if r and r > 0 then
		Theme.Corners(f, r)
	end
	f.Parent = parent
	return f
end

-- A thin outline round a frame.
function W.ring(obj, color, thick)
	local s = Instance.new("UIStroke")
	s.Color = color or C.Text
	s.Thickness = thick or 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

-- The thin line that separates list rows (along the top of a row).
function W.rule(parent)
	local f = W.block(parent, "Rule", 0, 0, 1, 1)
	f.Size = UDim2.new(1, 0, 0, 1)
	f.BackgroundTransparency = 0.88
	return f
end

-- A flat button with its own words in the Display font (DELIVER, GO, BUY...). The caller places it.
function W.button(parent, name, text, kind, onTap)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	flat(b, kind)
	b.FontFace = Theme.Font.Display
	b.TextSize = textPx(15)
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Parent = parent
	b.Activated:Connect(function()
		sfx("Click")
		if onTap then
			onTap()
		end
	end)
	return b
end

-- The page's scrolling list ("List": show keeps its scroll position across redraws), filling the page
-- below `top` pixels. Rows sit `gap` pixels apart (none: they draw their own thin lines).
function W.list(top, gap)
	top = top or 0
	local s = Instance.new("ScrollingFrame")
	s.Name = "List"
	s.Position = UDim2.fromOffset(0, top)
	s.Size = UDim2.new(1, 0, 1, -top)
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 3
	s.ScrollBarImageColor3 = C.Dim
	s.ScrollBarImageTransparency = 0.4
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.CanvasSize = UDim2.new()
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.Parent = ui.screen
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap or 0)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = s
	local p = Instance.new("UIPadding")
	p.PaddingRight = UDim.new(0, 6)
	p.Parent = s
	return s
end

-- The TUNE page's list: below `top` (a share of the page's height), its buttons 8 pixels apart.
local function list(top)
	return W.list(math.floor(ui.screen.Size.Y.Offset * top + 0.5), 8)
end

-- A list row of a fixed height: see-through, a thin line along its top.
function W.row(parent, name, height, order)
	local f = W.frame(parent, name or "Frame", order)
	f.Size = UDim2.new(1, 0, 0, height)
	W.rule(f)
	return f
end

-- Empty room between two things in a list.
function W.gap(parent, order, px)
	local f = W.frame(parent, "Gap", order)
	f.Size = UDim2.new(1, 0, 0, px)
	return f
end

-- A section head: small dim capitals over the rows that follow (as tall as its words need).
function W.head(parent, text, order, color)
	local l = themeText(parent, text, UDim2.fromScale(1, 0), nil, 13, "Bold", color or C.Dim)
	l.Name = "Head"
	l.LayoutOrder = order or 0
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextWrapped = true
	l.TextTruncate = Enum.TextTruncate.None
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 16), UDim.new(0, 6)
	pad.Parent = l
	return l
end

-- A few dim lines of help text, as tall as its words need.
function W.note(parent, text, order, color, align)
	local l = themeText(parent, text, UDim2.fromScale(1, 0), nil, 13, "Body", color or C.Dim, align)
	l.Name = "Note"
	l.LayoutOrder = order or 0
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextWrapped = true
	l.TextTruncate = Enum.TextTruncate.None
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = l
	return l
end

-- One list row: a bold title over dim lines on the left (each line wraps, so the row is as tall as its
-- words need) and, if asked for, one flat thumb-sized button on the right. A thin line along the top
-- separates it from the row above. Every piece is placed in pixels from the row's top, so the row can
-- size itself (AutomaticSize).
-- o = { Name, Order, Title, TitleColor, Sub, SubColor, Meta, MetaColor, Button (its words), ButtonName,
--       Kind, Width, OnTap }
-- Returns the row, the button (or nil) and the words' column: its lines have LayoutOrder 10 (title), 20
-- (sub) and 30 (meta), so a caller can slip a bar in between (W.meter).
function W.item(parent, o)
	local touch = touchHeight()
	local r = W.frame(parent, o.Name or "Frame", o.Order)
	r.Size = UDim2.fromScale(1, 0)
	r.AutomaticSize = Enum.AutomaticSize.Y
	W.rule(r)
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 9)
	pad.Parent = r
	local width = o.Button and (o.Width or 96) or 0
	local words = W.frame(r, "Words")
	words.Position = UDim2.fromOffset(0, 9)
	words.Size = UDim2.new(1, -(width > 0 and width + 10 or 0), 0, 0)
	words.AutomaticSize = Enum.AutomaticSize.Y
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.VerticalAlignment = Enum.VerticalAlignment.Center
	stack.Padding = UDim.new(0, 3)
	stack.Parent = words
	if o.Button then
		-- At least as tall as the button, so a short row's words sit centred beside it.
		local min = Instance.new("UISizeConstraint")
		min.MinSize = Vector2.new(0, touch)
		min.Parent = words
	end
	local function line(name, order, text, px, kind, color)
		local l = themeText(words, text, UDim2.fromScale(1, 0), nil, px, kind, color)
		l.Name = name
		l.LayoutOrder = order
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.TextWrapped = true
		l.TextTruncate = Enum.TextTruncate.None
		return l
	end
	if o.Title then
		line("Title", 10, o.Title, 15, "Bold", o.TitleColor)
	end
	if o.Sub and o.Sub ~= "" then
		line("Sub", 20, o.Sub, 13, "Body", o.SubColor or C.Dim)
	end
	if o.Meta and o.Meta ~= "" then
		line("Meta", 30, o.Meta, 14, "Display", o.MetaColor or C.Dim)
	end
	local b
	if o.Button then
		b = W.button(r, o.ButtonName or "Go", o.Button, o.Kind, o.OnTap)
		b.AnchorPoint = Vector2.new(1, 0)
		b.Position = UDim2.new(1, 0, 0, 9)
		b.Size = UDim2.fromOffset(width, touch)
	end
	return r, b, words
end

-- A thin progress bar as one line of a row's words; `text` (optional) is its count, on the right.
function W.meter(parent, order, share, color, text)
	local small = textPx(13)
	local f = W.frame(parent, "Meter", order)
	f.Size = UDim2.new(1, 0, 0, text and small + 4 or 12)
	local room = text and math.ceil(#text * small * 0.5) + 12 or 0
	local bar, fill = Theme.Bar(f, color)
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.fromScale(0, 0.5)
	bar.Size = UDim2.new(1, -room, 0, 6)
	bar.BackgroundColor3 = C.Dim -- the empty part: dim grey, like the TUNE page's bars
	bar.BackgroundTransparency = 0.75
	fill.Size = UDim2.fromScale(math.clamp(share, 0.02, 1), 1)
	if text then
		themeText(f, text, UDim2.new(0, room, 1, 0), UDim2.new(1, -room, 0, 0), 13, "Display", C.Dim, Enum.TextXAlignment.Right)
	end
	return f
end

-- One small stat in a grid (AUTONEON): its name and number over a thin bar.
function W.stat(parent, order, name, value, share)
	local small = textPx(13)
	local cell = W.frame(parent, name, order)
	themeText(cell, name, UDim2.new(0.55, 0, 0, small + 2), nil, 13, "Display", C.Dim)
	themeText(cell, value, UDim2.new(0.45, 0, 0, small + 2), UDim2.fromScale(0.55, 0), 13, "Display", nil, Enum.TextXAlignment.Right)
	local bar, fill = Theme.Bar(cell, C.Text)
	bar.Position = UDim2.fromOffset(0, small + 5)
	bar.Size = UDim2.new(1, 0, 0, 4)
	bar.BackgroundColor3 = C.Dim
	bar.BackgroundTransparency = 0.75
	fill.Size = UDim2.fromScale(math.clamp(share, 0.05, 1), 1)
	return cell
end

-- A small padlock on a dark disc (a paint or glow you can't use yet). No turned pieces: it lives in a
-- scrolling list, and a turned frame isn't clipped at the list's edge.
function W.lock(parent)
	local disc = W.block(parent, "Lock", 0, 0, 24, 24, C.Shadow, 12)
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.BackgroundTransparency = 0.35
	local shackle = W.block(disc, "Shackle", 8.5, 4.5, 7, 8, nil, 3)
	shackle.BackgroundTransparency = 1
	W.ring(shackle, C.Text, 1.5)
	W.block(disc, "Body", 6, 10.5, 12, 9, nil, 2, 2)
	return disc
end

-- Is this STYLE swatch (its Key) waiting for its second tap?
function W.styleArmed(key)
	local arm = S.styleArm
	return key ~= nil and arm ~= nil and arm.key == key and os.clock() - arm.at < K.StyleArmTime
end

-- One section of the STYLE page: its name and price on top, a line saying what a tap does (or, while a
-- swatch waits for its second tap, "TAP AGAIN TO BUY" with its name and price, in cash green), then a
-- grid of swatches: a thumb-sized colour chip with a caption under it. The one on the car wears a white
-- ring and a dot, one waiting for its second tap a green ring (the TUNE page's confirm colour), locked
-- ones a padlock. cells[i] = { Color, Name, Caption, CaptionColor, Current, Locked, Price, Key, Pick }:
-- Price set = it costs money, so it takes two taps (see the header); Pick() sends the request. Free and
-- locked swatches send on the first tap (a locked one: the server says what unlocks it). The grid's
-- holder keeps its default name ("Frame"); the swatches are "Swatch<n>", the line "Status" (in "StatusLine").
function W.swatches(parent, title, price, note, cells, order)
	local touch, nameH, small = touchHeight(), textPx(15) + 4, textPx(13)
	local gap = 6
	local cellW = math.max(touch, math.ceil(small * 3.6)) -- room for "RANK 10" / "$1,500" under the chip
	local cellH = touch + 4 + small + 2
	local width = ui.screen.Size.X.Offset - 6 - 4 -- the list's scroll bar keeps 6, the holder 4 (see below)
	local cols = math.max(1, math.floor((width + gap) / (cellW + gap)))
	local lines = math.ceil(#cells / cols)
	local armedCell
	for _, cell in ipairs(cells) do
		if cell.Price and W.styleArmed(cell.Key) then
			armedCell = cell
		end
	end
	local r = W.frame(parent, title, order)
	r.Size = UDim2.fromScale(1, 0)
	r.AutomaticSize = Enum.AutomaticSize.Y
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, 4)
	stack.Parent = r
	W.rule(r).LayoutOrder = 0
	local head = W.frame(r, "Head", 1)
	head.Size = UDim2.new(1, 0, 0, 6 + nameH)
	themeText(head, string.upper(title), UDim2.new(0.5, 0, 0, nameH), UDim2.fromOffset(0, 6), 15, "Bold")
	themeText(head, price, UDim2.new(0.5, 0, 0, nameH), UDim2.new(0.5, 0, 0, 6), 15, "Display", C.Cash, Enum.TextXAlignment.Right)
	local function armedText(cell)
		return "TAP AGAIN TO BUY: " .. tostring(cell.Name) .. "  " .. money(cell.Price)
	end
	-- The line keeps one height whether a swatch waits or not (the taller of the note and the longest
	-- "TAP AGAIN" text, laid under it unseen), so the grid doesn't jump between the two taps and the
	-- second one lands on the same swatch.
	local line = W.frame(r, "StatusLine", 2)
	line.Size = UDim2.fromScale(1, 0)
	line.AutomaticSize = Enum.AutomaticSize.Y
	local sizers = { { note, "Body" } }
	local longest
	for _, cell in ipairs(cells) do
		if cell.Price and (longest == nil or #armedText(cell) > #longest) then
			longest = armedText(cell)
		end
	end
	if longest then
		table.insert(sizers, { longest, "Bold" })
	end
	for i, sizer in ipairs(sizers) do
		local s = themeText(line, sizer[1], UDim2.fromScale(1, 0), nil, 13, sizer[2], C.Dim)
		s.Name = "Sizer" .. i
		s.TextTransparency = 1
		s.AutomaticSize = Enum.AutomaticSize.Y
		s.TextWrapped = true
		s.TextTruncate = Enum.TextTruncate.None
	end
	local status = themeText(line, armedCell and armedText(armedCell) or note,
		UDim2.fromScale(1, 0), nil, 13, armedCell and "Bold" or "Body", armedCell and C.Cash or C.Dim)
	status.Name = "Status"
	status.AutomaticSize = Enum.AutomaticSize.Y
	status.TextWrapped = true
	status.TextTruncate = Enum.TextTruncate.None
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, -4, 0, lines * (cellH + gap) + 4)
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = 3
	holder.Parent = r
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4) -- room for the top of a ring (each chip sits centred in a wider cell)
	pad.Parent = holder
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(cellW, cellH)
	grid.CellPadding = UDim2.fromOffset(gap, gap)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = holder
	for i, cell in ipairs(cells) do
		local armed = cell.Price ~= nil and W.styleArmed(cell.Key)
		local b = Instance.new("TextButton")
		b.Name = "Swatch" .. i
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.BorderSizePixel = 0
		b.LayoutOrder = i
		b.Parent = holder
		local chip = W.block(b, "Chip", 0, 0, touch, touch, cell.Color, 6)
		chip.AnchorPoint = Vector2.new(0.5, 0)
		chip.Position = UDim2.fromScale(0.5, 0)
		if cell.Current then
			W.ring(chip, C.Text, 2)
			local dot = W.block(chip, "On", 0, 0, 10, 10, C.Text, 5)
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Position = UDim2.fromScale(0.5, 0.5)
			W.ring(dot, K.Ink, 2)
		elseif armed then
			W.ring(chip, C.Cash, 3)
		else
			W.ring(chip, C.Text, 1).Transparency = 0.8
		end
		if cell.Locked then
			W.lock(chip)
		end
		local cap = themeText(b, armed and "AGAIN" or tostring(cell.Caption or ""), UDim2.new(1, 0, 0, small + 2),
			UDim2.fromOffset(0, touch + 4), 13, "Display", armed and C.Cash or cell.CaptionColor or C.Dim, Enum.TextXAlignment.Center)
		cap.Name = "Caption"
		cap.TextTruncate = Enum.TextTruncate.None
		-- The longest ("RANK 20", about 47 real pixels) only just fits the narrowest cell: let it shrink a
		-- little rather than run into its neighbour.
		cap.TextScaled = true
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = small
		fit.MinTextSize = small - 3
		fit.Parent = cap
		b.Activated:Connect(function()
			sfx("Click")
			if cell.Current then
				return -- already on the car (white ring)
			end
			if cell.Locked or not cell.Price then
				S.styleArm = nil
				cell.Pick() -- free (owned, stock, a pass / unlock one), or locked: the server explains
				return
			end
			if W.styleArmed(cell.Key) then
				S.styleArm = nil
				cell.Pick() -- the second tap: buy it (the server checks the price and our cash again)
				show("Custom")
				return
			end
			local arm = { key = cell.Key, at = os.clock() }
			S.styleArm = arm
			show("Custom") -- draws this one armed (and any other one back to normal)
			task.delay(K.StyleArmTime, function()
				if S.styleArm == arm then
					S.styleArm = nil
					if S.open and current == "Custom" then
						show("Custom")
					end
				end
			end)
		end)
	end
	return r
end

-- A paint or rim swatch: what it costs on this car (Garage.StyleCost, the rule the server charges by)
-- and whether it's on the car, locked, owned, stock or for sale. remote = "RequestPaint" / "RequestRims".
function W.styleCell(kind, def, index, entry, wearing, ownedSet, remote)
	local cell = { Color = entry.Color, Name = entry.Name, Key = kind .. ":" .. def.Id .. ":" .. index }
	local cost = Garage.StyleCost(kind, index, ownedSet) or 0
	if index == wearing then
		cell.Current, cell.Caption, cell.CaptionColor = true, "ON", C.Text
	elseif not Garage.Allowed(player, entry) then
		cell.Locked, cell.Caption, cell.CaptionColor = true, Garage.Needs(entry) or "LOCKED", C.Gold
	elseif cost > 0 then
		cell.Price, cell.Caption, cell.CaptionColor = cost, money(cost), C.Cash
	elseif Garage.IsStock(kind, index) then
		cell.Caption = "STOCK"
	elseif ownedSet[tostring(index)] then
		cell.Caption = "OWNED"
	else
		cell.Caption = "FREE" -- a pass or unlock entry you have
	end
	cell.Pick = function()
		Remotes.Event(remote):FireServer(def.Id, index)
	end
	return cell
end

-- App icon glyphs: a few white blocks on the app's coloured tile (no image assets). `g` is a 28 x 28
-- box and `ink` the tile's colour, for holes cut into the white. Keys are the PAGES keys. (Turned pieces
-- are fine here: the home screen doesn't scroll.)
W.glyph = {
	Garage = function(g, ink) -- a car, side on
		W.block(g, "Cabin", 7, 6, 14, 9, nil, 3)
		W.block(g, "Body", 0, 12, 28, 8, nil, 2)
		for i, x in ipairs({ 4, 17 }) do
			local wheel = W.block(g, "Wheel" .. i, x, 16, 7, 7, ink, 4, 2)
			W.ring(wheel, C.Text, 1.5)
		end
	end,
	Dealer = function(g) -- a steering wheel
		local rim = W.block(g, "Rim", 3, 3, 22, 22, nil, 11)
		rim.BackgroundTransparency = 1
		W.ring(rim, C.Text, 3)
		W.block(g, "Spokes", 4, 12.5, 20, 3)
		W.block(g, "Spoke", 12.5, 14, 3, 10)
		W.block(g, "Hub", 10, 10, 8, 8, nil, 4)
	end,
	GPS = function(g, ink) -- a map pin
		W.block(g, "Tip", 9.5, 14, 9, 9).Rotation = 45
		W.block(g, "Head", 5, 3, 18, 18, nil, 9)
		W.block(g, "Eye", 11, 9, 6, 6, ink, 3, 2)
	end,
	Jobs = function(g, ink) -- a briefcase
		local handle = W.block(g, "Handle", 10, 4.5, 8, 6, nil, 2)
		handle.BackgroundTransparency = 1
		W.ring(handle, C.Text, 2)
		W.block(g, "Case", 2, 9, 24, 15, nil, 3)
		W.block(g, "Seam", 2, 15, 24, 1.5, ink, nil, 2)
		W.block(g, "Clasp", 12, 13.5, 4, 4.5, nil, 1, 3)
	end,
	Shop = function(g, ink) -- a shopping bag
		local loop = W.block(g, "Loop", 9.5, 3, 9, 10, nil, 4)
		loop.BackgroundTransparency = 1
		W.ring(loop, C.Text, 2)
		W.block(g, "Bag", 4, 10, 20, 15, nil, 3)
		W.block(g, "Hole1", 9, 13, 2, 2, ink, 1, 2)
		W.block(g, "Hole2", 17, 13, 2, 2, ink, 1, 2)
	end,
	Spin = function(g, ink) -- a prize wheel: a ring, four spokes, a hub and the pointer on top
		local wheel = W.block(g, "Wheel", 3, 5, 22, 22, nil, 11)
		wheel.BackgroundTransparency = 1
		W.ring(wheel, C.Text, 2.5)
		for i, turn in ipairs({ 0, 45, 90, 135 }) do
			W.block(g, "Spoke" .. i, 13, 7, 2, 18).Rotation = turn
		end
		W.block(g, "Hub", 10.5, 12.5, 7, 7, ink, 4, 2)
		W.block(g, "Pin", 12, 0, 4, 6, nil, 1, 3)
	end,
	Goals = function(g) -- a trophy
		local handles = W.block(g, "Handles", 4, 4, 20, 7, nil, 3)
		handles.BackgroundTransparency = 1
		W.ring(handles, C.Text, 2)
		W.block(g, "Cup", 8, 2, 12, 13, nil, 4)
		W.block(g, "Stem", 12.5, 15, 3, 5)
		W.block(g, "Base", 8, 20, 12, 3.5, nil, 1)
	end,
	Crew = function(g) -- two people
		W.block(g, "Head1", 3.5, 5, 8, 8, nil, 4)
		W.block(g, "Body1", 2, 15, 11, 9, nil, 4)
		W.block(g, "Head2", 16.5, 5, 8, 8, nil, 4)
		W.block(g, "Body2", 15, 15, 11, 9, nil, 4)
	end,
	Home_ = function(g, ink) -- a house
		W.block(g, "Roof", 6, 3, 16, 16).Rotation = 45
		W.block(g, "Walls", 5, 12, 18, 13, nil, 1)
		W.block(g, "Door", 12, 17, 4, 8, ink, 1, 2)
	end,
	Empire = function(g, ink) -- a shop front under a striped awning, a gold coin over it
		for i = 0, 3 do
			W.block(g, "Awning" .. i, 2 + i * 6, 8, 6, 5, i % 2 == 0 and C.Text or ink, 1)
		end
		W.block(g, "Front", 3, 13, 22, 12, nil, 1)
		W.block(g, "Door", 6, 16, 6, 9, ink, 1, 2)
		W.block(g, "Window", 15, 16, 7, 5, ink, 1, 2)
		local coin = W.block(g, "Coin", 10, 0, 8, 8, C.Gold, 4, 2)
		W.ring(coin, C.Text, 1)
	end,
	Settings = function(g, ink) -- three sliders
		for i, x in ipairs({ 16, 5, 12 }) do
			local y = 3 + (i - 1) * 9
			W.block(g, "Track" .. i, 2, y, 24, 2, nil, 1)
			local knob = W.block(g, "Knob" .. i, x, y - 2, 6, 6, ink, 3, 2)
			W.ring(knob, C.Text, 1.5)
		end
	end,
}

------------------------------------------------------------------ the header and the home screen

-- Everything around the page, for this screen and this page: the home screen has no header (its page
-- starts right under the status bar, over the wallpaper); an app page gets the back chevron and its
-- title. The shell is built once, so its sizes are set again here for the scale in use.
local function layoutShell()
	local touch = touchHeight()
	local height = phone.Size.Y.Offset
	local home = S.back == nil
	local top = K.Bezel + K.Status
	-- The shell's own text floor (the page on screen may be drawn with another one: S.minText).
	local floor = math.ceil(K.MinText / math.max(ui.fit.Scale, 0.5))
	local clockPx, cashPx, titlePx = math.max(13, floor), math.max(14, floor), math.max(20, floor)
	ui.clock.TextSize = clockPx
	ui.cash.TextSize = cashPx
	ui.island.Size = UDim2.fromOffset(cashPx * 6, math.min(cashPx + 6, K.Status - 4))
	ui.icons.Scale = clockPx / 13
	-- The header: a thumb-sized back button with the chevron on the page's left edge, the title right
	-- of the chevron (over the button's right part: a label lets the tap through).
	ui.chevron.Scale = touch / Theme.Touch
	ui.back.Position = UDim2.fromOffset(K.Bezel, top)
	ui.back.Size = UDim2.fromOffset(touch, touch)
	local titleLeft = K.Inset + math.ceil(12 * ui.chevron.Scale) + 8
	ui.titleCap.MaxTextSize = titlePx
	ui.title.Position = UDim2.fromOffset(titleLeft, top + math.floor((touch - (titlePx + 8)) / 2))
	ui.title.Size = UDim2.fromOffset(K.W - titleLeft - K.Inset, titlePx + 8)
	ui.headRule.Position = UDim2.fromOffset(K.Inset, top + touch)
	ui.headRule.Size = UDim2.fromOffset(K.W - 2 * K.Inset, 1)
	ui.title.Visible, ui.back.Visible, ui.headRule.Visible = not home, not home, not home
	ui.wall.Visible = home
	-- The page between them, and the home bar's thumb-sized strip along the foot.
	local pageTop = top + (home and 8 or touch + 1)
	local barTop = height - K.Bezel - touch
	ui.screen.Position = UDim2.fromOffset(K.Inset, pageTop)
	ui.screen.Size = UDim2.fromOffset(K.W - 2 * K.Inset, math.max(barTop - pageTop, 40))
	ui.homeBar.Position = UDim2.fromOffset(K.W / 2 - 90, barTop)
	ui.homeBar.Size = UDim2.fromOffset(180, touch)
end

local function setHeader(title, backTo)
	if backTo == "Home" and S.fromGuide then
		backTo = "Guide" -- opened from HOW TO PLAY: Back returns there
	end
	ui.title.Text = title
	S.back = backTo
	layoutShell()
end

function PAGES.Home()
	setHeader("NEON PHONE", nil)
	local screen = ui.screen
	local touch, small = touchHeight(), textPx(13)
	local width, height = screen.Size.X.Offset, screen.Size.Y.Offset
	-- HOW TO PLAY and its hint keep the bottom of the page; the grid's rows (three apps each: three rows,
	-- four with EMPIRE) share what is left, so on a short screen the icons shrink instead of running off it.
	local apps = {}
	for _, app in ipairs(K.Apps) do
		if not app.Show or app.Show() then
			table.insert(apps, app)
		end
	end
	local rows = math.max(1, math.ceil(#apps / 3))
	local hintH, labelH, gap = small + 4, small + 4, 8
	local guideTop = height - hintH - 4 - touch
	local cellH = math.clamp(math.floor((guideTop - 10 - (rows - 1) * gap) / rows), 36 + labelH + 4, 68 + labelH + 4)
	local icon = cellH - labelH - 4
	-- A tall screen has room to spare: a big clock on top, like a lock screen's, and more air between
	-- the rows of icons.
	local free = guideTop - 10 - (rows * cellH + (rows - 1) * gap)
	local clockH = free >= 120 and 92 or 0
	gap = math.clamp(gap + math.floor((free - clockH) / (rows + 1)), gap, 26)
	local gridH = rows * cellH + (rows - 1) * gap
	if clockH > 0 then
		local big = themeText(screen, ui.clock.Text, UDim2.new(1, 0, 0, 56), UDim2.fromOffset(0, 12), 46, "Display", nil,
			Enum.TextXAlignment.Center, true)
		big.Name = "Clock"
		themeText(screen, "PORT SOLANA", UDim2.new(1, 0, 0, small + 4), UDim2.fromOffset(0, 68), 13, "Bold", C.Dim,
			Enum.TextXAlignment.Center, true).Name = "City"
	end
	local grid = W.frame(screen, "Apps")
	grid.Position = UDim2.fromOffset(0, clockH + math.max(0, math.floor((guideTop - 10 - clockH - gridH) / 2)))
	grid.Size = UDim2.fromOffset(width, gridH)
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / 3, -6, 0, cellH)
	layout.CellPadding = UDim2.fromOffset(9, gap)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for i, app in ipairs(apps) do
		-- The whole cell is the button (icon and label), so the tap target is bigger than the icon.
		local tile = Instance.new("TextButton")
		tile.Name = app.Page
		tile.LayoutOrder = i
		tile.BackgroundTransparency = 1
		tile.AutoButtonColor = false
		tile.Text = ""
		tile.Parent = grid
		local face = W.block(tile, "Icon", 0, 0, icon, icon, app.Color, math.floor(icon * 0.22))
		face.AnchorPoint = Vector2.new(0.5, 0)
		face.Position = UDim2.fromScale(0.5, 0)
		local g = W.frame(face, "Glyph")
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
		g.Size = UDim2.fromOffset(28, 28)
		local zoom = Instance.new("UIScale")
		zoom.Scale = icon / 50
		zoom.Parent = g
		W.glyph[app.Page](g, app.Color)
		local name = themeText(tile, app.Name, UDim2.new(1, 8, 0, labelH), UDim2.new(0, -4, 0, icon + 4), 13, "Display", nil,
			Enum.TextXAlignment.Center, true)
		name.Name = "Label"
		if app.Badge and app.Badge() then
			local dot = W.block(face, "Badge", icon - 9, -3, 12, 12, C.Danger, 6, 3)
			dot.AnchorPoint = Vector2.zero
		end
		tile.Activated:Connect(function()
			sfx("Click")
			show(app.Page)
		end)
	end
	-- HOW TO PLAY, under the grid: a wide flat card, like a home-screen widget.
	local guide = Instance.new("TextButton")
	guide.Name = "Guide"
	guide.AnchorPoint = Vector2.new(0.5, 0.5) -- centred, so the pulse grows evenly from the middle
	guide.Position = UDim2.new(0.5, 0, 0, guideTop + touch / 2)
	guide.Size = UDim2.new(1, 0, 0, touch)
	guide.Text = ""
	flat(guide, "Quiet")
	guide.BackgroundColor3 = K.Card
	guide.BackgroundTransparency = 0.1
	guide.Parent = screen
	guide.Activated:Connect(function()
		sfx("Click")
		show("Guide")
	end)
	local glow = W.ring(guide, C.Gold, 1)
	glow.Transparency = 0.5
	local badge = W.block(guide, "Badge", 0, 0, 28, 28, C.Gold, 6)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 10, 0.5, 0)
	themeText(badge, "?", UDim2.fromScale(1, 1), nil, 18, "Display", K.Ink, Enum.TextXAlignment.Center)
	themeText(guide, "HOW TO PLAY", UDim2.new(1, -84, 1, 0), UDim2.fromOffset(50, 0), 17, "Display")
	themeText(guide, "›", UDim2.new(0, 20, 1, 0), UDim2.new(1, -30, 0, 0), 20, "Display", C.Dim, Enum.TextXAlignment.Center)
	local hint = themeText(screen, "Steal cars, heists, homes & more", UDim2.new(1, 0, 0, hintH), UDim2.fromOffset(0, guideTop + touch + 4),
		13, "Body", C.Dim, Enum.TextXAlignment.Center, true)
	hint.Name = "GuideHint"
	-- First home screen this session: a few gentle pulses so new players spot it (never a popup).
	if not S.guideHinted then
		S.guideHinted = true
		local pop = Instance.new("UIScale")
		pop.Parent = guide
		local pulse = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 2, true, 0.4)
		TweenService:Create(pop, pulse, { Scale = 1.04 }):Play()
		TweenService:Create(glow, pulse, { Thickness = 2, Transparency = 0 }):Play()
	end
end

------------------------------------------------------------------ garage and its STYLE page

function PAGES.Garage()
	setHeader("GARAGE", "Home")
	local mine = owned()
	local touch, nameH = touchHeight(), textPx(15) + 4
	local styleW = 96
	local s = W.list(0)
	local n = 0
	for i, def in ipairs(Vehicles.List) do
		if mine[def.Id] and canDrive(def) and not def.Hidden then
			n += 1
			-- Name and class on one line, DELIVER and STYLE under it, then (cars that can be tuned) the TUNE
			-- strip: every button a thumb tall.
			local tunable = Garage.CanTune(def)
			local yButtons = 10 + nameH + 6
			local yTune = yButtons + touch + 6
			local r = W.row(s, def.Id, (tunable and yTune + touch or yButtons + touch) + 10, i)
			local paint = customOf(def.Id)
			local painted = paint > 0 and not def.Boat and Garage.Paints[paint]
			-- Boats ignore paint (older saves may still hold some), so they show their stock colour.
			local swatch = W.block(r, "Paint", 1, 10 + math.floor((nameH - 14) / 2), 14, 14, painted and painted.Color or def.Color, 4)
			W.ring(swatch, C.Text, 1).Transparency = 0.7
			themeText(r, def.DisplayName or def.Id, UDim2.new(0.64, -24, 0, nameH), UDim2.fromOffset(24, 10), 15, "Bold")
			themeText(r, def.Class or "", UDim2.new(0.36, 0, 0, nameH), UDim2.new(0.64, 0, 0, 10), 13, "Body", C.Dim,
				Enum.TextXAlignment.Right)
			local deliver = W.button(r, "Deliver", def.Boat and "LAUNCH" or "DELIVER", "Primary", function()
				Remotes.Event("RequestSpawnCar"):FireServer(def.Id)
				PhoneUI.Close()
			end)
			deliver.Position = UDim2.fromOffset(0, yButtons)
			deliver.Size = UDim2.new(1, -(styleW + 8), 0, touch)
			if def.Boat then
				-- A boat's textured hull shows no paint, rims or underglow (GarageService refuses them too).
				local note = themeText(r, "Factory colours", UDim2.fromOffset(styleW, touch), UDim2.new(1, -styleW, 0, yButtons), 13, "Body",
					C.Dim, Enum.TextXAlignment.Center)
				note.Name = "Factory"
				note.TextWrapped = true
			else
				local style = W.button(r, "Style", "STYLE", "Quiet", function()
					detailId = def.Id
					show("Custom")
				end)
				style.Position = UDim2.new(1, -styleW, 0, yButtons)
				style.Size = UDim2.fromOffset(styleW, touch)
			end
			if tunable then
				local tune = Garage.ParseTune(player:GetAttribute("Tune_" .. def.Id))
				local full = tune.Total >= Garage.MaxTuneTotal
				local b = themeButton(r, "Tune", touch, 0, "Quiet", function()
					detailId = def.Id
					show("Tune")
				end)
				b.Position = UDim2.fromOffset(0, yTune)
				themeText(b, "TUNE", UDim2.new(0, 60, 1, 0), UDim2.fromOffset(12, 0), 17, "Display")
				-- Display (condensed): the count still fits at a phone's text size. A stock car says what's
				-- inside (speed AND sound), so new players look for the exhausts too.
				local status = tune.Total == 0 and "SPEED + SOUND  ›" or (tune.Total .. " / " .. Garage.MaxTuneTotal .. " upgrades  ›")
				themeText(b, full and "FULLY TUNED" or status,
					UDim2.new(1, -90, 1, 0), UDim2.fromOffset(78, 0), 13, "Display", full and C.Gold or C.Dim,
					Enum.TextXAlignment.Right)
			end
		end
	end
	if n == 0 then
		W.note(s, "No cars for this role yet. Visit AutoNeon Motors downtown!", 1, C.Text, Enum.TextXAlignment.Center)
	end
end

function PAGES.Custom()
	local def = Vehicles.ById[detailId]
	if not def or def.Boat or def.Hidden then
		show("Garage") -- boats can't be styled (the Garage shows no STYLE button for them)
		return
	end
	setHeader(string.upper(def.DisplayName or def.Id), "Garage")
	local paint, glow, rim = customOf(def.Id)
	local paints, rims = styleOf(def.Id)
	local s = W.list(0)
	-- Paint: the car's own colour first (STOCK, always owned), then every Garage paint.
	local stock = typeof(def.Color) == "Color3" and def.Color or C.Dim
	local cells = { W.styleCell("Paints", def, 0, { Name = "Stock", Color = stock }, paint, paints, "RequestPaint") }
	for i, entry in ipairs(Garage.Paints) do
		table.insert(cells, W.styleCell("Paints", def, i, entry, paint, paints, "RequestPaint"))
	end
	W.swatches(s, "Paint", money(Garage.PaintPrice) .. " A COLOR",
		"Each new color costs " .. money(Garage.PaintPrice) .. " once on this car. Colors you own switch back free.", cells, 1)
	cells = {}
	for i, entry in ipairs(Garage.Rims) do
		table.insert(cells, W.styleCell("Rims", def, i, entry, rim > 0 and rim or Garage.StockRim, rims, "RequestRims"))
	end
	W.swatches(s, "Rims", money(Garage.RimPrice) .. " A STYLE",
		"Each new rim style costs " .. money(Garage.RimPrice) .. " once on this car. Rims you own switch back free.", cells, 2)
	-- Underglow: installed once per car, then every colour you may use is free.
	local installed = glow > 0
	cells = {}
	for i, entry in ipairs(Garage.Glows) do
		local cell = { Color = entry.Color, Name = entry.Name, Key = "Glows:" .. def.Id .. ":" .. i }
		if installed and i == glow then
			cell.Current, cell.Caption, cell.CaptionColor = true, "ON", C.Text
		elseif not Garage.Allowed(player, entry) then
			cell.Locked, cell.Caption, cell.CaptionColor = true, Garage.Needs(entry) or "LOCKED", C.Gold
		elseif not installed then
			cell.Price, cell.Caption, cell.CaptionColor = Garage.UnderglowPrice, "INSTALL", C.Cash
		else
			cell.Caption = "FREE"
		end
		cell.Pick = function()
			Remotes.Event("RequestUnderglow"):FireServer(def.Id, i)
		end
		table.insert(cells, cell)
	end
	W.swatches(s, "Underglow", installed and "INSTALLED" or money(Garage.UnderglowPrice),
		installed and "Installed on this car: color swaps are free."
			or ("Install once for " .. money(Garage.UnderglowPrice) .. ", then every color is free on this car."), cells, 3)
	W.note(s, "Changes show on this car next time it's delivered (or right away if it's out).", 4, nil,
		Enum.TextXAlignment.Center).Name = "Hint"
end

------------------------------------------------------------------ garage: the TUNE page (Theme look)

local TUNE_ARM_TIME = 4 -- seconds a buy button waits for its second tap
-- Seconds a sent purchase waits for the server's answer: the button reads FITTING... and buy taps are
-- ignored meanwhile. The answer (GarageResult, or a refusal toast) ends the wait sooner; with no answer
-- at all (a silent refusal) the button goes back to its price after this.
local TUNE_BUSY = 2.5
-- Seconds the BUY button keeps offering the exhaust heard last (each listen starts it again). Longer
-- than a buy button's wait: the rev alone lasts over two seconds, and BUY says what it buys and for
-- how much the whole time.
local EXHAUST_PICK_TIME = 8
local BAR_TIME = 0.45 -- seconds a stat bar takes to glide to a new length
local BAR_HEIGHT = 8 -- design px: thick enough to see the preview piece on a phone (0.7 scale)
local BAR_FLOOR = 0.7 -- an empty bar is 70% of this car's stock number (see the header)
local FLASH_TIME = 0.7 -- seconds a button stays lit after its upgrade lands

local tuneArm, tuneArmUntil = nil, 0 -- the buy button waiting for its second tap ("<carId>/<button>"), and until when
local tuneSent, tuneBusyUntil = nil, 0 -- the button whose purchase was sent (drawn FITTING...), and until when
-- The exhaust the BUY button offers ("<carId>/X:<exhaust key>": the unbought chip tapped last), and until when.
local exhaustPick, exhaustPickUntil = nil, 0
-- What the armed (then sent) button buys, for the bars' preview: { Key = "<carId>/<button>", Id = carId,
-- Stages = { [track] = stage after it }, Text = AUTO TUNE's plan line or nil }. nil for an exhaust.
local tuneTarget
local tuneBars = {} -- the stat bars as last drawn: { Id = carId, [field] = { From, To, At } }
local tuneFlash -- { At = os.clock(), Keys = { ["<carId>/<button>"] = true } }: buttons to light up (PhoneUI.Init sets it)

-- Theme's quiet surfaces are see-through black, made to sit over the street. The phone's screen is
-- near-black itself, so on this page they could not be told from it: rows and chips were words with no
-- button around them. Here they are Theme's lighter panel colour instead (flat gives every other page's
-- quiet buttons the same look).
local function lift(obj)
	obj.BackgroundColor3 = Theme.Color.PanelLight
	obj.BackgroundTransparency = 0.2
	return obj
end

-- A themeButton for the TUNE page: the quiet ones are lifted, white and green ones show as they are.
local function tuneButton(parent, name, height, order, kind, onTap)
	local b = themeButton(parent, name, height, order, kind, onTap)
	if kind ~= "Primary" and kind ~= "Confirm" then
		lift(b)
	end
	return b
end

local function percent(share)
	return math.floor(share * 100 + 0.5)
end

local function armed(key)
	return tuneArm == key and os.clock() < tuneArmUntil
end

local function sent(key)
	return tuneSent == key and os.clock() < tuneBusyUntil
end

local function picked(key)
	return exhaustPick == key and os.clock() < exhaustPickUntil
end

-- The armed or sent purchase on car `id` whose gain the bars preview, or nil.
local function previewOf(id)
	local t = tuneTarget
	if t and t.Id == id and (armed(t.Key) or sent(t.Key)) then
		return t
	end
	return nil
end

-- The stages a car would have after `plan` ({ { Track, Stage }, ... }): a copy, for the bars' preview.
local function stagesAfter(stages, plan)
	local after = table.clone(stages)
	for _, step in ipairs(plan) do
		after[step.Track] = math.max(after[step.Track] or 0, step.Stage)
	end
	return after
end

-- Ask the server for a purchase (`fire` sends the remote). The button reads FITTING... until the answer,
-- so the page never flicks back to the old price in between; PhoneUI.Init ends the wait when the answer
-- or a refusal toast arrives (tuneSent = nil).
local function send(key, fire)
	tuneArm = nil
	tuneSent, tuneBusyUntil = key, os.clock() + TUNE_BUSY
	fire()
	task.delay(TUNE_BUSY + 0.05, function()
		if tuneSent == key and os.clock() >= tuneBusyUntil then
			tuneSent = nil
			if S.open and current == "Tune" then
				show("Tune") -- refused without a word, or no answer: back to its price
			end
		end
	end)
end

-- Buying takes two taps: the first arms the button (the page redraws it green and the bars preview
-- `target`, see tuneTarget), the second, within TUNE_ARM_TIME, sends `run`. Arming another button, or
-- waiting too long, lets go of the first. (Exhausts don't buy this way: see pickExhaust.)
local function armOrRun(key, run, target)
	if armed(key) then
		send(key, run)
	else
		tuneArm, tuneArmUntil = key, os.clock() + TUNE_ARM_TIME
		tuneTarget = target
		exhaustPick = nil -- one green button at a time: the exhaust's BUY offer lets go too
		if target then
			target.Key = key
		end
		task.delay(TUNE_ARM_TIME + 0.05, function()
			if tuneArm == key and os.clock() >= tuneArmUntil then
				tuneArm = nil
				if S.open and current == "Tune" then
					show("Tune") -- back to its price
				end
			end
		end)
	end
	show("Tune")
end

-- An exhaust chip that isn't bought yet was tapped (and its rev played): offer it on the BUY button for
-- EXHAUST_PICK_TIME. Listening spends nothing however often a chip is tapped; each tap just starts the
-- wait again. A track or AUTO TUNE waiting for its second tap lets go (one green button at a time).
local function pickExhaust(key)
	exhaustPick, exhaustPickUntil = key, os.clock() + EXHAUST_PICK_TIME
	tuneArm = nil
	task.delay(EXHAUST_PICK_TIME + 0.05, function()
		if exhaustPick == key and os.clock() >= exhaustPickUntil then
			exhaustPick = nil
			if S.open and current == "Tune" then
				show("Tune") -- BUY goes quiet again
			end
		end
	end)
	show("Tune")
end

-- One stat bar: white = stock, pink = what the tune added, see-through pink = what the armed button
-- would add (shown before paying, like a tuning shop). `stock`, `to` (tuned) and `ahead` (after the
-- armed purchase, or nil) are lengths, 0..1. The bar runs from `left` px to `right` px short of the
-- panel's right edge, its top at `y`. A redraw in the middle of a glide (a purchase changes the cash and
-- the tune a moment apart, each redrawing the page) carries on from where the bar was instead of
-- starting again.
local function tuneBar(parent, field, left, right, y, stock, to, ahead, now)
	local rec = tuneBars[field]
	if not rec then
		rec = { From = stock, To = to, At = now }
	elseif math.abs(rec.To - to) > 0.001 then
		local done = math.clamp((now - rec.At) / BAR_TIME, 0, 1)
		rec = { From = rec.From + (rec.To - rec.From) * done, To = to, At = now }
	end
	tuneBars[field] = rec
	local done = math.clamp((now - rec.At) / BAR_TIME, 0, 1)
	local bar, fill = Theme.Bar(parent, Theme.Color.Brand)
	bar.Position = UDim2.new(0, left, 0, y)
	bar.Size = UDim2.new(1, -(left + right), 0, BAR_HEIGHT)
	-- The room left to grow has to show (a stock car's bar was a white line ending in nothing): Theme's
	-- black track can't be seen in here (see lift), so the empty part is dim grey, like an empty stage pip.
	bar.BackgroundColor3 = Theme.Color.Dim
	bar.BackgroundTransparency = 0.75
	-- Back to front: the preview piece (1), the tuned pink (2), the stock white (3).
	fill.ZIndex = 2
	fill.Size = UDim2.fromScale(rec.From + (rec.To - rec.From) * done, 1)
	if done < 1 and rec.From ~= rec.To then
		TweenService:Create(fill, TweenInfo.new(BAR_TIME * (1 - done), Enum.EasingStyle.Linear),
			{ Size = UDim2.fromScale(rec.To, 1) }):Play()
	end
	if ahead and ahead > to + 0.001 then
		local gain = Instance.new("Frame")
		gain.Name = "Preview"
		gain.Size = UDim2.fromScale(ahead, 1)
		gain.BackgroundColor3 = Theme.Color.Brand
		gain.BackgroundTransparency = 0.6
		gain.BorderSizePixel = 0
		gain.ZIndex = 1
		Theme.Corners(gain, 2)
		gain.Parent = bar
	end
	local base = Instance.new("Frame")
	base.Name = "Stock"
	base.Size = UDim2.fromScale(stock, 1)
	base.BackgroundColor3 = Theme.Color.Text
	base.BorderSizePixel = 0
	base.ZIndex = fill.ZIndex + 1 -- over the pink, so only the gain shows past its end
	Theme.Corners(base, 2)
	base.Parent = bar
end

-- Light a button up for a moment when its purchase lands (fades out; never takes taps).
local function flash(parent, key, now)
	if not tuneFlash or not tuneFlash.Keys[key] then
		return
	end
	local done = (now - tuneFlash.At) / FLASH_TIME
	if done >= 1 then
		return
	end
	local glow = Instance.new("Frame")
	glow.Name = "Flash"
	glow.Size = UDim2.fromScale(1, 1)
	glow.BackgroundColor3 = Theme.Color.Text
	glow.BackgroundTransparency = 0.5 + 0.5 * done
	glow.BorderSizePixel = 0
	glow.ZIndex = 5
	Theme.Corners(glow)
	glow.Parent = parent
	TweenService:Create(glow, TweenInfo.new(FLASH_TIME * (1 - done), Enum.EasingStyle.Linear), { BackgroundTransparency = 1 }):Play()
end

-- Let the player hear an exhaust before paying, if SoundClient offers a preview (it owns every sound).
local function previewExhaust(key)
	pcall(function()
		local sounds = require(script.Parent:WaitForChild("SoundClient"))
		if type(sounds.PreviewExhaust) == "function" then
			sounds.PreviewExhaust(key)
		end
	end)
end

local function tunePage()
	local def = Vehicles.ById[detailId]
	if not def or not Garage.CanTune(def) or not owned()[def.Id] then
		return show("Garage") -- boats, police cars and cars you don't own have no TUNE page
	end
	local id = def.Id
	setHeader("TUNE · " .. string.upper(def.DisplayName or id), "Garage")
	local tune = Garage.ParseTune(player:GetAttribute("Tune_" .. id))
	local cash = player:GetAttribute("Cash") or 0
	local now = os.clock()
	-- Text as it will be drawn (textPx: bigger on phones) and buttons tall enough for a thumb and for a
	-- name over a line of small text (48 on a PC, where 44 would be enough for the thumb alone).
	local big, small = textPx(17), textPx(11)
	local touch = math.max(touchHeight(), big + small + 20)
	if tuneBars.Id ~= id then
		tuneBars = { Id = id } -- another car: its bars grow from stock
	end
	local s = list(0.02)

	-- Every buy button asks this first: false (and a toast saying why) when the tap can't go through.
	-- GarageService checks the same things again. While a purchase is on its way (FITTING...) taps just
	-- do nothing.
	local function canBuy(price, what)
		if os.clock() < tuneBusyUntil then
			return false
		end
		if (player:GetAttribute("Heat") or 0) > 0 and player:GetAttribute("HeatSpotted") then
			NotifyController.Show(NotifyController.Messages.TuneWanted or "The cops can see you! Lose them before tuning.", nil, "police")
			return false
		end
		local have = player:GetAttribute("Cash") or 0
		if have < price then
			NotifyController.Show("You need " .. money(price - have) .. " more for " .. what .. ".", nil, "money")
			return false
		end
		return true
	end

	-- AUTO TUNE: the plan and its total are on the button before the first tap; the second tap sends it.
	local plan, total, cheapest = Garage.AutoTunePlan(def, tune.Stages, cash)
	local autoKey = id .. "/Auto"
	local autoSent = sent(autoKey)
	-- Cash that changed while AUTO TUNE waits for its second tap changes the plan: keep the preview on it.
	if armed(autoKey) and tuneTarget and tuneTarget.Key == autoKey and #plan > 0 then
		tuneTarget.Stages = stagesAfter(tune.Stages, plan)
		tuneTarget.Text = Garage.PlanText(plan)
	end
	local target = previewOf(id) -- the armed or sent purchase the bars preview, or nil
	local autoKind = "Primary"
	if not cheapest or (#plan == 0 and not autoSent) then
		autoKind = "Quiet" -- fully tuned, or nothing affordable
	elseif autoSent or armed(autoKey) then
		autoKind = "Confirm"
	end
	local titlePx, subPx = textPx(20), textPx(12)
	-- Room for the title and a plan that wraps onto two lines ("Engine 1, Turbo 1, Brakes 1, Tyres 1,
	-- Nitro 1" does on a phone).
	local autoHeight = math.max(touch, 16 + titlePx + 2 + subPx * 2)
	local auto = tuneButton(s, "AutoTune", autoHeight, 1, autoKind, function()
		if not cheapest then
			return -- fully tuned
		elseif #plan == 0 then
			canBuy(cheapest, "the cheapest upgrade") -- says how much is missing
		elseif canBuy(total, "AUTO TUNE") then
			armOrRun(autoKey, function()
				-- The total this button shows and the stages its plan starts from: the server buys no more
				-- than that, and nothing at all if the car has moved on (a second try after a slow answer).
				Remotes.Event("RequestAutoTune"):FireServer(id, total, tune.Total)
			end, { Id = id, Stages = stagesAfter(tune.Stages, plan), Text = Garage.PlanText(plan) })
		end
	end)
	auto.AutoButtonColor = cheapest ~= nil
	local title, sub
	if not cheapest then
		title, sub = "FULLY TUNED", "Every upgrade is fitted"
	elseif autoSent then
		title, sub = "FITTING...", target and target.Text or ""
	elseif #plan == 0 then
		title, sub = "AUTO TUNE", "Cheapest upgrade: " .. money(cheapest)
	else
		title, sub = (autoKind == "Confirm" and "TAP AGAIN  " or "AUTO TUNE  ") .. money(total), Garage.PlanText(plan)
	end
	-- Title over the plan, centred as a block: the plan is one line or two, whichever it needs.
	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Size = UDim2.new(1, -16, 1, -8)
	words.Position = UDim2.fromOffset(8, 4)
	words.Parent = auto
	local stack = Instance.new("UIListLayout")
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.VerticalAlignment = Enum.VerticalAlignment.Center
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Center
	stack.Padding = UDim.new(0, 2)
	stack.Parent = words
	themeText(words, title, UDim2.new(1, 0, 0, titlePx), nil, 20, "Display", auto.TextColor3,
		Enum.TextXAlignment.Center).LayoutOrder = 1
	local planLine = themeText(words, sub, UDim2.new(1, 0, 0, 0), nil, 12, "Body",
		autoKind == "Quiet" and Theme.Color.Dim or auto.TextColor3, Enum.TextXAlignment.Center)
	planLine.LayoutOrder = 2
	planLine.TextWrapped = true
	planLine.TextTruncate = Enum.TextTruncate.None
	planLine.AutomaticSize = Enum.AutomaticSize.Y -- as tall as its lines
	flash(auto, autoKey, now)

	-- Stock against tuned, one bar per track (each track's first field is the one the driver feels).
	-- Each bar is scaled to THIS car: empty = BAR_FLOOR of its stock number, full = this car fully tuned,
	-- so every stage is a clear step (on one scale for every car, Engine 1 on a Palmetto grew the bar by
	-- under 2 real px on a phone). The numbers on the right stay absolute (mph, %, seconds).
	local tracks = Garage.Tune.Tracks
	local tuned = Garage.TunedStats(def, tune.Stages)
	local fullTune = Garage.TunedStats(def, Garage.MaxStages)
	local ahead = target and Garage.TunedStats(def, target.Stages) -- after the armed purchase
	-- Label | bar | value on each line, sized from the text (a phone's bigger text gets a wider label).
	local pitch = math.max(20, small + 6)
	local labelWidth, valueWidth = small * 6 + 12, 64
	local barLeft, barRight = 10 + labelWidth + 6, valueWidth + 8 + 6
	local panel = Instance.new("Frame")
	panel.Name = "Stats"
	panel.LayoutOrder = 2
	panel.Size = UDim2.new(1, 0, 0, 16 + #tracks * pitch)
	lift(Theme.Panel(panel))
	panel.Parent = s
	for i, track in ipairs(tracks) do
		local field = track.Fields[1]
		local stage = tune.Stages[track.Key]
		local y = 8 + (i - 1) * pitch
		local stock = def[field] or 0
		local low = stock * BAR_FLOOR
		local span = math.max((fullTune[field] or stock) - low, 0.001)
		-- The armed purchase raises this track: preview its gain (see-through pink, and the number in pink).
		local nextStage = target and target.Stages[track.Key] or stage
		local previewing = ahead ~= nil and nextStage > stage
		themeText(panel, track.Stat, UDim2.fromOffset(labelWidth, pitch), UDim2.fromOffset(10, y), 11, "Bold", Theme.Color.Dim,
			nil, true)
		tuneBar(panel, field, barLeft, barRight, y + math.floor((pitch - BAR_HEIGHT) / 2),
			math.clamp((stock - low) / span, 0.03, 1), math.clamp((tuned[field] - low) / span, 0.03, 1),
			previewing and math.clamp((ahead[field] - low) / span, 0.03, 1) or nil, now)
		local shown = previewing and ahead[field] or tuned[field]
		local shownStage = previewing and nextStage or stage
		local value
		if field == "MaxSpeed" then
			value = math.floor(shown * K.StudsToMph + 0.5) .. " mph"
		elseif field == "NitroSeconds" then
			value = string.format("%.1f s", shown)
		else
			value = shownStage > 0 and ("+" .. percent(track.Gain[shownStage]) .. "%") or "stock"
		end
		local valueColor = stage > 0 and Theme.Color.Text or Theme.Color.Dim
		if previewing then
			valueColor = Theme.Color.Brand
		end
		themeText(panel, value, UDim2.fromOffset(valueWidth, pitch), UDim2.new(1, -(valueWidth + 8), 0, y), 13, "Display",
			valueColor, Enum.TextXAlignment.Right, true)
	end

	-- Exhausts (sound only), right under the bars: "faster" (AUTO TUNE) and "sounds better" share the
	-- first screen on a phone. Tapping a chip plays its rev, the fitted one too, so players can compare,
	-- and for a chip that isn't bought that is ALL a tap does, however often. (It used to arm a buy, so
	-- listening a second time paid up to $8,000 with no price on screen.) The head row's BUY button then
	-- offers the one heard last, by price and name, and is the only thing here that spends anything.
	-- One bought earlier fits with a single tap (free).
	-- The head row is always a thumb tall with BUY in it, so nothing moves under a finger when an offer
	-- comes or goes.
	local chipName = textPx(14)
	local chipTop = -math.floor((chipName + 2 + small) / 2) -- a name over a small line, centred as a block
	local cols = 3
	-- The exhaust on BUY: the one being bought right now, else the unbought one heard last.
	local offer, offerKey
	for _, exhaust in ipairs(Garage.Exhausts) do
		local k = id .. "/X:" .. exhaust.Key
		if not tune.Owned[exhaust.Key] and (sent(k) or (not offer and picked(k))) then
			offer, offerKey = exhaust, k
		end
	end
	local buying = offer ~= nil and sent(offerKey)
	local affordable = offer ~= nil and cash >= offer.Price
	local headName = textPx(15)
	local headTop = -math.floor((headName + 2 + small) / 2)
	local head = Instance.new("Frame")
	head.Name = "ExhaustHead"
	head.LayoutOrder = 3
	head.Size = UDim2.new(1, 0, 0, touch)
	head.BackgroundTransparency = 1
	head.Parent = s
	themeText(head, "EXHAUST SOUND", UDim2.new(2 / 3, -4, 0, headName), UDim2.new(0, 2, 0.5, headTop), 15, "Display", nil, nil,
		true)
	themeText(head, "tap one to hear it", UDim2.new(2 / 3, -4, 0, small), UDim2.new(0, 2, 0.5, headTop + headName + 2), 11,
		"Body", Theme.Color.Dim, nil, true)
	-- Green only when a tap would really buy (or is buying); quiet with dim words otherwise.
	local buy = tuneButton(head, "BuyExhaust", touch, 0, (buying or affordable) and "Confirm" or "Quiet", function()
		if not offer then
			NotifyController.Show("Tap an exhaust to hear it first.", nil, "info")
		elseif canBuy(offer.Price, "the " .. offer.Name .. " exhaust") then
			send(offerKey, function()
				Remotes.Event("RequestExhaust"):FireServer(id, offer.Key)
			end)
			show("Tune") -- FITTING... here and on its chip
		end
	end)
	-- As wide as a chip and right above the last column of them (the grid below: cells a third of the
	-- width less 4, 6 apart).
	buy.Position = UDim2.new(1 - 1 / cols, 4, 0, 0)
	buy.Size = UDim2.new(1 / cols, -4, 0, touch)
	buy.AutoButtonColor = offer ~= nil
	local buyInk = (buying or affordable) and buy.TextColor3 or Theme.Color.Dim
	if offer then
		-- "BUY $8,000" over "RACE": the price is on the button at the moment of paying.
		themeText(buy, buying and "FITTING..." or ("BUY " .. money(offer.Price)), UDim2.new(1, -8, 0, chipName),
			UDim2.new(0, 4, 0.5, chipTop), 14, "Display", buyInk, Enum.TextXAlignment.Center)
		themeText(buy, offer.Name, UDim2.new(1, -8, 0, small), UDim2.new(0, 4, 0.5, chipTop + chipName + 2), 11, "Display",
			buyInk, Enum.TextXAlignment.Center)
	else
		themeText(buy, "BUY", UDim2.new(1, -8, 1, 0), UDim2.fromOffset(4, 0), 14, "Display", buyInk, Enum.TextXAlignment.Center)
	end
	local lines = math.ceil(#Garage.Exhausts / cols)
	local grid = Instance.new("Frame")
	grid.Name = "Exhausts"
	grid.LayoutOrder = 4
	grid.Size = UDim2.new(1, 0, 0, lines * touch + (lines - 1) * 6)
	grid.BackgroundTransparency = 1
	grid.Parent = s
	local cells = Instance.new("UIGridLayout")
	cells.CellSize = UDim2.new(1 / cols, -4, 0, touch)
	cells.CellPadding = UDim2.fromOffset(6, 6)
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.Parent = grid
	-- Name over status, centred as a block. The status is in the condensed Display font so "FITTING..."
	-- (and BUY's "BUY $8,000") fit a chip a third of the screen wide at a phone's text size.
	for i, exhaust in ipairs(Garage.Exhausts) do
		local key = exhaust.Key
		local fitted = tune.Exhaust == key
		local bought = tune.Owned[key] == true
		local armKey = id .. "/X:" .. key
		local fitting = not fitted and sent(armKey)
		local chip = tuneButton(grid, key, touch, i, fitted and "Primary" or (fitting and "Confirm" or "Quiet"), function()
			previewExhaust(key) -- every chip, the fitted one too
			if fitted then
				return
			end
			if bought then
				-- Yours already: one tap fits it, free (canBuy: not while the cops watch or a purchase is on its way).
				if canBuy(0, exhaust.Name) then
					exhaustPick = nil
					send(armKey, function()
						Remotes.Event("RequestExhaust"):FireServer(id, key)
					end)
					show("Tune") -- FITTING... on the chip
				end
			else
				pickExhaust(armKey) -- only heard: BUY, above, offers it now (no toast, no cash check, no cost)
			end
		end)
		local ink = chip.TextColor3
		if offer == exhaust and not fitting then
			-- The one BUY offers: a solid chip with a pink line along its foot (Theme: pink only as a
			-- highlight). Every quiet chip is the lighter colour in here (see lift), so the line is what
			-- marks it: 3 px, which is still 2 real pixels on a phone.
			chip.BackgroundTransparency = 0
			local mark = Instance.new("Frame")
			mark.Name = "Picked"
			mark.Size = UDim2.new(1, -12, 0, 3)
			mark.Position = UDim2.new(0, 6, 1, -6)
			mark.BackgroundColor3 = Theme.Color.Brand
			mark.BorderSizePixel = 0
			mark.Parent = chip
		end
		themeText(chip, exhaust.Name, UDim2.new(1, -8, 0, chipName), UDim2.new(0, 4, 0.5, chipTop), 14, "Display", ink,
			Enum.TextXAlignment.Center)
		local status, statusColor
		if fitted then
			status, statusColor = "FITTED", ink
		elseif fitting then
			status, statusColor = "FITTING...", ink
		elseif bought then
			status, statusColor = "OWNED", Theme.Color.Dim
		else
			status, statusColor = money(exhaust.Price), cash >= exhaust.Price and Theme.Color.Cash or Theme.Color.Dim
		end
		themeText(chip, status, UDim2.new(1, -8, 0, small), UDim2.new(0, 4, 0.5, chipTop + chipName + 2), 11, "Display",
			statusColor, Enum.TextXAlignment.Center)
		flash(chip, armKey, now)
	end

	-- The five tracks. The whole row is the buy button for its next stage: name and pips over the gain
	-- (centred as a block), the price on the right. The pips already say which stage it's on.
	local nameTop = -math.floor((big + 2 + small) / 2)
	for i, track in ipairs(tracks) do
		local key = track.Key
		local stage = tune.Stages[key]
		local price = Garage.StagePrice(def, key, stage + 1) -- nil once the track is maxed
		local armKey = id .. "/" .. key
		local fitting = price ~= nil and sent(armKey)
		local confirm = fitting or (price ~= nil and armed(armKey))
		local r = tuneButton(s, key, touch, 10 + i, confirm and "Confirm" or "Quiet", function()
			if price and canBuy(price, key .. " stage " .. (stage + 1)) then
				armOrRun(armKey, function()
					-- The stage this row shows: after a slow answer and a second try, the server won't sell
					-- the next (dearer) stage in its place.
					Remotes.Event("RequestTune"):FireServer(id, key, stage + 1)
				end, { Id = id, Stages = stagesAfter(tune.Stages, { { Track = key, Stage = stage + 1 } }) })
			end
		end)
		r.AutoButtonColor = price ~= nil
		local ink = r.TextColor3
		themeText(r, string.upper(key), UDim2.new(0, 72, 0, big), UDim2.new(0, 10, 0.5, nameTop), 17, "Display", ink)
		pips(r, UDim2.new(0, 86, 0.5, nameTop + math.floor((big - 10) / 2)), stage, #track.Gain, ink)
		-- The gain the next stage brings the car to (over stock), or the last one's on a maxed track. While
		-- armed the bars above show that gain, so the line says what to do.
		local line
		if not price then
			line = "+" .. percent(track.Gain[stage]) .. "% " .. track.What
		elseif fitting then
			line = "FITTING..."
		elseif confirm then
			line = "TAP AGAIN"
		else
			line = "+" .. percent(track.Gain[stage + 1]) .. "% " .. track.What
		end
		themeText(r, line, UDim2.new(1, -112, 0, small), UDim2.new(0, 10, 0.5, nameTop + big + 2), 11, "Body",
			confirm and ink or Theme.Color.Dim)
		local priceColor = Theme.Color.Gold -- MAX
		if price then
			priceColor = confirm and ink or (cash >= price and Theme.Color.Cash or Theme.Color.Dim)
		end
		themeText(r, price and money(price) or "MAX", UDim2.new(0, 90, 0, big), UDim2.new(1, -100, 0.5, -math.floor(big / 2)), 17,
			"Display", priceColor, Enum.TextXAlignment.Right)
		flash(r, armKey, now)
	end

	-- Two lines' room: it wraps at a phone's text size.
	local foot = themeText(s, "Upgrades fit at once if the car is out.", UDim2.new(1, 0, 0, small * 2 + 6), nil, 11, "Body",
		Theme.Color.Dim, Enum.TextXAlignment.Center, true)
	foot.Name = "Hint"
	foot.LayoutOrder = 30
	foot.TextWrapped = true
	foot.TextTruncate = Enum.TextTruncate.None
end

-- A place from MapService's Places list by name (the dealerships add themselves there), else `fallback`.
local function placePos(name, fallback)
	local ok, places = pcall(function()
		return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("Places") or "[]")
	end)
	for _, p in ipairs(ok and places or {}) do
		if p.n == name then
			return Vector3.new(p.x, 0, p.z)
		end
	end
	return fallback
end

-- Point the GPS at a place from that list (or `fallback`) and put the phone away.
local function routeTo(name, fallback)
	local pos = placePos(name, fallback)
	if not pos then
		NotifyController.Show("Can't find " .. name .. " on the map yet. Try again in a moment!", nil, "info")
		return
	end
	GPSClient.SetTarget(name, pos)
	PhoneUI.Close()
end

PAGES.Tune = tunePage

------------------------------------------------------------------ AUTONEON, HOME, GPS, JOBS

function PAGES.Dealer()
	setHeader("AUTONEON", "Home")
	local mine = owned()
	local touch, nameH, small = touchHeight(), textPx(15) + 4, textPx(13)
	local statH = small + 11
	-- Name and price, class (and a heist lock), four small stats two by two, then one wide button.
	local yClass = 10 + nameH + 2
	local yStats = yClass + small + 4 + 8
	local yButton = yStats + statH * 2 + 6 + 10
	local s = W.list(0)
	W.note(s, "Browse here, buy in person: see each ride up close at the dealership.", 0).Name = "Intro"
	for i, def in ipairs(Vehicles.List) do
		if def.Police or def.Hidden then
			continue
		end
		local r = W.row(s, def.Id, yButton + touch + 10, i)
		local have = player:GetAttribute("BigHeists") or 0
		local tag, tagColor = money(def.Price or 0), C.Cash
		local class = def.Class or ""
		local text, kind, click
		if mine[def.Id] then
			tag, tagColor = "OWNED", C.Dim
			text, kind = "IN YOUR GARAGE", "Quiet"
		elseif def.Pass then
			tag, tagColor = "GAME PASS", C.Gold
			text, kind = "SEE IT IN THE SHOP", "Quiet"
			click = function()
				S.fromGuide, S.guideScroll = false, nil -- (like a fresh open: the SHOP goes Back to the home screen)
				show("Shop")
			end
		elseif def.UnlockHeists and have < def.UnlockHeists then
			-- Heist-locked (Config.Vehicles UnlockHeists): the lock and this player's count; the cash price
			-- stays on the right of the name.
			class = class .. "  ·  after " .. def.UnlockHeists .. " big heists"
			text, kind = "LOCKED: " .. def.UnlockHeists .. " BIG HEISTS (" .. have .. "/" .. def.UnlockHeists .. ")", "Quiet"
			click = function()
				NotifyController.Show("Pull big heists (" .. Heists.BigNames() .. "), or help your crew pull them, to unlock the "
					.. (def.DisplayName or def.Id) .. ". Then buy it with cash at the dealer.", C.Gold, "info")
			end
		else
			local where = def.Boat and K.Dealers.Boats or K.Dealers.Cars
			text, kind = def.Boat and "GPS TO THE MARINA" or "GPS TO THE DEALER", "Quiet"
			click = function()
				routeTo(where.Name, where.Pos)
			end
		end
		themeText(r, def.DisplayName or def.Id, UDim2.new(0.6, 0, 0, nameH), UDim2.fromOffset(0, 10), 15, "Bold")
		themeText(r, tag, UDim2.new(0.4, 0, 0, nameH), UDim2.new(0.6, 0, 0, 10), 15, "Display", tagColor, Enum.TextXAlignment.Right)
		themeText(r, class, UDim2.new(1, 0, 0, small + 4), UDim2.fromOffset(0, yClass), 13, "Body", C.Dim)
		local stats = W.frame(r, "Stats")
		stats.Position = UDim2.fromOffset(0, yStats)
		stats.Size = UDim2.new(1, 0, 0, statH * 2 + 6)
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.new(0.5, -6, 0, statH)
		grid.CellPadding = UDim2.fromOffset(12, 6)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = stats
		local speed = def.MaxSpeed or 120
		W.stat(stats, 1, "SPEED", math.floor(speed * K.StudsToMph + 0.5) .. " mph", speed / math.max(Vehicles.TopSpeed or 200, 1))
		W.stat(stats, 2, "ACCEL", (def.AccelRating or 1) .. " / 5", (def.AccelRating or 1) / 5)
		W.stat(stats, 3, "HANDLING", (def.HandlingRating or 1) .. " / 5", (def.HandlingRating or 1) / 5)
		W.stat(stats, 4, "TOUGH", (def.Toughness or 1) .. " / 5", (def.Toughness or 1) / 5)
		local b = W.button(r, "Buy", text, kind, click)
		b.Position = UDim2.fromOffset(0, yButton)
		b.Size = UDim2.new(1, 0, 0, touch)
		if not click then
			b.TextColor3 = C.Dim -- nothing to do with one you own
			b.AutoButtonColor = false
		end
	end
end

function PAGES.Home_()
	setHeader("HOME", "Home")
	local ok, HouseClient = pcall(function()
		return require(script.Parent:WaitForChild("HouseClient", 2))
	end)
	if not ok or not HouseClient then
		W.note(ui.screen, "Homes are loading...", 0, C.Text, Enum.TextXAlignment.Center)
		return
	end
	local s = W.list(0)
	local mine = HouseClient.HomeName()
	W.item(s, {
		Name = "MyHome", Order = 0,
		Title = mine or "You don't own a home yet",
		Sub = mine and "You spawn there in free roam, and your cars wait in its garage." or "Pick one below and drive to its front door.",
		Button = mine and "GO HOME" or "HOW IT WORKS", ButtonName = "GoHome", Kind = mine and "Primary" or "Quiet", Width = 124,
		OnTap = function()
			if HouseClient.RouteTo() then
				PhoneUI.Close()
			else
				NotifyController.Show("Pick a home below, drive to its front door and press View / Buy. You spawn there and your cars wait in its garage.",
					nil, "info")
			end
		end,
	})
	for i, h in ipairs(HouseClient.Homes()) do
		W.item(s, {
			Name = h.Id, Order = i,
			Title = h.Name,
			Sub = h.Blurb,
			Meta = (h.Owned and "YOURS" or money(h.Price)) .. "  ·  " .. tostring(h.GarageSlots) .. " cars  ·  "
				.. GPSClient.FormatDistance(GPSClient.Distance(h.Position) or 0),
			MetaColor = h.Owned and C.Gold or C.Cash,
			Button = "GPS", ButtonName = "Go", Width = 72,
			OnTap = function()
				HouseClient.RouteTo(h.Id)
				PhoneUI.Close()
			end,
		})
	end
end

------------------------------------------------------------------ EMPIRE (player businesses)

-- Your Empire rank (its XP bar and the next unlock), your businesses (level, trickle, the register with its
-- bar, GPS; COLLECT from here at Empire rank RemoteCollect+), businesses for sale (price, what unlocks them,
-- distance, GPS) and the ones coming in later updates. Everything comes from BusinessClient (the server
-- checks COLLECT again); BusinessClient redraws this page when its numbers change (PhoneUI.Refresh).
function PAGES.Empire()
	setHeader("EMPIRE", "Home")
	local ok, BusinessClient = pcall(function()
		return require(script.Parent:WaitForChild("BusinessClient", 2))
	end)
	if not ok or type(BusinessClient) ~= "table" or type(BusinessClient.On) ~= "function" or not BusinessClient.On() then
		W.note(ui.screen, "Businesses are loading...", 0, C.Text, Enum.TextXAlignment.Center)
		return
	end
	local s = W.list(0)
	local emp = BusinessClient.Empire()
	local info = emp.Need <= 0 and "Max rank!" or (emp.Into .. " / " .. emp.Need .. " XP" .. (emp.Next and ("  ·  next: " .. emp.Next) or ""))
	local _, _, rankWords = W.item(s, {
		Name = "Rank", Order = 0,
		Title = "EMPIRE RANK " .. emp.Rank .. (emp.Title and ("  ·  " .. string.upper(tostring(emp.Title))) or ""), TitleColor = C.Gold,
		Sub = info,
	})
	W.meter(rankWords, 15, emp.Share, C.Gold)
	local owned = BusinessClient.Owned()
	W.head(s, "YOUR BUSINESSES", 10)
	if #owned == 0 then
		W.note(s, "You don't own a business yet. Each one has its own job that pays more than normal work, and a register that fills while you play.", 11)
	end
	for i, b in ipairs(owned) do
		local full = b.Register >= b.Cap
		local _, _, words = W.item(s, {
			Name = b.Id, Order = 10 + i * 2,
			Title = b.Name .. "  ·  LEVEL " .. b.Level,
			Sub = b.Extra or string.format("+$%d a minute%s  ·  %d jobs done", math.floor(b.Rate + 0.5), b.Busy and " (crew here: +25%)" or "", b.JobsDone),
			SubColor = b.ExtraColor, -- (BusinessClient: a shady business's dirty cash and raid, M3)
			Meta = "REGISTER " .. money(b.Register) .. " / " .. money(b.Cap) .. (full and "  ·  FULL" or ""),
			MetaColor = full and C.Gold or C.Cash,
			Button = "GPS", ButtonName = "Go", Width = 72,
			OnTap = function()
				BusinessClient.RouteTo(b.Id)
				PhoneUI.Close()
			end,
		})
		W.meter(words, 35, b.Register / math.max(b.Cap, 1), full and C.Gold or C.Cash)
		if emp.RemoteCollect then
			local collect = W.button(s, "Collect" .. b.Id, "COLLECT " .. money(b.Register), b.Register >= 1 and "Primary" or "Quiet", function()
				BusinessClient.Collect(b.Id)
			end)
			collect.Size = UDim2.new(1, 0, 0, touchHeight())
			collect.LayoutOrder = 11 + i * 2
		end
	end
	if #owned > 0 and not emp.RemoteCollect then
		W.note(s, "Collect at the business (Manage at its door), or from here at Empire rank " .. tostring(emp.RemoteRank) .. ".", 39)
	end
	local sale = BusinessClient.ForSale()
	if #sale > 0 then
		W.head(s, "FOR SALE", 40)
		for i, b in ipairs(sale) do
			W.item(s, {
				Name = "Sale" .. b.Id, Order = 40 + i,
				Title = b.Name,
				Sub = tostring(b.JobLine or "") .. "  ·  register +$" .. tostring(b.Trickle) .. " a minute",
				Meta = money(b.Price) .. (b.Locked and ("  ·  EMPIRE " .. b.Unlock .. " NEEDED") or "") .. "  ·  "
					.. GPSClient.FormatDistance(GPSClient.Distance(b.Pos) or 0),
				MetaColor = b.Locked and C.Purple or C.Cash,
				Button = "GPS", ButtonName = "Go", Width = 72,
				OnTap = function()
					BusinessClient.RouteTo(b.Id)
					PhoneUI.Close()
				end,
			})
		end
	end
	local soon = BusinessClient.ComingSoon()
	if #soon > 0 then
		W.head(s, "COMING SOON", 70)
		for i, b in ipairs(soon) do
			W.item(s, {
				Name = "Soon" .. b.Id, Order = 70 + i,
				Title = b.Name, TitleColor = C.Dim,
				Sub = tostring(b.JobLine or ""),
				Meta = money(b.Price) .. ((b.Unlock or 1) > 1 and ("  ·  EMPIRE " .. b.Unlock) or "") .. (b.Kind == "Shady" and "  ·  SHADY" or ""),
			})
		end
	end
	W.note(s, "Empire XP: buy and upgrade businesses, finish their jobs, serve player customers and stop break-ins.", 100, nil,
		Enum.TextXAlignment.Center)
end

function PAGES.GPS()
	setHeader("GPS", "Home")
	local places = {}
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("Places") or "[]")
	end)
	if ok and type(decoded) == "table" then
		places = decoded
	end
	local open = {}
	for id in string.gmatch(ReplicatedStorage:GetAttribute("OpenHeists") or "", "[^,]+") do
		open[id] = true
	end
	local touch = touchHeight()
	-- Three tabs side by side (6 px apart), the one showing in white.
	local tabs = W.frame(ui.screen, "Tabs")
	tabs.Position = UDim2.fromOffset(0, 8)
	tabs.Size = UDim2.new(1, 0, 0, touch)
	for i, t in ipairs(K.GpsTabs) do
		local tab = W.button(tabs, t[1], t[2], S.gpsTab == t[1] and "Primary" or "Quiet", function()
			S.gpsTab = t[1]
			show("GPS")
		end)
		tab.Position = UDim2.new((i - 1) / 3, (i - 1) * 2, 0, 0)
		tab.Size = UDim2.new(1 / 3, -4, 1, 0)
	end
	local top = 8 + touch + 8
	if GPSClient.Target() then
		local clearRoute = W.button(ui.screen, "ClearRoute", "CLEAR ROUTE", "Quiet", function()
			GPSClient.Clear()
			show("GPS")
		end)
		clearRoute.Position = UDim2.fromOffset(0, top)
		clearRoute.Size = UDim2.new(1, 0, 0, touch)
		top += touch + 8
	end
	local s = W.list(top)
	local rows = {}
	for _, p in ipairs(places) do
		if p.c == S.gpsTab or (S.gpsTab == "Service" and p.c == "Business") then -- (businesses under PLACES)
			local pos = Vector3.new(p.x, 0, p.z)
			table.insert(rows, { p = p, pos = pos, d = GPSClient.Distance(pos) or 0 })
		end
	end
	table.sort(rows, function(a, b)
		if S.gpsTab == "Heist" and (open[a.p.id] ~= nil) ~= (open[b.p.id] ~= nil) then
			return open[a.p.id] ~= nil
		end
		return a.d < b.d
	end)
	for i, item in ipairs(rows) do
		local p = item.p
		local status = (p.k and (p.k .. " · ") or "") .. GPSClient.FormatDistance(item.d)
		local nameColor, statusColor
		if p.c == "Heist" then
			-- Open heists first and in full white, with OPEN in green; closed ones dim.
			nameColor = not open[p.id] and C.Dim or nil
			statusColor = open[p.id] and C.Cash or nil
			status = (open[p.id] and "OPEN · " or "closed · ") .. GPSClient.FormatDistance(item.d)
		end
		W.item(s, {
			Name = tostring(p.id or p.n), Order = i,
			Title = p.n, TitleColor = nameColor,
			Sub = status, SubColor = statusColor,
			Button = "GO", ButtonName = "Go", Width = 64,
			OnTap = function()
				GPSClient.SetTarget(p.n, item.pos)
				PhoneUI.Close()
			end,
		})
	end
	if #rows == 0 then
		W.note(s, "Nothing on the map here yet.", 1, nil, Enum.TextXAlignment.Center)
	end
end

function PAGES.Jobs()
	setHeader("JOBS", "Home")
	local s = W.list(0)
	-- Police duty: an optional job (everyone joins free roam). TeamService checks heat, the cooldown and
	-- the cop cap and says why in a toast; a switch respawns you at your side's spawn with its starter
	-- car, and the phone goes away when it lands (PhoneUI.Init, "Side").
	local cop = (player:GetAttribute("Side") or "Civilian") == "Cop"
	local cops = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Side") == "Cop" then
			cops += 1
		end
	end
	W.item(s, {
		Name = "Duty", Order = 1,
		Title = cop and "ON DUTY: POLICE" or "POLICE: AN OPTIONAL JOB", TitleColor = C.Police,
		Sub = cop and "Chase wanted players for bounties. Go off duty to roam free again."
			or "Chase wanted players for bounties. Go off duty any time.",
		Meta = "Cops on duty: " .. cops .. " / " .. Teams.MaxCops(#Players:GetPlayers()), MetaColor = C.Police,
		Button = cop and "GO OFF DUTY" or "GO ON DUTY", ButtonName = "Duty", Kind = cop and "Quiet" or "Primary", Width = 124,
		OnTap = function()
			S.dutyAskedAt = os.clock()
			Remotes.Event("RequestTeam"):FireServer(cop and "Civilian" or "Cop")
		end,
	})
	local jobs = {
		{ "Taxi driver", "Pick up passengers, drop them off fast for tips.", "Taxi Stand" },
		{ "Street racer", "Beat par on 3 routes. Set a best time!", "Ocean Drive Sprint" },
		{ "Drifter", "Slide through the Drift Zone on Lighthouse Key.", "Drift Zone" },
	}
	for i, j in ipairs(jobs) do
		W.item(s, {
			Name = j[3], Order = i + 1,
			Title = j[1],
			Sub = j[2],
			Button = "GPS", ButtonName = "Go", Width = 72,
			OnTap = function()
				routeTo(j[3], nil)
			end,
		})
	end
	-- Phone missions (MissionService): full pay once a day each.
	local done = {}
	for id in string.gmatch(player:GetAttribute("MissionsDone") or "", "[^,]+") do
		done[id] = true
	end
	W.head(s, "MISSIONS", 50)
	for i, m in ipairs(Missions.List) do
		W.item(s, {
			Name = m.Id, Order = 50 + i,
			Title = m.Name .. (done[m.Id] and "  ✓" or ""), TitleColor = done[m.Id] and C.Cash or nil,
			Sub = m.Blurb,
			Meta = (done[m.Id] and "repeat " or "") .. money(done[m.Id] and math.floor(m.Cash * Missions.RepeatShare) or m.Cash)
				.. (m.NeedsBoat and "  ·  boat" or ""),
			MetaColor = C.Cash,
			Button = "START", ButtonName = "Start", Kind = "Primary", Width = 84,
			OnTap = function()
				Remotes.Event("RequestMission"):FireServer("Start", m.Id)
				PhoneUI.Close()
			end,
		})
	end
end

------------------------------------------------------------------ shop

local priceCache = {} -- [Id] = the Robux price Roblox gave for it (read live: Config.Shop's is only a start)

-- "R$ 499": Roblox's live price once the item has a real Id (a web call: yields, cached), else the
-- starting price in Config.Shop. noWait: no web call (what's known right now, for the first draw).
local function priceText(item, infoType, noWait)
	if item.Id ~= 0 and priceCache[item.Id] == nil and not noWait then
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, item.Id, infoType)
		if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
			priceCache[item.Id] = info.PriceInRobux
		end
	end
	local robux = item.Id ~= 0 and priceCache[item.Id] or item.Price
	return type(robux) == "number" and ("R$ " .. string.sub(money(robux), 2)) or ""
end

-- One SHOP row: the item's words, its Robux price and one button: OWNED, FREE (Studio and the game's
-- owner, "ShopFree": the server grants it, RequestShopFree), BUY (Roblox's prompt) or SOON (no Id yet).
-- kind = "Pass" | "Product" (RequestShopFree's kinds).
function W.shopRow(parent, kind, item, order, o)
	local free = player:GetAttribute("ShopFree")
	local infoType = kind == "Pass" and Enum.InfoType.GamePass or Enum.InfoType.Product
	local tail = "" -- after the price on the row's last line
	local text, buttonKind, tap
	if o.Owns then
		text, buttonKind, tail = "OWNED", "Quiet", "  ·  yours"
	elseif free == "Studio" or free == "Owner" then
		text, buttonKind = "FREE", "Confirm"
		tail = free == "Studio" and "  ·  free in Studio" or "  ·  free for you"
		tap = function()
			Remotes.Event("RequestShopFree"):FireServer(kind, item.Key)
		end
	elseif item.Id ~= 0 then
		text, buttonKind = "BUY", "Primary"
		tap = function()
			if kind == "Pass" then
				MarketplaceService:PromptGamePassPurchase(player, item.Id)
			else
				MarketplaceService:PromptProductPurchase(player, item.Id)
			end
		end
	else
		text, buttonKind, tail = "SOON", "Quiet", "  ·  COMING SOON"
		tap = function()
			NotifyController.Show((kind == "Pass" and (tostring(item.Name) .. " is") or "Cash packs are") .. " coming soon!", nil, "info")
		end
	end
	local _, b, words = W.item(parent, {
		Name = item.Key, Order = order,
		Title = o.Title, TitleColor = o.TitleColor, Sub = o.Sub,
		Meta = priceText(item, infoType, true) .. tail, MetaColor = C.Text,
		Button = text, ButtonName = "Buy", Kind = buttonKind, Width = 96,
		OnTap = function()
			if tap then
				tap()
			end
		end,
	})
	if not tap and b then
		b.TextColor3 = C.Dim -- nothing to do with one you own
		b.AutoButtonColor = false
	end
	if item.Id ~= 0 and priceCache[item.Id] == nil then
		task.spawn(function()
			local price = priceText(item, infoType)
			local meta = words:FindFirstChild("Meta")
			if meta and meta.Parent then
				meta.Text = price .. tail
			end
		end)
	end
end

function PAGES.Shop()
	setHeader("SHOP", "Home")
	local s = W.list(0)
	local free = player:GetAttribute("ShopFree")
	if free == "Studio" then
		W.note(s, "STUDIO TEST: every pass and cash pack here is free and instant.", -1, C.Gold, Enum.TextXAlignment.Center).Name = "Free"
	elseif free == "Owner" then
		W.note(s, "YOUR GAME: every pass is on for you, and cash packs are free.", -1, C.Gold, Enum.TextXAlignment.Center).Name = "Free"
	end
	W.head(s, "GAME PASSES", 0)
	for i, pass in ipairs(Shop.Passes) do
		W.shopRow(s, "Pass", pass, i, {
			Title = pass.Name, Sub = pass.Perk, Owns = player:GetAttribute("Pass_" .. pass.Key) == true,
		})
	end
	W.head(s, "CASH PACKS", 49)
	-- Honest about what cash packs can't do: heist locks, cop ranks and pass cars stay locked.
	W.note(s, "Cash packs add cash only: they can't skip heist locks, cop ranks or passes.", 50).Name = "CashNote"
	for i, product in ipairs(Shop.Products) do
		W.shopRow(s, "Product", product, 50 + i, { Title = money(product.Cash), TitleColor = C.Cash })
	end
	W.note(s, "Prices in Robux. Cash goes straight into your bank.", 100, nil, Enum.TextXAlignment.Center).Name = "Foot"
end

------------------------------------------------------------------ goals: ranks + daily challenges

-- The daily spin (SpinClient): today's spin or when the next one comes, the boosts running, and a button
-- that sets the GPS to the Lucky Wheel downtown, where the spin happens.
function PAGES.Spin()
	setHeader("DAILY SPIN", "Home")
	local ok, SpinClient = pcall(function()
		return require(script.Parent:WaitForChild("SpinClient", 2))
	end)
	if not ok or type(SpinClient) ~= "table" or type(SpinClient.Status) ~= "function" then
		W.note(ui.screen, "The wheel is loading...", 0, C.Text, Enum.TextXAlignment.Center)
		return
	end
	local st = SpinClient.Status()
	local s = W.list(0)
	local function hm(seconds)
		seconds = math.max(0, math.floor(seconds or 0))
		local h, m = seconds // 3600, (seconds % 3600) // 60
		return h > 0 and (h .. "h " .. m .. "m") or (math.max(m, 1) .. "m")
	end
	W.item(s, {
		Name = "Today", Order = 0,
		Title = st.Ready and "YOUR FREE SPIN IS READY" or "TODAY'S SPIN IS USED", TitleColor = st.Ready and C.Gold or C.Text,
		Sub = st.Ready and "Spin the Lucky Wheel downtown: cash, 2X CASH, 2X XP, a free gun, or a 1 in 18 shot at a supercar."
			or ("Next free spin in " .. hm(st.NextIn) .. ". Anyone can watch the wheel downtown."),
		Meta = "LUCKY WHEEL  ·  " .. GPSClient.FormatDistance(GPSClient.Distance(SpinClient.WheelPos()) or 0),
		MetaColor = C.Gold,
	})
	for i, kind in ipairs({ "Cash", "XP" }) do
		if (st[kind] or 0) > 0 then
			W.item(s, {
				Name = "Boost" .. kind, Order = i,
				Title = "2X " .. string.upper(kind) .. " ON", TitleColor = kind == "Cash" and C.Cash or C.Purple,
				Sub = hm(st[kind]) .. " of play left",
			})
		end
	end
	local open = W.button(s, "OpenWheel", "GPS TO THE LUCKY WHEEL", st.Ready and "Primary" or "Quiet", function()
		SpinClient.RouteToWheel()
		PhoneUI.Close()
	end)
	open.Size = UDim2.new(1, 0, 0, touchHeight())
	open.LayoutOrder = 10
	W.note(s, "One spin a day for everyone. Every slice of the wheel is the same size: each one is a 1 in 18 chance. "
		.. "Boosts only count down while you play.", 20, nil, Enum.TextXAlignment.Center)
end

function PAGES.Goals()
	setHeader("GOALS", "Home")
	local ProgressClient = require(script.Parent:WaitForChild("ProgressClient"))
	local s = W.list(0)
	-- Goal chain hidden with its X (JourneyService)? Offer it back; the server puts it where it was.
	if player:GetAttribute("JourneyHidden") == true then
		W.gap(s, -2, 8)
		local again = W.button(s, "ShowGoals", "SHOW MY GOALS AGAIN", "Quiet", function()
			Remotes.Event("JourneyStep"):FireServer("Show")
		end)
		again.Size = UDim2.new(1, 0, 0, touchHeight())
		again.LayoutOrder = -1
		W.gap(s, 0, 8)
	end
	for i, side in ipairs({ "Civilian", "Cop" }) do
		local rank, frac, xp, nextXP = ProgressClient.Progress(side)
		local cop = side == "Cop"
		local unlocks = Progression.Unlocks[cop and "cop" or "civ"]
		local nextUnlock
		for rr = rank + 1, Progression.MaxRank do
			if unlocks[rr] then
				nextUnlock = "Rank " .. rr .. ": " .. unlocks[rr]
				break
			end
		end
		local info = rank >= Progression.MaxRank and "Max rank!" or (xp .. " / " .. nextXP .. " XP" .. (nextUnlock and ("  ·  next: " .. nextUnlock) or ""))
		local _, _, words = W.item(s, {
			Name = side, Order = i,
			Title = (cop and "POLICE" or "FREE ROAM") .. "  ·  RANK " .. rank, TitleColor = cop and C.Police or nil,
			Sub = info,
		})
		W.meter(words, 15, frac, cop and C.Police or C.Text)
	end
	local reward = Progression.ChallengeReward
	W.head(s, "TODAY'S CHALLENGES  ·  " .. money(reward.Cash) .. " + " .. reward.XP .. " XP EACH", 10, C.Gold)
	local ok, listData = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("Challenges") or "[]")
	end)
	local byId = {}
	for _, c in ipairs(Progression.Challenges) do
		byId[c.Id] = c
	end
	for i, entry in ipairs(ok and type(listData) == "table" and listData or {}) do
		local def = byId[entry.id]
		if def then
			local progress = tonumber(entry.p) or 0
			local _, _, words = W.item(s, {
				Name = def.Id, Order = 10 + i,
				Title = (entry.done and "✓ " or "") .. def.Text, TitleColor = entry.done and C.Cash or nil,
			})
			W.meter(words, 15, progress / math.max(def.Goal, 1), entry.done and C.Cash or (def.Side == "Cop" and C.Police or C.Text),
				progress .. "/" .. def.Goal)
		end
	end
	W.note(s, "New challenges every day at midnight (UTC).", 100, nil, Enum.TextXAlignment.Center)
end

------------------------------------------------------------------ crew

-- Roblox's invite check and the friends-online list are web calls that wait and can fail (and Studio
-- sends no invites), so they're asked in the background and the CREW page redraws when they answer.
-- While the CREW page stays open the friends list is asked again every K.FriendsFresh seconds (PhoneUI.Init).
local crew = {
	inviteOk = nil, -- nil: not known yet, else Roblox's answer
	inviteAsking = false, -- the INVITE FRIENDS slot shows a dim placeholder meanwhile (no rows jump later)
	inviteFailedAt = nil, -- os.clock() of the last failed check (asked again a minute later)
	friendsOnline = nil, -- { At = os.clock(), List = { GetFriendsOnline entries }, Failed = bool }
	friendsAsking = false,
	friendsSig = nil, -- what the last answer showed: the page only redraws when that changes
	queued = false,
	joiningUntil = {}, -- [friend's UserId] = os.clock() until which their JOIN button shows JOINING...
	bigScoreLine = nil, -- THE BIG SCORE's status label on the page as drawn (the 0.5 s loop rewrites its words)
	bigScoreKey = nil, -- ...and what that line meant then (a change redraws the page: START / QUIT follow it)
	quitArmedUntil = 0, -- os.clock() until which QUIT waits for its second tap
	leaveArmedUntil = 0, -- os.clock() until which LEAVE CREW waits for its second tap
}

-- The crew job's preps done (CrewService's "CrewPreps": ",id,id," or "" for none; nil without a crew):
-- done, how many there are, and the raw list.
function crew.prepCount()
	local list = player:GetAttribute("CrewPreps")
	local preps = (Missions.CrewJob and Missions.CrewJob.Preps) or {}
	local done = 0
	if type(list) == "string" then
		for _, id in ipairs(preps) do
			if string.find(list, "," .. id .. ",", 1, true) then
				done += 1
			end
		end
	end
	return done, #preps, list
end

-- THE BIG SCORE's line: could this player start it right now? Worked out here from what the server
-- publishes (BigScoreService checks it all again, and a refusal comes with a toast that says why).
-- Returns the words, their colour, ready (START would go), running (we're on its roster) and a key that
-- only changes when the meaning does (not every second of a countdown).
function crew.bigScoreStatus()
	local def = Heists.BigScore or {}
	local step = player:GetAttribute("BigScore")
	if step ~= nil then
		return "On the job: step " .. tostring(step) .. "/6. Your goal is at the top of the screen.", C.Gold, false, true,
			"run" .. tostring(step)
	end
	if player:GetAttribute("Side") ~= "Civilian" then
		return "Free-roam players only.", C.Dim, false, false, "side"
	end
	if ReplicatedStorage:GetAttribute("BigScoreBusy") == true then
		return "A crew is on it right now.", C.Dim, false, false, "busy"
	end
	local need, rank = def.MinRank or 3, player:GetAttribute("CivRank") or 1
	if rank < need then
		return "Unlocks at free-roam rank " .. need .. " (you're " .. rank .. ").", C.Purple, false, false, "rank"
	end
	-- The crew job: every crew prep first (no crew: the crew count below says what's missing).
	local prepsDone, prepsTotal, prepList = crew.prepCount()
	if type(prepList) == "string" and prepsDone < prepsTotal then
		return "Do your crew preps first: " .. prepsDone .. "/" .. prepsTotal .. " done (above).", C.Orange, false, false,
			"preps" .. prepsDone
	end
	local t = Workspace:GetServerTimeNow()
	local readyAt = player:GetAttribute("BigScoreReadyAt")
	if type(readyAt) == "number" and readyAt > t then
		local left = math.ceil(readyAt - t)
		return string.format("Laying low: ready again in %d:%02d", left // 60, left % 60), C.Dim, false, false, "wait"
	end
	if (player:GetAttribute("Heat") or 0) > 0 then
		return "Lose the cops first.", C.Danger, false, false, "heat"
	end
	if player:GetAttribute("Mission") ~= nil or player:GetAttribute("RacingId") ~= nil or player:GetAttribute("JobKind") ~= nil then
		return "Finish what you're doing first.", C.Orange, false, false, "doing"
	end
	-- Who could come along: crewmates in free roam, not on a mission, race or job shift, past their own
	-- cooldown (just you without a crew).
	local count = 1
	local id = player:GetAttribute("Crew")
	if id then
		local ok, crews = pcall(HttpService.JSONDecode, HttpService, ReplicatedStorage:GetAttribute("Crews") or "{}")
		local ids = ok and type(crews) == "table" and crews[id]
		if type(ids) == "table" then
			count = 0
			for _, uid in ipairs(ids) do
				local p = Players:GetPlayerByUserId(tonumber(uid) or 0)
				local at = p and p:GetAttribute("BigScoreReadyAt")
				local busy = p and (p:GetAttribute("Mission") ~= nil or p:GetAttribute("RacingId") ~= nil or p:GetAttribute("JobKind") ~= nil)
				if p and p:GetAttribute("Side") == "Civilian" and not busy and not (type(at) == "number" and at > t) then
					count += 1
				end
			end
		end
	end
	local min = RunService:IsStudio() and 1 or (def.CrewMin or 2) -- (Studio: solo, so it can be tested alone)
	if count < min then
		return "Needs a crew of " .. min .. "+ ready to go (you have " .. count .. ").", C.Orange, false, false, "crew" .. count
	end
	return "Ready: " .. math.min(count, def.CrewMax or 4) .. " of you can go now.", C.Cash, true, false, "ready" .. count
end

-- Deferred: an answer can land while the CREW page itself is still drawing (it would draw the page twice).
local function redrawCrew()
	if crew.queued then
		return
	end
	crew.queued = true
	task.defer(function()
		crew.queued = false
		if S.open and current == "Crew" then
			show("Crew")
		end
	end)
end

local function askInvite()
	if crew.inviteOk ~= nil or crew.inviteAsking or RunService:IsStudio()
		or (crew.inviteFailedAt and os.clock() - crew.inviteFailedAt < 60) then
		return
	end
	crew.inviteAsking = true
	task.spawn(function()
		local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
		crew.inviteAsking = false
		if ok then
			crew.inviteOk = can == true
		else
			crew.inviteFailedAt = os.clock()
		end
		redrawCrew() -- the button (or nothing) takes the placeholder's place
	end)
end

local function askFriends()
	if crew.friendsAsking or (crew.friendsOnline and os.clock() - crew.friendsOnline.At < K.FriendsFresh) then
		return
	end
	-- Unpublished there are no other servers, and Studio's test players (negative UserIds) have no friends.
	if game.PlaceId == 0 or (RunService:IsStudio() and player.UserId <= 0) then
		crew.friendsOnline = { At = os.clock(), List = {}, Failed = false }
		return
	end
	crew.friendsAsking = true
	task.spawn(function()
		local ok, entries = pcall(player.GetFriendsOnline, player, 200)
		local others = {}
		local sig = ok and "ok" or "failed"
		if ok and type(entries) == "table" then
			for _, f in ipairs(entries) do
				-- In a server of this game that isn't this one (friends in this one are under PLAYERS HERE).
				if f.PlaceId == game.PlaceId and type(f.GameId) == "string" and f.GameId ~= ""
					and f.GameId ~= game.JobId and type(f.VisitorId) == "number" and not Players:GetPlayerByUserId(f.VisitorId) then
					table.insert(others, f)
					sig ..= "|" .. f.VisitorId .. "@" .. f.GameId
				end
			end
		end
		crew.friendsOnline = { At = os.clock(), List = others, Failed = not ok }
		crew.friendsAsking = false
		if sig ~= crew.friendsSig then
			crew.friendsSig = sig
			redrawCrew()
		end
	end)
end

-- Put a JOIN button back once its wait is over (still here: the teleport didn't happen).
local function resetJoinLater(b, id)
	task.delay(math.max(0, (crew.joiningUntil[id] or 0) - os.clock()), function()
		if b.Parent then
			b.Text = "JOIN"
		end
	end)
end

-- Roblox's own invite pop-up. LaunchData carries our UserId so FriendsService knows who a friend came to
-- see (crew invite, spawning beside us). Sending invites never pays anything (Roblox rules).
local function promptInvite()
	local ok = pcall(function()
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = "Come play Theft Miami Coast with me!"
		options.LaunchData = tostring(player.UserId)
		SocialService:PromptGameInvite(player, options)
	end)
	if ok then
		-- Analytics, and tells FriendsService that a friend arriving with our UserId soon was really invited.
		Remotes.Event("RequestFriends"):FireServer("InvitePrompt")
	else
		NotifyController.Show("Invites aren't available right now. Try again later!", nil, "info")
	end
end

-- Today's play-together bonus and the Squad paint, with the rules FriendsService publishes.
local function playTogetherRow(parent, order)
	local need = ReplicatedStorage:GetAttribute("CoplayMinutes") or 10
	local cash = ReplicatedStorage:GetAttribute("CoplayCash") or 2000
	local squad = ReplicatedStorage:GetAttribute("CoplaySquadDays") or 3
	local mins = math.min(player:GetAttribute("CoplayMins") or 0, need)
	local days = player:GetAttribute("CoplayDays") or 0
	local done = player:GetAttribute("CoplayDone") == true
	local _, _, words = W.item(parent, {
		Name = "PlayTogether", Order = order,
		Title = "PLAY TOGETHER",
		Sub = done and "Today's co-op bonus is paid. See you tomorrow!"
			or ("Play " .. need .. " min with a Roblox friend in this server: " .. money(cash) .. " once a day."),
		Meta = days >= squad and "Squad paint unlocked (GARAGE > STYLE)"
			or ("Squad paint: play together on " .. squad .. " days (" .. days .. "/" .. squad .. ")"),
		MetaColor = C.Gold,
	})
	W.meter(words, 25, done and 1 or mins / math.max(need, 1), C.Cash, (done and need or mins) .. "/" .. need .. " min")
end

function PAGES.Crew()
	setHeader("CREW", "Home")
	askInvite()
	askFriends()
	local touch = touchHeight()
	local s = W.list(0)
	W.gap(s, -1, 8)
	if crew.inviteOk then
		local invite = W.button(s, "InviteFriends", "INVITE FRIENDS", "Primary", promptInvite)
		invite.Size = UDim2.new(1, 0, 0, touch)
		invite.LayoutOrder = 0
	elseif crew.inviteAsking then
		-- Holds the button's place until Roblox answers, so the rows below never jump under a finger.
		local slot = themeText(s, "INVITE FRIENDS", UDim2.new(1, 0, 0, touch), nil, 15, "Display", C.Dim, Enum.TextXAlignment.Center)
		slot.Name = "InviteFriends"
		slot.LayoutOrder = 0
		slot.BackgroundTransparency = 0.2
		slot.BackgroundColor3 = K.Card
		Theme.Corners(slot)
	elseif RunService:IsStudio() then
		W.note(s, "INVITE FRIENDS shows here in the live game.", 0, nil, Enum.TextXAlignment.Center).Name = "InviteStudio"
	end
	local myCrew = player:GetAttribute("Crew")
	-- INVITE EVERYONE HERE (CrewService "Call"): a crew call in chat for the whole server and an I'M IN card for
	-- everyone free to join. Citizens only; it reads CREW CALL SENT while this player's call is open.
	if player:GetAttribute("Side") == "Civilian" then
		local callUntil = player:GetAttribute("CrewCallUntil")
		local open = type(callUntil) == "number" and callUntil > workspace:GetServerTimeNow()
		local call = W.button(s, "InviteEveryone", open and "CREW CALL SENT" or "INVITE EVERYONE HERE", open and "Quiet" or "Primary",
			function()
				if not open then
					Remotes.Event("RequestCrew"):FireServer("Call")
					PhoneUI.Close() -- (the answer is a toast, and the I'M IN cards go out to everyone else)
				end
			end)
		call.Size = UDim2.new(1, 0, 0, touch)
		call.LayoutOrder = 1
	end
	W.note(s, (myCrew and "Rob together: +20% cash when a crewmate is close." or "Invite players to rob together (+20% cash) and ride in each other's cars.")
		.. (player:GetAttribute("FriendBonus") and "  Friend here: +10%!" or ""), 2, nil, Enum.TextXAlignment.Center).Name = "Info"
	local order = 3
	-- THE CREW HEIST (CrewService): the preps that unlock THE BIG SCORE, played by the crew together (START sends
	-- RequestCrew "Prep"; the server says why not if it can't), and RESUME HEIST / PAUSE HEIST (the plan on
	-- everyone's screen, CrewClient). Without a crew, what a crew would get.
	local job = Missions.CrewJob or { Preps = {} }
	local prepsDone, prepsTotal, prepList = crew.prepCount()
	local prepRunning = player:GetAttribute("CrewPrepRun")
	if myCrew and type(prepList) == "string" then
		local paused = player:GetAttribute("CrewPaused") == true
		W.head(s, "CREW HEIST: " .. string.upper(job.Name or "The Big Score") .. "   " .. prepsDone .. "/" .. prepsTotal .. " PREPS"
			.. (paused and "   (PAUSED)" or ""), order, C.Gold)
		order += 1
		local toggle = W.button(s, "PauseHeist", paused and "RESUME HEIST" or "PAUSE HEIST", paused and "Primary" or "Quiet",
			function()
				Remotes.Event("RequestCrew"):FireServer("Pause", not paused)
				if paused then
					PhoneUI.Close() -- (the plan comes back on the screen)
				end
			end)
		toggle.Size = UDim2.new(1, 0, 0, touch)
		toggle.LayoutOrder = order
		order += 1
		if paused then
			W.note(s, "Your crew's heist is on hold. Progress is saved: RESUME HEIST puts the plan back on screen.", order).Name =
				"PausedNote"
			order += 1
		end
		for _, id in ipairs(job.Preps or {}) do
			local m = Missions.ById[id]
			if m then
				local isDone = string.find(prepList, "," .. id .. ",", 1, true) ~= nil
				local onIt = prepRunning == id
				W.item(s, {
					Name = "Prep" .. id, Order = order,
					Title = m.Name .. (isDone and "  ✓" or ""), TitleColor = isDone and C.Cash or nil,
					Sub = m.Blurb,
					Meta = isDone and "Done" or onIt and "Your crew is on it now"
						or (money(m.Cash) .. " each  ·  together  ·  " .. math.floor(m.TimeLimit / 60) .. " min"),
					MetaColor = isDone and C.Dim or onIt and C.Gold or C.Cash,
					Button = (not isDone and not onIt and player:GetAttribute("Side") == "Civilian") and "START" or nil,
					ButtonName = "Start", Kind = "Primary", Width = 84,
					OnTap = function()
						Remotes.Event("RequestCrew"):FireServer("Prep", id)
						PhoneUI.Close()
					end,
				})
				order += 1
			end
		end
	elseif not myCrew then
		W.head(s, "CREW HEIST", order, C.Gold)
		order += 1
		W.note(s, "Crews make way more money: The Big Score pays " .. money(Heists.BigScoreCut(2)) .. "+ each. You can team up"
			.. " with anyone in this server: tap INVITE by a name under PLAYERS HERE, or give someone a ride. A crew of 2 to 4"
			.. " drives " .. prepsTotal .. " preps together to unlock it.", order).Name = "JobNote"
		order += 1
	end
	-- THE BIG SCORE (BigScoreService): whether you could start it right now (PhoneUI.Init's 0.5 s loop
	-- keeps the line's countdown fresh) and START, or QUIT (two taps: it can end the job for the whole
	-- crew) while you're on it. Cops get the line without a button.
	local heist = Heists.BigScore or {}
	local status, statusColor, ready, running, key = crew.bigScoreStatus()
	local armed = running and crew.quitArmedUntil > os.clock()
	local bars = heist.Bars or 12
	W.head(s, "THE BIG SCORE", order, C.Gold)
	order += 1
	local bigButton
	local _, b, words = W.item(s, {
		Name = "BigScore", Order = order,
		Title = "Rob the Solana Gold Reserve",
		Sub = "Hack an armored van, open the gate together, drill the vault, load up to " .. bars .. " gold bars and get the van to"
			.. " the Hideout. Crew of " .. (heist.CrewMin or 2) .. "-" .. (heist.CrewMax or 4) .. ": a full van pays "
			.. money(Heists.BigScoreCut(2)) .. " each for 2, " .. money(Heists.BigScoreCut(heist.CrewMax or 4)) .. " each for "
			.. (heist.CrewMax or 4) .. ".",
		Meta = status, MetaColor = statusColor,
		Button = (running or player:GetAttribute("Side") == "Civilian") and (running and (armed and "SURE?" or "QUIT") or "START") or nil,
		ButtonName = running and "Quit" or "Start",
		Kind = running and "Danger" or (ready and "Primary" or "Quiet"),
		Width = 88,
		OnTap = function()
			if not running then
				Remotes.Event("RequestBigScore"):FireServer("Start")
				if ready then
					PhoneUI.Close() -- (the start stamp is on its way; a refusal's toast is easier to read with the phone up)
				end
				return
			end
			if crew.quitArmedUntil <= os.clock() then
				crew.quitArmedUntil = os.clock() + 3
				bigButton.Text = "SURE?"
				task.delay(3.05, function()
					if bigButton.Parent and crew.quitArmedUntil <= os.clock() then
						bigButton.Text = "QUIT"
					end
				end)
				return
			end
			crew.quitArmedUntil = 0
			Remotes.Event("RequestBigScore"):FireServer("Quit")
		end,
	})
	bigButton = b
	if armed and b then
		-- (redrawn while QUIT waits for its second tap: it reads SURE? until the wait is over)
		task.delay(crew.quitArmedUntil - os.clock() + 0.05, function()
			if b.Parent and crew.quitArmedUntil <= os.clock() then
				b.Text = "QUIT"
			end
		end)
	end
	crew.bigScoreLine = words:FindFirstChild("Meta")
	crew.bigScoreKey = key
	order += 1
	if myCrew then
		W.head(s, "YOUR CREW", order)
		order += 1
		-- The saved crew (CrewService's "CrewRoster"), whether they're here or not; whoever is here as a fallback.
		local okRoster, roster = pcall(HttpService.JSONDecode, HttpService, player:GetAttribute("CrewRoster") or "[]")
		local listed = false
		for _, entry in ipairs(okRoster and type(roster) == "table" and roster or {}) do
			local uid = type(entry) == "table" and tonumber(entry.i)
			if uid then
				local p = Players:GetPlayerByUserId(uid)
				local here = p ~= nil and p:GetAttribute("Crew") == myCrew
				W.item(s, {
					Name = "Mate" .. uid, Order = order,
					Title = tostring(entry.n or "?") .. (uid == player.UserId and "  (you)" or ""),
					Sub = uid ~= player.UserId and (here and "Here now" or "Not in this server") or nil,
					SubColor = here and C.Cash or C.Dim,
				})
				order += 1
				listed = true
			end
		end
		if not listed then
			for _, p in ipairs(Players:GetPlayers()) do
				if p:GetAttribute("Crew") == myCrew then
					W.item(s, { Name = "Mate" .. p.UserId, Order = order, Title = p.DisplayName .. (p == player and "  (you)" or "") })
					order += 1
				end
			end
		end
		W.note(s, "Your crew is saved: it's still your crew next time you play.", order).Name = "Saved"
		order += 1
		-- Two taps: leaving a crew of two breaks it up, crew job and all.
		local leaveArmed = crew.leaveArmedUntil > os.clock()
		local leave
		leave = W.button(s, "Leave", leaveArmed and "TAP AGAIN TO LEAVE" or "LEAVE CREW", leaveArmed and "Danger" or "Quiet", function()
			if crew.leaveArmedUntil <= os.clock() then
				crew.leaveArmedUntil = os.clock() + 3
				leave.Text = "TAP AGAIN TO LEAVE"
				task.delay(3.05, function()
					if leave.Parent and crew.leaveArmedUntil <= os.clock() then
						leave.Text = "LEAVE CREW"
					end
				end)
				return
			end
			crew.leaveArmedUntil = 0
			Remotes.Event("RequestCrew"):FireServer("Leave")
		end)
		leave.Size = UDim2.new(1, 0, 0, touch)
		leave.LayoutOrder = order
		order += 1
	end
	W.head(s, "PLAYERS HERE", order)
	order += 1
	if not myCrew and #Players:GetPlayers() > 1 then
		W.note(s, "Anyone here can join your crew: tap INVITE to ask them.", order).Name = "AnyoneNote"
		order += 1
	end
	local any = false
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and (not myCrew or p:GetAttribute("Crew") ~= myCrew) then
			any = true
			local side = p:GetAttribute("Side") or ""
			-- Their crew call is open (CrewService "CrewCallUntil"): I'M IN joins their crew right away.
			local callUntil = p:GetAttribute("CrewCallUntil")
			local calling = type(callUntil) == "number" and callUntil > workspace:GetServerTimeNow()
				and player:GetAttribute("Side") == "Civilian"
			W.item(s, {
				Name = tostring(p.UserId), Order = order,
				Title = p.DisplayName,
				Sub = calling and "Wants to start a heist!" or side == "Cop" and "Police" or side == "Prisoner" and "In prison" or "Free roam",
				SubColor = calling and C.Gold or nil,
				Button = calling and "I'M IN" or "INVITE", ButtonName = calling and "Join" or "Invite", Kind = calling and "Primary" or nil,
				Width = 88,
				OnTap = function()
					if calling then
						Remotes.Event("RequestCrew"):FireServer("CallJoin", p.UserId)
					else
						Remotes.Event("RequestCrew"):FireServer("Invite", p.UserId)
					end
				end,
			})
			order += 1
		end
	end
	if not any then
		W.note(s, crew.inviteOk and "Nobody else here yet. Tap INVITE FRIENDS above!" or "Nobody else here yet.", order, nil,
			Enum.TextXAlignment.Center)
		order += 1
	end
	-- Friends in other servers of this game: JOIN asks the server to teleport us there (FriendsService).
	W.head(s, "FRIENDS IN OTHER SERVERS", order)
	order += 1
	local others = {}
	for _, f in ipairs(crew.friendsOnline and crew.friendsOnline.List or {}) do
		if not Players:GetPlayerByUserId(f.VisitorId) and #others < K.MaxFriendRows then
			table.insert(others, f) -- (a friend who came here since the list was fetched is under PLAYERS HERE)
		end
	end
	for _, f in ipairs(others) do
		local id = f.VisitorId
		local name = f.DisplayName or f.UserName or "Your friend"
		-- A redraw mid-JOIN (a co-op minute, someone joining) keeps showing JOINING... until the wait is over.
		local busy = (crew.joiningUntil[id] or 0) > os.clock()
		local join
		local _, b = W.item(s, {
			Name = "Friend" .. id, Order = order,
			Title = name,
			Sub = "Another Theft Miami Coast server",
			Button = busy and "JOINING..." or "JOIN", ButtonName = "Join", Width = 104,
			OnTap = function()
				if (crew.joiningUntil[id] or 0) > os.clock() then
					return -- already asked (the server says if it can't)
				end
				-- The server refuses these too; checking first saves a "Joining..." that's refused at once.
				if (player:GetAttribute("Heat") or 0) > 0 then
					NotifyController.Show("Lose the cops before joining a friend.", nil, "police")
					return
				end
				if (player:GetAttribute("Carried") or 0) > 0 then
					NotifyController.Show("Bank your bag cash first: it can't come with you!", nil, "money")
					return
				end
				crew.joiningUntil[id] = os.clock() + K.JoinWait
				join.Text = "JOINING..."
				Remotes.Event("RequestFriends"):FireServer("Join", id, f.GameId)
				NotifyController.Show("Joining " .. name .. "...", nil, "crew")
				resetJoinLater(join, id)
			end,
		})
		join = b
		order += 1
		if busy then
			resetJoinLater(join, id)
		end
	end
	if #others == 0 then
		local text
		if game.PlaceId == 0 then
			text = "Friends in other servers show once the game is published."
		elseif not crew.friendsOnline then
			text = "Looking for friends..."
		elseif crew.friendsOnline.Failed then
			text = "Couldn't check your friends right now."
		else
			text = "No friends in other Theft Miami Coast servers right now."
		end
		W.note(s, text, order, nil, Enum.TextXAlignment.Center).Name = "NoFriends"
		order += 1
	end
	playTogetherRow(s, order)
end

------------------------------------------------------------------ settings

function PAGES.Settings()
	setHeader("SETTINGS", "Home")
	local Settings = require(script.Parent:WaitForChild("SettingsClient"))
	local touch, nameH = touchHeight(), textPx(15) + 4
	local s = W.list(0)
	-- A title over five steps side by side (5 px apart), the one in use in white.
	local function volumeRow(key, title, order)
		local r = W.row(s, key, 10 + nameH + 6 + touch + 10, order)
		themeText(r, title, UDim2.new(1, 0, 0, nameH), UDim2.fromOffset(0, 10), 15, "Bold")
		for i, v in ipairs({ 0, 0.25, 0.5, 0.75, 1 }) do
			local on = math.abs((Settings.Get(key) or 0) - v) < 0.01
			local b = W.button(r, key .. i, v == 0 and "OFF" or (math.floor(v * 100) .. "%"), on and "Primary" or "Quiet", function()
				Settings.Set(key, v)
				show("Settings")
			end)
			b.Position = UDim2.new((i - 1) / 5, i - 1, 0, 10 + nameH + 6)
			b.Size = UDim2.new(1 / 5, -4, 0, touch)
		end
	end
	volumeRow("Music", "Music volume", 1)
	volumeRow("Effects", "Sound effects", 2)
	local perf = Settings.Get("Performance")
	W.item(s, {
		Name = "Performance", Order = 3,
		Title = "Performance mode",
		Sub = "Fewer traffic cars and people, no night window glow. Smoother on older phones.",
		Button = perf and "ON" or "OFF", ButtonName = "Toggle", Kind = perf and "Primary" or "Quiet", Width = 72,
		OnTap = function()
			Settings.Set("Performance", not perf)
			show("Settings")
		end,
	})
	-- Passive mode (CombatService decides; this only asks).
	local passive = Settings.Get("Passive")
	W.item(s, {
		Name = "Passive", Order = 4,
		Title = "Passive mode",
		Sub = "Nobody can hit you, and you can't fight. Not while wanted or carrying a bag.",
		Button = passive and "ON" or "OFF", ButtonName = "Toggle", Kind = passive and "Primary" or "Quiet", Width = 72,
		OnTap = function()
			Settings.Set("Passive", not passive) -- only a request; the server answers through the attribute "Passive"
		end,
	})
	-- The key list is for keyboards: a touch-only player has the on-screen buttons instead.
	if not (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) then
		W.note(s, "Keys: P phone · E use · F get in/out · Z aim · X shoot / punch · R reload · Tab weapons · Space drift · Shift nitro · H horn/siren · V radio · R flip (in a car)",
			5, nil, Enum.TextXAlignment.Center).Name = "Keys"
	end
end

------------------------------------------------------------------ how to play

-- Is street-car stealing (CarjackService) running on this server? It creates the RequestCarjack remote.
local function carjackLive()
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	return folder ~= nil and folder:FindFirstChild("RequestCarjack") ~= nil
end

-- The guide's sections, in short lines (most fit on one line) so a whole section fits on a phone screen.
-- Short is the name on its topic chip. Buttons: { text, Gps = place name (+ Fallback position) } routes
-- the GPS, { text, Tab = "Heist" / "Activity" } opens that GPS tab, { text, Page = page } opens a phone
-- page. In the text, [word] marks a key, button or sign (shown in bold white). Touch-only players (the
-- same test as CombatClient's hint) see their on-screen buttons instead of keys. Numbers come from the
-- shared configs; the few that only live in a server service say which one.
local function guideSections()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local function pick(keys, taps)
		return touch and taps or keys
	end
	local homeFrom
	for _, h in ipairs(Housing.List) do
		homeFrom = math.min(homeFrom or h.Price, h.Price)
	end
	local bank = Heists.Types.CoastalBank
	local reward = Progression.ChallengeReward
	-- The bag's size, worked out like EconomyService.CarryLimit (bigger with the Big Duffel Bag pass).
	local bag = math.floor(Heists.CarryLimit * (1 + (player:GetAttribute("Pass_BigDuffel") and Shop.DuffelCarryBonus or 0)))
	-- Coast Arms (Config.Combat): where it is, and what its first gun costs.
	local gunShop = Combat.Shop or {}
	local pistol = Combat.Guns and Combat.Guns.Pistol

	-- Labels from InteractClient's contextual button (JACK, BREAK IN, STEAL; F on a keyboard) and the
	-- HOT CAR sign over CarBoostService's hot cars.
	local steal
	if carjackLive() then
		steal = {
			"Stand in front of a car: it stops.",
			pick("At its door, press [F] to [JACK] it.", "At its door, tap [JACK]."),
			pick("Car park cars: hold [F] to [BREAK IN].", "Car park cars: hold [BREAK IN]."),
			pick("[HOT CAR] sign? Hold [F] to [STEAL].", "[HOT CAR] sign? Hold [STEAL]."),
			"Sell at the Chop Shop. Hot cars pay most!",
		}
	else
		-- Without CarjackService only the hot cars can be stolen.
		steal = {
			"Find a parked car with a [HOT CAR] sign.",
			pick("Hold [F] next to it to [STEAL] it.", "Hold [STEAL] next to it."),
			"Sell it at the Chop Shop for bag cash.",
		}
	end

	local rank = { "Robberies, races and jobs give XP.", "Ranks (up to " .. Progression.MaxRank .. ") unlock rewards." }
	if bank and bank.MinRank then
		local yacht = Heists.Types.SeaDream
		table.insert(rank, "The Coastal Bank" .. ((yacht and yacht.MinRank == bank.MinRank) and " and the Sea Dream need" or " needs")
			.. " rank " .. bank.MinRank .. ".")
	end
	table.insert(rank, "Daily [GOALS]: " .. money(reward.Cash) .. " + " .. reward.XP .. " XP each.")

	return {
		{
			Id = "Controls", Title = "Driving & controls", Short = "DRIVE",
			Lines = pick({
				"[WASD] drive · [Space] drift",
				"[Shift] nitro · [R] flip · [H] horn",
				"[F] get in/out · [E] use · [P] phone",
				"[V] radio · [C] smoke when wanted",
			}, {
				"Tap [GET IN] next to your car.",
				"Steer with the thumbstick.",
				"[GAS] [BRAKE] [NITRO] [DRIFT] [EXIT]",
				"Upside down? [FLIP]. Wanted? [SMOKE].",
			}),
		},
		{
			Id = "Steal", Title = "Steal cars", Short = "STEAL",
			Lines = steal,
			Buttons = { { "GPS: CHOP SHOP", Gps = "Chop Shop" } },
		},
		{
			Id = "Rob", Title = "Rob stores & ATMs", Short = "ROB",
			Lines = {
				pick("Stores: aim at the clerk ([Z]). ATMs: hold [Rob].", "Stores: [AIM] at the clerk. ATMs: hold [Rob]."),
				"[GPS] > [HEISTS] shows which are open.",
				"Cash goes in your bag (max " .. money(bag) .. ").",
				"Lose the cops, bank it at the Hideout.",
			},
			Buttons = { { "OPEN HEISTS", Tab = "Heist" }, { "GPS: HIDEOUT", Gps = "Hideout" } },
		},
		{
			Id = "Wanted", Title = "Wanted stars", Short = "STARS",
			Lines = {
				-- 5: HeatService's cap (the HUD's 5 stars).
				"Crimes give you stars (up to 5).",
				"Stay out of sight and they fade.",
				"Banking at the Hideout clears them.",
				"Spray & Go or a new [OUTFIT] take a star off.",
				pick("Cornered? [H] hands up: cuffed, not shot.", "Cornered? [HANDS UP]: cuffed, not shot."),
			},
			Buttons = { { "GPS: HIDEOUT", Gps = "Hideout" }, { "GPS: SPRAY & GO", Gps = "Spray & Go" } },
		},
		{
			Id = "Rank", Title = "Rank up", Short = "RANK",
			Lines = rank,
			Buttons = { { "OPEN GOALS", Page = "Goals" } },
		},
		{
			Id = "Buy", Title = "Buy cars & boats", Short = "BUY",
			Lines = {
				"Cars: AutoNeon Motors, downtown.",
				"Boats: Marina Boat Sales.",
				pick("Walk up, press [E] to [View], then [BUY].", "Walk up, tap [View], then [BUY]."),
				"Call your rides with [CAR] or [GARAGE].",
				"Faster, better sounding: [GARAGE] > [TUNE].",
			},
			Buttons = {
				{ "GPS: CARS", Gps = K.Dealers.Cars.Name, Fallback = K.Dealers.Cars.Pos },
				{ "GPS: BOATS", Gps = K.Dealers.Boats.Name, Fallback = K.Dealers.Boats.Pos },
				{ "PRICES", Page = "Dealer" },
			},
		},
		{
			Id = "Homes", Title = "Homes", Short = "HOMES",
			Lines = {
				homeFrom and ("Homes start at " .. money(homeFrom) .. ".") or "Pick one in [HOME].",
				pick("Press [E] at its door: [View / Buy].", "Tap [View / Buy] at its door."),
				"In free roam you spawn there.",
				"Your cars wait in its garage.",
			},
			Buttons = { { "OPEN HOME", Page = "Home_" } },
		},
		{
			Id = "Fight", Title = "Fists & guns", Short = "FIGHT",
			Lines = {
				pick("[Z] aim · [X] shoot (or punch) · [R] reload", "Tap [WEAPON] to switch, [FIRE] to shoot."),
				"Guns from " .. money(pistol and pistol.Price or 0) .. " at Coast Arms.",
				"Guns kill, fists knock out. Both drop cash.",
				"No fights in safe zones or [Passive] mode.",
			},
			Buttons = {
				{ "GPS: COAST ARMS", Gps = gunShop.Name or "Coast Arms", Fallback = gunShop.Center },
				{ "OPEN SETTINGS", Page = "Settings" },
			},
		},
		{
			Id = "Jobs", Title = "Jobs & fun", Short = "JOBS",
			Lines = {
				"Taxi Stand & Courier Depot: drive up.",
				"Races, " .. #Activities.Stunts .. " stunt jumps, drifting: all pay!",
				-- 12 minutes: CarMeetService, EVERY (480 s) + WARNING (60) + LENGTH (180) from one meet to the next.
				"Car Meet at Marina Row every 12 minutes.",
				"Missions are in [JOBS].",
			},
			Buttons = { { "OPEN JOBS", Page = "Jobs" }, { "OPEN FUN", Tab = "Activity" } },
		},
		{
			Id = "Police", Title = "Play as police", Short = "POLICE",
			Lines = {
				"Optional job: [JOBS] > [GO ON DUTY].",
				-- $80: ArrestService PATROL_PAY.
				"Cops earn $80 a minute on patrol.",
				-- The Cuff prompt is held with Q (ArrestService), not E.
				pick("[T] taser · [G] spikes · hold [Q] to [Cuff]", "[TASER] · [SPIKES] · hold [Cuff]"),
				"Caught robbers lose their bag.",
			},
			Buttons = { { "OPEN JOBS", Page = "Jobs" } },
		},
		{
			Id = "Saving", Title = "Saving", Short = "SAVE",
			Lines = {
				"Cash, cars, home and ranks save by themselves.",
				-- $7,000: DailyService (PER_DAY x the streak day, capped at day 7).
				"Come back daily: the bonus grows to $7,000.",
				"Bag cash never saves: bank it first!",
			},
		},
	}
end

-- Rich text for a guide line: [word] -> bold white, and &, <, > escaped first.
local function markup(text)
	local safe = string.gsub(text, "&", "&amp;")
	safe = string.gsub(safe, "<", "&lt;")
	safe = string.gsub(safe, ">", "&gt;")
	return (string.gsub(safe, "%[(.-)%]", '<font color="#F5F5F5"><b>%1</b></font>'))
end

local function guideAction(b)
	if b.Gps then
		routeTo(b.Gps, b.Fallback) -- (put away on the guide: it reopens at this spot, see PhoneUI.Close)
	elseif b.Tab then
		S.gpsTab = b.Tab
		S.fromGuide = true
		show("GPS")
	elseif b.Page then
		S.fromGuide = true
		show(b.Page)
	end
end

-- Scroll the guide list `s` so `sec` sits at its top (nil: back to the topics). Absolute positions are
-- screen pixels (after the phone's UIScale); CanvasPosition is in the phone's own units, hence / the scale.
-- A spot past the end of the list is held at the end by the ScrollingFrame itself.
local function guideJump(s, sec)
	local y = sec and s.CanvasPosition.Y + (sec.AbsolutePosition.Y - s.AbsolutePosition.Y) / ui.fit.Scale or 0
	TweenService:Create(s, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CanvasPosition = Vector2.new(0, math.max(y, 0)) }):Play()
end

-- One section: a thin line, a title row (with TOP back to the topics), bullet lines (wrapped, their height
-- set by the text) and a row of buttons. Returns its frame.
local function guideSection(parent, sec, order)
	local touch, px = touchHeight(), textPx(14)
	local f = W.frame(parent, sec.Id, order)
	f.Size = UDim2.fromScale(1, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = f
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = f
	local head = W.frame(f, "Head", 0)
	head.Size = UDim2.new(1, 0, 0, touch + 8)
	W.rule(head)
	local title = themeText(head, sec.Title, UDim2.new(1, -76, 1, 0), nil, 18, "Display")
	title.Name = "Title"
	local top = W.button(head, "Top", "TOP", "Quiet", function()
		guideJump(parent, nil)
	end)
	top.Position = UDim2.new(1, -64, 0, 4)
	top.Size = UDim2.fromOffset(64, touch)
	top.TextColor3 = C.Dim
	for i, line in ipairs(sec.Lines) do
		local holder = W.frame(f, "Line" .. i, i)
		holder.Size = UDim2.fromScale(1, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		W.block(holder, "Dot", 3, math.floor(px / 2) - 1, 4, 4, C.Dim, 2)
		local t = themeText(holder, markup(line), UDim2.new(1, -14, 0, 0), UDim2.fromOffset(14, 0), 14, "Body", C.Dim)
		t.Name = "Text"
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.TextWrapped = true
		t.TextTruncate = Enum.TextTruncate.None
		t.RichText = true
		t.TextYAlignment = Enum.TextYAlignment.Top
	end
	if sec.Buttons then
		local bar = W.frame(f, "Buttons", 50)
		bar.Size = UDim2.new(1, 0, 0, touch + 4)
		local n, gap = #sec.Buttons, 6
		for i, b in ipairs(sec.Buttons) do
			-- n equal buttons with `gap` pixels between them: GPS ones route you there, OPEN ones open an app.
			local btn = W.button(bar, b.Gps or b.Tab or b.Page, b[1], "Quiet", function()
				guideAction(b)
			end)
			btn.Position = UDim2.new((i - 1) / n, (i - 1) * gap / n, 0, 4)
			btn.Size = UDim2.new(1 / n, -gap * (n - 1) / n, 0, touch)
		end
	end
	return f
end

function PAGES.Guide()
	setHeader("HOW TO PLAY", "Home")
	local touch = touchHeight()
	local s = W.list(0)
	W.note(s, "Tap a topic to jump to it. GPS buttons set your route.", 0, nil, Enum.TextXAlignment.Center).Name = "Intro"
	local sections = guideSections()
	-- Topic chips, three to a row: each scrolls to its section.
	local rows = math.ceil(#sections / 3)
	local chips = W.frame(s, "Topics", 1)
	chips.Size = UDim2.new(1, 0, 0, rows * touch + (rows - 1) * 6 + 12)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(1 / 3, -4, 0, touch)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = chips
	for i, sec in ipairs(sections) do
		local f = guideSection(s, sec, 10 + i)
		local chip = W.button(chips, sec.Id, sec.Short, "Quiet", function()
			guideJump(s, f)
		end)
		chip.LayoutOrder = i
	end
end

------------------------------------------------------------------ showing a page

-- Gamepad (and keyboard) UI navigation. GuiService.SelectedObject may sit on a page button that the
-- next redraw destroys. selectionPath notes where it is, from the screen down: each level's name and its
-- place among same-named brothers ({ { "List", 1 }, { "Engine", 1 } }), so findPath can pick out the very
-- same button on the redrawn page (a redraw builds the same tree in the same order). nil when nothing
-- on the page is selected (touch and mouse players never have a selection).
local function selectionPath()
	local screen = ui.screen
	local sel = GuiService.SelectedObject
	if not sel or not sel:IsDescendantOf(screen) then
		return nil
	end
	local path = {}
	local node = sel
	while node ~= screen do
		local nth = 0
		for _, c in ipairs(node.Parent:GetChildren()) do
			if c.Name == node.Name then
				nth += 1
				if c == node then
					break
				end
			end
		end
		table.insert(path, 1, { node.Name, nth })
		node = node.Parent
	end
	return path
end

local function findPath(path)
	local node = ui.screen
	for _, step in ipairs(path) do
		local found
		local nth = 0
		for _, c in ipairs(node:GetChildren()) do
			if c.Name == step[1] then
				nth += 1
				if nth == step[2] then
					found = c
					break
				end
			end
		end
		if not found then
			return nil
		end
		node = found
	end
	return node
end

-- The page's first button a gamepad can land on (pages build top to bottom, so it's the top one).
local function firstButton()
	for _, d in ipairs(ui.screen:GetDescendants()) do
		if d:IsA("GuiButton") and d.Selectable and d.Visible then
			return d
		end
	end
	return nil
end

show = function(name)
	local screen = ui.screen
	-- A gamepad's selection is on a button this redraw is about to destroy: note which one (see above).
	local selPath = selectionPath()
	local samePage = name == current
	-- Re-showing the same page (after a purchase, say) keeps the scroll position, and so does coming
	-- Back to the guide from a page it opened, or opening it again soon after putting the phone away on it.
	local old = screen:FindFirstChild("List")
	if current == "Guide" and name ~= "Guide" and old then
		S.guideScroll = old.CanvasPosition
	end
	if name == "Home" or name == "Guide" then
		S.fromGuide = false
	end
	if name == "Home" then
		S.guideScroll = nil
	end
	local resume = S.guideResume and os.clock() - S.guideResume.At < K.ResumeFor and S.guideResume.Pos or nil
	local keep = (samePage and old and old.CanvasPosition) or (name == "Guide" and (S.guideScroll or resume)) or nil
	current = name
	S.minText = name == "Tune" and K.TuneMinText or K.MinText
	for _, c in ipairs(screen:GetChildren()) do
		c:Destroy()
	end
	PAGES[name]()
	-- Put the selection back: on the same button after a redraw (a TUNE buy's second press must land on
	-- the button its first press armed), on the first button of a new page (or if that button is gone).
	if selPath then
		local twin = samePage and current == name and findPath(selPath) or nil
		if not (twin and twin:IsA("GuiButton")) then
			twin = firstButton()
		end
		if twin then
			GuiService.SelectedObject = twin
		end
	end
	local new = screen:FindFirstChild("List")
	if keep and new then
		task.defer(function()
			new.CanvasPosition = keep
			-- Rows size themselves to their words, so the canvas can reach full height a frame later than
			-- this: if the position was cut short, set it again then.
			task.wait()
			if new.Parent and new.CanvasPosition.Y < keep.Y - 1 then
				new.CanvasPosition = keep
			end
		end)
	end
end

-- BACK (the header's chevron, gamepad B): to the page this one was opened from.
local function goBack()
	if S.back then
		if current == "Guide" then
			S.guideResume = nil -- done with the guide: next time it starts at the top
		end
		show(S.back)
	end
end

-- The home bar: back to the home screen, and from there the phone goes away.
local function goHome()
	if current == "Home" then
		PhoneUI.Close()
	else
		if current == "Guide" then
			S.guideResume = nil -- (as BACK)
		end
		show("Home")
	end
end

------------------------------------------------------------------ the phone itself

-- The open phone's right edge (offset from the screen's right): clear of the HUD's Buttons zone, so the
-- PHONE / CAR tiles (and the PC key cap on their left) stay visible and tappable while it's open.
local function bodyRight()
	local touch = Theme.IsTouch()
	local z = Theme.Zone("Buttons", touch)
	return z.Pos.X.Offset - z.Size.X.Offset - (touch and 8 or 36) -- PC -108, phone -132
end

-- Where the phone rests while it is up...
local function restAt()
	return UDim2.new(1, bodyRight(), 0.5, 0)
end

-- ...and where it comes from and goes back to: lower and a little to the right, like a hand's pocket.
local function awayAt()
	return UDim2.new(1, bodyRight() + K.Slip, 0.5 + K.Drop, 0)
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Phone"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")
	ui.gui = gui

	-- PHONE: a square tile in the HUD's Buttons zone (slot 1, CAR is slot 2), with the P key cap on a
	-- keyboard. HUDController draws and places it, and re-places it when the screen or input changes.
	ui.openButton = HUDController.ZoneButton(gui, "PhoneButton", "Phone", "PHONE", "P", 1)
	ui.openButton.Activated:Connect(function()
		PhoneUI.Toggle()
	end)

	-- The body: laid out at a fixed design width (K.W) and scaled to the screen with a UIScale, so text
	-- and buttons keep their proportions from a small phone to a big monitor.
	phone = Instance.new("Frame")
	phone.Name = "Body"
	phone.AnchorPoint = Vector2.new(1, 0.5)
	phone.Position = restAt()
	phone.Size = UDim2.fromOffset(K.W, 690)
	phone.BackgroundColor3 = K.Case
	phone.BorderSizePixel = 0
	phone.Active = true -- taps on the phone never fall through to the game
	phone.Visible = false
	phone.Parent = gui
	-- A tap or click that begins on the phone (on its words too) never puts it away (PhoneUI.Init).
	phone.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
			S.phoneTouchAt = os.clock()
		end
	end)
	Theme.Corners(phone, K.Round)
	W.ring(phone, K.Edge, 1.5) -- the thin metal edge
	ui.fit = Instance.new("UIScale")
	ui.fit.Name = "Fit"
	ui.fit.Parent = phone

	-- The glass (its height is set by fitToScreen), and the home screen's wallpaper on it: a dark dusk
	-- sky, the brand's pink and cyan far down in the dark.
	local inner = K.Round - K.Bezel
	ui.glass = W.block(phone, "Glass", K.Bezel, K.Bezel, K.W - 2 * K.Bezel, 100, K.Glass, inner)
	ui.wall = W.block(ui.glass, "Wall", 0, 0, 1, 1, C.Text, inner)
	ui.wall.Size = UDim2.fromScale(1, 1)
	local sky = Instance.new("UIGradient")
	sky.Rotation = 70
	sky.Color = ColorSequence.new(K.WallTop, K.WallFoot)
	sky.Parent = ui.wall

	-- Status bar: the clock on the left, cash in the island, signal and battery on the right.
	local side = K.Inset - K.Bezel
	local status = W.frame(phone, "Status")
	status.Position = UDim2.fromOffset(K.Bezel, K.Bezel)
	status.Size = UDim2.fromOffset(K.W - 2 * K.Bezel, K.Status)
	status.ZIndex = 2
	ui.clock = themeText(status, "12:00", UDim2.new(0, 110, 1, 0), UDim2.fromOffset(side, 0), 13, "Bold")
	ui.clock.Name = "Clock"
	ui.island = W.block(status, "Island", 0, 0, 84, 20, C.Shadow, 10)
	ui.island.AnchorPoint = Vector2.new(0.5, 0.5)
	ui.island.Position = UDim2.fromScale(0.5, 0.5)
	Theme.Corners(ui.island, 10).CornerRadius = UDim.new(0.5, 0) -- a pill at any height
	ui.cash = themeText(ui.island, "$0", UDim2.fromScale(1, 1), nil, 14, "Display", C.Cash, Enum.TextXAlignment.Center)
	ui.cash.Name = "Cash"
	-- Four signal bars and a battery, drawn from blocks. Their UIScale keeps them as tall as the clock's
	-- digits on small screens (layoutShell).
	local icons = W.frame(status, "Icons")
	icons.AnchorPoint = Vector2.new(1, 0.5)
	icons.Position = UDim2.new(1, -side, 0.5, 0)
	icons.Size = UDim2.fromOffset(46, 12)
	ui.icons = Instance.new("UIScale")
	ui.icons.Parent = icons
	for i = 1, 4 do
		local tall = 3 + i * 2
		W.block(icons, "Signal" .. i, (i - 1) * 5, 12 - tall, 3, tall, C.Text, 1)
	end
	local cell = W.block(icons, "Battery", 24, 1, 19, 10, C.Text, 3)
	cell.BackgroundTransparency = 1
	W.ring(cell, C.Text, 1).Transparency = 0.4
	W.block(cell, "Charge", 2, 2, 12, 6, C.Text, 1)
	W.block(icons, "Cap", 44, 4, 2, 4, C.Text, 1).BackgroundTransparency = 0.4

	-- The header of an app page: the back chevron (two small turned blocks; the button around it is a
	-- thumb wide and tall), the title and a thin line under them. layoutShell places and sizes them.
	ui.back = Instance.new("TextButton")
	ui.back.Name = "Back"
	ui.back.Text = ""
	ui.back.BackgroundTransparency = 1
	ui.back.AutoButtonColor = false
	ui.back.ZIndex = 2
	ui.back.Parent = phone
	local chevron = W.frame(ui.back, "Chevron")
	chevron.AnchorPoint = Vector2.new(0, 0.5)
	chevron.Position = UDim2.new(0, side - 3, 0.5, 0)
	chevron.Size = UDim2.fromOffset(12, 18)
	W.block(chevron, "Up", 0, 4, 12, 2.5, C.Text, 1).Rotation = -45
	W.block(chevron, "Down", 0, 11.5, 12, 2.5, C.Text, 1).Rotation = 45
	ui.chevron = Instance.new("UIScale")
	ui.chevron.Parent = chevron
	ui.back.Activated:Connect(function()
		sfx("Click")
		goBack()
	end)
	-- The title shrinks to fit its line (TextScaled, capped at the size layoutShell gives it), so a long
	-- car name on the TUNE page is never cut off.
	ui.title = themeText(phone, "", UDim2.fromOffset(200, 30), nil, 20, "Display")
	ui.title.Name = "Title"
	ui.title.ZIndex = 2
	ui.title.TextScaled = true
	ui.titleCap = Instance.new("UITextSizeConstraint")
	ui.titleCap.MinTextSize = 10
	ui.titleCap.MaxTextSize = 20
	ui.titleCap.Parent = ui.title
	ui.headRule = W.block(phone, "HeadRule", 0, 0, 1, 1, C.Text, 0, 2)
	ui.headRule.BackgroundTransparency = 0.88

	-- The page. Every page is drawn into it (show), and what scrolls past its edges is clipped.
	ui.screen = W.frame(phone, "Screen")
	ui.screen.ClipsDescendants = true
	ui.screen.ZIndex = 2

	-- The home bar: a thumb-sized button with a thin pill in its middle.
	ui.homeBar = Instance.new("TextButton")
	ui.homeBar.Name = "HomeBar"
	ui.homeBar.Text = ""
	ui.homeBar.BackgroundTransparency = 1
	ui.homeBar.AutoButtonColor = false
	ui.homeBar.ZIndex = 2
	ui.homeBar.Parent = phone
	local pill = W.block(ui.homeBar, "Pill", 0, 0, 116, 4, C.Text, 2)
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.BackgroundTransparency = 0.45
	ui.homeBar.Activated:Connect(function()
		sfx("Click")
		goHome()
	end)

	-- The dark screen of a phone that is on its way up or down (raise / lower), over everything on the glass.
	ui.cover = W.block(phone, "Cover", K.Bezel, K.Bezel, K.W - 2 * K.Bezel, 100, C.Shadow, inner, 5)
	ui.cover.Visible = false
end

-- Fit the phone to the screen: scale 0.7-1.1 by the screen's height (smaller still if the screen is too
-- narrow for it), then as tall as the screen allows.
local function fitToScreen()
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(844, 390)
	local scale = math.clamp(vp.Y / 720, 0.7, 1.1)
	scale = math.max(0.5, math.min(scale, (vp.X + bodyRight() - 8) / K.W))
	local height = math.clamp(math.floor(vp.Y * 0.92 / scale), 240, 720)
	ui.fit.Scale = scale
	phone.Size = UDim2.fromOffset(K.W, height)
	ui.glass.Size = UDim2.fromOffset(K.W - 2 * K.Bezel, height - 2 * K.Bezel)
	ui.cover.Size = ui.glass.Size
	layoutShell()
	if not S.sliding then
		phone.Position = restAt()
	end
end

local function refreshStatus()
	local t = Lighting.ClockTime
	local h = math.floor(t)
	local m = math.floor((t - h) * 60)
	local h12 = h % 12
	local text = string.format("%d:%02d %s", h12 == 0 and 12 or h12, m, h >= 12 and "PM" or "AM")
	ui.clock.Text = text
	ui.cash.Text = money(player:GetAttribute("Cash") or 0)
	local big = ui.screen:FindFirstChild("Clock") -- the home screen's big clock, when it has one
	if big and big:IsA("TextLabel") then
		big.Text = text
	end
end

-- While the phone is up the character holds one and looks down at it (PoseClient shows it to everyone).
-- Not in a seat: a driver's hands stay on the wheel. Nothing happens if that controller isn't there.
local function holdPhone(on)
	if on then
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		on = not (hum and hum.SeatPart)
	end
	if S.posed == on then
		return
	end
	S.posed = on
	task.spawn(function()
		pcall(function()
			local module = script.Parent:FindFirstChild("PoseClient")
			local poses = module and require(module)
			if type(poses) == "table" and type(poses.Broadcast) == "function" then
				poses.Broadcast("PhoneLook", on)
			end
		end)
	end)
end

local function stopSlide()
	for _, tween in ipairs(S.tweens) do
		tween:Cancel()
	end
	table.clear(S.tweens)
end

-- Bring the phone up: from the lower right, tilted, settling upright in K.Raise seconds. A turned frame
-- clips nothing (a long list would hang out of the phone), so the page stays hidden and the glass dark
-- until it is upright; then the screen lights up. A phone still on its way down turns round where it is.
local function raise()
	S.anim += 1
	local id = S.anim
	stopSlide()
	ui.screen.Visible = false
	ui.cover.BackgroundTransparency = 0
	ui.cover.Visible = true
	if not S.sliding then
		phone.Position = awayAt()
		phone.Rotation = K.Tilt
	end
	S.sliding = true
	phone.Visible = true
	local slide = TweenService:Create(phone, TweenInfo.new(K.Raise, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{ Position = restAt() })
	local turn = TweenService:Create(phone, TweenInfo.new(K.Raise, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = 0 })
	table.insert(S.tweens, slide)
	table.insert(S.tweens, turn)
	slide:Play()
	turn:Play()
	task.delay(K.Raise, function()
		if S.anim ~= id then
			return -- put away (or raised again) meanwhile
		end
		stopSlide()
		S.sliding = false
		phone.Position = restAt()
		phone.Rotation = 0
		ui.screen.Visible = true
		local wake = TweenService:Create(ui.cover, TweenInfo.new(K.Wake), { BackgroundTransparency = 1 })
		table.insert(S.tweens, wake)
		wake:Play()
		task.delay(K.Wake, function()
			if S.anim == id then
				ui.cover.Visible = false
			end
		end)
	end)
end

-- Put it away: the screen goes dark, then the reverse of raise in K.Lower seconds.
local function lower()
	S.anim += 1
	local id = S.anim
	stopSlide()
	ui.screen.Visible = false
	ui.cover.BackgroundTransparency = 0
	ui.cover.Visible = true
	S.sliding = true
	local slide = TweenService:Create(phone, TweenInfo.new(K.Lower, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = awayAt(), Rotation = K.Tilt })
	table.insert(S.tweens, slide)
	slide:Play()
	task.delay(K.Lower, function()
		if S.anim ~= id then
			return -- raised again meanwhile
		end
		stopSlide()
		S.sliding = false
		phone.Visible = false
	end)
end

function PhoneUI.IsOpen()
	return S.open
end

-- pageName: a PAGES key (none or unknown = the home screen). arg: for "Tune" / "Custom", the vehicle id
-- whose page to open (the dealer's TUNE IT). On a phone that is already up it just changes the page.
function PhoneUI.Open(pageName, arg)
	if not phone then
		return -- not built yet (PhoneUI.Init)
	end
	-- Not on the first-join title screen (local attribute TitleScreen, TeamUI): the phone's layer is
	-- switched off there, so P raised it unseen. It was then up over the fresh HUD the moment a side was
	-- picked, and GET IN did nothing until it was put away.
	if player:GetAttribute("TitleScreen") == true then
		return
	end
	if player:GetAttribute("Side") == "Prisoner" then
		NotifyController.Show("Phones are confiscated in prison. Try the vent...", nil, "prison")
		return
	end
	-- A gamepad selection somewhere else (the dealer card's TUNE IT, say) moves onto the phone below.
	local selected = GuiService.SelectedObject
	local wasOpen = S.open
	S.open = true
	fitToScreen()
	pcall(function()
		require(script.Parent.DealerClient).Close() -- the dealer card and the phone share the right side
	end)
	refreshStatus()
	S.fromGuide, S.guideScroll = false, nil -- a fresh open never goes Back into the guide
	if (pageName == "Tune" or pageName == "Custom") and type(arg) == "string" and Vehicles.ById[arg] then
		detailId = arg
	end
	show(PAGES[pageName] and pageName or "Home")
	if selected and not selected:IsDescendantOf(phone) then
		local first = firstButton()
		if first then
			GuiService.SelectedObject = first
		end
	end
	if not wasOpen then
		raise()
		holdPhone(true)
	end
end

function PhoneUI.Close()
	if not S.open then
		return
	end
	-- Put away on the guide (a GPS button, P, the PHONE button): remember where, so HOW TO PLAY reopens there.
	if current == "Guide" then
		local l = ui.screen:FindFirstChild("List")
		if l then
			S.guideResume = { Pos = l.CanvasPosition, At = os.clock() }
		end
	end
	-- A gamepad selection must not stay on a hidden phone button (a press would still reach it).
	local selected = GuiService.SelectedObject
	if selected and selected:IsDescendantOf(phone) then
		GuiService.SelectedObject = nil
	end
	S.open = false
	table.clear(S.taps)
	S.styleArm = nil
	lower()
	holdPhone(false)
end

function PhoneUI.Toggle()
	if S.open then
		PhoneUI.Close()
	else
		PhoneUI.Open()
	end
end

-- Redraw a page if it's the one on screen (BusinessClient: the EMPIRE app after its numbers change). The
-- scroll position and a gamepad's selection stay where they were (show).
function PhoneUI.Refresh(pageName)
	if S.open and current == pageName and PAGES[pageName] then
		show(current)
	end
end

function PhoneUI.Init()
	build()
	fitToScreen()
	-- Redraw a page if it's the one open. Deferred so a burst of changes (a whole crew leaving, the co-op
	-- bonus setting three attributes at once) redraws once.
	local pending = {}
	local function refreshIf(name)
		if pending[name] then
			return
		end
		pending[name] = true
		task.defer(function()
			pending[name] = nil
			if S.open and current == name then
				show(name)
			end
		end)
	end
	-- Pages measure their rows from the phone's scale, so a new screen size draws the open one again.
	local cam = Workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			fitToScreen()
			refreshIf(current)
		end)
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.ButtonB then
			-- Gamepad B goes Back while the phone's buttons are being used (on foot: in a car B gets out).
			local selected = GuiService.SelectedObject
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if S.open and selected and selected:IsDescendantOf(phone) and not (hum and hum.SeatPart) then
				if S.back then
					goBack()
				else
					PhoneUI.Close()
				end
			end
			return
		end
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.P then
			PhoneUI.Toggle()
		elseif input.KeyCode == Enum.KeyCode.DPadDown then
			-- A gamepad had no button for the phone at all, so its garage, GPS and jobs (and the guide's
			-- "open your PHONE" step) were out of reach. D-pad down was free: up flips the car, left / right
			-- is the radio, and a press that moved a menu's selection comes in as processed (above).
			if S.open then
				-- With a phone button selected the D-pad walks the page (B puts the phone away then).
				local selected = GuiService.SelectedObject
				if not (selected and selected:IsDescendantOf(phone)) then
					PhoneUI.Close()
				end
				return
			end
			-- The dressing room steps through its list with this button and keeps the phone shut (WardrobeUI).
			local ok, dressing = pcall(function()
				return require(script.Parent.WardrobeUI).IsOpen()
			end)
			if ok and dressing == true then
				return
			end
			PhoneUI.Open()
			-- On foot the selection goes to the page's first button once the phone is upright, so the D-pad
			-- and A work it and B goes Back. Not in a car, where B gets out: a second press puts it away there.
			task.delay(K.Raise + 0.05, function()
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if S.open and GuiService.SelectedObject == nil and not (hum and hum.SeatPart) then
					GuiService.SelectedObject = firstButton()
				end
			end)
		end
	end)
	-- Tap or click anywhere around the open phone to put it away (see the header): only a quick tap that
	-- no GUI took and that lands outside the body. Both ways of reading a screen point are tried (an input
	-- position may or may not count Roblox's top bar; the body's lives in a gui that ignores it), so a tap
	-- near the phone's top or bottom edge is never taken for one outside it.
	local function onPhone(pos)
		local a, size = phone.AbsolutePosition, phone.AbsoluteSize
		for _, p in ipairs({ pos, pos + GuiService:GetGuiInset() }) do
			if p.X >= a.X and p.X <= a.X + size.X and p.Y >= a.Y and p.Y <= a.Y + size.Y then
				return true
			end
		end
		return false
	end
	-- Where a tap is kept: each finger by its own input, the mouse's left button by one key; nil for
	-- every other input (keys, the right button, the mouse moving).
	local function tapKey(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.Touch then
			return input
		end
		return t == Enum.UserInputType.MouseButton1 and "Mouse" or nil
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		local key = tapKey(input)
		if not key then
			return
		end
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if processed or not S.open or S.sliding or onPhone(pos) then
			return -- a HUD button, the phone itself, or a phone still moving
		end
		S.taps[key] = { pos = pos, at = os.clock() }
	end)
	UserInputService.InputEnded:Connect(function(input)
		local key = tapKey(input)
		local tap = key and S.taps[key]
		if not tap then
			return
		end
		S.taps[key] = nil
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if S.open and not S.sliding and os.clock() - tap.at <= K.TapTime and (pos - tap.pos).Magnitude <= K.TapSlop
			and os.clock() - S.phoneTouchAt > 0.3 and not onPhone(pos) then
			PhoneUI.Close()
		end
	end)
	-- Keep open pages fresh when the server changes what we own or how our cars look.
	local function maybeRefresh()
		if S.open and (current == "Garage" or current == "Custom" or current == "Tune" or current == "Dealer" or current == "Shop"
			or current == "Goals" or current == "Crew" or current == "Jobs" or current == "Home_") then
			show(current)
		end
	end
	player.AttributeChanged:Connect(function(name)
		if name == "OwnedCars" or string.sub(name, 1, 7) == "Custom_" or string.sub(name, 1, 5) == "Pass_"
			or string.sub(name, 1, 7) == "Unlock_" or name == "Challenges" or name == "CivXP" or name == "CopXP"
			or name == "CopRank" or name == "Crew" or name == "FriendBonus" or name == "MissionsDone" or name == "JourneyHidden"
			or name == "BigHeists" or name == "Home" then
			maybeRefresh()
		elseif string.sub(name, 1, 6) == "Style_" then
			refreshIf("Custom") -- the paints and rims this car owns (GarageService)
		elseif name == "ShopFree" then
			refreshIf("Shop") -- FREE buttons (ShopService)
		elseif string.sub(name, 1, 5) == "Tune_" then
			refreshIf("Tune")
			refreshIf("Garage") -- its TUNE strips count the upgrades
		elseif name == "Passive" then
			refreshIf("Settings")
		elseif name == "CoplayMins" or name == "CoplayDone" or name == "CoplayDays" then
			refreshIf("Crew") -- the play-together progress (FriendsService)
		elseif name == "BigScore" or name == "BigScoreReadyAt" or name == "CivRank" then
			refreshIf("Crew") -- THE BIG SCORE's line and its START / QUIT
		elseif name == "CrewPreps" or name == "CrewRoster" or name == "CrewPrepRun" or name == "CrewPaused" then
			refreshIf("Crew") -- the crew job's preps and the saved crew (CrewService)
		elseif name == "Cash" and S.open then
			refreshStatus()
			refreshIf("Tune") -- prices turn green the moment they're affordable, and AUTO TUNE's plan grows
		elseif name == "Side" then
			local side = player:GetAttribute("Side")
			ui.openButton.Visible = side ~= "Prisoner"
			if side == "Prisoner" then
				PhoneUI.Close()
			elseif os.clock() - S.dutyAskedAt < K.DutyWait then
				-- JOBS asked for this switch: the server is respawning us at the side's spawn.
				S.dutyAskedAt = -math.huge
				PhoneUI.Close()
				NotifyController.Show(side == "Cop" and "On duty! Your patrol car is waiting at the station."
					or "Off duty. Port Solana is yours to roam.", side == "Cop" and C.Police or nil, side == "Cop" and "police" or "info")
			else
				maybeRefresh()
			end
		end
	end)
	-- CREW lists other players (their Crew and Side) and GPS marks open heists, so redraw those pages when
	-- that changes too.
	local function watchPlayer(p)
		if p == player then
			return -- our own Crew and Side are handled above
		end
		p:GetAttributeChangedSignal("Crew"):Connect(function()
			refreshIf("Crew")
		end)
		p:GetAttributeChangedSignal("Side"):Connect(function()
			refreshIf("Crew")
		end)
	end
	Players.PlayerAdded:Connect(function(p)
		watchPlayer(p)
		refreshIf("Crew")
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		watchPlayer(p)
	end
	-- ChildRemoved fires once the player is gone, so GetPlayers() no longer lists them.
	Players.ChildRemoved:Connect(function()
		refreshIf("Crew")
	end)
	ReplicatedStorage:GetAttributeChangedSignal("OpenHeists"):Connect(function()
		refreshIf("GPS")
	end)
	-- THE BIG SCORE's line: another crew starting or ending it, and the crews it counts.
	for _, name in ipairs({ "BigScoreBusy", "Crews" }) do
		ReplicatedStorage:GetAttributeChangedSignal(name):Connect(function()
			refreshIf("Crew")
		end)
	end
	-- A refused JOIN (friend gone, full server...) puts the JOIN buttons back at once, and so does a
	-- refused tune purchase (GarageService's toasts) for the button that read FITTING...
	Remotes.OnClient("Notify", function(key)
		if (key == "FriendJoinFailed" or key == "FriendServerFull" or key == "FriendJoinWanted" or key == "FriendJoinBag"
			or key == "FriendJoinPrison" or key == "FriendJoinStudio" or key == "FriendInServer") and next(crew.joiningUntil) then
			table.clear(crew.joiningUntil)
			refreshIf("Crew")
		elseif (key == "NotEnoughCash" or key == "TuneWanted") and tuneSent then
			tuneSent, tuneBusyUntil = nil, 0
			refreshIf("Tune")
		end
	end)
	-- A tune purchase landed: take taps again, light up the buttons it changed and redraw the TUNE page
	-- (the bars glide to their new lengths there).
	local function tuneLanded(id, buttons)
		tuneSent, tuneBusyUntil = nil, 0
		local keys = {}
		for _, b in ipairs(buttons) do
			keys[tostring(id) .. "/" .. tostring(b)] = true
		end
		tuneFlash = { At = os.clock(), Keys = keys }
		refreshIf("Tune")
	end
	-- Like a tuning shop: once new parts are fitted the engine revs, in this car's own exhaust note (the
	-- tune doesn't change the exhaust, so the attribute already holds the right one), instead of an
	-- arcade cash sound.
	local function revFitted(id)
		previewExhaust(Garage.ParseTune(player:GetAttribute("Tune_" .. tostring(id))).Exhaust)
	end
	Remotes.OnClient("GarageResult", function(result)
		if type(result) ~= "table" then
			return
		end
		local def = Vehicles.ById[result.Id]
		local name = def and (def.DisplayName or def.Id) or "car"
		if result.Kind == "Bought" then
			HUDController.Stamp("NEW RIDE!", name .. " is in your Garage", C.Brand)
		elseif result.Kind == "Painted" then
			local what = tostring(result.Name or "New")
			NotifyController.Show(result.Bought and (what .. " paint is yours on the " .. name .. "! Switch back free any time.")
				or (what .. " paint on your " .. name .. "."), nil, result.Bought and "success" or "info")
		elseif result.Kind == "Rims" then
			local what = tostring(result.Name or "New")
			NotifyController.Show(result.Bought and (what .. " rims are yours on the " .. name .. "! Switch back free any time.")
				or (what .. " rims on your " .. name .. "."), nil, result.Bought and "success" or "info")
		elseif result.Kind == "Glow" then
			NotifyController.Show(result.Bought and ("Underglow installed on your " .. name .. "! Color swaps are free now.")
				or (tostring(result.Name or "New") .. " underglow on your " .. name .. "."), nil, result.Bought and "success" or "info")
		elseif result.Kind == "Tuned" then
			tuneLanded(result.Id, { result.Track })
			NotifyController.Show(tostring(result.Track) .. " stage " .. tostring(result.Stage) .. " fitted to your " .. name .. "!",
				nil, "success")
			revFitted(result.Id)
		elseif result.Kind == "AutoTuned" then
			local buttons = { "Auto" }
			for key in pairs(type(result.Tracks) == "table" and result.Tracks or {}) do
				table.insert(buttons, key)
			end
			tuneLanded(result.Id, buttons)
			NotifyController.Show("AUTO TUNE on your " .. name .. ": " .. tostring(result.Text) .. " ("
				.. money(tonumber(result.Total) or 0) .. ")", nil, "success")
			revFitted(result.Id)
		elseif result.Kind == "Exhaust" then
			if exhaustPick == tostring(result.Id) .. "/X:" .. tostring(result.Key) then
				exhaustPick = nil -- it's fitted: BUY has nothing to offer (even if Tune_ arrives a moment later)
			end
			tuneLanded(result.Id, { "X:" .. tostring(result.Key) })
			local exhaust = Garage.ExhaustByKey[result.Key]
			local which = exhaust and exhaust.Name or "NEW"
			if result.Bought then
				NotifyController.Show(which .. " exhaust fitted to your " .. name .. "!", nil, "success")
				sfx("Cash") -- the purchase itself...
				previewExhaust(result.Key) -- ...and the new sound (BUY's own tap is silent; a swap's tap played it)
			else
				NotifyController.Show(which .. " exhaust back on your " .. name .. ".", nil, "info")
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			-- On touch screens the PHONE button sits where the steering thumb goes: hide it while driving.
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local driving = hum ~= nil and hum.SeatPart ~= nil
			ui.openButton.Visible = player:GetAttribute("Side") ~= "Prisoner"
				and not (driving and UserInputService.TouchEnabled and not UserInputService.MouseEnabled)
			if S.open then
				refreshStatus() -- the clock keeps the game's time
				holdPhone(true) -- (sat down or stood up with the phone out)
				if current == "Crew" then
					askFriends() -- at most once per K.FriendsFresh; the page redraws only if the list changed
					-- THE BIG SCORE's line: a countdown is rewritten in place; a change of meaning (ready now,
					-- lost the cops, cooldown over) redraws the page so START follows it.
					local line = crew.bigScoreLine
					if line and line.Parent then
						local text, color, _, _, key = crew.bigScoreStatus()
						if key ~= crew.bigScoreKey then
							refreshIf("Crew")
						elseif line.Text ~= text then
							line.Text = text
							line.TextColor3 = color
						end
					end
				end
			end
		end
	end)
end

return PhoneUI
