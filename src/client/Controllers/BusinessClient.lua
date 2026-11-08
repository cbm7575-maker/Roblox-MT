-- BusinessClient (ModuleScript, StarterPlayerScripts.Controllers.BusinessClient)
-- The client side of Empire, player businesses (Config.Businesses; BusinessService on the server decides
-- everything and checks every request again). Does nothing at all while ReplicatedStorage attribute
-- BusinessesOn isn't true (the launch switch: see Config.Businesses.Live).
--
-- THE CARDS (ScreenGui "Business", DisplayOrder 9, the flat "street" look of HouseClient's buy card; frame
-- "Card"). Opened by the server's BusinessCard (the door prompt). On a PC: top-left under Roblox's top bar,
-- Roblox's chat window hidden while it's open; on a phone: centred, Theme.Touch-tall buttons, CLOSE / CANCEL
-- on the left (the thumb side). Walking off the lot (the server's Reach) or sitting down closes it. Keys: X / gamepad B
-- close it, Enter / gamepad Y press its first button (never while seated or from behind Roblox's menu).
--   * BUY card (not yours): the name and price, the job in one line with its pay, the register (trickle a
--     minute and its size), the blurb, the level-5 picture in words; BUY (NEED $X MORE / EMPIRE n NEEDED) and
--     CANCEL.
--   * MANAGE card (yours): the name and LEVEL n, five level pips, the trickle (+25% while a crewmate is here),
--     the register filling live with its bar, what the next level adds and costs; COLLECT $X | START JOB,
--     UPGRADE $X | CLOSE. START JOB turns the buttons into the business's jobs (Config Jobs: WASH A CAR |
--     DELIVER A CAR at the Car Wash), BACK | CLOSE; with only one job (Palm Grind's RUSH ORDERS) it starts it.
--   * CREW card (a crewmate owns it): "<Owner>'s Suds & Shine", their level, what working here pays both of
--     you; its jobs (WASH A CAR | DELIVER A CAR, or RUSH ORDERS), BUY YOUR OWN | CLOSE.
--   The card counts as a panel: BusinessClient.IsOpen() (CombatClient lowers the gun, InteractClient offers
--   no E / F behind it). The wash mini-game counts too while a car is in the bay.
--
-- THE WASH BAY (BusinessJob "Wash"): the customer car exists only on this device (a ReplicatedStorage
-- TrafficModels body in a random paint, or a greybox car, in Workspace "BizLocal"): it rolls into the bay
-- the server picked, with its tag over it ("Carla's sedan"; a special customer's name and what it pays: a muddy
-- truck is a pickup, a wedding car white with a JUST MARRIED board, a classic car mint, cream or cherry) and
-- 4-7 dirty spots, each the server's dirt (mud, bugs or bird mess: its own look, colour and taps).
-- SPRAY and RINSE are timing gauges (the Print Shop's: Job.band / Job.drawGauge): hold the HOLD button (Theme's
-- Action zone; F on a keyboard, RT on a gamepad), the fill goes grey, green in the band, orange past it; water
-- from the bay's nozzle and the hose's hiss (Sounds WashHiss) while held. The server grades it: PERFECT! / OK /
-- TOO EARLY pops over the button (Job.pop; a ding for PERFECT). SCRUB: tap each spot's round button ("BIRD ×4"):
-- a squeak and a puff of suds, the spot shrinks and fades, the last tap a sparkle pop (Sounds WashSqueak,
-- WashPop); Wash.spread keeps the buttons apart on screen (the Nov 4 Studio test: two could overlap on a phone).
-- Every step goes to the server (RequestBusiness "Step"); its "WashStep" answer puts the game back where the
-- server is when a step didn't count. Paid ("WashPaid"): the shine sweep and sparkle, the ★ / ★★ / ★★★ rating
-- slamming down over the car (the server's), the pay counting up, and the AFTER panel (the pay, the stars, the
-- tip's story: "tip $192 · streak ×1.1"): NEXT CAR | DELIVER | END. The washed car honks twice as it pulls out.
-- DETAIL DELIVERY ("Detail"): the GPS routes to the customer's address, a gold ring and beam mark it, the
-- strip counts down the tip, the line under it counts the dents ("DENTS 0": red and shaking at a dent; "SPORTS
-- CAR" for the sports car the server sometimes hands you). "DetailPaid": the customer walks out to the car and
-- waves (a few local parts), the car fades, the DELIVERED · NO DENTS (or -2 DENTS) stamp with the stars and the
-- streak; the shift goes on: the GPS back, and at the business (on foot) the AFTER panel again.
-- RUSH ORDERS (Palm Grind, M2; BusinessJob "Rush" / "RushStep" / "RushLeg" / "RushPaid"): at the counter, the
-- HOLD button shows within K.GRAB_RANGE of the RUSH ORDERS shelf (on foot): hold it (F / RT / mouse / finger)
-- for Config.Rush.GrabHold to grab an order (RequestBusiness "Step" GrabOn / GrabOff; the server times it and
-- answers "RushStep" Again when it didn't count). Each address ("RushLeg"): the ring and beam, the GPS, and the
-- strip's coffee cup (draining hot to cold as the clock runs) and "PROFESSOR LANE · ICED LATTE" (a VIP: "VIP ·
-- STELLA STARR" and a gold edge round the strip), the clock counting down on the right (the tip it would pay now
-- on a PC: Businesses.RushTip, the server's own maths; LATE once it runs out); the line under it: a multi-stop
-- order's pips ("1/3 DELIVERED"), the gold streak, RUSH HOUR and its clock. "RushPaid": the medal stamp (GOLD /
-- SILVER / BRONZE, the server's) and a cup popping up at the door; after the order's last stop PERFECT RUN (all
-- GOLD: the bonus), VIP DELIVERED (confetti) or the medal with ORDER DELIVERED; then the GPS back to the café.
-- RUSH HOUR (BusinessResult "RushHour" / "RushHourOver"; the owner's attribute BizRushHour): a stamp on the job,
-- a toast otherwise.
-- THE PRINT SHOP (M3; BusinessJob "Print" / "PrintStep" / "Printed" / "Loaded" / "Spotted" / "Laundered" /
-- "BagsLost" / "BagsBack"; the server decides everything: Services.BusinessJobs.PrintShop). One shift, two jobs:
--   * PRINT, a timing game: at each of the three stations (in order) the HOLD button shows within K.STATION_SHOW
--     (on foot). It's a gauge: it fills over the station's Full seconds with a green band (Config.Print.Stations
--     Sweet) drawn in it; the fill turns green inside the band, orange past it, and lets go by itself when full.
--     The server times and grades it ("PrintStep" Grade): a pop over the button says PERFECT! (with the streak
--     multiplier from 2 in a row; a ding) / OK / TOO EARLY. The strip shows the streak (×1.15) or the stock.
--     A press run ("Printed"): the press's ka-chunk (Sounds "Stamp"), sheets fluttering out of the tray (one
--     ParticleEmitter, a burst), a "+$1,600 DIRTY" pop rising over it, and the stack of fake bills on the counting
--     table growing (Print.cash: at most K.CASH_MAX parts, under the camera, only within K.CASH_RANGE).
--   * LAUNDER: the strip walks you through it (PARK YOUR CAR IN THE BAY, WALK TO THE CASH CART, HOLD TO LOAD THE
--     BAGS); "Loaded": the drop's ring, beam and GPS, "DROP AT THE ARCADE" with the distance, and the HEAT meter
--     under the strip (player attribute BizHeat, the server's: gold, orange from 40%, red from 75%; SPOTTED when
--     wanted). "Laundered": the clean cash counts up on screen (a cash register), the LAUNDERED stamp with the pay,
--     "clean run · bonus $X" when you were never spotted.
--   * The end ("Ended" with a Summary): the SHIFT REPORT card below (press runs, PERFECTs, the best streak, runs,
--     clean runs, $ printed and earned).
--   * RAIDS (ReplicatedStorage BizRaids; BusinessResult Raid / RaidBreached / RaidSeized / RaidHeld / RaidOver): the
--     warning or the dispatch toast and the GPS, the strip's red RAID countdown (owner and crew: RAID! GET TO YOUR
--     PRINT SHOP / HOLD THE DOOR! / COPS BREAKING IN 40%; a cop: BREACH THE PRINT SHOP DOOR / SEARCH THE PRESSES),
--     a siren loop at the shop within K.SIREN_RANGE, the AI car's light bar flashing, the map icon flashing red
--     (BizAlarm), and the endings: SEIZED $X (a cop's stamp, with the reward), RAIDED (the owner), RAID FAILED (the
--     owner and the crew who held the door, with the bonus and XP). The raid prompts (BizBreachPrompt,
--     BizSearchPrompt) are switched on only on an eligible cop's device; during a warrant the door's own prompt
--     steps aside there so E is BREACH. The manage card and the EMPIRE app show the dirty cash and the raid.
-- BOAT TOURS (Coastline Boat Rentals, M4; BusinessJob "Tour" / "TourSeat" / "TourGo" / "TourStop" / "TourPhotoOn" /
-- "TourPhoto" / "TourMood" / "TourPaid"; the server decides everything: Services.BusinessJobs.BoatRentals).
--   * At the dock ("Tour" Stage "board"): WALK TO THE BOAT with the distance until you're at the helm (the boat's
--     "Drive" bubble shows only to you), then ALL ABOARD... while the tourists hop on. A special tour says so in a
--     toast (CELEBRITY TOUR with the star's name, FISHING PARTY, SUNSET TOUR) and on the line under the strip.
--   * "TourGo": the ship's horn (Sounds TourHorn), ALL ABOARD! over the HOLD spot, and the route: BUOY RINGS on the
--     water (local parts under the camera: a see-through ring wall, K.BUOYS bobbing buoys, a name tag; gold for a
--     landmark, pink for a PHOTO STOP, green for a FISHING STOP, aqua for the dock; the next one bright with a light
--     pillar, the one after it dim) and a white GPS line on the water (GPSClient.SetPath, K.TOUR_PATH, with Height:
--     the next three stops and the dock; redrawn from the boat when it's K.OFF_LINE off it).
--   * The strip: NEXT: THE SEA DREAM and the distance; PHOTO STOP: SLOW DOWN! near a photo ring; inside it HOLD IT
--     STEADY... / SLOWER FOR A PERFECT SHOT / TOO FAST! with the PHOTO gauge under the line (the Print Shop's heat
--     bar: green under the PERFECT speed, orange under the photo speed, red too fast; this device's own reading of
--     the server's Businesses.PhotoStep); BACK TO THE DOCK, STOP IN THE DOCK RING; GET BACK IN THE BOAT! when out.
--     The line under it: HAPPY 92% (the tourists' mood, player attribute BizTourHappy: green, orange, red), STOP
--     2/5, PAR 0:21 (or +0:05), the special, the streak.
--   * Every ring passed bursts; the TOUR GUIDE's line for that landmark pops up in a bubble under the strip for
--     K.GUIDE_TIME. A photo graded ("TourPhoto"): PERFECT SHOT! / NICE SHOT! / MISSED THE PHOTO! (fishing: CAUGHT A
--     BIG ONE! / A NIBBLE! / THEY GOT AWAY!), the screen's camera flashes with the shutter (Sounds TourShutter; the
--     tourists' heads flash for everyone on the server). "TourMood": the line under the strip shakes (a crash for a
--     ram, a splash and a toast for running aground; the tourist's shout is the server's bubble).
--   * "TourPaid": the ★ / ★★ / ★★★ TOUR stamp with the tip, bonus and streak, the pay counting up, confetti for
--     ★★★; then ("Tour" Stage "after", once the tourists have stepped off and cheered) the AFTER panel: the pay, the
--     stars and what was missing for ★★★ ("for ★★★: faster, PERFECT photos, a smoother ride"), NEXT TOUR | END.
-- THE JET SKI RENTAL (BusinessResult "Rented" / "RentalWarn" / "RentalOver"; player attribute BizRentalUntil): a toast
-- when you rent one, the strip's RENTAL line counting the time down (orange in the last minute) whenever no job or
-- alarm has the strip, a toast at a minute left and one when it goes back.
-- VIP PICKUPS (the Afterglow Nightclub, M5; BusinessJob "Vip" / "VipAboard" / "VipPap" / "VipLost" / "VipComfort" /
-- "VipPaid"; the server decides everything: Services.BusinessJobs.Nightclub).
--   * The pickup ("Vip" Stage "pickup"): GET IN THE LIMO until you're at its wheel (its "Drive" bubble shows only to
--     you), then PICK UP <NAME> · <THE VILLA> with the distance, the gold ring and beam at the pickup and the GPS. A
--     special VIP says so in a toast (SUPERSTAR, TABLOID STAR, LATE FOR THE SHOW) and on the line under the strip.
--   * "VipAboard": VIP ABOARD! over the HOLD spot, the door and a honk, what the VIP said; then TO THE RED CARPET with
--     the distance, the GPS to the club and the VIP mark at the carpet (a pink ring the size of a GOOD stop, a gold dot
--     for PERFECT, a beam). The line under it: COMFORT 92% (player attribute BizVipComfort: green, orange, red), PAR,
--     PAPARAZZI!, the special, NIGHT ×1.25, the streak. Near the club: STOP ON THE VIP MARK.
--   * "VipPap": PAPARAZZI! (a toast and the Spotted beep), the strip's LOSE THE PAPARAZZI! with the nearest one's
--     distance (cars with attribute BizPapFor = you). "VipLost": the LOST THEM! stamp and the LostCops sting.
--     "VipComfort": the line under the strip shakes (a crash sound, a camera flash for paparazzi).
--   * "VipPaid": the RED CARPET: the press's flashes on screen (Tour.flashes), the Passed sting, the ★ / ★★ / ★★★ RED
--     CARPET stamp with the stop (PERFECT / GOOD / OK STOP), the tip, LOST THEM, night, the streak; the pay counting up,
--     confetti for ★★★. Then ("Vip" Stage "after", once the VIP has walked in) the AFTER panel: NEXT VIP | END.
-- THE CLUB (BusinessResult "ClubIn" / "ClubOut" / "BoothBooked" / "BoothCrew" / "BoothWarn" / "BoothOver" / "Washed";
-- player attributes BizClub, BizCoverUntil, BizBoothUntil): the toasts; the rope's prompt reads "Cover charge $50", or
-- "Enter the club (free)" for owners and their crew, "(paid)" with a pass. Inside (BizClub): the strip says AFTERGLOW ·
-- DANCE FLOOR (or YOUR VIP BOOTH and its clock), END JOB reads LEAVE (RequestBusiness "Mod", id, "Leave"), and this
-- device makes the dance floor's tiles and the wall lights pulse (level 2+, its own level). The back room's WASH prompt
-- shows only to the club's owners; the card and the EMPIRE app show the back room's dirty cash, the wash and a raid.
-- The job's line (frame "Strip", Theme's Banner zone: a gold tag and what to do, at most K.STRIP_MAX letters; the
-- distance or the tip on the right; frame "StripSub" under it) and END JOB (a tile in the side column under the
-- Buttons zone, LawClient.SideSlot) show for the whole job. "Ended" says why, and THE SHIFT REPORT (frame
-- "ShiftReport", centred on every device): SHIFT REPORT · <BRAND>, the money counting up, the shift's numbers (the
-- server's Report or Summary: cars washed, ★★★, best streaks, deliveries, dents; orders, stops, medals, perfect
-- runs; press runs...), the Empire XP, CONTINUE (the same job again at the business, else the GPS back) | DONE
-- (Enter / Y, X / B). It goes by itself after K.REPORT_TIME or when you sit down.
--
-- COLD BREW (BusinessResult "ColdBrew"): a toast with what it does; another when it wears off (player
-- attribute ColdBrewUntil, server time; LocomotionClient reads the same attribute for the stamina).
--
-- PER-DEVICE LEVEL PROPS: every part tagged "BizProp" (attributes BizId, MinLevel, MaxLevel) is shown only
-- while the level this device shows for that business is within MinLevel..MaxLevel; else it's made fully
-- see-through and its gui, lights, decals and textures are switched off on this device only (nothing
-- replicates). The level shown: your own if you own it; else your crewmate's (the highest crewmate owner in
-- the server, from ReplicatedStorage "BizOwners"); else the featured owner's; else 1. The owner plate under
-- the roof sign says "★ YOUR SUDS & SHINE ★", "<Crewmate>'s Suds & Shine", "<Featured>'s Suds & Shine" or
-- FOR SALE · $25,000. Door prompts read Manage / Work here / View / Buy $X; the shine prompt only shows while
-- you drive your own car (not a boat); a customer car's "Drive" prompt only to its driver.
--
-- SHINE SPARKLE: cars (Workspace.Vehicles) within K.SHINE_RANGE of the camera whose owner's ShineUntil is in
-- the future get a sparkle emitter on their chassis and glossier paint, on this device (at most K.SHINE_MAX).
--
-- BREAK-INS: BusinessResult "BreakIn" (yours or a crewmate's): a toast, a GPS route to the business, the
-- strip's red BREAK-IN line with the time left (when no other job line is up), the map icon flashing red
-- (player attribute BizAlarm). A gun pointed at a robber (CombatClient.Aiming, within K.SCARE_REACH and
-- K.SCARE_CONE, once a second) asks the server to scare it off; punches and shots go through CombatService
-- as usual. Robbers' poses (model attribute Pose) play here with PoseClient, like HeistClient's clerks.
--
-- TOASTS AND STAMPS (BusinessResult): bought (a stamp), upgraded (LEVEL n, what it adds), collected, register
-- full, a customer ("Player2 got a shine at your Car Wash +$70", "...a cold brew at your Coffee Shop +$42"),
-- shined, cold brew, crew cut, break-in, stopped, lost, EMPIRE RANK n (a stamp, with what it unlocks), and
-- every refusal in words (K.MSG).
--
-- API (PhoneUI's EMPIRE app, MinimapClient, MapClient, CombatClient, InteractClient):
--   BusinessClient.On() -> the feature runs in this server
--   BusinessClient.IsOpen() -> a card, the wash mini-game, the rush orders' GRAB hold at the shelf, or the
--     Print Shop's HOLD (a station, the cash cart) is up
--   BusinessClient.Owned() -> { { Id, Name, Short, Level, Register (live), Cap, Rate, Busy, Next, Lifetime,
--     JobsDone, Pos, and for a shady business Dirty, Stock, Extra (the EMPIRE app's line: the dirty cash, or
--     RAID! and the clock), ExtraColor } } in config order
--   BusinessClient.ForSale() -> { { Id, Name, Price, Unlock, Locked, Pos, JobLine, Trickle } } (Enabled, not yours; a
--     locked one's JobLine starts "Unlocks at Empire 2 (you're 1)", M4)
--   BusinessClient.ComingSoon() -> { { Id, Name, Price, Unlock, JobLine, Kind } } (not Enabled yet)
--   BusinessClient.Empire() -> { Rank, XP, Share, Into, Need, Next (the next unlock's words), Title, RemoteCollect }
--   BusinessClient.RouteTo(id) -> GPS to its door; BusinessClient.Collect(id) -> remote collect (Empire 5+)
--   BusinessClient.MapBlips() -> { { Id, Name, Pos, Letter, Color, Owned, Alarm } } (Enabled businesses)
-- Studio: the phone layout follows PreviewTouch like every HUD piece; BizTestCrew (Workspace attribute) makes
-- every other player count as a crewmate here too.

local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Businesses = require(ReplicatedStorage.Shared.Config.Businesses)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local Theme = require(ReplicatedStorage.Shared.Util.Theme)
local RobloxMenu = require(ReplicatedStorage.Shared.Util.RobloxMenu)
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local NotifyController = require(script.Parent:WaitForChild("NotifyController"))
local GPSClient = require(script.Parent:WaitForChild("GPSClient"))

local player = Players.LocalPlayer

local BusinessClient = {}

local C = Theme.Color
local money = HUDController.Money
local WASH = Businesses.Wash
local E = Businesses.Empire

-- Every number and word this file uses (balance lives in Config.Businesses).
local K = {
	DISPLAY_ORDER = 9, -- as HouseClient's card
	CARD_PAD = 18,
	CARD_W = 392, -- PC; a phone: 46% of the width, 300-380
	SCARE_REACH = 22, -- studs: a gun this close on a robber asks the server (it allows Config's ScareReach)
	SCARE_CONE = 0.94, -- cosine from the crosshair's line
	SCARE_GAP = 1, -- seconds between two asks
	SHINE_RANGE = 160, -- studs from the camera a shiny car sparkles
	SHINE_MAX = 8,
	HOLD_EXTRA = 0.15, -- seconds a hold is kept past the server's hold time before letting go (lag)
	SCRUB_GAP = WASH.ScrubGap + 0.04, -- this device counts a tap no sooner than the server does
	RING = 64, -- the drop ring's size (studs across): Config.Detail.StopRadius x 2 (and Config.Rush's)
	GRAB_RANGE = 7, -- studs (flat) from the RUSH ORDERS shelf the GRAB hold shows (the server allows Config.Rush.GrabRange)
	BREW = Color3.fromRGB(196, 128, 70), -- the GRAB hold's fill: coffee
	-- The Print Shop (M3)
	SWEET = Color3.fromRGB(90, 220, 120), -- the gauge's green band, and the fill while it's inside it
	INK = Color3.fromRGB(150, 156, 170), -- the gauge's fill outside the band
	BILL = Color3.fromRGB(122, 168, 112), -- fake bills (the stack, the sheets, the DIRTY pop)
	STATION_SHOW = 6, -- studs (flat) from a print station the HOLD shows (the server allows Config.Print.Range)
	LOAD_SHOW = 7, -- studs (flat) from the cash cart the LOAD hold shows (the server allows Config.Launder.LoadRange)
	CASH_MAX = 12, -- bundles at most on the counting table (parts made on this device only)
	CASH_RANGE = 220, -- studs from the shop the stack is drawn within
	COUNT_TIME = 1.3, -- seconds the laundered cash counts up on screen
	SIREN_RANGE = 350, -- studs from a raided shop its siren is heard
	-- The fun pass (launch/18-BUSINESS-FUN-PASS.md): every job's feel. The server decides every grade, medal,
	-- streak and special; these are only looks.
	REPORT_TIME = 25, -- seconds the SHIFT REPORT card stays up (or DONE / CONTINUE)
	REPORT_W = 400, -- its width on a PC (a phone: 46% of the screen, 300-380, as the cards)
	STRIP_MAX = 30, -- letters at most in a strip line (the Nov 4 Studio test: longer ones were cut off)
	SUB_H = 18, -- the line under the strip: the dents, the stops' pips, the streak, rush hour
	SCRUB_PX = 66, -- a SCRUB button on a phone (54 on a PC)...
	SCRUB_PX_PC = 54,
	SCRUB_SPACE = 10, -- ...and the pixels kept between two of them on screen (Wash.spread pushes them apart)
	SQUEAK_LIFE = 0.2, -- seconds of the squeak a scrub tap plays (Sounds WashSqueak)
	HONK_GAP = 0.35, -- seconds between the two honks as a washed car pulls out
	GLEAM_TIME = 0.6, -- seconds the shine sweep takes across a washed car
	RATING_TIME = 2.2, -- seconds the ★ rating stamp stays over the car
	HANDOVER_WALK = 1.6, -- seconds the delivery customer takes to walk out to their car
	HOT = Color3.fromRGB(214, 92, 40), -- a rush order's cup when its clock starts...
	COLD = Color3.fromRGB(96, 160, 226), -- ...and at 0:00 (the colour drains as it runs)
	MEDAL = { Gold = Color3.fromRGB(255, 200, 60), Silver = Color3.fromRGB(205, 214, 228), Bronze = Color3.fromRGB(205, 127, 70) },
	CONFETTI = 24, -- particles in a VIP's confetti burst (one burst, then gone)
	CONFETTI_COLORS = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 90, 160), Color3.fromRGB(80, 200, 255), Color3.fromRGB(120, 230, 120) },
	-- The wash's dirt (Config.Wash.Dirt): looks and button words.
	DIRT = {
		Mud = { Color = Color3.fromRGB(96, 72, 48), Material = Enum.Material.Sand, Size = 1.9, Button = Color3.fromRGB(120, 90, 60), Word = "MUD" },
		Bugs = { Color = Color3.fromRGB(58, 66, 36), Material = Enum.Material.Slate, Size = 1.5, Button = Color3.fromRGB(78, 92, 44), Word = "BUGS" },
		Bird = { Color = Color3.fromRGB(232, 232, 222), Material = Enum.Material.Concrete, Size = 1.7, Button = Color3.fromRGB(226, 226, 214), Word = "BIRD", Dark = true },
	},
	WEDDING = Color3.fromRGB(250, 250, 252), -- the wedding car's paint
	CLASSIC = { Color3.fromRGB(118, 196, 186), Color3.fromRGB(232, 216, 172), Color3.fromRGB(160, 28, 40) }, -- mint, cream, cherry
	SKINS = { Color3.fromRGB(234, 192, 150), Color3.fromRGB(160, 110, 75), Color3.fromRGB(255, 220, 185), Color3.fromRGB(110, 75, 55) },
	SHIRTS = { Color3.fromRGB(255, 140, 120), Color3.fromRGB(120, 200, 230), Color3.fromRGB(250, 220, 90), Color3.fromRGB(170, 120, 220) },
	PAINTS = {
		Color3.fromRGB(196, 54, 54), Color3.fromRGB(230, 230, 236), Color3.fromRGB(28, 30, 36), Color3.fromRGB(40, 92, 160),
		Color3.fromRGB(150, 156, 164), Color3.fromRGB(240, 196, 44), Color3.fromRGB(64, 120, 80), Color3.fromRGB(120, 60, 150),
	},
	FOAM = Color3.fromRGB(245, 248, 255),
	SPRAY = Color3.fromRGB(150, 210, 255),
	RINSE = Color3.fromRGB(220, 240, 255),
	SPARKLE = "rbxasset://textures/particles/sparkles_main.dds",
	-- Boat tours (M4): the buoy rings, the GPS line on the water, the photo gauge, the guide's bubble.
	TOUR_PATH = "BizTour", -- GPSClient path name (a race's line is "Race": a newer path replaces an older one)
	WATER_Y = -1.5, -- the sea's surface: where a buoy ring floats
	WATER_LINE_Y = -1, -- the GPS line on the water (as ActivityClient's)
	RING_WALL = 1.2, -- studs thick: a ring's see-through wall (a hollow CylinderHandleAdornment)
	RING_H = 5, -- studs tall
	BUOYS = 8, -- buoys round a ring (local parts, bobbing)
	BUOY = 2.2, -- a buoy's size
	BEAM_H = 120, -- the light pillar over the next ring
	RING_COLOR = {
		Pass = Color3.fromRGB(255, 200, 60), -- gold
		Photo = Color3.fromRGB(255, 90, 170), -- pink: slow down here
		Fish = Color3.fromRGB(90, 220, 120), -- green: stop here
		Dock = Color3.fromRGB(70, 220, 210), -- aqua: the end
	},
	PHOTO_WARN = 160, -- studs before a photo or fishing ring the strip says to slow down
	GUIDE_TIME = 4.5, -- seconds the tour guide's line stays up
	REPLAN = 3, -- seconds between two checks of the GPS line (redrawn from the boat when 150+ studs off it)
	OFF_LINE = 150,
	MOOD_GOOD = 0.8, -- the HAPPY % is green from here (the ★ for a smooth ride: Config Tour.Mood.StarAt)...
	MOOD_OK = 0.5, -- ...orange from here, red under it
	-- VIP pickups and the club (M5)
	VIP_PINK = Color3.fromRGB(255, 62, 165),
	-- BusinessResult "No" reasons, in words.
	MSG = {
		TooFar = "Get closer to the business first.",
		Owned = "You already own this business.",
		Locked = "Reach a higher Empire rank to buy this one.",
		Empty = "The register is empty.",
		MaxLevel = "Fully upgraded already!",
		NotYours = "Only its owners and their crew can work here.",
		BaysBusy = "Every bay is busy right now. Try again in a moment, or deliver a car.",
		JobElsewhere = "You're working at another business. END JOB first.",
		OnDelivery = "Finish the delivery first (or END JOB).",
		OnRush = "You're on rush orders. Finish them first (or END JOB).",
		PickupBlocked = "Something's on the PICK-UP box. Clear it and try again.",
		NoAddress = "No customer is home right now. Try again in a moment.",
		NoCar = "No customer car is ready. Try again in a moment.",
		RemoteRank = "Collecting from the phone unlocks at Empire rank " .. E.RemoteCollect .. ".",
		ShineOwnCar = "Drive your own car under the gantry for a shine.",
		ShineStop = "Stop under the gantry first.",
		ShineAlready = "Your car is still sparkling!",
		ColdBrewOnFoot = "Walk up to the counter to order.",
		ColdBrewAlready = "You've still got a cold brew going!",
		StockFull = "The back room is full! Launder a load before you print more.",
		NoStock = "Nothing to load yet: print some first.",
		NotInBay = "Park your own car in the LOADING bay first (and stop).",
		BagsAway = "Drop the bags first: you're on a run.",
		-- Boat Rentals (M4)
		NoBoat = "The tour boat isn't ready. Try again in a moment.",
		BerthBlocked = "Something's in the tour boat's berth. Clear it and try again.",
		RentCivOnly = "Only citizens can rent a jet ski.",
		RentWanted = "Lose the cops before you rent a jet ski.",
		RentOnFoot = "Walk up to the JET SKI RENTALS stand to rent one.",
		RentAlready = "You've already got a jet ski out!",
		RentBusy = "Both rental slots are busy. Try again in a moment.",
		-- The Nightclub (M5)
		NoLimo = "The limo isn't ready. Try again in a moment.",
		LimoBlocked = "Something's in the LIMO bay. Clear it and try again.",
		NoPickup = "No VIP is waiting right now. Try again in a moment.",
		ClubCivOnly = "Only citizens can go clubbing.",
		ClubWanted = "The bouncers won't let you in while you're wanted.",
		ClubOnFoot = "Walk up to the velvet rope to get in.",
		ClubBusy = "Finish your job first, then come dancing.",
		BoothTaken = "Another party has the VIP booth right now.",
		BoothAlready = "The VIP booth is already yours!",
		BoothReserved = "That booth is reserved. VIPs only!",
		WashNotYours = "Only the club's owner can wash the back room's cash.",
		WashCivOnly = "Only citizens can wash cash.",
		BackRoomEmpty = "The safe is empty. The card game fills it after dark.",
	},
	-- BusinessJob "Ended" reasons, in words (nil: nothing more to say).
	ENDED = {
		Player = "Job over.",
		Wanted = "Job over: you're wanted. Lose the cops first.",
		Side = "Job over.",
		Died = "Job over.",
		OwnerLeft = "Job over: the owner left the server.",
		LeftBay = "Job over: you walked away from the bay.",
		LeftCar = "Job over: you left the customer's car.",
		CarGone = "Job over: the customer's car is gone.",
		Invalid = "Job over.",
		LeftOwnCar = "Job over: you left your car with the order.",
		NoCarYet = "Job over: get in your own car after you grab an order (tap CAR to call it).",
		Idle = "Job over: no order picked up for a while.",
		Busy = "Job over.",
		BagsLeft = "Job over: you left the car with the bags.",
		BagsCar = "Job over: the car with the bags is gone.",
		NoNextCar = "Shift over: no car started for a while.",
		LeftBoat = "Job over: you left the tour boat.",
		BoatGone = "Job over: the tour boat is gone.",
		LeftLimo = "Job over: you left the club's limo.",
		LimoGone = "Job over: the limo is gone.",
		NoLimo = "Job over: the limo isn't ready.",
		NoPickup = "Job over: no VIP is waiting right now.",
	},
	-- VIP pickups' own words for an ending, where they differ from ENDED.
	ENDED_VIP = {
		Idle = "Shift over: no VIP picked up for a while.",
		Player = "Shift over.",
	},
	-- Boat tours' own words for an ending, where they differ from ENDED.
	ENDED_TOUR = {
		Idle = "Shift over: no tour started for a while.",
		Player = "Shift over.",
	},
	-- The Print Shop's own words for an ending, where they differ from ENDED.
	ENDED_PRINT = {
		Idle = "Shift over: nothing printed or loaded for a while.",
		Player = "Shift over.",
	},
}

local ui = {} -- the screen pieces (build): gui, card and its parts, strip, hold, after, endJob; marker, beam
local S = {
	on = false,
	state = nil, -- the last BusinessState
	owners = {}, -- ReplicatedStorage "BizOwners", decoded
	card = nil, -- { id, mode = "Buy" | "Manage" | "Crew", sub = "main" | "job", owner, ownerName, level }
	actions = {}, -- [button index] = what it does now
	chatHidden = false,
	wash = nil, -- the wash mini-game (see Wash below)
	job = nil, -- { kind = "Wash" | "Detail" | "Rush", id, ... } (Rush: see Rush below)
	brewUntil = nil, -- server time your cold brew wears off (for the "wore off" toast)
	alarm = {}, -- [id] = { untilT (server time), ownerName, mine }
	props = setmetatable({}, { __mode = "k" }), -- [part] = its look before we hid it
	hidden = setmetatable({}, { __mode = "k" }), -- [part] = true while hidden here
	shine = {}, -- [car] = { emitter, paint = { [part] = reflectance } }
	lazy = {},
	lastScare = 0,
	gpsName = nil :: string?, -- the GPS target we set (cleared only if it's still ours)
	robberPoses = setmetatable({}, { __mode = "k" }), -- [model] = { name, handle }
	raids = {}, -- ReplicatedStorage "BizRaids", decoded: [id] = { o, n, s, u, ai, b, h, c } (the Print Shop's raids)
	cashShown = nil, -- bundles on the counting table now (Print.cash)
	siren = nil, -- the raid siren loop playing here, and at which business
	sirenId = nil,
}

local Card, Job, Wash, Fx, Rush, Print, Detail, Tour = {}, {}, {}, {}, {}, {}, {}, {} -- the pieces of this file, as tables (keeps the top level small)
local Vip, Club = {}, {} -- (M5: the Nightclub's VIP pickups and the club)

------------------------------------------------------------------ small helpers

local function other(name)
	local m = S.lazy[name]
	if m == nil then
		local module = script.Parent:FindFirstChild(name)
		local ok, res = false, nil
		if module then
			ok, res = pcall(require, module)
		end
		m = (ok and type(res) == "table") and res or false
		S.lazy[name] = m
	end
	return m or nil
end

-- A one-shot (SoundClient.Play): where = nil (flat), a Vector3 or a part; maxLife cuts it off early.
local function sound(name, where, volume, maxLife)
	task.spawn(function()
		local s = other("SoundClient")
		if s and type(s.Play) == "function" then
			pcall(s.Play, name, where, volume, maxLife)
		end
	end)
end

-- A loop (SoundClient.Loop) on a part until the caller destroys it (or the part goes); nil when there's none.
local function loopSound(name, where, volume)
	local s = other("SoundClient")
	if s and type(s.Loop) == "function" then
		local ok, snd = pcall(s.Loop, name, where, volume)
		return ok and snd or nil
	end
	return nil
end

-- A strip line no longer than K.STRIP_MAX letters: the parts in order, dropping the optional ones (from the end)
-- until it fits, then cutting the first. parts = { "required", { "optional" }, ... }.
local function fit(parts, sep)
	sep = sep or " · "
	local list = {}
	for _, p in ipairs(parts) do
		if type(p) == "table" then
			if p[1] and p[1] ~= "" then
				table.insert(list, { text = p[1], optional = true })
			end
		elseif p and p ~= "" then
			table.insert(list, { text = p, optional = false })
		end
	end
	local function join()
		local out = {}
		for _, p in ipairs(list) do
			table.insert(out, p.text)
		end
		return table.concat(out, sep)
	end
	local text = join()
	for i = #list, 1, -1 do
		if utf8.len(text) and utf8.len(text) <= K.STRIP_MAX then
			break
		end
		if list[i].optional then
			table.remove(list, i)
			text = join()
		end
	end
	local n = utf8.len(text) or #text
	if n > K.STRIP_MAX then
		local cut = utf8.offset(text, K.STRIP_MAX + 1)
		if cut then
			text = string.sub(text, 1, cut - 1)
		end
	end
	return text
end

local function request(...)
	Remotes.Event("RequestBusiness"):FireServer(...)
end

local function serverNow()
	return Workspace:GetServerTimeNow()
end

local function myRoot()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function myHum()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function defOf(id)
	return Businesses.ById[id or ""]
end

-- Another player in your crew (or, in Studio with BizTestCrew, anyone else).
local function isCrewmate(p)
	if not p or p == player then
		return false
	end
	if RunService:IsStudio() and Workspace:GetAttribute("BizTestCrew") == true then
		return true
	end
	local crew = player:GetAttribute("Crew")
	return crew ~= nil and crew == p:GetAttribute("Crew")
end

local function inputMode()
	local name = UserInputService:GetLastInputType().Name
	if string.sub(name, 1, 7) == "Gamepad" then
		return "gamepad"
	elseif name == "Touch" or Theme.IsTouch() then
		return "touch"
	end
	return "keyboard"
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function rich(s)
	return (string.gsub(string.gsub(tostring(s), "&", "&amp;"), "<", "&lt;"))
end

------------------------------------------------------------------ state

-- Your entry for a business (the last BusinessState), or nil.
local function mine(id)
	local list = S.state and S.state.List
	return type(list) == "table" and list[id] or nil
end

-- The register now: the last number plus what has trickled in since (the server's own maths, x its scale).
local function liveRegister(id)
	local e = mine(id)
	if not e then
		return 0
	end
	local since = math.max(0, serverNow() - (tonumber(S.state.At) or serverNow())) * (tonumber(S.state.Scale) or 1)
	return math.min(tonumber(e.Cap) or 0, (tonumber(e.Register) or 0) + (tonumber(e.Rate) or 0) / 60 * since)
end

local function empireXP()
	return tonumber(player:GetAttribute("EmpireXP")) or (S.state and tonumber(S.state.XP)) or 0
end

local function empireRank()
	return Businesses.RankFor(empireXP())
end

-- The level this device shows for a business, and whose it is ("mine" | "crew" | "featured" | nil), with a name.
local function shownOwner(id)
	local e = mine(id)
	if e then
		return Businesses.ClampLevel(e.Level), "mine", player.DisplayName
	end
	local info = S.owners[id]
	if type(info) == "table" then
		local best, bestName
		for uid, lvl in pairs(type(info.o) == "table" and info.o or {}) do
			local p = Players:GetPlayerByUserId(tonumber(uid) or 0)
			if p and isCrewmate(p) and (not best or (tonumber(lvl) or 1) > best) then
				best, bestName = tonumber(lvl) or 1, p.DisplayName
			end
		end
		if best then
			return Businesses.ClampLevel(best), "crew", bestName
		end
		if info.f and info.l then
			return Businesses.ClampLevel(info.l), "featured", tostring(info.n or "")
		end
	end
	return 1, nil, nil
end

------------------------------------------------------------------ level props, plates and prompts (per device)

-- Show or hide one level prop on this device only.
-- Shown, it takes its own look back from the part's BizT attribute (BusinessService stamps it when it builds the
-- prop); hidden, it's fully see-through. Always set from that, never from a remembered copy: the Nov 4 Studio test
-- found every prop stuck see-through after a level change (a remembered "own look" of 1 had gone stale).
function Fx.setProp(part, show)
	local base = part:GetAttribute("BizT")
	if type(base) ~= "number" then
		local rec = S.props[part]
		if not rec then
			rec = { t = part.Transparency < 1 and part.Transparency or 0, kids = {} }
			S.props[part] = rec
		end
		base = rec.t
	end
	S.hidden[part] = (not show) or nil
	local want = show and base or 1
	if part.Transparency ~= want then
		part.Transparency = want
	end
	local night = Workspace:GetAttribute("IsNight") == true
	local glow = CollectionService:HasTag(part, "NightNeon") or CollectionService:HasTag(part, "NightLamp")
	for _, d in ipairs(part:GetChildren()) do
		if d:IsA("SurfaceGui") or d:IsA("BillboardGui") then
			d.Enabled = show
		elseif d:IsA("Light") then
			d.Enabled = show and (not glow or night)
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") then
			d.Enabled = show
		elseif d:IsA("Decal") or d:IsA("Texture") then
			local t = d:GetAttribute("BizT")
			d.Transparency = show and (type(t) == "number" and t or 0) or 1
		end
	end
end

function Fx.propWanted(part)
	local id = part:GetAttribute("BizId")
	local minL = tonumber(part:GetAttribute("MinLevel")) or 1
	local maxL = tonumber(part:GetAttribute("MaxLevel")) or Businesses.MaxLevel
	local level = shownOwner(id)
	return level >= minL and level <= maxL
end

function Fx.applyProps()
	for _, part in ipairs(CollectionService:GetTagged("BizProp")) do
		if part:IsA("BasePart") then
			Fx.setProp(part, Fx.propWanted(part))
		end
	end
end

-- The owner plate, the door prompt and the shine prompt's words for one building (when it is streamed in).
function Fx.dressSite(model)
	local def = defOf(model:GetAttribute("BusinessId"))
	if not def then
		return
	end
	local _, whose, name = shownOwner(def.Id)
	local plate = model:FindFirstChild("OwnerPlate", true)
	local gui = plate and plate:FindFirstChild("SignGui")
	local title = gui and gui:FindFirstChild("Title")
	if title then
		local text, color
		if whose == "mine" then
			text, color = "★ YOUR " .. string.upper(def.Brand or def.Name) .. " ★", Color3.fromRGB(110, 242, 196)
		elseif whose == "crew" or whose == "featured" then
			text, color = tostring(name) .. "'s " .. (def.Brand or def.Name), whose == "crew" and C.Purple or C.Gold
		else
			text, color = "FOR SALE · " .. money(def.Price), C.Gold
		end
		if title.Text ~= text then
			title.Text = text
		end
		title.TextColor3 = color
	end
	local door = model:FindFirstChild("BusinessDoor", true)
	if door and door:IsA("ProximityPrompt") then
		local words = (whose == "mine" and "Manage") or (whose == "crew" and "Work here") or ("View / Buy " .. money(def.Price))
		if door.ActionText ~= words then
			door.ActionText = words
		end
	end
end

function Fx.dressAll()
	local shops = Workspace:FindFirstChild("Shops")
	for _, m in ipairs(shops and shops:GetChildren() or {}) do
		if m:IsA("Model") and m:GetAttribute("BusinessId") then
			Fx.dressSite(m)
		end
	end
	Fx.applyProps()
end

-- Four times a second: the shine prompt (only while driving your own car) and customer cars' Drive prompt.
function Fx.prompts()
	local hum = myHum()
	local seat = hum and hum.SeatPart
	-- (the car or nil: never false, which a passenger seat gave, and car:GetAttribute then errored 4 times a second)
	local car = (seat and seat.Name == "DriverSeat" and seat.Parent) or nil
	local driving = car ~= nil and car:GetAttribute("OwnerUserId") == player.UserId and car:GetAttribute("Boat") ~= true
	local shops = Workspace:FindFirstChild("Shops")
	for _, m in ipairs(shops and shops:GetChildren() or {}) do
		local p = m:GetAttribute("BusinessId") and m:FindFirstChild("BizShinePrompt", true)
		if p and p:IsA("ProximityPrompt") and p.Enabled ~= driving then
			p.Enabled = driving
		end
	end
	local vehicles = Workspace:FindFirstChild("Vehicles")
	for _, v in ipairs(vehicles and vehicles:GetChildren() or {}) do
		if v:GetAttribute("BizCar") == true then
			local s = v:FindFirstChild("DriverSeat")
			local p = s and s:FindFirstChild("BizDrivePrompt")
			if p and p:IsA("ProximityPrompt") then
				local show = v:GetAttribute("BizDriverUserId") == player.UserId and s.Occupant == nil and not (hum and hum.SeatPart)
				if p.Enabled ~= show then
					p.Enabled = show
				end
			end
		end
	end
end

------------------------------------------------------------------ shine sparkle (every device)

function Fx.unshine(car)
	local rec = S.shine[car]
	S.shine[car] = nil
	if not rec then
		return
	end
	if rec.emitter then
		rec.emitter:Destroy()
	end
	for part, refl in pairs(rec.paint) do
		if part.Parent then
			part.Reflectance = refl
		end
	end
end

function Fx.shineTick()
	local cam = Workspace.CurrentCamera
	local at = cam and cam.CFrame.Position or Vector3.zero
	local now = serverNow()
	local keep = {}
	local count = 0
	local vehicles = Workspace:FindFirstChild("Vehicles")
	for _, car in ipairs(vehicles and vehicles:GetChildren() or {}) do
		local chassis = car:IsA("Model") and car.PrimaryPart
		local owner = chassis and Players:GetPlayerByUserId(car:GetAttribute("OwnerUserId") or 0)
		local untilT = owner and owner:GetAttribute("ShineUntil")
		if chassis and type(untilT) == "number" and untilT > now and car:GetAttribute("Boat") ~= true
			and (chassis.Position - at).Magnitude <= K.SHINE_RANGE and count < K.SHINE_MAX then
			count += 1
			keep[car] = true
			if not S.shine[car] then
				local e = Instance.new("ParticleEmitter")
				e.Name = "BizShine"
				e.Texture = K.SPARKLE
				e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 230, 255))
				e.LightEmission = 1
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 0) })
				e.Lifetime = NumberRange.new(0.5, 0.9)
				e.Rate = 7
				e.Speed = NumberRange.new(0.5, 1.5)
				e.SpreadAngle = Vector2.new(180, 180)
				e.Shape = Enum.ParticleEmitterShape.Box
				e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
				e.Parent = chassis
				local paint = {}
				for _, d in ipairs(car:GetDescendants()) do
					if d:IsA("BasePart") and d:GetAttribute("BodyPaint") then
						paint[d] = d.Reflectance
						d.Reflectance = math.min(0.6, d.Reflectance + 0.25)
					end
				end
				S.shine[car] = { emitter = e, paint = paint }
			end
		end
	end
	for car in pairs(S.shine) do
		if not keep[car] then
			Fx.unshine(car)
		end
	end
end

------------------------------------------------------------------ the cards

local function label(parent, name, size, kind)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = ""
	Theme.Text(l, size, kind)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

function Card.build()
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Active = true
	Theme.Panel(card, 0.18)
	card.Visible = false
	card.Parent = ui.gui
	ui.card = card
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Position = UDim2.fromOffset(K.CARD_PAD, 0)
	accent.Size = UDim2.fromOffset(40, 2)
	accent.BackgroundColor3 = C.Brand
	accent.BorderSizePixel = 0
	accent.Parent = card
	ui.title = label(card, "Title", nil, "Display")
	ui.title.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.MinTextSize = 15
	fit.MaxTextSize = 22
	fit.Parent = ui.title
	ui.right = label(card, "Right", 20, "Display")
	ui.right.TextXAlignment = Enum.TextXAlignment.Right
	ui.pips = Instance.new("Frame")
	ui.pips.Name = "Pips"
	ui.pips.BackgroundTransparency = 1
	ui.pips.Parent = card
	ui.pipList = {}
	for i = 1, Businesses.MaxLevel do
		local p = Instance.new("Frame")
		p.Name = "Pip" .. i
		p.BorderSizePixel = 0
		p.Size = UDim2.new(1 / Businesses.MaxLevel, -4, 1, 0)
		p.Position = UDim2.new((i - 1) / Businesses.MaxLevel, 0, 0, 0)
		Theme.Corners(p, 2)
		p.Parent = ui.pips
		ui.pipList[i] = p
	end
	ui.line1 = label(card, "Info", 14, "Body")
	ui.line1.TextColor3 = C.Dim
	ui.line1.RichText = true
	ui.line1.TextWrapped = true
	ui.line1.TextYAlignment = Enum.TextYAlignment.Top
	ui.reg = label(card, "Register", 15, "Display")
	ui.reg.RichText = true
	ui.bar, ui.fill = Theme.Bar(card, C.Cash)
	ui.blurb = label(card, "Blurb", 14, "Body")
	ui.blurb.TextWrapped = true
	ui.blurb.TextYAlignment = Enum.TextYAlignment.Top
	ui.rule = Instance.new("Frame")
	ui.rule.Name = "Rule"
	ui.rule.BackgroundColor3 = C.Text
	ui.rule.BackgroundTransparency = 0.8
	ui.rule.BorderSizePixel = 0
	ui.rule.Parent = card
	ui.note = label(card, "Note", 13, "Body")
	ui.note.TextWrapped = true
	ui.note.TextYAlignment = Enum.TextYAlignment.Top
	ui.buttons = {}
	for i = 1, 4 do
		local b = Instance.new("TextButton")
		b.Name = "Button" .. i
		b.Text = ""
		Theme.Button(b, "Quiet")
		b.FontFace = Theme.Font.Display
		b.TextScaled = true
		local bfit = Instance.new("UITextSizeConstraint")
		bfit.MinTextSize = 12
		bfit.MaxTextSize = 17
		bfit.Parent = b
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
		pad.Parent = b
		b.Parent = card
		b.Activated:Connect(function()
			local fn = S.actions[i]
			if fn then
				sound("Click")
				fn()
			end
		end)
		ui.buttons[i] = b
	end
end

-- A card button: its words, look and what it does (nil = hidden).
function Card.button(i, text, kind, fn, dim)
	local b = ui.buttons[i]
	b.Visible = text ~= nil
	S.actions[i] = text and fn or nil
	if not text then
		return
	end
	b.Text = text
	Theme.Button(b, kind or "Quiet")
	b.FontFace = Theme.Font.Display
	if dim then
		b.AutoButtonColor = false
		b.TextColor3 = C.Dim
	end
end

function Card.close()
	S.card = nil
	if ui.card then
		ui.card.Visible = false
	end
	if S.chatHidden then
		S.chatHidden = false
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat, true)
	end
end

-- Lay the card out for what's showing (see the header for where it sits).
function Card.layout()
	local touch = Theme.IsTouch()
	local pad = K.CARD_PAD
	local w = K.CARD_W
	if touch then
		local vp = Workspace.CurrentCamera.ViewportSize
		w = math.clamp(math.floor(vp.X * 0.46), 300, 380)
	end
	local inner = w - pad * 2
	local btnH = touch and Theme.Touch or 40
	local y = 14
	ui.title.Position = UDim2.fromOffset(pad, y)
	ui.title.Size = UDim2.fromOffset(inner - 124, 30)
	ui.right.Position = UDim2.fromOffset(pad + inner - 120, y + 1)
	ui.right.Size = UDim2.fromOffset(120, 28)
	y += 36
	if ui.pips.Visible then
		ui.pips.Position = UDim2.fromOffset(pad, y)
		ui.pips.Size = UDim2.fromOffset(inner, 5)
		y += 12
	end
	ui.line1.Position = UDim2.fromOffset(pad, y)
	ui.line1.Size = UDim2.fromOffset(inner, 36)
	y += 40
	if ui.reg.Visible then
		ui.reg.Position = UDim2.fromOffset(pad, y)
		ui.reg.Size = UDim2.fromOffset(inner, 20)
		y += 24
		ui.bar.Position = UDim2.fromOffset(pad, y)
		ui.bar.Size = UDim2.fromOffset(inner, 6)
		y += 14
	end
	ui.bar.Visible = ui.reg.Visible
	if ui.blurb.Visible then
		ui.blurb.Position = UDim2.fromOffset(pad, y)
		ui.blurb.Size = UDim2.fromOffset(inner, 52)
		y += 56
	end
	ui.rule.Position = UDim2.fromOffset(pad, y)
	ui.rule.Size = UDim2.fromOffset(inner, 1)
	y += 9
	ui.note.Position = UDim2.fromOffset(pad, y)
	ui.note.Size = UDim2.fromOffset(inner, 34)
	y += 40
	-- Buttons: two to a row. On a phone the right-hand button of each row goes left (CLOSE under the thumb).
	local half = math.floor((inner - 8) / 2)
	local shown = {}
	for i = 1, 4 do
		if ui.buttons[i].Visible then
			table.insert(shown, i)
		end
	end
	local row = 0
	for n = 1, #shown, 2 do
		local a, b = shown[n], shown[n + 1]
		local ry = y + row * (btnH + 8)
		local leftI, rightI = a, b
		if touch and b then
			leftI, rightI = b, a
		end
		if b then
			ui.buttons[leftI].Position = UDim2.fromOffset(pad, ry)
			ui.buttons[leftI].Size = UDim2.fromOffset(half, btnH)
			ui.buttons[rightI].Position = UDim2.fromOffset(pad + half + 8, ry)
			ui.buttons[rightI].Size = UDim2.fromOffset(inner - half - 8, btnH)
		else
			ui.buttons[a].Position = UDim2.fromOffset(pad, ry)
			ui.buttons[a].Size = UDim2.fromOffset(inner, btnH)
		end
		row += 1
	end
	ui.card.Size = UDim2.fromOffset(w, y + row * (btnH + 8) - 8 + pad)
	-- In the middle of the screen on every device. (On a PC it used to sit top-left, right over the Coast Feed
	-- and the toast stack, whose words showed through it: found in the Nov 4 Studio test.)
	ui.card.AnchorPoint = Vector2.new(0.5, 0.5)
	ui.card.Position = UDim2.fromScale(0.5, touch and 0.5 or 0.47)
end

-- The live parts (four times a second): the register, its bar and the COLLECT button.
function Card.live()
	local c = S.card
	if not c or c.mode ~= "Manage" then
		return
	end
	local e = mine(c.id)
	if not e then
		return
	end
	local reg, cap = liveRegister(c.id), tonumber(e.Cap) or 1
	ui.reg.Text = string.format('REGISTER  <font color="#%s">%s</font>  <font color="#%s">/ %s</font>', C.Cash:ToHex(),
		money(reg), C.Dim:ToHex(), money(cap))
	ui.fill.Size = UDim2.fromScale(math.clamp(reg / math.max(cap, 1), 0.02, 1), 1)
	ui.fill.BackgroundColor3 = reg >= cap and C.Gold or C.Cash
	if c.sub == "main" then
		local amount = math.floor(reg)
		local text = amount > 0 and ("COLLECT " .. money(amount)) or "REGISTER EMPTY"
		if ui.buttons[1].Text ~= text then
			Card.button(1, text, amount > 0 and "Primary" or "Quiet", function()
				request("Collect", c.id)
			end, amount <= 0)
		end
	end
end

-- Buttons 1-2: the business's jobs (Config Jobs: the first one Primary). owner: the crewmate's UserId when
-- working for them (nil: your own).
function Card.jobButtons(def, owner)
	for i = 1, 2 do
		local j = def.Jobs and def.Jobs[i]
		if j then
			Card.button(i, j.Label, i == 1 and "Primary" or "Quiet", function()
				Card.close()
				request("Job", def.Id, j.Kind, owner)
			end)
		end
	end
end

-- Fill the card in for its mode (see the header).
function Card.fill()
	local c = S.card
	local def = c and defOf(c.id)
	if not def then
		Card.close()
		return
	end
	local cash = tonumber(player:GetAttribute("Cash")) or 0
	local rank = empireRank()
	ui.pips.Visible = c.mode ~= "Buy"
	ui.reg.Visible = c.mode == "Manage"
	ui.blurb.Visible = c.mode == "Buy"
	ui.right.TextColor3 = C.Gold
	for i = 1, 4 do
		Card.button(i, nil)
	end
	local level = 1
	if c.mode == "Buy" then
		local lv1 = def.Levels[1]
		ui.title.Text = def.Name
		ui.right.Text = money(def.Price)
		ui.right.TextColor3 = C.Cash
		ui.line1.Text = "<b>The job:</b> " .. rich(def.JobLine or "") .. " · " .. rich(def.JobPay or "")
		ui.blurb.Text = (def.Blurb or "") .. string.format("  Its register fills $%d a minute while you play%s (holds %s).", lv1.Trickle,
			def.NightMult and string.format(", ×%d at night", def.NightMult) or "", money(lv1.Cap))
		local locked = not Businesses.Unlocked(def, rank)
		if locked then
			ui.note.Text = "Needs Empire rank " .. def.Unlock .. " (you're " .. rank .. "). Earn Empire XP running a business."
			ui.note.TextColor3 = C.Purple
		else
			ui.note.Text = "Level 5: " .. string.lower(string.sub(def.Levels[5].Adds or "", 1, 1)) .. string.sub(def.Levels[5].Adds or "", 2) .. "."
			ui.note.TextColor3 = C.Gold
		end
		local short = def.Price - cash
		if locked then
			Card.button(1, "EMPIRE " .. def.Unlock .. " NEEDED", "Quiet", function() end, true)
		elseif short > 0 then
			Card.button(1, "NEED " .. money(short) .. " MORE", "Quiet", function() end, true)
		else
			Card.button(1, "BUY " .. money(def.Price), "Primary", function()
				Card.close()
				request("Buy", def.Id)
			end)
		end
		Card.button(4, "CANCEL", "Quiet", Card.close)
	elseif c.mode == "Manage" then
		local e = mine(c.id) or {}
		level = Businesses.ClampLevel(e.Level)
		ui.title.Text = def.Name
		ui.right.Text = "LEVEL " .. level
		local rate = tonumber(e.Rate) or Businesses.Trickle(def, level, false)
		ui.line1.Text = string.format("Register +$%d a minute while you're online%s · %d jobs done", math.floor(rate + 0.5),
			e.Busy and ' <font color="#' .. C.Cash:ToHex() .. '">(+25% busy: crew here)</font>' or "", tonumber(e.JobsDone) or 0)
		local nextPrice = tonumber(e.Next) or Businesses.UpgradePrice(def, level)
		if nextPrice then
			local nxt = def.Levels[level + 1]
			ui.note.Text = string.format("Level %d: %s · +$%d/min, +%d%% job pay", level + 1, nxt.Adds or "",
				nxt.Trickle - def.Levels[level].Trickle, math.floor((nxt.JobMult - def.Levels[level].JobMult) * 100 + 0.5))
			ui.note.TextColor3 = C.Gold
		else
			ui.note.Text = "Fully grown: level " .. Businesses.MaxLevel .. ". ★"
			ui.note.TextColor3 = C.Dim
		end
		if def.Kind == "Shady" then
			-- The dirty cash in stock (a raid takes only this) and a raid on it.
			ui.line1.Text = string.format('Register +$%d a minute · %d jobs done\n<font color="#%s">Dirty cash %s / %s</font> · a run carries %s',
				math.floor(rate + 0.5), tonumber(e.JobsDone) or 0, K.BILL:ToHex(), money(tonumber(e.Dirty) or 0),
				money(tonumber(e.Stock) or Businesses.Stock(level)), money(tonumber(e.Carry) or Businesses.Carry(level)))
			local r = S.raids[def.Id]
			if type(r) == "table" and r.o == player.UserId then
				ui.note.Text = string.format("RAID ON (%s)! Hold the door inside, or launder the stock out.", clock((tonumber(r.u) or serverNow()) - serverNow()))
				ui.note.TextColor3 = C.Danger
			end
		elseif def.BackRoom then
			-- (M5) The club: the night x2 on the register, and the back room (a raid takes only its stock).
			ui.line1.Text = string.format('Register +$%d a minute%s · %d jobs done\n%s', math.floor(rate + 0.5),
				e.Night and (' <font color="#' .. K.VIP_PINK:ToHex() .. '">(NIGHT ×' .. tostring(def.NightMult or 2) .. ')</font>') or (" (×" .. tostring(def.NightMult or 2) .. " at night)"),
				tonumber(e.JobsDone) or 0, Club.backRoomLine(e))
			local r = S.raids[def.Id]
			if type(r) == "table" and r.o == player.UserId then
				ui.note.Text = string.format("RAID ON THE BACK ROOM (%s)! Hold the door inside the club, or WASH the cash out.",
					clock((tonumber(r.u) or serverNow()) - serverNow()))
				ui.note.TextColor3 = C.Danger
			end
		end
		if c.sub == "job" then
			Card.jobButtons(def, nil)
			Card.button(3, "BACK", "Quiet", function()
				c.sub = "main"
				Card.fill()
			end)
		else
			ui.buttons[1].Text = "" -- (Card.live writes COLLECT)
			Card.button(1, "COLLECT", "Primary", function()
				request("Collect", def.Id)
			end)
			Card.button(2, "START JOB", "Quiet", function()
				local jobs = def.Jobs or {}
				if #jobs == 1 then
					Card.close() -- (one job: straight to it)
					request("Job", def.Id, jobs[1].Kind)
					return
				end
				c.sub = "job"
				Card.fill()
			end)
			if nextPrice and cash >= nextPrice then
				Card.button(3, "UPGRADE " .. money(nextPrice), "Quiet", function()
					request("Upgrade", def.Id)
				end)
			elseif nextPrice then
				Card.button(3, "NEED " .. money(nextPrice - cash) .. " MORE", "Quiet", function() end, true)
			else
				Card.button(3, "MAX LEVEL", "Quiet", function() end, true)
			end
		end
		Card.button(4, "CLOSE", "Quiet", Card.close)
	else -- Crew
		level = Businesses.ClampLevel(c.level)
		ui.title.Text = tostring(c.ownerName or "Your crewmate") .. "'s " .. (def.Brand or def.Name)
		ui.right.Text = "LEVEL " .. level
		ui.line1.Text = "Work here for your crewmate: you get your normal pay, and they get a "
			.. math.floor(Businesses.CrewCut * 100 + 0.5) .. "% cut on top."
		ui.note.Text = "Want your own? It's " .. money(def.Price) .. ", and the job pays you directly."
		ui.note.TextColor3 = C.Dim
		Card.jobButtons(def, c.owner)
		if not Businesses.Unlocked(def, rank) then
			Card.button(3, "EMPIRE " .. def.Unlock .. " NEEDED", "Quiet", function() end, true)
		elseif cash >= def.Price then
			Card.button(3, "BUY YOUR OWN", "Quiet", function()
				Card.close()
				request("Buy", def.Id)
			end)
		else
			Card.button(3, "NEED " .. money(def.Price - cash) .. " MORE", "Quiet", function() end, true)
		end
		Card.button(4, "CLOSE", "Quiet", Card.close)
	end
	for i = 1, Businesses.MaxLevel do
		ui.pipList[i].BackgroundColor3 = i <= level and C.Gold or C.Dim
		ui.pipList[i].BackgroundTransparency = i <= level and 0 or 0.7
	end
	Card.layout()
	Card.live()
end

function Card.open(info)
	local def = defOf(info.Id)
	if not def or player:GetAttribute("InHome") == true then
		return
	end
	S.card = { id = def.Id, mode = info.Mode, sub = "main", owner = info.Owner, ownerName = info.OwnerName, level = info.Level }
	Card.fill()
	ui.card.Visible = true
	if not Theme.IsTouch() and not S.chatHidden and StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat) then
		S.chatHidden = pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat, false)
	end
	sound("Click")
end

------------------------------------------------------------------ the job HUD (strip, HOLD, after panel, END JOB, drop marker)

function Job.build()
	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	Theme.Panel(strip, 0.25)
	strip.Visible = false
	strip.Parent = ui.gui
	ui.strip = strip
	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.Size = UDim2.new(0, 3, 1, 0)
	edge.BackgroundColor3 = C.Gold
	edge.BorderSizePixel = 0
	edge.Parent = strip
	ui.stripEdge = edge
	ui.stripTitle = label(strip, "Title", 15, "Bold")
	ui.stripTitle.RichText = true
	ui.stripTitle.TextTruncate = Enum.TextTruncate.AtEnd
	ui.stripTitle.Position = UDim2.fromOffset(12, 0)
	ui.stripTitle.Size = UDim2.new(1, -110, 1, 0)
	ui.stripRight = label(strip, "Right", 16, "Display")
	ui.stripRight.TextXAlignment = Enum.TextXAlignment.Right
	ui.stripRight.AnchorPoint = Vector2.new(1, 0)
	ui.stripRight.Position = UDim2.new(1, -10, 0, 0)
	ui.stripRight.Size = UDim2.new(0, 96, 1, 0)
	-- A rush order's coffee cup at the strip's left (frames only: no texture); its colour drains hot to cold.
	local cup = Instance.new("Frame")
	cup.Name = "Cup"
	cup.BackgroundTransparency = 1
	cup.AnchorPoint = Vector2.new(0, 0.5)
	cup.Position = UDim2.new(0, 10, 0.5, 0)
	cup.Size = UDim2.fromOffset(20, 20)
	cup.Visible = false
	cup.Parent = strip
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Position = UDim2.fromOffset(0, 5)
	body.Size = UDim2.fromOffset(14, 15)
	body.BorderSizePixel = 0
	Theme.Corners(body, 3)
	body.Parent = cup
	local lid = Instance.new("Frame")
	lid.Name = "Lid"
	lid.Position = UDim2.fromOffset(-1, 2)
	lid.Size = UDim2.fromOffset(16, 4)
	lid.BackgroundColor3 = C.Text
	lid.BorderSizePixel = 0
	Theme.Corners(lid, 2)
	lid.Parent = cup
	local handle = Instance.new("Frame")
	handle.Name = "Handle"
	handle.Position = UDim2.fromOffset(12, 8)
	handle.Size = UDim2.fromOffset(7, 8)
	handle.BackgroundTransparency = 1
	Theme.Corners(handle, 4)
	local ring = Instance.new("UIStroke")
	ring.Thickness = 2
	ring.Parent = handle
	handle.Parent = cup
	ui.cup, ui.cupBody, ui.cupRing = cup, body, ring
	-- A VIP order's gold edge round the whole strip.
	local stroke = Instance.new("UIStroke")
	stroke.Name = "VipEdge"
	stroke.Color = C.Gold
	stroke.Thickness = 2
	stroke.Enabled = false
	stroke.Parent = strip
	ui.stripStroke = stroke

	-- The line under the strip (Job.subLine): the dents, a multi-stop order's pips, the streak, rush hour.
	local sub = Instance.new("Frame")
	sub.Name = "StripSub"
	sub.BackgroundTransparency = 1
	sub.Visible = false
	sub.Parent = ui.gui
	ui.sub = sub
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.Size = UDim2.fromScale(1, 1)
	Theme.Panel(inner, 0.35)
	inner.Parent = sub
	ui.subInner = inner
	ui.subPips = {}
	for i = 1, 3 do
		local p = Instance.new("Frame")
		p.Name = "Pip" .. i
		p.AnchorPoint = Vector2.new(0, 0.5)
		p.Position = UDim2.new(0, 8 + (i - 1) * 12, 0.5, 0)
		p.Size = UDim2.fromOffset(8, 8)
		p.BorderSizePixel = 0
		Theme.Corners(p, 4)
		p.Visible = false
		p.Parent = inner
		ui.subPips[i] = p
	end
	ui.subText = label(inner, "Words", 13, "Bold")
	ui.subText.RichText = true
	ui.subText.TextTruncate = Enum.TextTruncate.AtEnd
	ui.subText.Position = UDim2.fromOffset(8, 0)
	ui.subText.Size = UDim2.new(1, -16, 1, 0)

	-- HOLD: a big flat button in the Action zone that fills while held.
	local hold = Instance.new("TextButton")
	hold.Name = "Hold"
	hold.Text = ""
	hold.AutoButtonColor = false
	Theme.Button(hold, "Quiet")
	hold.BackgroundTransparency = 0.2
	hold.Visible = false
	hold.Parent = ui.gui
	ui.hold = hold
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = K.SPRAY
	fill.BackgroundTransparency = 0.35
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	Theme.Corners(fill)
	fill.Parent = hold
	ui.holdFill = fill
	ui.holdText = label(hold, "Words", 18, "Display")
	ui.holdText.Size = UDim2.fromScale(1, 1)
	ui.holdText.TextXAlignment = Enum.TextXAlignment.Center
	ui.holdText.ZIndex = 3
	ui.holdKey = Theme.Key(hold, "F")
	ui.holdKey.AnchorPoint = Vector2.new(0, 0.5)
	ui.holdKey.Position = UDim2.new(0, 10, 0.5, 0)
	ui.holdKey.ZIndex = 4
	-- Held with the mouse or a finger: let go anywhere ends it (UserInputService.InputEnded in start), so a
	-- finger that slides off the button still lets go.
	hold.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Job.holdBegin(input)
		end
	end)

	-- AFTER a wash: the pay, and NEXT CAR | DELIVER | END.
	local after = Instance.new("Frame")
	after.Name = "After"
	Theme.Panel(after, 0.2)
	after.Visible = false
	after.Parent = ui.gui
	ui.after = after
	ui.afterTitle = label(after, "Title", 18, "Display")
	ui.afterTitle.TextXAlignment = Enum.TextXAlignment.Center
	ui.afterTitle.RichText = true
	ui.afterSub = label(after, "Sub", 13, "Body") -- the tip's story: "tip $192 · ★★★ streak ×1.1"
	ui.afterSub.TextXAlignment = Enum.TextXAlignment.Center
	ui.afterSub.RichText = true
	ui.afterSub.TextColor3 = C.Dim
	ui.afterButtons = {}
	for i, spec in ipairs({ { "Next", "NEXT CAR", "Primary" }, { "Deliver", "DELIVER", "Quiet" }, { "End", "END", "Quiet" } }) do
		local b = Instance.new("TextButton")
		b.Name = spec[1]
		b.Text = spec[2]
		Theme.Button(b, spec[3])
		b.FontFace = Theme.Font.Display
		b.TextSize = 16
		b.Parent = after
		ui.afterButtons[i] = b
	end
	-- (after a wash, or back at the lot after a delivery: the shift goes on)
	ui.afterButtons[1].Activated:Connect(function()
		sound("Click")
		local job = S.job
		if job and (job.kind == "Wash" or job.kind == "Detail") then
			ui.after.Visible = false
			S.afterWait = os.clock() + 1.5 -- (the server's answer is on its way: Detail.backTick waits for it)
			request("Job", job.id, "Wash", job.owner)
		elseif job and job.kind == "Tour" then
			ui.after.Visible = false
			S.afterWait = os.clock() + 1.5 -- (the next tour's "Tour" is on its way: Tour.tick waits for it)
			request("Step", "Next") -- NEXT TOUR
		elseif job and job.kind == "Vip" then
			ui.after.Visible = false
			S.afterWait = os.clock() + 1.5 -- (the next VIP's "Vip" is on its way: Vip.tick waits for it)
			request("Step", "Next") -- NEXT VIP
		end
	end)
	ui.afterButtons[2].Activated:Connect(function()
		sound("Click")
		local job = S.job
		if job and (job.kind == "Wash" or job.kind == "Detail") then
			ui.after.Visible = false
			S.afterWait = os.clock() + 1.5
			request("Job", job.id, "Detail", job.owner)
		end
	end)
	ui.afterButtons[3].Activated:Connect(function()
		sound("Click")
		request("EndJob")
	end)

	-- END JOB: a tile in the side column (LawClient.SideSlot), like ActivityClient's END SHIFT.
	local endJob = Instance.new("TextButton")
	endJob.Name = "EndJob"
	endJob.Text = "END JOB"
	Theme.Button(endJob, "Quiet")
	endJob.FontFace = Theme.Font.Display
	endJob.TextSize = 13
	endJob.Visible = false
	Theme.Shadow(endJob)
	endJob.Parent = ui.gui
	ui.endJob = endJob
	endJob.Activated:Connect(function()
		sound("Click")
		if not S.job and Club.inside() then
			request("Mod", player:GetAttribute("BizClub"), "Leave") -- (M5: LEAVE the club)
			return
		end
		request("EndJob")
	end)

	-- THE SHIFT REPORT (Job.report): a centred card after any job's end, CONTINUE | DONE. (The Print Shop's
	-- M3 SHIFT OVER summary, generalized to every business: one panel on a phone too.)
	local rep = Instance.new("Frame")
	rep.Name = "ShiftReport"
	rep.Active = true
	Theme.Panel(rep, 0.15)
	rep.Visible = false
	rep.Parent = ui.gui
	ui.report = rep
	local repEdge = Instance.new("Frame")
	repEdge.Name = "Accent"
	repEdge.Size = UDim2.fromOffset(40, 2)
	repEdge.BackgroundColor3 = C.Gold
	repEdge.BorderSizePixel = 0
	repEdge.Parent = rep
	ui.repKicker = label(rep, "Kicker", 12, "Bold")
	ui.repKicker.TextColor3 = C.Gold
	ui.repTitle = label(rep, "Title", 20, "Display")
	ui.repTitle.TextTruncate = Enum.TextTruncate.AtEnd
	ui.repEarned = label(rep, "Earned", 22, "Display")
	ui.repEarned.TextXAlignment = Enum.TextXAlignment.Right
	ui.repEarned.TextColor3 = C.Cash
	ui.repLines = label(rep, "Lines", 14, "Body")
	ui.repLines.RichText = true
	ui.repLines.TextWrapped = true
	ui.repLines.TextYAlignment = Enum.TextYAlignment.Top
	ui.repXP = label(rep, "XP", 14, "Bold")
	ui.repXP.TextColor3 = C.Gold
	ui.repButtons = {}
	for i, spec in ipairs({ { "Continue", "CONTINUE", "Primary" }, { "Done", "DONE", "Quiet" } }) do
		local b = Instance.new("TextButton")
		b.Name = spec[1]
		b.Text = spec[2]
		Theme.Button(b, spec[3])
		b.FontFace = Theme.Font.Display
		b.TextSize = 16
		b.Parent = rep
		ui.repButtons[i] = b
	end
	ui.repButtons[1].Activated:Connect(function()
		sound("Click")
		Job.reportContinue()
	end)
	ui.repButtons[2].Activated:Connect(function()
		sound("Click")
		Job.reportClose()
	end)
end

-- Where the job pieces sit now (the zones, the side slot); a few times a second while a job is on.
function Job.place()
	local touch = Theme.IsTouch()
	Theme.Place(ui.strip, "Banner", touch)
	local z = Theme.Zone("Action", touch)
	ui.hold.AnchorPoint = z.Anchor
	ui.hold.Position = z.Pos
	ui.hold.Size = touch and UDim2.fromOffset(220, 64) or UDim2.fromOffset(280, 52)
	ui.holdKey.Visible = inputMode() ~= "touch"
	if ui.holdKey.Visible then
		ui.holdKey.Text = inputMode() == "gamepad" and "RT" or "F"
		ui.holdKey.Size = UDim2.fromOffset(math.max(22, 10 + #ui.holdKey.Text * 9), 22)
	end
	-- AFTER: centred above the Action zone.
	local w = touch and 340 or 420
	local btnH = touch and Theme.Touch or 40
	ui.after.AnchorPoint = Vector2.new(0.5, 1)
	if touch then
		-- Low and a little right of centre: clear of the thumbstick (lower left) and the Banner zone.
		ui.after.Position = UDim2.new(0.56, 0, 1, -20)
	else
		ui.after.Position = z.Pos
	end
	local subH = ui.afterSub.Text ~= "" and 18 or 0
	ui.after.Size = UDim2.fromOffset(w, 12 + 26 + subH + 8 + btnH + 12)
	ui.afterTitle.Position = UDim2.fromOffset(12, 10)
	ui.afterTitle.Size = UDim2.new(1, -24, 0, 26)
	ui.afterSub.Visible = subH > 0
	ui.afterSub.Position = UDim2.fromOffset(12, 10 + 26)
	ui.afterSub.Size = UDim2.new(1, -24, 0, 16)
	-- The buttons shown, side by side: NEXT CAR | DELIVER | END, or a boat tour's NEXT TOUR | END.
	local tour = S.job ~= nil and (S.job.kind == "Tour" or S.job.kind == "Vip")
	ui.afterButtons[1].Text = (S.job and S.job.kind == "Vip" and "NEXT VIP") or (tour and "NEXT TOUR") or "NEXT CAR"
	ui.afterButtons[2].Visible = not tour
	local shown = {}
	for _, b in ipairs(ui.afterButtons) do
		if b.Visible then
			table.insert(shown, b)
		end
	end
	local each = math.floor((w - 24 - 8 * (#shown - 1)) / math.max(1, #shown))
	for i, b in ipairs(shown) do
		b.Position = UDim2.fromOffset(12 + (i - 1) * (each + 8), 12 + 26 + subH + 8)
		b.Size = UDim2.fromOffset(each, btnH)
	end
	-- The line under the strip (left-aligned with its words), and the shift report card in the middle.
	local sp, ss = ui.strip.AbsolutePosition, ui.strip.AbsoluteSize
	ui.sub.Position = UDim2.fromOffset(sp.X + 8, sp.Y + ss.Y + 4)
	ui.sub.Size = UDim2.fromOffset(math.max(180, math.min(ss.X - 16, 320)), K.SUB_H)
	Job.placeReport(touch)
	if ui.endJob.Visible then
		local law = other("LawClient")
		local ok, pos, size = false, nil, nil
		if law and type(law.SideSlot) == "function" then
			local okSlots, index = pcall(law.PlaceSlots)
			ok, pos, size = pcall(law.SideSlot, ui.gui, okSlots and tonumber(index) or 0, touch)
		end
		if not ok or typeof(pos) ~= "Vector2" or typeof(size) ~= "Vector2" then
			local s = ui.gui.AbsoluteSize
			pos, size = Vector2.new(s.X - 72, s.Y * 0.5 + 66), Vector2.new(52, 52)
		end
		ui.endJob.Position = UDim2.fromOffset(pos.X, pos.Y)
		ui.endJob.Size = UDim2.fromOffset(size.X, size.Y)
	end
	Print.place(touch)
	Tour.place(touch)
end

-- The drop's ring and beam (local parts under the camera).
function Job.marker(pos)
	if ui.ring then
		ui.ring:Destroy()
		ui.ring = nil
	end
	if ui.beam then
		ui.beam:Destroy()
		ui.beam = nil
	end
	if not pos then
		return
	end
	local function part(name, size, cf, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = C.Gold
		p.Size = size
		p.CFrame = cf
		p.Transparency = transparency
		p.Parent = Workspace.CurrentCamera
		return p
	end
	ui.ring = part("BizDropRing", Vector3.new(0.3, K.RING, K.RING), CFrame.new(pos.X, 0.35, pos.Z) * CFrame.Angles(0, 0, math.rad(90)), 0.6)
	ui.ring.Shape = Enum.PartType.Cylinder
	ui.beam = part("BizDropBeam", Vector3.new(1.4, 160, 1.4), CFrame.new(pos.X, 80, pos.Z), 0.72)
end

function Job.setGPS(name, pos)
	S.gpsName = name
	GPSClient.SetTarget(name, pos)
end

function Job.clearGPS()
	if S.gpsName and GPSClient.Target() == S.gpsName then
		GPSClient.Clear()
	end
	S.gpsName = nil
end

-- The strip's words (five times a second): the job's, else a break-in's.
function Job.strip()
	local touch = Theme.IsTouch()
	local job = S.job
	local title, right, edge = nil, "", C.Gold
	local tag
	if job and job.kind == "Wash" and S.wash then
		local w = S.wash
		tag = "CAR WASH"
		local left = 0
		for _, m in ipairs(w.mud or {}) do
			if m.taps < m.need then
				left += 1
			end
		end
		local words = ({
			arrive = "CAR PULLING IN...",
			spray = "SPRAY · LET GO IN THE GREEN",
			scrub = "SCRUB THE DIRT (" .. left .. " LEFT)",
			rinse = "RINSE · LET GO IN THE GREEN",
			wait = "SHINING...",
			paid = "NEXT CAR, DELIVER, OR END",
		})[w.stage] or ""
		if w.holding then
			words = "LET GO IN THE GREEN!"
		end
		title = words
		right = (job.earned or 0) > 0 and money(job.earned) or ("BAY " .. tostring(w.bay))
		-- Out of reach of the bay: say where to go (and keep HOLD hidden until there; Job.strip runs every frame).
		if w.stage ~= "paid" and not w.holding then
			local near, d = Wash.near(w)
			if not near then
				title = "WALK TO BAY " .. tostring(w.bay) -- (the distance is on the right; a longer line was cut off)
				right = GPSClient.FormatDistance(d)
			end
			local holding = w.stage == "spray" or w.stage == "rinse"
			if ui.hold.Visible ~= (holding and near) then
				ui.hold.Visible = holding and near
			end
		end
	elseif job and job.kind == "Detail" and job.stage == "back" then
		-- Between cars after a delivery: back to the business (the AFTER panel there: Detail.backTick).
		tag = "DETAIL"
		local def = defOf(job.id)
		local root = myRoot()
		local d = (root and def) and flat(root.Position - Businesses.DoorPosition(def)).Magnitude or math.huge
		if def and d <= Businesses.Reach then
			local hum = myHum()
			title = (hum and hum.SeatPart) and "PARK AND GET OUT" or "NEXT CAR, DELIVER, OR END"
			right = (job.earned or 0) > 0 and money(job.earned) or ""
		else
			title = fit({ "BACK TO " .. string.upper(def and (def.Brand or def.Name) or "THE CAR WASH"), { "TAP CAR" } })
			right = d < math.huge and GPSClient.FormatDistance(d) or ""
		end
	elseif job and job.kind == "Detail" and job.pos then
		tag = "DETAIL"
		-- (the car's name is in the toast and the sub line: "DELIVER THE GATORBACK TO PROFESSOR LANE" was cut off)
		title = fit({ "DELIVER TO " .. string.upper(tostring(job.name or "THE OWNER")) })
		local root = myRoot()
		local dist = root and GPSClient.FormatDistance(flat(root.Position - job.pos).Magnitude) or ""
		local left = job.est and math.max(0, math.floor(job.est - (os.clock() - job.since))) or 0
		right = left > 0 and ((touch and "" or "TIP ") .. left .. "s") or dist
	elseif job and job.kind == "Rush" then
		tag, title, right = Rush.line(touch)
	elseif job and job.kind == "Print" then
		tag, title, right = Print.line(touch)
		if tag == "RAID" then
			edge = C.Danger
		end
	elseif job and job.kind == "Tour" then
		tag, title, right, edge = Tour.line(touch)
	elseif job and job.kind == "Vip" then
		tag, title, right, edge = Vip.line(touch)
	else
		local busyElsewhere = player:GetAttribute("JobKind") ~= nil
		-- A Print Shop raid you're part of (as a cop, its owner or their crew) comes before a break-in.
		for id in pairs(S.raids) do
			local role, r = Print.roleIn(id)
			local def = role and defOf(id)
			if def and not busyElsewhere and not title then
				tag, title, right = Print.raidLine(def, role, r, touch)
				edge = role == "Cop" and C.Police or C.Danger
			end
		end
		local bestId, best
		for id, a in pairs(S.alarm) do
			if a.untilT > serverNow() and (not best or a.untilT < best.untilT) then
				bestId, best = id, a
			end
		end
		if best and not busyElsewhere and not title then
			local def = defOf(bestId)
			tag = "BREAK-IN"
			edge = C.Danger
			title = "STOP THE ROBBERS AT " .. string.upper(def and (best.mine and "YOUR " or (tostring(best.ownerName) .. "'S ")) .. (def.Short or def.Name) or "THE BUSINESS")
			right = clock(best.untilT - serverNow())
		end
		-- A rented jet ski (M4): its time left (orange in the last minute).
		local left = Businesses.RentalLeft(player:GetAttribute("BizRentalUntil"), serverNow())
		if left > 0 and not busyElsewhere and not title then
			tag = "RENTAL"
			title = string.upper(Businesses.Rental.Label) .. " RENTAL"
			right = clock(left)
			edge = left <= Businesses.Rental.Warn and C.Orange or C.Gold
		end
		-- Inside the Afterglow Nightclub (M5): the club's line, and END JOB becomes LEAVE.
		local inClub = Club.inside()
		if inClub and not busyElsewhere and not title then
			tag, title, right, edge = Club.line()
		end
		if not job then
			if ui.endJob.Visible ~= inClub then
				ui.endJob.Visible = inClub
			end
			if inClub and ui.endJob.Text ~= "LEAVE" then
				ui.endJob.Text = "LEAVE"
			end
		end
	end
	if job and ui.endJob.Text ~= "END JOB" then
		ui.endJob.Text = "END JOB"
	end
	local on = title ~= nil and player:GetAttribute("TitleScreen") ~= true
	if on then
		local stampTop = HUDController.StampTop and HUDController.StampTop()
		if stampTop then
			local absY = ui.strip.AbsolutePosition.Y + ui.strip.AbsoluteSize.Y
			on = stampTop >= absY
		end
	end
	ui.strip.Visible = on
	Job.subLine(on and job or nil)
	if not on then
		return
	end
	-- A rush order on its way: the cup at the left (hot to cold as its clock runs) and a VIP's gold edge.
	local rush = job ~= nil and job.kind == "Rush" and job.stage == "drive" and job.pos ~= nil
	ui.cup.Visible = rush
	ui.stripStroke.Enabled = rush and job.vip == true
	if rush then
		local share = math.clamp(((job.endsAt or serverNow()) - serverNow()) / math.max(job.timer or 1, 1), 0, 1)
		local c = K.COLD:Lerp(K.HOT, share)
		ui.cupBody.BackgroundColor3 = c
		ui.cupRing.Color = c
	end
	local x = rush and 36 or 12
	if ui.stripTitle.Position.X.Offset ~= x then
		ui.stripTitle.Position = UDim2.fromOffset(x, 0)
		ui.stripTitle.Size = UDim2.new(1, -98 - x, 1, 0)
	end
	ui.stripEdge.BackgroundColor3 = edge
	local hex = edge:ToHex()
	local text
	if touch then
		text = string.format('<font face="Oswald" weight="bold" size="15" color="#%s">%s</font>', hex, rich(title))
	else
		text = string.format('<font face="Oswald" weight="bold" size="16" color="#%s">%s</font>   %s', hex, tag, rich(title))
	end
	if ui.stripTitle.Text ~= text then
		ui.stripTitle.Text = text
	end
	if ui.stripRight.Text ~= right then
		ui.stripRight.Text = right
	end
	ui.stripRight.TextColor3 = (edge == C.Danger and C.Danger) or (job and job.kind == "Rush" and job.late and C.Orange) or C.Text
end

-- Is the owner of this job (or you) in a rush hour now? Returns the server time it ends, or nil.
function Job.rushHourUntil(job)
	local owner = job and Players:GetPlayerByUserId(tonumber(job.owner) or 0) or player
	local untilT = owner and owner:GetAttribute("BizRushHour")
	return Businesses.RushHourOn(untilT, serverNow()) and untilT or nil
end

-- The line under the strip (five times a second with the strip): what the job's streak, dents, stops or rush
-- hour say. job = nil hides it.
function Job.subLine(job)
	local parts, pips, color, dentColor = {}, nil, C.Text, nil
	if job and job.kind == "Wash" and S.wash then
		local w = S.wash
		local sp = w.special and WASH.Specials[w.special]
		if sp then
			table.insert(parts, sp.Name)
			table.insert(parts, { sp.Words })
			color = C.Gold
		end
		if (w.streak or 0) >= 2 then
			table.insert(parts, { "STREAK ×" .. w.streak })
		end
	elseif job and job.kind == "Detail" and job.stage ~= "back" and job.pos then
		local dents = job.dents or 0
		table.insert(parts, "DENTS " .. dents)
		dentColor = dents > 0 and C.Danger or C.Cash -- (red from the first dent)
		if job.sports then
			table.insert(parts, { "SPORTS CAR" })
		end
		if (job.streak or 0) >= 2 then
			table.insert(parts, { "STREAK ×" .. job.streak })
		end
	elseif job and job.kind == "Tour" then
		local p
		p, color, dentColor = Tour.subParts(job)
		for _, x in ipairs(p) do
			table.insert(parts, x)
		end
	elseif job and job.kind == "Vip" then
		local p
		p, color, dentColor = Vip.subParts(job)
		for _, x in ipairs(p) do
			table.insert(parts, x)
		end
	elseif job and job.kind == "Rush" then
		local untilT = Job.rushHourUntil(job)
		if job.stage == "drive" and (job.of or 1) > 1 then
			pips = { done = (job.leg or 1) - 1, of = job.of }
			table.insert(parts, string.format("%d/%d DELIVERED", (job.leg or 1) - 1, job.of))
		end
		if untilT then
			table.insert(parts, { "RUSH HOUR +" .. math.floor(Businesses.Rush.RushHour.TipBoost * 100 + 0.5) .. "% " .. clock(untilT - serverNow()) })
			color = C.Orange
		end
		if (job.streak or 0) >= 2 then
			table.insert(parts, { "GOLD STREAK ×" .. job.streak })
		end
	end
	if #parts == 0 then
		ui.sub.Visible = false
		return
	end
	local words = rich(fit(parts))
	if dentColor then
		-- (the first word in its own colour: the delivery's DENTS n, a boat tour's HAPPY n%)
		words = string.gsub(words, "^%u+ %d+%%?", function(s)
			return string.format('<font color="#%s">%s</font>', dentColor:ToHex(), s)
		end, 1)
	end
	local pipW = 0
	for i, pip in ipairs(ui.subPips) do
		local show = pips ~= nil and i <= pips.of
		pip.Visible = show
		if show then
			pip.BackgroundColor3 = i <= pips.done and C.Cash or C.Dim
			pip.BackgroundTransparency = i <= pips.done and 0 or 0.5
			pipW = 8 + i * 12
		end
	end
	ui.subText.Position = UDim2.fromOffset(math.max(8, pipW), 0)
	ui.subText.Size = UDim2.new(1, -math.max(8, pipW) - 8, 1, 0)
	if ui.subText.Text ~= words then
		ui.subText.Text = words
	end
	ui.subText.TextColor3 = color
	ui.sub.Visible = true
end

-- The sub line gives a quick shake (a dent): its inner panel only, so Job.place's position stays.
function Job.shakeSub()
	S.shakeToken = (S.shakeToken or 0) + 1
	local token = S.shakeToken
	task.spawn(function()
		for i = 1, 8 do
			if S.shakeToken ~= token then
				return
			end
			ui.subInner.Position = UDim2.fromOffset((i % 2 == 0 and 1 or -1) * (9 - i) * 0.6, 0)
			task.wait(0.035)
		end
		ui.subInner.Position = UDim2.fromOffset(0, 0)
	end)
end

function Job.finish(info)
	local job = S.job
	S.job = nil
	Wash.clear(true)
	Job.marker(nil)
	Job.clearGPS()
	ui.endJob.Visible = false
	ui.hold.Visible = false
	ui.after.Visible = false
	ui.sub.Visible = false
	ui.cup.Visible = false
	ui.stripStroke.Enabled = false
	local reason = type(info) == "table" and info.Reason or nil
	local words = K.ENDED[reason or ""]
	local jobs, earned = tonumber(info and info.Jobs) or 0, tonumber(info and info.Earned) or 0
	if reason == "Delivered" or reason == "Left" then
		return -- ("Delivered": an older server's end after a delivery; the DELIVERED stamp said it all)
	end
	if job and job.kind == "Print" then
		-- The Print Shop: its own words (its summary is on the shift report card below).
		S.cashShown = nil
		if ui.heat then
			ui.heat.Visible = false
		end
		words = K.ENDED_PRINT[reason or ""] or words
	elseif job and job.kind == "Tour" then
		-- A boat tour: its rings, line, gauge and bubble go (the server takes the boat and the tourists).
		Tour.clear(job)
		words = K.ENDED_TOUR[reason or ""] or words
	elseif job and job.kind == "Vip" then
		-- VIP pickups: the rings and the mark go (the server takes the limo, the VIP and the paparazzi).
		Vip.clear()
		words = K.ENDED_VIP[reason or ""] or words
	end
	-- The words for the ending (END JOB itself needs none: the card says it), then the SHIFT REPORT card when
	-- anything was done; with nothing done, the old one-line toast.
	local summary = type(info) == "table" and info.Summary or nil
	local done = jobs > 0 or earned > 0 or (type(summary) == "table" and (tonumber(summary.Prints) or 0) > 0)
	if words and reason ~= "Player" then
		NotifyController.Show(words, nil, (reason == "Wanted" and "police") or "info")
	end
	if done then
		Job.report(info, job)
	elseif reason == "Player" and words then
		NotifyController.Show(words, nil, "info")
	end
end

------------------------------------------------------------------ the shift report (every job's end)

-- Its lines from the server's numbers (BusinessJob "Ended": Report, or the Print Shop's Summary). Rich text.
function Job.reportLines(info)
	local function s(n, word, plural)
		n = tonumber(n) or 0
		return string.format("%d %s", n, n == 1 and word or (plural or (word .. "s")))
	end
	local gold = C.Gold:ToHex()
	local r = type(info.Report) == "table" and info.Report or nil
	local sum = type(info.Summary) == "table" and info.Summary or nil
	local lines = {}
	if sum then
		-- The Print Shop (its M3 summary, unchanged).
		table.insert(lines, string.format("%s · %d PERFECT · best streak %d (×%.2f)", s(sum.Prints, "press run"), tonumber(sum.Perfects) or 0,
			tonumber(sum.Best) or 0, tonumber(sum.BestMult) or 1))
		table.insert(lines, string.format("%s laundered · %d clean · %s printed", s(sum.Runs, "run"), tonumber(sum.CleanRuns) or 0,
			money(tonumber(sum.Dirty) or 0)))
	elseif r and r.Pickups ~= nil then
		-- The Afterglow Nightclub's VIP pickups.
		table.insert(lines, string.format('%s · <font color="#%s">%d ★★★</font> · best streak %d', s(r.Pickups, "VIP"), gold,
			tonumber(r.Stars3) or 0, tonumber(r.Best) or 0))
		local extra = { s(r.Perfects, "PERFECT stop") }
		if tonumber(r.Comfort) then
			table.insert(extra, tonumber(r.Comfort) .. "% comfort")
		end
		table.insert(lines, table.concat(extra, " · "))
		local more = {}
		if (tonumber(r.Paps) or 0) > 0 then
			table.insert(more, string.format("paparazzi lost %d / %d", tonumber(r.Lost) or 0, tonumber(r.Paps) or 0))
		end
		if (tonumber(r.Night) or 0) > 0 then
			table.insert(more, s(r.Night, "night pickup"))
		end
		if (tonumber(r.Specials) or 0) > 0 then
			table.insert(more, s(r.Specials, "special VIP"))
		end
		if #more > 0 then
			table.insert(lines, table.concat(more, " · "))
		end
	elseif r and r.Tours ~= nil then
		-- Coastline Boat Rentals' tours.
		table.insert(lines, string.format('%s · <font color="#%s">%d ★★★</font> · best streak %d', s(r.Tours, "tour"), gold,
			tonumber(r.Stars3) or 0, tonumber(r.Best) or 0))
		local photos = tonumber(r.Photos) or 0
		if photos > 0 then
			table.insert(lines, string.format("%s · %d PERFECT%s", s(photos, "photo stop"), tonumber(r.Perfects) or 0,
				(tonumber(r.Missed) or 0) > 0 and (" · " .. tonumber(r.Missed) .. " missed") or ""))
		end
		local extra = { s(r.Tourists, "tourist") }
		if tonumber(r.Happy) then
			table.insert(extra, tonumber(r.Happy) .. "% happy")
		end
		if (tonumber(r.Specials) or 0) > 0 then
			table.insert(extra, s(r.Specials, "special tour"))
		end
		table.insert(lines, table.concat(extra, " · "))
	elseif r and r.Orders ~= nil then
		-- Palm Grind's rush orders.
		table.insert(lines, string.format("%s · %s", s(r.Orders, "order"), s(r.Drops, "stop")))
		table.insert(lines, string.format('<font color="#%s">%d GOLD</font> · %d SILVER · %d BRONZE', K.MEDAL.Gold:ToHex(), tonumber(r.Gold) or 0,
			tonumber(r.Silver) or 0, tonumber(r.Bronze) or 0))
		local extra = { "best streak " .. (tonumber(r.Best) or 0) }
		if (tonumber(r.PerfectRuns) or 0) > 0 then
			table.insert(extra, 1, s(r.PerfectRuns, "perfect run"))
		end
		if (tonumber(r.Vips) or 0) > 0 then
			table.insert(extra, s(r.Vips, "VIP"))
		end
		table.insert(lines, table.concat(extra, " · "))
	elseif r then
		-- The Car Wash: washes and deliveries.
		if (tonumber(r.Washes) or 0) > 0 then
			table.insert(lines, string.format('%s · <font color="#%s">%d ★★★</font> · best streak %d', s(r.Washes, "car washed", "cars washed"),
				gold, tonumber(r.Stars3) or 0, tonumber(r.BestWash) or 0))
		end
		if (tonumber(r.Deliveries) or 0) > 0 then
			local dents = tonumber(r.Dents) or 0
			table.insert(lines, string.format("%s · %s · best streak %d", s(r.Deliveries, "delivery", "deliveries"),
				dents == 0 and "no dents" or s(dents, "dent"), tonumber(r.BestDetail) or 0))
		end
		if (tonumber(r.Specials) or 0) > 0 then
			table.insert(lines, s(r.Specials, "special customer"))
		end
	else
		table.insert(lines, s(info.Jobs, "job"))
	end
	return table.concat(lines, "\n"), #lines
end

-- BusinessJob "Ended" with anything done: the card (centred), the money counting up, CONTINUE | DONE.
function Job.report(info, job)
	local def = defOf(info.Id)
	if not def or not ui.report then
		return
	end
	local text, n = Job.reportLines(info)
	S.report = { id = def.Id, kind = info.Kind or (job and job.kind) or (def.Jobs and def.Jobs[1] and def.Jobs[1].Kind),
		owner = info.Owner, lines = n }
	ui.repKicker.Text = "SHIFT REPORT"
	ui.repTitle.Text = string.upper(def.Brand or def.Name)
	ui.repLines.Text = text
	local xp = tonumber(info.XP) or 0
	ui.repXP.Text = xp > 0 and string.format("+%d Empire XP", xp) or ""
	Job.placeReport(Theme.IsTouch())
	ui.report.Visible = true
	sound("Stamp")
	-- The money counts up (the M3 count-up's easing, in the card).
	local earned = tonumber(info.Earned) or 0
	S.reportToken = (S.reportToken or 0) + 1
	local token = S.reportToken
	task.spawn(function()
		local t0 = os.clock()
		while S.reportToken == token do
			local a = math.clamp((os.clock() - t0) / K.COUNT_TIME, 0, 1)
			ui.repEarned.Text = money(math.floor(earned * (1 - (1 - a) ^ 3)))
			if a >= 1 then
				break
			end
			task.wait()
		end
	end)
	task.delay(K.REPORT_TIME, function()
		if S.reportToken == token then
			Job.reportClose()
		end
	end)
end

function Job.reportClose()
	S.reportToken = (S.reportToken or 0) + 1
	S.report = nil
	if ui.report then
		ui.report.Visible = false
	end
end

-- CONTINUE: the same job again, if you're still at the business (on foot); else the GPS back to it.
function Job.reportContinue()
	local r = S.report
	Job.reportClose()
	local def = r and defOf(r.id)
	if not def then
		return
	end
	local root, hum = myRoot(), myHum()
	local near = root ~= nil and flat(root.Position - def.Position).Magnitude <= Businesses.Reach - 2
	if near and hum and not hum.SeatPart then
		request("Job", def.Id, r.kind, r.owner ~= player.UserId and r.owner or nil)
	else
		Job.setGPS(def.Brand or def.Name, Businesses.DoorPosition(def))
		NotifyController.Show("Head back to " .. (def.Brand or def.Name) .. " to start again (on foot at the door).", nil, "info")
	end
end

-- The card in the middle of the screen (every device: the Nov 4 Studio test), one panel on a phone too.
function Job.placeReport(touch)
	local rep = ui.report
	if not rep then
		return
	end
	local pad = K.CARD_PAD
	local w = K.REPORT_W
	if touch then
		local vp = Workspace.CurrentCamera.ViewportSize
		w = math.clamp(math.floor(vp.X * 0.46), 300, 380)
	end
	local inner = w - pad * 2
	local btnH = touch and Theme.Touch or 40
	local n = S.report and S.report.lines or 2
	local y = 12
	ui.repKicker.Position = UDim2.fromOffset(pad, y)
	ui.repKicker.Size = UDim2.fromOffset(inner, 14)
	y += 16
	ui.repTitle.Position = UDim2.fromOffset(pad, y)
	ui.repTitle.Size = UDim2.fromOffset(inner - 130, 28)
	ui.repEarned.Position = UDim2.fromOffset(pad + inner - 128, y)
	ui.repEarned.Size = UDim2.fromOffset(128, 28)
	y += 34
	ui.repLines.TextSize = touch and 13 or 14 -- (a phone's narrower card: every line still fits on one)
	local linesH = 19 * math.max(1, n)
	ui.repLines.Position = UDim2.fromOffset(pad, y)
	ui.repLines.Size = UDim2.fromOffset(inner, linesH)
	y += linesH + 4
	if ui.repXP.Text ~= "" then
		ui.repXP.Position = UDim2.fromOffset(pad, y)
		ui.repXP.Size = UDim2.fromOffset(inner, 18)
		y += 22
	end
	ui.repXP.Visible = ui.repXP.Text ~= ""
	-- CONTINUE | DONE; on a phone DONE goes left (the thumb side, as the cards' CLOSE).
	local half = math.floor((inner - 8) / 2)
	local cont, done = ui.repButtons[1], ui.repButtons[2]
	local left, right = cont, done
	if touch then
		left, right = done, cont
	end
	left.Position = UDim2.fromOffset(pad, y + 4)
	left.Size = UDim2.fromOffset(half, btnH)
	right.Position = UDim2.fromOffset(pad + half + 8, y + 4)
	right.Size = UDim2.fromOffset(inner - half - 8, btnH)
	rep.Size = UDim2.fromOffset(w, y + 4 + btnH + pad)
	rep.AnchorPoint = Vector2.new(0.5, 0.5)
	rep.Position = UDim2.fromScale(0.5, touch and 0.5 or 0.47)
	local accent = rep:FindFirstChild("Accent")
	if accent then
		accent.Position = UDim2.fromOffset(pad, 0)
	end
end

------------------------------------------------------------------ the wash mini-game (this device only)

-- The customer car: a TrafficModels body (pivot at its bottom middle, front facing -Z) in a random paint, or a
-- greybox car. Every part anchored, never solid. special (the server's roll): a muddy truck is a pickup, a
-- wedding car white, a classic car mint, cream or cherry. Returns the model and its kind in words ("sedan").
function Wash.buildCar(seed, special)
	local rng = Random.new(seed)
	local paint = K.PAINTS[rng:NextInteger(1, #K.PAINTS)]
	if special == "Wedding" then
		paint = K.WEDDING
	elseif special == "Classic" then
		paint = K.CLASSIC[rng:NextInteger(1, #K.CLASSIC)]
	end
	local templates = ReplicatedStorage:FindFirstChild("TrafficModels")
	local list = {}
	for _, t in ipairs(templates and templates:GetChildren() or {}) do
		if t:IsA("Model") then
			table.insert(list, t)
		end
	end
	local model
	local kind = "sedan"
	if #list > 0 then
		local pick = list[rng:NextInteger(1, #list)]
		if special == "Muddy" then
			for _, t in ipairs(list) do
				if string.lower(t.Name) == "pickup" then
					pick = t
				end
			end
		end
		kind = string.lower(pick.Name)
		model = pick:Clone()
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanTouch = false
				d.CanQuery = true -- (until the mud is placed: see Wash.placeMud)
				if d:GetAttribute("BodyPaint") then
					d.Color = paint
					d.Reflectance = special == "Classic" and 0.2 or 0.05
				end
			elseif d:IsA("BaseScript") then
				d:Destroy()
			end
		end
	else
		model = Instance.new("Model")
		local function add(name, size, cf, color, material, shape)
			local p = Instance.new("Part")
			p.Name = name
			p.Anchored = true
			p.CanCollide, p.CanTouch, p.CastShadow = false, false, true
			p.Size = size
			p.CFrame = cf
			p.Color = color
			p.Material = material or Enum.Material.SmoothPlastic
			if shape then
				p.Shape = shape
			end
			p.Parent = model
			if name == "Body" or name == "Roof" then
				p:SetAttribute("BodyPaint", true)
			end
			return p
		end
		local body = add("Body", Vector3.new(6.6, 1.8, 13), CFrame.new(0, 2, 0), paint)
		model.PrimaryPart = body
		add("Cabin", Vector3.new(5.6, 1.6, 6), CFrame.new(0, 3.7, 0.6), Color3.fromRGB(40, 50, 70), Enum.Material.Glass).Transparency = 0.3
		add("Roof", Vector3.new(5.5, 0.25, 5.8), CFrame.new(0, 4.6, 0.6), paint)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				add("Wheel", Vector3.new(1, 2.4, 2.4), CFrame.new(sx * 3, 1.2, sz * 4.2), Color3.fromRGB(28, 28, 32), nil, Enum.PartType.Cylinder)
			end
		end
		model.WorldPivot = CFrame.new()
	end
	model.Name = "BizCustomerCar"
	if special == "Wedding" then
		Wash.weddingSign(model)
	end
	return model, kind
end

-- The wedding car's JUST MARRIED board across its tail (one part, a SurfaceGui: no texture).
function Wash.weddingSign(model)
	local cf, size = model:GetBoundingBox()
	local p = Instance.new("Part")
	p.Name = "JustMarried"
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Size = Vector3.new(math.max(3, size.X * 0.7), 1.1, 0.12)
	p.CFrame = cf * CFrame.new(0, -size.Y * 0.05, size.Z / 2 + 0.1) -- (the tail: +Z of the body, which faces -Z)
	p.Color = Color3.fromRGB(255, 255, 255)
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = model
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Back
	sg.CanvasSize = Vector2.new(260, 44)
	sg.LightInfluence = 0
	sg.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.FontFace = Theme.Font.Display
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(230, 70, 140)
	t.Text = "JUST MARRIED"
	t.Parent = sg
end

-- The customer's tag over the car: "Carla's sedan", and a special one's name and what it pays (the server's roll).
-- A BillboardGui under the car (in Workspace: it takes no taps, so it never blocks a SCRUB button).
function Wash.tag(w)
	local car = w.car
	local core = car and (car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart", true))
	if not core then
		return
	end
	local cf, size = car:GetBoundingBox()
	local top = cf.Position.Y + size.Y / 2
	local bb = Instance.new("BillboardGui")
	bb.Name = "BizTag"
	bb.Adornee = core
	bb.Size = UDim2.fromOffset(230, w.special and 44 or 26)
	bb.StudsOffsetWorldSpace = Vector3.new(0, top - core.Position.Y + 2.6, 0)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Parent = core
	local name = label(bb, "Name", 16, "Display")
	name.Size = UDim2.new(1, 0, 0, 24)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.Text = string.format("%s's %s", tostring(w.name or "A customer"), w.kind or "car")
	local sp = w.special and WASH.Specials[w.special]
	if sp then
		local line = label(bb, "Special", 13, "Bold")
		line.Position = UDim2.fromOffset(0, 22)
		line.Size = UDim2.new(1, 0, 0, 20)
		line.TextXAlignment = Enum.TextXAlignment.Center
		line.TextColor3 = C.Gold
		line.Text = sp.Name .. " · " .. sp.Words
	end
	w.tagGui = bb
end

function Wash.folder()
	local f = Workspace:FindFirstChild("BizLocal")
	if not f then
		f = Instance.new("Folder")
		f.Name = "BizLocal" -- (made on this device: nothing here replicates)
		f.Parent = Workspace
	end
	return f
end

-- The car's place in the bay (its pivot on the bay floor, nose into the bay) and where it pulls in from.
function Wash.spots(w)
	local def = defOf(w.id)
	local bay = def and Businesses.BayCFrame(def, w.bay)
	if not bay then
		return nil, nil
	end
	local inBay = bay * CFrame.new(0, 0.3, 0)
	local b = def.Layout.Bays[w.bay]
	local mouth = Businesses.Frame(def) * CFrame.new(b.X, 0.2, def.Layout.BayMouth) * CFrame.Angles(0, math.pi, 0)
	return inBay, mouth
end

-- Tween a model's pivot (a CFrameValue drives it: models can't be tweened directly).
function Wash.slide(model, from, to, seconds, fadeOut)
	local v = Instance.new("CFrameValue")
	v.Value = from
	model:PivotTo(from)
	v.Changed:Connect(function(cf)
		if model.Parent then
			model:PivotTo(cf)
		end
	end)
	local tween = TweenService:Create(v, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = to })
	tween:Play()
	tween.Completed:Connect(function()
		v:Destroy()
	end)
	if fadeOut then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				TweenService:Create(d, TweenInfo.new(seconds), { Transparency = 1 }):Play()
			end
		end
	end
	return tween
end

-- The dirt: Spots discs on the body, each with its SCRUB button; each spot's dirt is the server's (info.Dirt):
-- mud, bugs or bird mess, each with its own look and taps (Config Wash.Dirt). The candidate places are spread
-- round the car (both sides front and back, hood, roof, tail deck, both bumpers), and Wash.spread keeps their
-- buttons apart on screen (the Nov 4 Studio test: two could overlap on a phone).
function Wash.placeMud(w)
	local car = w.car
	local cf, size = car:GetBoundingBox()
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local rng = Random.new(w.seed + 7)
	-- Candidate spots in the car's box space (front -Z): a point outside the body and the way in toward it.
	local candidates = {
		{ Vector3.new(-hx - 2, -hy * 0.1, -hz * 0.32), Vector3.new(1, 0, 0) },
		{ Vector3.new(-hx - 2, -hy * 0.1, hz * 0.38), Vector3.new(1, 0, 0) },
		{ Vector3.new(hx + 2, -hy * 0.1, -hz * 0.32), Vector3.new(-1, 0, 0) },
		{ Vector3.new(hx + 2, -hy * 0.1, hz * 0.38), Vector3.new(-1, 0, 0) },
		{ Vector3.new(0, hy + 2, -hz * 0.62), Vector3.new(0, -1, 0) },
		{ Vector3.new(rng:NextNumber(-0.3, 0.3) * hx, hy + 2, hz * 0.05), Vector3.new(0, -1, 0) },
		{ Vector3.new(0, hy + 2, hz * 0.78), Vector3.new(0, -1, 0) },
		{ Vector3.new(hx * 0.3, -hy * 0.25, hz + 2), Vector3.new(0, 0, -1) },
		{ Vector3.new(-hx * 0.3, -hy * 0.25, -hz - 2), Vector3.new(0, 0, 1) },
	}
	for i = #candidates, 2, -1 do
		local j = rng:NextInteger(1, i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { car }
	w.mud = {}
	for n = 1, math.min(w.spots, #candidates) do
		local c = candidates[n]
		local dirt = (w.dirt and w.dirt[n]) or "Mud"
		local look = K.DIRT[dirt] or K.DIRT.Mud
		local from = cf:PointToWorldSpace(c[1])
		local dir = cf:VectorToWorldSpace(c[2]) * (math.max(size.X, size.Y, size.Z) + 4)
		local hit = Workspace:Raycast(from, dir, params)
		local pos, normal
		if hit then
			pos, normal = hit.Position, hit.Normal
		else
			pos = cf:PointToWorldSpace(c[1] + c[2] * 2)
			normal = cf:VectorToWorldSpace(-c[2])
		end
		local disc = Instance.new("Part")
		disc.Name = "Dirt"
		disc.Shape = Enum.PartType.Cylinder
		disc.Size = Vector3.new(0.12, look.Size, look.Size)
		disc.CFrame = CFrame.lookAt(pos + normal * 0.06, pos + normal * 2) * CFrame.Angles(0, math.rad(90), 0)
		disc.Color = look.Color
		disc.Material = look.Material
		disc.Anchored = true
		disc.CanCollide, disc.CanQuery, disc.CanTouch, disc.CastShadow = false, false, false, false
		disc.Parent = car
		local m = { part = disc, taps = 0, need = Businesses.WashTaps(dirt), dirt = dirt, normal = normal, pos = pos, size0 = look.Size }
		w.mud[n] = m
		Wash.scrubButton(w, n, m)
	end
	for _, d in ipairs(car:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
		end
	end
end

-- One spot's round SCRUB button over the car (a BillboardGui in PlayerGui: guis only take taps there): its dirt
-- and the taps left ("BIRD ×4"), in the dirt's colour.
function Wash.scrubButton(w, n, m)
	local touch = Theme.IsTouch()
	local px = touch and K.SCRUB_PX or K.SCRUB_PX_PC
	local look = K.DIRT[m.dirt] or K.DIRT.Mud
	local bb = Instance.new("BillboardGui")
	bb.Name = "BizScrub" .. n
	bb.Adornee = m.part
	bb.Size = UDim2.fromOffset(px, px)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 70
	bb.ResetOnSpawn = false
	bb.Active = true
	bb.Enabled = false
	bb.Parent = player:WaitForChild("PlayerGui")
	local b = Instance.new("TextButton")
	b.Name = "Scrub"
	b.Size = UDim2.fromScale(1, 1)
	b.BackgroundColor3 = look.Button
	b.BackgroundTransparency = 0.1
	b.AutoButtonColor = true
	b.FontFace = Theme.Font.Display
	b.TextColor3 = look.Dark and Color3.fromRGB(30, 30, 34) or C.Text
	b.TextScaled = true
	b.Text = look.Word .. " ×" .. m.need
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = b
	local ring = Instance.new("UIStroke")
	ring.Color = C.Text
	ring.Thickness = 2
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.14, 0), UDim.new(0.14, 0)
	pad.Parent = b
	b.Parent = bb
	b.Activated:Connect(function()
		Wash.scrub(n)
	end)
	m.gui, m.button = bb, b
end

-- Every frame while scrubbing: SCRUB buttons that land on top of each other on screen (a spot behind another from
-- where you stand) are pushed apart sideways until there's K.SCRUB_SPACE between them. Only the buttons move (the
-- BillboardGui's camera-space StudsOffset), never the dirt; nothing runs outside the scrub stage.
function Wash.spread()
	local w = S.wash
	if not w or w.stage ~= "scrub" or not w.mud then
		return
	end
	local cam = Workspace.CurrentCamera
	local vp = cam.ViewportSize
	local px = (Theme.IsTouch() and K.SCRUB_PX or K.SCRUB_PX_PC) + K.SCRUB_SPACE
	local list = {}
	for i, m in ipairs(w.mud) do
		if m.gui and m.gui.Enabled then
			local v, on = cam:WorldToViewportPoint(m.part.Position)
			if on then
				table.insert(list, { m = m, i = i, x = v.X, y = v.Y, depth = v.Z, ox = 0 })
			else
				m.gui.StudsOffset = Vector3.zero
			end
		end
	end
	for _ = 1, 3 do
		for a = 1, #list do
			for b = a + 1, #list do
				local A, B = list[a], list[b]
				local dy = math.abs(A.y - B.y)
				if dy < px then
					local need = math.sqrt(px * px - dy * dy)
					local dx = (B.x + B.ox) - (A.x + A.ox)
					if math.abs(dx) < need then
						local push = (need - math.abs(dx)) / 2
						local dir = dx > 0.5 and 1 or (dx < -0.5 and -1 or (A.i < B.i and 1 or -1))
						A.ox -= dir * push
						B.ox += dir * push
					end
				end
			end
		end
	end
	local perPx = 2 * math.tan(math.rad(cam.FieldOfView) / 2) / math.max(vp.Y, 1) -- studs a pixel at 1 stud deep
	for _, e in ipairs(list) do
		e.m.gui.StudsOffset = Vector3.new(e.ox * perPx * math.max(e.depth, 0.1), 0, 0)
	end
end

-- Foam over the car after the spray (white blobs on the dirty spots and the roof).
function Wash.foam(w, on)
	for _, f in ipairs(w.foam or {}) do
		f:Destroy()
	end
	w.foam = {}
	if not on or not w.car then
		return
	end
	local cf, size = w.car:GetBoundingBox()
	local spots = {}
	for _, m in ipairs(w.mud or {}) do
		if m.taps < m.need then
			table.insert(spots, { m.pos + m.normal * 0.3, 2.6 })
		end
	end
	for _, z in ipairs({ -0.15, 0.2 }) do
		table.insert(spots, { cf:PointToWorldSpace(Vector3.new(0, size.Y / 2, size.Z * z)), 3.4 })
	end
	for _, s in ipairs(spots) do
		local p = Instance.new("Part")
		p.Name = "Foam"
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(s[2], s[2], s[2])
		p.CFrame = CFrame.new(s[1])
		p.Color = K.FOAM
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.2
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
		p.Parent = w.car
		table.insert(w.foam, p)
	end
end

-- Water from above the bay at the car while a hold is on (kind "spray" soapy blue, "rinse" clear), with the
-- hose's hiss (a loop on the nozzle: it goes with it).
function Wash.water(w, kind)
	if w.nozzle then
		w.nozzle:Destroy()
		w.nozzle = nil
	end
	if not kind or not w.car then
		return
	end
	local cf, size = w.car:GetBoundingBox()
	local a = Instance.new("Part")
	a.Name = "Nozzle"
	a.Size = Vector3.new(size.X, 0.2, size.Z * 0.8)
	a.CFrame = cf * CFrame.new(0, size.Y / 2 + 5, 0)
	a.Transparency = 1
	a.Anchored = true
	a.CanCollide, a.CanQuery, a.CanTouch = false, false, false
	a.Parent = Wash.folder()
	local e = Instance.new("ParticleEmitter")
	e.Texture = K.SPARKLE
	e.Color = ColorSequence.new(kind == "spray" and K.SPRAY or K.RINSE)
	e.LightEmission = 0.3
	e.Transparency = NumberSequence.new(0.25)
	e.Size = NumberSequence.new(kind == "spray" and 0.55 or 0.35)
	e.Squash = NumberSequence.new(-2)
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Speed = NumberRange.new(26, 34)
	e.Lifetime = NumberRange.new(0.2, 0.3)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rate = 140
	e.Parent = a
	w.nozzle = a
	loopSound("WashHiss", a, kind == "rinse" and 0.8 or 1) -- (a loop on the part ends when the part goes)
end

-- A short burst of sparkles from a part (a spot scrubbed clean, a finished car); its emitter is made once.
function Wash.burst(part, n, size)
	local e = part:FindFirstChild("BizBurst")
	if not e then
		e = Instance.new("ParticleEmitter")
		e.Name = "BizBurst"
		e.Texture = K.SPARKLE
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, size or 0.8), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.4, 0.8)
		e.Speed = NumberRange.new(2, 5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rate = 0
		e.Parent = part
	end
	e:Emit(n)
end

function Wash.sparkle(w)
	if not w.car then
		return
	end
	local _, size = w.car:GetBoundingBox()
	local core = w.car.PrimaryPart or w.car:FindFirstChildWhichIsA("BasePart", true)
	if not core then
		return
	end
	Wash.burst(core, math.floor(math.clamp(size.Magnitude * 2, 20, 60)), 0.8)
	for _, d in ipairs(w.car:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("BodyPaint") then
			d.Reflectance = 0.3
		end
	end
	Wash.gleam(w)
end

-- The shine sweep: one bright sheet passing along the car, nose to tail, then gone.
function Wash.gleam(w)
	local car = w.car
	if not car then
		return
	end
	local cf, size = car:GetBoundingBox()
	local p = Instance.new("Part")
	p.Name = "Gleam"
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 255, 255)
	p.Transparency = 0.55
	p.Size = Vector3.new(size.X + 0.4, size.Y + 0.4, 0.35)
	p.Parent = car
	local from, to = cf * CFrame.new(0, 0, -size.Z / 2), cf * CFrame.new(0, 0, size.Z / 2)
	p.CFrame = from
	TweenService:Create(p, TweenInfo.new(K.GLEAM_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = to, Transparency = 0.85 }):Play()
	task.delay(K.GLEAM_TIME + 0.05, function()
		p:Destroy()
	end)
end

-- "★★★" (the server's rating) slamming down over the car, then fading: lit stars in gold, the rest dim.
local function starsText(stars, dimHex)
	stars = math.clamp(math.floor(tonumber(stars) or 0), 0, 3)
	return string.format('<font color="#%s">%s</font><font color="#%s">%s</font>', K.MEDAL.Gold:ToHex(), string.rep("★", stars),
		dimHex or "5A5F68", string.rep("★", 3 - stars))
end

function Wash.rating(w, stars, words)
	local car = w.car
	local core = car and (car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart", true))
	if not core then
		return
	end
	local cf, size = car:GetBoundingBox()
	local bb = Instance.new("BillboardGui")
	bb.Name = "BizRating"
	bb.Adornee = core
	bb.Size = UDim2.fromOffset(260, 92)
	bb.StudsOffsetWorldSpace = Vector3.new(0, cf.Position.Y + size.Y / 2 - core.Position.Y + 6.5, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 120
	bb.LightInfluence = 0
	bb.Parent = core
	local s = label(bb, "Stars", 50, "Display")
	s.RichText = true
	s.Size = UDim2.new(1, 0, 0, 58)
	s.TextXAlignment = Enum.TextXAlignment.Center
	s.Text = starsText(stars)
	local t = label(bb, "Words", 18, "Display")
	t.Position = UDim2.fromOffset(0, 58)
	t.Size = UDim2.new(1, 0, 0, 26)
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.TextColor3 = stars >= 3 and K.MEDAL.Gold or C.Text
	t.Text = words
	local scale = Instance.new("UIScale")
	scale.Scale = 2.2
	scale.Parent = s
	TweenService:Create(scale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	sound("Stamp", core, 0.8)
	task.delay(K.RATING_TIME, function()
		if bb.Parent then
			TweenService:Create(s, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.delay(0.45, function()
				bb:Destroy()
			end)
		end
	end)
end

-- Is the worker close enough to their bay for a hold or a tap to count (the server's BayRange)? (Found in the
-- Nov 4 Studio test: START JOB is pressed at the door, ~46 studs from bay 1, and nothing said where to go.)
function Wash.near(w)
	local def = defOf(w.id)
	local bay = def and Businesses.BayCFrame(def, w.bay)
	local root = myRoot()
	if not bay or not root then
		return true, 0 -- (can't tell: don't hide anything)
	end
	local d = flat(root.Position - bay.Position).Magnitude
	return d <= WASH.BayRange - 2, d
end

-- Show the stage's controls: HOLD for spray / rinse (a gauge with its green band), the SCRUB buttons for the
-- spots left.
function Wash.show()
	local w = S.wash
	if not w then
		Rush.show() -- (the HOLD button is the rush orders' GRAB, or nothing)
		return
	end
	local holding = w.stage == "spray" or w.stage == "rinse"
	ui.hold.Visible = holding and (w.holding ~= nil or (Wash.near(w)))
	if holding and not w.holding then
		local g = WASH.Gauge[w.stage]
		Job.band(g)
		ui.holdText.Text = w.stage == "spray" and "HOLD TO SPRAY" or "HOLD TO RINSE"
	elseif not holding and ui.holdBand then
		ui.holdBand.Visible = false
	end
	for _, m in ipairs(w.mud or {}) do
		if m.gui then
			m.gui.Enabled = w.stage == "scrub" and m.taps < m.need
		end
	end
	ui.after.Visible = w.stage == "paid"
end

-- pointer: the mouse or touch InputObject holding it (nil: a key).
function Wash.startHold(pointer)
	local w = S.wash
	if not w or w.holding or (w.stage ~= "spray" and w.stage ~= "rinse") or os.clock() < w.readyClock then
		return
	end
	w.holding = { at = os.clock(), kind = w.stage, pointer = pointer }
	request("Step", w.stage == "spray" and "SprayOn" or "RinseOn")
	Wash.water(w, w.stage)
end

-- Let go (done = the gauge filled and let go by itself). The server grades it from its own clock: "WashStep"
-- (the spray) or "WashPaid" (the rinse) pops PERFECT! / OK, or "Again" + Early: TOO EARLY, hold it again.
function Wash.endHold(done)
	local w = S.wash
	local h = w and w.holding
	if not h then
		return
	end
	w.holding = nil
	Wash.water(w, nil)
	request("Step", h.kind == "spray" and "SprayOff" or "RinseOff")
	local g = WASH.Gauge[h.kind]
	if done or os.clock() - h.at >= g.Min then
		-- On to the next stage at once (the server's WashStep puts it back if the hold didn't count).
		if h.kind == "spray" then
			w.stage = "scrub"
			Wash.foam(w, true)
		else
			w.stage = "wait"
		end
	else
		ui.holdFill.Size = UDim2.fromScale(0, 1)
	end
	Wash.show()
end

function Wash.scrub(n)
	local w = S.wash
	local m = w and w.mud and w.mud[n]
	if not m or w.stage ~= "scrub" or m.taps >= m.need or os.clock() - (w.lastTap or 0) < K.SCRUB_GAP then
		return
	end
	w.lastTap = os.clock()
	m.taps += 1
	request("Step", "Scrub", n)
	sound("WashSqueak", m.part, nil, K.SQUEAK_LIFE)
	local left = m.need - m.taps
	local share = m.taps / m.need
	-- The spot shrinks and fades with each tap; a puff of suds where it was scrubbed.
	m.part.Transparency = math.min(1, share * 0.85 + (left == 0 and 0.15 or 0))
	m.part.Size = Vector3.new(0.12, m.size0 * (1 - 0.45 * share), m.size0 * (1 - 0.45 * share))
	if m.button then
		m.button.Text = left > 0 and ((K.DIRT[m.dirt] or K.DIRT.Mud).Word .. " ×" .. left) or "✓"
	end
	if not m.puff then
		local e = Instance.new("ParticleEmitter")
		e.Texture = K.SPARKLE
		e.Color = ColorSequence.new(K.FOAM)
		e.Size = NumberSequence.new(0.5)
		e.Lifetime = NumberRange.new(0.3, 0.5)
		e.Speed = NumberRange.new(2, 5)
		e.SpreadAngle = Vector2.new(90, 90)
		e.Rate = 0
		e.Parent = m.part
		m.puff = e
	end
	m.puff:Emit(8)
	if left == 0 then
		-- The last tap: a pop of sparkles and a ding.
		Wash.burst(m.part, 10, 0.6)
		sound("WashPop", m.part)
	end
	local done = true
	for _, x in ipairs(w.mud) do
		if x.taps < x.need then
			done = false
		end
	end
	if done then
		w.stage = "rinse"
	end
	Wash.show()
end

-- Every frame while a hold is on: the gauge (green while inside the band), letting go by itself when it's full.
function Wash.step()
	local w = S.wash
	local h = w and w.holding
	if not h then
		return
	end
	if Job.drawGauge(os.clock() - h.at, WASH.Gauge[h.kind]) then
		Wash.endHold(true) -- (full: it lets go by itself, an OK)
	end
end

-- Remove the car and every piece of the mini-game. driveOff: the car backs out first, honking twice.
function Wash.clear(driveOff)
	local w = S.wash
	S.wash = nil
	if not w then
		return
	end
	Wash.water(w, nil)
	for _, m in ipairs(w.mud or {}) do
		if m.gui then
			m.gui:Destroy()
		end
	end
	local car = w.car
	if car and car.Parent then
		local _, mouth = Wash.spots(w)
		if driveOff and mouth then
			local core = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart", true)
			if core and w.stage == "paid" then
				sound("Horn", core, 0.7)
				task.delay(K.HONK_GAP, function()
					if core.Parent then
						sound("Horn", core, 0.7)
					end
				end)
			end
			Wash.slide(car, car:GetPivot(), mouth * CFrame.new(0, 0, 6), WASH.DepartTime, true)
			task.delay(WASH.DepartTime + 0.1, function()
				car:Destroy()
			end)
		else
			car:Destroy()
		end
	end
end

-- BusinessJob "Wash": a new customer (the last one pulls out first). Its dirt, name and any special are the
-- server's.
function Wash.start(info)
	local old = S.wash
	local fresh = S.job == nil or S.job.id ~= info.Id
	if old then
		Wash.clear(true)
	end
	local dirt = {}
	for i, d in ipairs(type(info.Dirt) == "table" and info.Dirt or {}) do
		dirt[i] = WASH.Dirt[d] and d or "Mud"
	end
	local w = {
		id = info.Id, bay = tonumber(info.Bay) or 1, spots = tonumber(info.Spots) or 4, seed = tonumber(info.Seed) or 1,
		owner = info.Owner, stage = "arrive", readyClock = os.clock() + (tonumber(info.Ready) or WASH.ArriveTime),
		dirt = dirt, special = WASH.Specials[info.Special or ""] and info.Special or nil, name = info.Name,
		streak = tonumber(info.Streak) or 0,
	}
	S.wash = w
	S.job = S.job and S.job.id == w.id and S.job or { kind = "Wash", id = w.id, earned = 0 }
	S.job.kind = "Wash"
	S.job.owner = info.Owner
	S.job.stage = nil
	ui.afterSub.Text = ""
	Job.reportClose()
	local inBay, mouth = Wash.spots(w)
	if not inBay then
		return
	end
	if fresh and not S.toldWash then
		S.toldWash = true
		NotifyController.Show("Wash: let go of SPRAY and RINSE in the GREEN for PERFECT. Two PERFECTs and a quick scrub = ★★★: bigger tips, and a streak.",
			nil, "info")
	end
	local sp = w.special and WASH.Specials[w.special]
	if sp then
		NotifyController.Show(string.format("Special customer: a %s! %s.", string.lower(sp.Name), sp.Words), C.Gold, "info")
	end
	local startIn = math.max(0, w.readyClock - os.clock() - WASH.ArriveTime)
	task.delay(startIn, function()
		if S.wash ~= w then
			return
		end
		local car, kind = Wash.buildCar(w.seed, w.special)
		w.kind = kind
		car:PivotTo(mouth)
		car.Parent = Wash.folder()
		w.car = car
		Wash.tag(w)
		Wash.slide(car, mouth, inBay, math.max(0.5, w.readyClock - os.clock()))
		task.delay(math.max(0.5, w.readyClock - os.clock()) + 0.05, function()
			if S.wash ~= w or not car.Parent then
				return
			end
			car:PivotTo(inBay)
			Wash.placeMud(w)
			w.stage = "spray"
			Wash.show()
		end)
	end)
	ui.endJob.Visible = true
	ui.after.Visible = false
	Wash.show()
	Job.place()
end

-- BusinessJob "WashStep": the server's stage (and the taps it counted), the spray's grade, or TOO EARLY.
function Wash.onStep(info)
	local w = S.wash
	if not w or type(info) ~= "table" then
		return
	end
	local stage = info.Stage
	if stage ~= "spray" and stage ~= "scrub" and stage ~= "rinse" then
		return
	end
	if w.holding and w.holding.kind ~= stage then
		w.holding = nil
		Wash.water(w, nil)
	end
	if info.Early then
		Job.pop("TOO EARLY", C.Orange)
		if not w.toldHold then
			w.toldHold = true
			NotifyController.Show("Keep holding until the bar reaches the GREEN, then let go.", nil, "info")
		end
	elseif info.Grade == "Perfect" then
		Job.pop("PERFECT!", K.SWEET)
		sound("Checkpoint")
	elseif info.Grade == "Ok" then
		Job.pop("OK", C.Text)
	end
	if type(info.Taps) == "table" then
		for i, m in ipairs(w.mud or {}) do
			local t = tonumber(info.Taps[i]) or 0
			if t ~= m.taps then
				m.taps = t
				local share = math.min(1, t / m.need)
				m.part.Transparency = math.min(1, share * 0.85 + (t >= m.need and 0.15 or 0))
				m.part.Size = Vector3.new(0.12, m.size0 * (1 - 0.45 * share), m.size0 * (1 - 0.45 * share))
				if m.button then
					local left = m.need - t
					m.button.Text = left > 0 and ((K.DIRT[m.dirt] or K.DIRT.Mud).Word .. " ×" .. left) or "✓"
				end
			end
		end
	end
	if stage == "spray" then
		Wash.foam(w, false)
	elseif stage == "scrub" and w.stage ~= "scrub" then
		Wash.foam(w, true)
	end
	w.stage = stage
	Wash.show()
end

-- BusinessJob "WashPaid": the rinse's grade, the gleam and the ★ rating over the car, the pay counting up, the
-- AFTER panel with the tip's story (the server's numbers: stars, streak, special).
function Wash.onPaid(info)
	local w = S.wash
	if S.job then
		S.job.earned = tonumber(info.Earned) or S.job.earned
	end
	local pay, tip = tonumber(info.Pay) or 0, tonumber(info.Tip) or 0
	if info.Refused then
		-- (the server's MinTime: faster than a human can wash; that car isn't paid, the job goes on)
		if w then
			w.stage = "paid"
			w.streak = 0
		end
		NotifyController.Show("Too fast: that car wasn't paid. Take your time with the next one.", nil, "warning")
		ui.afterTitle.Text = '<font color="#' .. C.Danger:ToHex() .. '">NOT PAID</font>  <font size="14">TOO FAST</font>'
		ui.afterSub.Text = ""
		Wash.show()
		Job.place()
		return
	end
	if info.Grade == "Perfect" then
		Job.pop("PERFECT!", K.SWEET)
		sound("Checkpoint")
	elseif info.Grade == "Ok" then
		Job.pop("OK", C.Text)
	end
	local stars = math.clamp(math.floor(tonumber(info.Stars) or 1), 1, 3)
	local streak = tonumber(info.Streak) or 0
	local mult = tonumber(info.Mult) or 1
	local sp = info.Special and WASH.Specials[info.Special]
	if w then
		w.stage = "paid"
		w.streak = streak
		Wash.foam(w, false)
		Wash.sparkle(w)
		Wash.rating(w, stars, stars == 3 and (streak >= 2 and ("PERFECT WASH · STREAK ×" .. streak) or "PERFECT WASH")
			or (stars == 2 and "GREAT WASH" or "WASHED"))
	end
	sound("CashIn")
	Job.countUp(pay + tip)
	ui.afterTitle.Text = string.format('<font color="#%s">+%s</font>  %s', C.Cash:ToHex(), money(pay + tip), starsText(stars))
	-- The tip's story, in one short line.
	local story = { "tip " .. money(tip) }
	if streak >= 2 then
		table.insert(story, string.format("streak ×%.1f", mult))
	elseif stars < 3 then
		table.insert(story, info.Quick and "PERFECT both holds for ★★★" or "a quicker wash for the ★")
	end
	if sp then
		table.insert(story, 1, sp.Name)
	end
	ui.afterSub.Text = rich(table.concat(story, " · "))
	if tonumber(info.Broke) then
		NotifyController.Show(string.format("Streak over (%d ★★★ in a row). Start a new one!", tonumber(info.Broke)), nil, "info")
	elseif streak >= 2 and mult > 1 then
		NotifyController.Show(string.format("★★★ streak ×%d: tips ×%.1f!", streak, mult), C.Gold, "success")
	end
	Wash.show()
	Job.place()
end

------------------------------------------------------------------ detail delivery (the Car Wash)

-- BusinessJob "Detail": the customer car is yours to deliver (a sports car now and then: the server's roll).
function Detail.onStart(info)
	Card.close()
	Wash.clear(true)
	Job.reportClose()
	ui.hold.Visible = false
	ui.after.Visible = false
	ui.afterSub.Text = ""
	local earned = tonumber(info.Earned) or (S.job and S.job.earned) or 0
	S.job = {
		kind = "Detail", id = info.Id, stage = "drive", pos = typeof(info.Pos) == "Vector3" and info.Pos or nil, name = info.Name,
		car = info.Car, est = tonumber(info.Est), since = os.clock(), earned = earned, sports = info.Sports == true,
		streak = tonumber(info.Streak) or 0, dents = 0, owner = info.Owner,
	}
	if S.job.pos then
		Job.marker(S.job.pos)
		Job.setGPS(tostring(info.Name or "Customer"), S.job.pos)
	end
	ui.endJob.Visible = true
	Job.place()
	if S.job.sports then
		local SP = Businesses.Detail.Sports
		NotifyController.Show(string.format("Handle with care: a %s! Sports cars tip ×%.1f, but every dent costs %s. Drive it to %s.",
			tostring(info.Car or "sports car"), SP.TipMult, money(SP.DentCost), tostring(info.Name or "its owner")), C.Gold, "info")
	else
		NotifyController.Show("Drive the " .. tostring(info.Car or "car") .. " to " .. tostring(info.Name or "its owner")
			.. ". Fast and clean pays the full tip: every dent costs you.", nil, "info")
	end
end

-- BusinessJob "Dent": the counter on the line under the strip turns red and shakes.
function Detail.onDent(info)
	local job = S.job
	local dents = tonumber(info.Dents) or 1
	local cost = Businesses.Detail.DentCost
	if job and job.kind == "Detail" then
		job.dents = dents
		if job.sports then
			cost = Businesses.Detail.Sports.DentCost
		end
	end
	sound("Crash")
	Job.shakeSub()
	NotifyController.Show(string.format("Dent! -%s off the tip (%d so far).", money(cost), dents), C.Orange, "warning")
end

-- BusinessJob "DetailPaid": the customer walks out to meet you, the DELIVERED stamp (no dents, or how many), the
-- rating; then back to the business for the next car (the shift goes on).
function Detail.onPaid(info)
	local job = S.job
	local pay, tip = tonumber(info.Pay) or 0, tonumber(info.Tip) or 0
	local dents = tonumber(info.Dents) or 0
	local stars = math.clamp(math.floor(tonumber(info.Stars) or 1), 1, 3)
	local streak, mult = tonumber(info.Streak) or 0, tonumber(info.Mult) or 1
	local def = defOf(info.Id or (job and job.id))
	if job and job.kind == "Detail" then
		job.stage = "back"
		job.pos = nil
		job.dents = dents
		job.streak = streak
		job.earned = tonumber(info.Earned) or job.earned
	end
	Job.marker(nil)
	if def then
		Job.setGPS(def.Brand or def.Name, typeof(info.Back) == "Vector3" and info.Back or Businesses.DoorPosition(def))
	end
	sound("CashIn")
	Fx.customer(info.Vehicle, info.At)
	local title = dents == 0 and "DELIVERED · NO DENTS" or string.format("DELIVERED · -%d DENT%s", dents, dents == 1 and "" or "S")
	local sub = string.rep("★", stars) .. " · tip " .. money(tip) .. (streak >= 2 and string.format(" · streak ×%.1f", mult) or "")
	HUDController.Stamp(title, sub, dents == 0 and C.Cash or C.Orange, info.Sports and "SPORTS CAR" or "DETAIL", { Cash = pay + tip })
	if tonumber(info.Broke) then
		NotifyController.Show(string.format("No-dent streak over (%d in a row).", tonumber(info.Broke)), nil, "info")
	end
	NotifyController.Show("Tap CAR to call yours, then head back to " .. (def and (def.Brand or def.Name) or "the car wash")
		.. " for the next car (or END JOB).", nil, "info")
end

-- Five times a second between cars after a delivery: back at the business on foot, the AFTER panel (NEXT CAR |
-- DELIVER | END); our GPS back cleared there.
function Detail.backTick()
	local job = S.job
	if not job or job.kind ~= "Detail" or job.stage ~= "back" then
		return
	end
	local def = defOf(job.id)
	local root, hum = myRoot(), myHum()
	local near = def ~= nil and root ~= nil and flat(root.Position - def.Position).Magnitude <= Businesses.Reach - 2
	if near and S.gpsName == (def.Brand or def.Name) then
		Job.clearGPS()
	end
	local show = near and hum ~= nil and hum.SeatPart == nil and not S.card and os.clock() >= (S.afterWait or 0)
	if show and not ui.after.Visible then
		ui.afterTitle.Text = string.format('NEXT CUSTOMER?  <font color="#%s">+%s</font>', C.Cash:ToHex(), money(job.earned or 0))
		ui.afterSub.Text = (job.streak or 0) >= 2 and ("no-dent streak ×" .. job.streak .. " · keep it going") or "this shift so far"
		Job.place()
	end
	ui.after.Visible = show
end

-- The delivery's customer walking out to their car and waving, then the car fading away (this device only: the
-- server takes the car Detail.HandOver seconds after the drop). car = the customer car, at = its chassis CFrame.
function Fx.customer(car, at)
	if typeof(at) ~= "CFrame" then
		return
	end
	local rng = Random.new(math.floor(os.clock() * 1000) % 100000)
	local skin = K.SKINS[rng:NextInteger(1, #K.SKINS)]
	local shirt = K.SHIRTS[rng:NextInteger(1, #K.SHIRTS)]
	local pants = Color3.fromRGB(40, 44, 56)
	local side = at.RightVector * -1 -- (the driver's side)
	local from = at.Position + side * 10
	local to = at.Position + side * 3.6
	-- The ground under them (the car and you are left out).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { car, player.Character, Wash.folder() }
	local hit = Workspace:Raycast(from + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), params)
	local ground = hit and hit.Position.Y or (at.Position.Y - 2.5)
	local m = Instance.new("Model")
	m.Name = "BizCustomer"
	local function part(name, size, offset, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, true
		p.Size = size
		p.CFrame = CFrame.new(offset)
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = m
		return p
	end
	part("LegL", Vector3.new(0.9, 2, 0.9), Vector3.new(-0.5, 1, 0), pants)
	part("LegR", Vector3.new(0.9, 2, 0.9), Vector3.new(0.5, 1, 0), pants)
	part("Body", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0), shirt)
	part("ArmL", Vector3.new(0.8, 2, 0.8), Vector3.new(-1.4, 3, 0), skin)
	local arm = part("ArmR", Vector3.new(0.8, 2, 0.8), Vector3.new(1.4, 3, 0), skin)
	part("Head", Vector3.new(1.1, 1.1, 1.1), Vector3.new(0, 4.6, 0), skin)
	m.WorldPivot = CFrame.new()
	m.Parent = Wash.folder()
	local walkFrom = CFrame.lookAt(Vector3.new(from.X, ground, from.Z), Vector3.new(to.X, ground, to.Z))
	local walkTo = CFrame.lookAt(Vector3.new(to.X, ground, to.Z), Vector3.new(at.Position.X, ground, at.Position.Z))
	Wash.slide(m, walkFrom, walkTo, K.HANDOVER_WALK)
	task.delay(K.HANDOVER_WALK + 0.05, function()
		if not m.Parent then
			return
		end
		-- A wave: the right arm swings up over the shoulder.
		local shoulder = arm.CFrame * CFrame.new(0, 1, 0)
		local up = shoulder * CFrame.Angles(0, 0, math.rad(150)) * CFrame.new(0, -1, 0)
		TweenService:Create(arm, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 1, true), { CFrame = up }):Play()
	end)
	local fadeAt = math.max(0.5, Businesses.Detail.HandOver - 0.6)
	task.delay(fadeAt, function()
		local list = {}
		for _, d in ipairs(m:GetDescendants()) do
			table.insert(list, d)
		end
		if typeof(car) == "Instance" and car.Parent then
			for _, d in ipairs(car:GetDescendants()) do
				table.insert(list, d)
			end
		end
		for _, d in ipairs(list) do
			if d:IsA("BasePart") and d.Transparency < 1 then
				TweenService:Create(d, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end
		task.delay(0.6, function()
			m:Destroy()
		end)
	end)
end

------------------------------------------------------------------ rush orders (Palm Grind)

-- The HOLD button belongs to whichever job is on: the wash's SPRAY / RINSE, or the rush orders' GRAB.
function Job.holdBegin(pointer)
	if S.wash then
		Wash.startHold(pointer)
	elseif S.job and S.job.kind == "Print" then
		Print.startHold(pointer)
	else
		Rush.startHold(pointer)
	end
end

function Job.holdEnd(done)
	if S.wash and S.wash.holding then
		Wash.endHold(done)
	elseif S.job and S.job.kind == "Rush" and S.job.holding then
		Rush.endHold(done)
	elseif S.job and S.job.kind == "Print" and S.job.holding then
		Print.endHold(done)
	end
end

-- The hold that's on now (the wash's, the rush job's or the Print Shop's), or nil.
function Job.holding()
	return (S.wash and S.wash.holding) or (S.job and (S.job.kind == "Rush" or S.job.kind == "Print") and S.job.holding) or nil
end

-- In the driver's seat of your own land car (the rush job's rule, as the server's)?
function Rush.inOwnCar()
	local hum = myHum()
	local seat = hum and hum.SeatPart
	-- (the car or nil: a passenger seat gave false, and car:GetAttribute errored)
	local car = (seat and seat.Name == "DriverSeat" and seat.Parent) or nil
	return car ~= nil and car:GetAttribute("OwnerUserId") == player.UserId and car:GetAttribute("Boat") ~= true
end

-- Waiting for an order, on foot, at the RUSH ORDERS shelf: the GRAB hold can show.
function Rush.canGrab()
	local job = S.job
	if not job or job.kind ~= "Rush" or job.stage ~= "pickup" or (job.waitUntil and os.clock() < job.waitUntil) then
		return false -- (waitUntil: a full GRAB was just sent; the order is on its way)
	end
	if S.alarm[job.id] then
		return false -- (robbers at the counter: the gun comes first, and the HOLD would count as a panel and lower it)
	end
	local def = defOf(job.id)
	local root, hum = myRoot(), myHum()
	if not def or not def.Layout.Orders or not root or not hum or hum.SeatPart or hum.Health <= 0 then
		return false
	end
	local spot = Businesses.At(def, def.Layout.Orders)
	return flat(root.Position - spot).Magnitude <= K.GRAB_RANGE and math.abs(root.Position.Y - spot.Y) < 12
end

-- The HOLD button for GRAB (shown at the shelf, and for as long as a hold is on).
function Rush.show()
	local job = S.job
	if job ~= nil and job.kind == "Print" then
		Print.show() -- (the Print Shop's HOLD: its stations and the cash cart)
		return
	end
	if ui.holdBand then
		ui.holdBand.Visible = false
	end
	local show = Rush.canGrab() or (job ~= nil and job.kind == "Rush" and job.holding ~= nil)
	ui.hold.Visible = show == true
	if show and not job.holding then
		ui.holdFill.Size = UDim2.fromScale(0, 1)
		ui.holdFill.BackgroundColor3 = K.BREW
		ui.holdText.Text = "HOLD TO GRAB THE ORDER"
	end
end

-- pointer: the mouse or touch InputObject holding it (nil: a key).
function Rush.startHold(pointer)
	local job = S.job
	if not job or job.kind ~= "Rush" or job.holding or not Rush.canGrab() then
		return
	end
	job.holding = { at = os.clock(), pointer = pointer }
	ui.holdFill.BackgroundColor3 = K.BREW
	request("Step", "GrabOn")
	sound("Click")
end

-- Let go: early (the server says "RushStep" Again) or at the end of the hold (done = true).
function Rush.endHold(done)
	local job = S.job
	local h = job and job.holding
	if not h then
		return
	end
	job.holding = nil
	request("Step", "GrabOff")
	ui.holdFill.Size = UDim2.fromScale(0, 1)
	if done then
		job.waitUntil = os.clock() + 1.5
		sound("Success")
	elseif not job.toldHold then
		job.toldHold = true
		NotifyController.Show("Hold it until the bar is full to grab the order.", nil, "info")
	end
	Rush.show()
end

-- Every frame while GRAB is held: the bar, and letting go by itself when it's full.
function Rush.step()
	local job = S.job
	local h = job and job.kind == "Rush" and job.holding
	if not h then
		return
	end
	local share = (os.clock() - h.at) / (Businesses.Rush.GrabHold + K.HOLD_EXTRA)
	ui.holdFill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
	if share >= 1 then
		Rush.endHold(true)
	end
end

-- Five times a second while on rush orders: the HOLD button, and our GPS back to the café cleared on arrival.
function Rush.tick()
	local job = S.job
	if not job or job.kind ~= "Rush" then
		return
	end
	if not S.wash then
		Rush.show()
	end
	local def = defOf(job.id)
	local root = myRoot()
	if job.stage == "pickup" and def and root and S.gpsName == (def.Brand or def.Name)
		and flat(root.Position - def.Position).Magnitude <= Businesses.Reach then
		Job.clearGPS()
	end
end

-- The strip: tag, what to do, and the right-hand words (the clock, and the tip it would pay now on a PC).
function Rush.line(touch)
	local job = S.job
	local def = defOf(job.id)
	if job.stage ~= "drive" or not job.pos then
		job.late = false
		local root = myRoot()
		local right = (job.earned or 0) > 0 and money(job.earned) or ""
		if root and def and flat(root.Position - def.Position).Magnitude <= Businesses.Reach then
			-- (short enough for the PC strip: the longer "GRAB AN ORDER AT THE RUSH ORDERS SHELF" was cut off)
			return "RUSH ORDER", Rush.canGrab() and "HOLD TO GRAB THE ORDER" or "STAND ON THE YELLOW PICK-UP MAT", right
		end
		local dist = (root and def) and GPSClient.FormatDistance(flat(root.Position - Businesses.DoorPosition(def)).Magnitude) or ""
		-- ("BACK TO PALM GRIND FOR THE NEXT ORDER" was 37 letters: the strip keeps K.STRIP_MAX)
		return "RUSH ORDER", fit({ "BACK TO " .. string.upper(def and (def.Brand or def.Name) or "THE CAFÉ"), { "NEXT ORDER" } }), dist
	end
	local left = (job.endsAt or serverNow()) - serverNow()
	job.late = left <= 0
	-- "PROFESSOR LANE · ICED LATTE" (the cup is drawn at the strip's left); a VIP: "VIP · STELLA STARR · MOCHA".
	-- Kept to K.STRIP_MAX letters: the drink goes first when it's too long (the stops are on the line under it).
	local who = job.vip and ("VIP · " .. string.upper(tostring(job.who or "A VIP"))) or string.upper(tostring(job.name or "THE CUSTOMER"))
	local title = fit({ who, { string.upper(tostring(job.drink or "")) } })
	if not Rush.inOwnCar() then
		title = fit({ "GET IN YOUR CAR", { who } })
	end
	if job.late then
		return "RUSH ORDER", title, "LATE"
	end
	-- (the tip it would pay now: the server's own maths, its streak and rush hour included)
	local tip = def and Businesses.RushTip(def, job.level or 1, (job.timer or 0) - left, job.timer or 1, job.vip, job.streak,
		Job.rushHourUntil(job) ~= nil) or 0
	return "RUSH ORDER", title, touch and clock(left) or (money(tip) .. "  " .. clock(left))
end

-- BusinessJob "Rush": at the counter (a new job, or back from an order).
function Rush.onStart(info)
	Card.close()
	Wash.clear(true)
	ui.after.Visible = false
	local old = S.job
	local fresh = not old or old.kind ~= "Rush" or old.id ~= info.Id
	S.job = { kind = "Rush", id = info.Id, stage = "pickup", level = tonumber(info.Level) or 1, earned = tonumber(info.Earned) or 0,
		count = tonumber(info.Count) or 0, toldHold = not fresh and old.toldHold or nil, owner = info.Owner,
		streak = tonumber(info.Streak) or 0 }
	if fresh then
		Job.reportClose()
	end
	Job.marker(nil)
	local def = defOf(info.Id)
	if info.Back and def then
		Job.setGPS(def.Brand or def.Name, Businesses.DoorPosition(def))
	end
	if fresh then
		NotifyController.Show("Rush orders: hold GRAB at the RUSH ORDERS shelf, then drive the order over in your own car. The faster you get there, the bigger the tip.",
			nil, "info")
	end
	ui.endJob.Visible = true
	Rush.show()
	Job.place()
end

-- BusinessJob "RushStep": the GRAB didn't count (let go early, or not at the shelf).
function Rush.onStep(info)
	local job = S.job
	if not job or job.kind ~= "Rush" then
		return
	end
	job.holding, job.waitUntil = nil, nil
	ui.holdFill.Size = UDim2.fromScale(0, 1)
	if info.Far then
		NotifyController.Show("Stand at the RUSH ORDERS shelf (the yellow mat) to grab an order.", nil, "info")
	elseif not job.toldHold then
		job.toldHold = true
		NotifyController.Show("Hold it until the bar is full to grab the order.", nil, "info")
	end
	Rush.show()
end

-- BusinessJob "RushLeg": the next address (the order's first one says what the order is).
function Rush.onLeg(info)
	local job = S.job
	if not job or job.kind ~= "Rush" then
		job = { kind = "Rush", id = info.Id, earned = 0, count = 0 }
		S.job = job
	end
	Card.close()
	job.holding = nil
	job.stage = "drive"
	job.pos = typeof(info.Pos) == "Vector3" and info.Pos or nil
	job.name, job.who, job.vip, job.drink = info.Name, info.Who, info.Vip == true, info.Drink
	job.owner = info.Owner or job.owner
	job.streak = tonumber(info.Streak) or job.streak or 0
	job.leg, job.of = tonumber(info.Leg) or 1, tonumber(info.Of) or 1
	job.timer = tonumber(info.Timer) or 30
	job.endsAt = tonumber(info.Ends) or (serverNow() + job.timer)
	job.level = tonumber(info.Level) or job.level or 1
	job.earned = tonumber(info.Earned) or job.earned
	ui.hold.Visible = false
	ui.endJob.Visible = true
	if job.pos then
		Job.marker(job.pos)
		Job.setGPS(tostring(info.Name or "Customer"), job.pos)
	end
	local where = job.vip and (tostring(info.Who or "a VIP") .. " at " .. tostring(info.Name or "a big home")) or tostring(info.Name or "the customer")
	if info.First then
		sound("Success")
		local more = job.of > 1 and string.format(" (then %d more stop%s)", job.of - 1, job.of > 2 and "s" or "") or ""
		local what = job.drink and (tostring(job.drink) .. " for ") or "take it to "
		NotifyController.Show(string.format("Order up: %s%s%s. Get in your car: the clock is running (%s). GOLD = the full tip.", what, where, more,
			clock(job.timer)), C.Gold, "info")
	elseif job.vip then
		NotifyController.Show("Last stop: a VIP order for " .. where .. ". VIPs tip big!", C.Gold, "info")
	end
	Job.place()
end

-- BusinessJob "RushPaid": one address delivered. Its MEDAL (the server's) as a stamp and a coffee cup popping up at
-- the door (a ding for a GOLD); after the order's last stop: PERFECT RUN (every stop GOLD: the bonus), VIP DELIVERED
-- (with confetti), or the medal and ORDER DELIVERED.
function Rush.onPaid(info)
	local job = S.job
	local pay, tip, bonus = tonumber(info.Pay) or 0, tonumber(info.Tip) or 0, tonumber(info.Bonus) or 0
	local medal = K.MEDAL[info.Medal or ""] and info.Medal or "Silver"
	local streak, mult = tonumber(info.Streak) or 0, tonumber(info.Mult) or 1
	if job and job.kind == "Rush" then
		job.earned = tonumber(info.Earned) or job.earned
		job.count = tonumber(info.Count) or job.count
		job.streak = streak
	end
	sound("CashIn")
	if medal == "Gold" then
		sound("Checkpoint") -- (the medal ding)
	end
	local pos = typeof(info.Pos) == "Vector3" and info.Pos or (job and job.pos)
	if pos then
		Fx.cupPop(pos, medal)
	end
	local name = info.Vip and tostring(info.Who or "the VIP") or tostring(info.Name or "the customer")
	local extra = (info.RushHour and " · RUSH HOUR" or "") .. (streak >= 2 and string.format(" · streak ×%.1f", mult) or "")
	local stops, leg = tonumber(info.Of) or 1, tonumber(info.Leg) or 1
	if info.Last then
		Job.marker(nil)
		local order = tonumber(info.Order) or (pay + tip + bonus)
		if info.Vip then
			Fx.confetti(pos)
			HUDController.Stamp("VIP DELIVERED", (bonus > 0 and "PERFECT RUN · " or (string.upper(medal) .. " · ")) .. name .. extra, K.MEDAL.Gold,
				"RUSH ORDER", { Cash = order })
		elseif bonus > 0 then
			HUDController.Stamp("PERFECT RUN", string.format("All %d stops GOLD · bonus %s%s", stops, money(bonus), extra), K.MEDAL.Gold, "RUSH ORDER",
				{ Cash = order })
		else
			HUDController.Stamp(string.upper(medal), string.format("Order delivered · %s · %d stop%s%s", money(order), stops, stops == 1 and "" or "s", extra),
				K.MEDAL[medal], "RUSH ORDER")
		end
	else
		HUDController.Stamp(string.upper(medal), name .. " · +" .. money(pay + tip) .. extra, K.MEDAL[medal], string.format("RUSH ORDER · %d/%d", leg, stops))
	end
	if info.Late then
		NotifyController.Show("Late: the base pay only (no tip). Faster next time for GOLD!", nil, "info")
	end
	if tonumber(info.Broke) then
		NotifyController.Show(string.format("Gold streak over (%d in a row).", tonumber(info.Broke)), nil, "info")
	end
end

-- A coffee cup popping up over a rush order's door, in its medal's colour (a BillboardGui on a part under the
-- camera; gone in 1.4 s).
function Fx.cupPop(pos, medal)
	local p = Instance.new("Part")
	p.Name = "BizCupPop"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0))
	p.Parent = Workspace.CurrentCamera
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 64)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 200
	gui.Parent = p
	local cup = ui.cup:Clone()
	cup.Visible = true
	cup.AnchorPoint = Vector2.new(0.5, 0)
	cup.Position = UDim2.fromScale(0.5, 0)
	cup.Size = UDim2.fromOffset(20, 20)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = cup
	local color = K.MEDAL[medal] or K.MEDAL.Silver
	cup.Body.BackgroundColor3 = color
	local ring = cup.Handle:FindFirstChildOfClass("UIStroke")
	if ring then
		ring.Color = color
	end
	cup.Parent = gui
	local word = label(gui, "Medal", 18, "Display")
	word.Position = UDim2.fromOffset(0, 40)
	word.Size = UDim2.new(1, 0, 0, 22)
	word.TextXAlignment = Enum.TextXAlignment.Center
	word.TextColor3 = color
	word.Text = string.upper(medal or "")
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.8 }):Play()
	TweenService:Create(gui, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 3, 0) }):Play()
	task.delay(1.4, function()
		p:Destroy()
	end)
end

-- One burst of confetti (a VIP delivered): K.CONFETTI coloured flakes, one emitter, gone in 2.5 s.
function Fx.confetti(pos)
	if typeof(pos) ~= "Vector3" then
		return
	end
	local p = Instance.new("Part")
	p.Name = "BizConfetti"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency = 1
	p.Size = Vector3.new(2, 1, 2)
	p.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
	p.Parent = Workspace.CurrentCamera
	local keys = {}
	for i, c in ipairs(K.CONFETTI_COLORS) do
		keys[i] = ColorSequenceKeypoint.new((i - 1) / math.max(1, #K.CONFETTI_COLORS - 1), c)
	end
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(keys)
	e.Size = NumberSequence.new(0.35)
	e.Lifetime = NumberRange.new(1.4, 2.2)
	e.Speed = NumberRange.new(18, 26)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Drag = 1.2
	e.RotSpeed = NumberRange.new(-300, 300)
	e.Rotation = NumberRange.new(0, 360)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = 0
	e.Parent = p
	e:Emit(K.CONFETTI) -- (the VIP DELIVERED stamp plays the reward sting)
	task.delay(2.5, function()
		p:Destroy()
	end)
end

------------------------------------------------------------------ the Print Shop (M3): PRINT, LAUNDER, the raids

-- Its own screen pieces (built once): the gauge's green band in the HOLD button and the grade pop over it (the
-- wash's SPRAY / RINSE gauges use them too: Job.band, Job.drawGauge, Job.pop), the heat meter under the strip, the
-- count-up of laundered cash (every job's: Job.countUp). (Its end-of-shift summary became every job's shift report.)
function Print.build()
	local band = Instance.new("Frame")
	band.Name = "Sweet"
	band.BackgroundColor3 = K.SWEET
	band.BackgroundTransparency = 0.45
	band.BorderSizePixel = 0
	band.ZIndex = 2
	band.Visible = false
	band.Parent = ui.hold
	ui.holdBand = band
	local grade = label(ui.gui, "Grade", 26, "Display")
	grade.TextXAlignment = Enum.TextXAlignment.Center
	grade.AnchorPoint = Vector2.new(0.5, 1)
	grade.Size = UDim2.fromOffset(280, 34)
	grade.Visible = false
	ui.grade = grade
	local heat = Instance.new("Frame")
	heat.Name = "Heat"
	heat.BackgroundTransparency = 1
	heat.Visible = false
	heat.Parent = ui.gui
	ui.heat = heat
	ui.heatWord = label(heat, "Word", 12, "Bold")
	ui.heatWord.Size = UDim2.new(0, 64, 1, 0)
	ui.heatWord.Text = "HEAT"
	ui.heatBar, ui.heatFill = Theme.Bar(heat, C.Gold)
	ui.heatBar.AnchorPoint = Vector2.new(0, 0.5)
	ui.heatBar.Position = UDim2.new(0, 64, 0.5, 0)
	ui.heatBar.Size = UDim2.new(1, -64, 0, 8)
	local count = label(ui.gui, "CountUp", 44, "Display")
	count.TextXAlignment = Enum.TextXAlignment.Center
	count.AnchorPoint = Vector2.new(0.5, 0.5)
	count.Position = UDim2.fromScale(0.5, 0.6)
	count.Size = UDim2.fromOffset(420, 56)
	count.TextColor3 = C.Cash
	count.Visible = false
	ui.count = count
end

-- Where its pieces sit (with Job.place).
function Print.place(touch)
	if ui.heat == nil then
		return
	end
	Print.placeNow(touch)
end

function Print.placeNow(touch)
	local s, p = ui.strip.AbsoluteSize, ui.strip.AbsolutePosition
	ui.heat.Position = UDim2.fromOffset(p.X + 12, p.Y + s.Y + 4)
	ui.heat.Size = UDim2.fromOffset(math.max(160, s.X - 24), 14)
	-- The grade pop: centred just above the HOLD button (the gui ignores the inset, so screen pixels line up).
	local hp, hs = ui.hold.AbsolutePosition, ui.hold.AbsoluteSize
	ui.grade.Position = UDim2.fromOffset(hp.X + hs.X / 2, hp.Y - 6)
	-- The count-up: a little higher on a phone, clear of the AFTER panel at the bottom.
	ui.count.Position = UDim2.fromScale(0.5, touch and 0.56 or 0.6)
end

local function printJob()
	local job = S.job
	return (job ~= nil and job.kind == "Print") and job or nil
end

-- Is the local player one the server would send to this raid as a cop (BizRaids entry)?
function Print.copFor(r)
	if type(r) ~= "table" or r.o == player.UserId then
		return false
	end
	local cop = player:GetAttribute("Side") == "Cop" or (RunService:IsStudio() and Workspace:GetAttribute("BizTestCop") == player.Name)
	if not cop then
		return false
	end
	return not isCrewmate(Players:GetPlayerByUserId(tonumber(r.o) or 0))
end

-- My role in the raid at this business: "Owner" | "Crew" | "Cop" | nil.
function Print.roleIn(id)
	local r = S.raids[id]
	if type(r) ~= "table" then
		return nil, nil
	end
	if r.o == player.UserId then
		return "Owner", r
	end
	local owner = Players:GetPlayerByUserId(tonumber(r.o) or 0)
	if owner and isCrewmate(owner) then
		return "Crew", r
	end
	if Print.copFor(r) then
		return "Cop", r
	end
	return nil, r
end

-- The dirty cash this device should show at the shop: the shift's owner's, else your own (BusinessState).
function Print.stock(id)
	local job = printJob()
	if job and job.id == id then
		return job.dirty or 0, job.stock or 1
	end
	local e = mine(id)
	if e then
		return tonumber(e.Dirty) or 0, tonumber(e.Stock) or 1
	end
	return 0, 1
end

-- Your own land car (Workspace.Vehicles, OwnerUserId yours, not a boat) standing in the loading bay?
function Print.carInBay(def)
	local vehicles = Workspace:FindFirstChild("Vehicles")
	local bay = Businesses.At(def, def.Layout.Bay)
	for _, car in ipairs(vehicles and vehicles:GetChildren() or {}) do
		local chassis = car:IsA("Model") and car.PrimaryPart
		if chassis and car:GetAttribute("OwnerUserId") == player.UserId and car:GetAttribute("Boat") ~= true
			and flat(chassis.Position - bay).Magnitude <= Businesses.Launder.BayRange - 1 then
			return true
		end
	end
	return false
end

-- What the HOLD button would do here now: "load" (the cash cart, with stock), "station" (the next one), or nil.
function Print.canHold()
	local job = printJob()
	if not job or job.stage ~= "shop" or (job.waitUntil and os.clock() < job.waitUntil) then
		return nil
	end
	local def = defOf(job.id)
	local root, hum = myRoot(), myHum()
	if not def or not root or not hum or hum.SeatPart or hum.Health <= 0 then
		return nil
	end
	local role, r = Print.roleIn(job.id)
	if r and (role == "Owner" or role == "Crew") and r.s == "search" then
		return nil -- (cops at the presses: the gun comes first, and the HOLD would count as a panel and lower it)
	end
	local function near(spot, range)
		local at = Businesses.At(def, spot)
		return flat(root.Position - at).Magnitude <= range and math.abs(root.Position.Y - at.Y) < 12
	end
	if near(def.Layout.Load, K.LOAD_SHOW) and (job.dirty or 0) >= 1 then
		return "load"
	end
	if near(def.Layout.Stations[job.station or 1], K.STATION_SHOW) then
		return "station"
	end
	return nil
end

-- The HOLD button for the shift (its words, the gauge's green band).
function Print.show()
	local job = printJob()
	if not job then
		if ui.holdBand then
			ui.holdBand.Visible = false
		end
		return
	end
	local what = (job.holding and job.holding.kind) or Print.canHold()
	ui.hold.Visible = what ~= nil
	if not what then
		ui.holdBand.Visible = false
		return
	end
	if job.holding then
		return -- (Print.step draws it while held)
	end
	ui.holdFill.Size = UDim2.fromScale(0, 1)
	if what == "load" then
		ui.holdBand.Visible = false
		ui.holdFill.BackgroundColor3 = C.Cash
		ui.holdText.Text = "HOLD TO LOAD THE BAGS"
		return
	end
	local st = Businesses.Print.Stations[job.station or 1]
	Job.band(st)
	ui.holdText.Text = st.Name
end

-- A timing gauge in the HOLD button (the Print Shop's stations, the wash's SPRAY / RINSE): its green band drawn
-- in, the fill empty and grey. gauge = { Min, Sweet = { from, to }, Full }; nil hides the band.
function Job.band(gauge)
	if not gauge then
		ui.holdBand.Visible = false
		return
	end
	ui.holdBand.Visible = true
	ui.holdBand.Position = UDim2.fromScale(gauge.Sweet[1] / gauge.Full, 0)
	ui.holdBand.Size = UDim2.fromScale((gauge.Sweet[2] - gauge.Sweet[1]) / gauge.Full, 1)
	ui.holdFill.Size = UDim2.fromScale(0, 1)
	ui.holdFill.BackgroundColor3 = K.INK
end

-- The gauge after `t` seconds held: the fill (green inside the band, orange past it). Returns true once full.
function Job.drawGauge(t, gauge)
	ui.holdFill.Size = UDim2.fromScale(math.clamp(t / gauge.Full, 0, 1), 1)
	local inBand = t >= gauge.Sweet[1] and t <= gauge.Sweet[2]
	ui.holdFill.BackgroundColor3 = inBand and K.SWEET or (t > gauge.Sweet[2] and C.Orange or K.INK)
	return t >= gauge.Full
end

function Print.startHold(pointer)
	local job = printJob()
	local what = job and not job.holding and Print.canHold()
	if not what then
		return
	end
	job.holding = { at = os.clock(), pointer = pointer, kind = what, station = job.station }
	request("Step", "HoldOn")
	sound("Click")
end

function Print.endHold(auto)
	local job = printJob()
	local h = job and job.holding
	if not h then
		return
	end
	job.holding = nil
	request("Step", "HoldOff")
	job.waitUntil = os.clock() + (h.kind == "load" and 1.5 or 0.35) -- (the server's verdict is on its way)
	if h.kind == "load" and not auto then
		ui.holdFill.Size = UDim2.fromScale(0, 1)
	end
	Print.show()
end

-- Every frame while held: the gauge (green while inside the band), letting go by itself when it's full.
function Print.step()
	local job = printJob()
	local h = job and job.holding
	if not h then
		return
	end
	local t = os.clock() - h.at
	if h.kind == "load" then
		local share = t / (Businesses.Launder.LoadHold + K.HOLD_EXTRA)
		ui.holdFill.Size = UDim2.fromScale(math.clamp(share, 0, 1), 1)
		if share >= 1 then
			Print.endHold(true)
		end
		return
	end
	local st = Businesses.Print.Stations[h.station or 1]
	if Job.drawGauge(t, st) then
		Print.endHold(true) -- (full: it lets go by itself, an OK)
	end
end

-- A quick word over the HOLD button: PERFECT! / OK / TOO EARLY (every job's gauge: Print.pop is the same).
function Job.pop(text, color)
	local g = ui.grade
	g.Text = text
	g.TextColor3 = color
	g.TextTransparency = 0
	g.Visible = true
	S.popToken = (S.popToken or 0) + 1
	local token = S.popToken
	task.delay(0.9, function()
		if S.popToken == token then
			TweenService:Create(g, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end
	end)
end
Print.pop = Job.pop

-- This device's effects at the shop (a folder under the camera: nothing replicates, parts are capped).
function Print.fxFolder()
	local cam = Workspace.CurrentCamera
	local f = cam:FindFirstChild("BizPrintFx")
	if not f then
		f = Instance.new("Folder")
		f.Name = "BizPrintFx"
		f.Parent = cam
	end
	return f
end

-- The press's out tray: sheets flutter out of it (a few particles), the "+$X DIRTY" pop rises over it.
function Print.tray(def)
	local f = Print.fxFolder()
	local p = f:FindFirstChild("Tray")
	if not p then
		p = Instance.new("Part")
		p.Name = "Tray"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Transparency = 1
		p.Size = Vector3.new(3, 0.4, 1)
		p.Parent = f
		local e = Instance.new("ParticleEmitter")
		e.Name = "Sheets"
		e.Rate = 0
		e.Color = ColorSequence.new(K.BILL, Color3.fromRGB(240, 240, 228))
		e.Size = NumberSequence.new(0.42)
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(4, 8)
		e.SpreadAngle = Vector2.new(35, 35)
		e.Acceleration = Vector3.new(0, -14, 0)
		e.Drag = 1.5
		e.RotSpeed = NumberRange.new(-200, 200)
		e.Rotation = NumberRange.new(0, 360)
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = p
	end
	p.CFrame = CFrame.new(Businesses.At(def, def.Layout.Tray) + Vector3.new(0, 3.6, 0))
	return p
end

function Print.flutter(def, n)
	local tray = Print.tray(def)
	local e = tray:FindFirstChild("Sheets")
	if e then
		e:Emit(n)
	end
end

function Print.dirtyPop(def, amount)
	local tray = Print.tray(def)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Parent = tray
	local l = label(gui, "Pop", 26, "Display")
	l.Size = UDim2.fromScale(1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextColor3 = K.BILL
	l.Text = "+" .. money(amount) .. " DIRTY"
	TweenService:Create(gui, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.9), { TextTransparency = 1 }):Play()
	task.delay(1.5, function()
		gui:Destroy()
	end)
end

-- The fake bills on the counting table: up to K.CASH_MAX bundles, as full as the stock (this device only).
function Print.cash()
	local def = defOf("PrintShop")
	if not def or not def.Enabled or not def.Layout.Cash then
		return
	end
	local root = myRoot()
	local dirty, stock = Print.stock(def.Id)
	local near = root ~= nil and flat(root.Position - def.Position).Magnitude <= K.CASH_RANGE
	local want = near and dirty > 0 and math.clamp(math.ceil(K.CASH_MAX * dirty / math.max(stock, 1)), 1, K.CASH_MAX) or 0
	if want == S.cashShown then
		return
	end
	S.cashShown = want
	local f = Print.fxFolder()
	local old = f:FindFirstChild("Cash")
	if old then
		old:Destroy()
	end
	if want <= 0 then
		return
	end
	local m = Instance.new("Folder")
	m.Name = "Cash"
	m.Parent = f
	local frame = Businesses.Frame(def) * CFrame.new(def.Layout.Cash)
	for i = 0, want - 1 do
		local col, row, layer = i % 3, math.floor(i / 3) % 2, math.floor(i / 6)
		local p = Instance.new("Part")
		p.Name = "Bundle"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size = Vector3.new(0.95, 0.38, 0.5)
		p.Color = K.BILL
		p.Material = Enum.Material.SmoothPlastic
		p.CFrame = frame * CFrame.new(-1.05 + col * 1.05, 3.1 + layer * 0.4, -0.35 + row * 0.7) * CFrame.Angles(0, math.rad((i * 37) % 9 - 4), 0)
		p.Parent = m
	end
end

-- The shift's strip: tag, what to do, the right-hand words.
function Print.line(touch)
	local job = S.job
	local def = defOf(job.id)
	local root = myRoot()
	if not def then
		return "PRINT", "", ""
	end
	-- A raid on this shop's owner comes first (you're their crew or them).
	local role, r = Print.roleIn(job.id)
	if (role == "Owner" or role == "Crew") and r then
		return Print.raidLine(def, role, r, touch)
	end
	if job.stage == "drive" then
		local hum = myHum()
		local seat = hum and hum.SeatPart
		local inCar = seat ~= nil and seat.Name == "DriverSeat"
		if not inCar then
			local left = math.max(0, (job.outAt or os.clock()) + (job.grace or 20) - os.clock())
			return "LAUNDER", "GET BACK IN YOUR CAR", clock(left)
		end
		local dist = (root and job.pos) and GPSClient.FormatDistance(flat(root.Position - job.pos).Magnitude) or ""
		return "LAUNDER", "DROP AT " .. string.upper(tostring(job.name or "THE DROP")), dist
	end
	if not root or flat(root.Position - def.Position).Magnitude > Businesses.Reach + 6 then
		local dist = root and GPSClient.FormatDistance(flat(root.Position - Businesses.DoorPosition(def)).Magnitude) or ""
		return "PRINT", "BACK TO THE PRINT SHOP", dist
	end
	local right = (job.streak or 0) > 0 and ((touch and "" or "STREAK ") .. string.format("×%.2f", job.mult or 1)) or money(job.dirty or 0)
	if job.holding then
		return job.holding.kind == "load" and "LAUNDER" or "PRINT", job.holding.kind == "load" and "LOADING THE BAGS..." or "LET GO IN THE GREEN!", right
	end
	local dirty = job.dirty or 0
	local wantLoad = dirty >= 1 and (job.mode == "Launder" or dirty >= (job.carry or math.huge) or dirty >= (job.stock or math.huge))
	if wantLoad then
		local cart = Businesses.At(def, def.Layout.Load)
		if not Print.carInBay(def) then
			return "LAUNDER", "PARK YOUR CAR IN THE BAY", money(math.min(dirty, job.carry or dirty))
		elseif flat(root.Position - cart).Magnitude > K.LOAD_SHOW then
			return "LAUNDER", "WALK TO THE CASH CART", GPSClient.FormatDistance(flat(root.Position - cart).Magnitude)
		end
		return "LAUNDER", "HOLD TO LOAD THE BAGS", money(math.min(dirty, job.carry or dirty))
	end
	local st = Businesses.Print.Stations[job.station or 1]
	local spot = Businesses.At(def, def.Layout.Stations[job.station or 1])
	local d = flat(root.Position - spot).Magnitude
	if d > K.STATION_SHOW then
		return "PRINT", "WALK TO THE " .. st.Where, touch and right or GPSClient.FormatDistance(d)
	end
	return "PRINT", "HOLD · LET GO IN THE GREEN", right
end

-- The words a raid uses for this building (M5: the Nightclub's back room as well as the Print Shop).
function Print.raidWords(def)
	if def and def.BackRoom then
		return { place = "THE AFTERGLOW", door = "THE BACK-ROOM DOOR", search = "THE SAFE", whose = "Afterglow back room", stamp = "BACK ROOM",
			stuff = "dirty cash", out = "WASH the cash out at the safe", searchVerb = "Hold SEARCH at the safe." }
	end
	return { place = "THE PRINT SHOP", door = "THE PRINT SHOP DOOR", search = "THE PRESSES", whose = "Print Shop", stamp = "PRINT SHOP",
		stuff = "fake cash", out = "launder the stock out", searchVerb = "Hold SEARCH at the presses." }
end

-- A raid's strip line for its owner, crew or a cop.
function Print.raidLine(def, role, r, _touch)
	local w = Print.raidWords(def)
	local left = clock((tonumber(r.u) or serverNow()) - serverNow())
	if role == "Cop" then
		if r.ai then
			return "RAID", "AI UNIT ON " .. w.place, left
		end
		return "RAID", r.s == "search" and ("SEARCH " .. w.search) or ("BREACH " .. w.door), left
	end
	local root = myRoot()
	local inside = root ~= nil and Businesses.Inside(def, root.Position)
	if r.s == "search" then
		if r.ai and r.h then
			return "RAID", "HOLDING THEM OFF " .. w.search .. "!", left
		end
		return "RAID", r.ai and ("COPS SEARCHING " .. math.floor((tonumber(r.b) or 0) * 100) .. "%") or "COPS INSIDE: STOP THE SEARCH", left
	end
	if inside then
		return "RAID", "HOLD THE DOOR!", left
	end
	if r.ai and (tonumber(r.b) or 0) > 0 then
		return "RAID", "COPS BREAKING IN " .. math.floor((tonumber(r.b) or 0) * 100) .. "%", left
	end
	return "RAID", role == "Owner" and ("RAID! GET TO " .. (def.BackRoom and "YOUR CLUB" or "YOUR PRINT SHOP")) or "RAID! HELP HOLD THE DOOR", left
end

-- Five times a second during the shift: the HOLD button, the heat meter, our GPS back to the shop cleared there.
function Print.tick()
	local job = printJob()
	if ui.heat then
		local heat = player:GetAttribute("BizHeat")
		local on = job ~= nil and job.stage == "drive" and ui.strip.Visible
		ui.heat.Visible = on
		if on then
			local wanted = (tonumber(player:GetAttribute("Heat")) or 0) > 0
			local v = wanted and 1 or math.clamp(tonumber(heat) or 0, 0, 1)
			ui.heatFill.Size = UDim2.fromScale(math.max(v, 0.02), 1)
			ui.heatFill.BackgroundColor3 = (wanted or v >= 0.75) and C.Danger or (v >= 0.4 and C.Orange or C.Gold)
			ui.heatWord.Text = wanted and "SPOTTED" or "HEAT"
			ui.heatWord.TextColor3 = (wanted or v >= 0.75) and C.Danger or C.Text
		end
	end
	if not job then
		return
	end
	if not S.wash then
		Print.show()
	end
	local def = defOf(job.id)
	local root = myRoot()
	if job.stage == "shop" and def and root and S.gpsName == (def.Brand or def.Name)
		and flat(root.Position - def.Position).Magnitude <= Businesses.Reach then
		Job.clearGPS()
	end
	if job.stage == "drive" then
		local hum = myHum()
		local seat = hum and hum.SeatPart
		if seat and seat.Name == "DriverSeat" then
			job.outAt = nil
		elseif not job.outAt then
			job.outAt = os.clock()
		end
	end
end

-- Count money up on screen, then it fades: the laundered cash, a washed car's pay (every job's: Print.countUp is the
-- same). color: the text's (default cash green).
function Job.countUp(total, color)
	local c = ui.count
	c.Visible = true
	c.TextTransparency = 0
	c.TextColor3 = color or C.Cash
	S.countToken = (S.countToken or 0) + 1
	local token = S.countToken
	local t0 = os.clock()
	task.spawn(function()
		while S.countToken == token do
			local a = math.clamp((os.clock() - t0) / K.COUNT_TIME, 0, 1)
			c.Text = "+" .. money(math.floor(total * (1 - (1 - a) ^ 3)))
			if a >= 1 then
				break
			end
			task.wait()
		end
		task.wait(1.1)
		if S.countToken == token then
			TweenService:Create(c, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.wait(0.45)
			if S.countToken == token then
				c.Visible = false
			end
		end
	end)
end
Print.countUp = Job.countUp

-- BusinessJob "Print": at the shop (a new shift, or back from a run).
function Print.onShop(info)
	Card.close()
	Wash.clear(true)
	ui.after.Visible = false
	local old = S.job
	local fresh = not old or old.kind ~= "Print" or old.id ~= info.Id
	S.job = {
		kind = "Print", id = info.Id, stage = "shop", mode = info.Mode, station = tonumber(info.Station) or 1,
		streak = tonumber(info.Streak) or 0, mult = tonumber(info.Mult) or 1, level = tonumber(info.Level) or 1,
		earned = tonumber(info.Earned) or 0, count = tonumber(info.Count) or 0, dirty = tonumber(info.Dirty) or 0,
		stock = tonumber(info.Stock) or 1, carry = tonumber(info.Carry) or 1, owner = info.Owner,
	}
	Job.marker(nil)
	local def = defOf(info.Id)
	if info.Back and def then
		Job.setGPS(def.Brand or def.Name, Businesses.DoorPosition(def))
	end
	if fresh then
		Job.reportClose()
		NotifyController.Show(info.Mode == "Launder"
			and "Launder: park your own car in the LOADING bay, then hold LOAD at the cash cart and drive the bags to the drop."
			or "Print: walk to each station and hold. Let go in the GREEN for PERFECT: more bills, and a streak.", nil, "info")
	end
	ui.endJob.Visible = true
	Print.show()
	Job.place()
end

-- BusinessJob "PrintStep": a station counted (the grade), or a hold that didn't.
function Print.onStep(info)
	local job = printJob()
	if not job then
		return
	end
	job.holding, job.waitUntil = nil, nil
	ui.holdFill.Size = UDim2.fromScale(0, 1)
	if info.Again then
		if info.Early then
			Print.pop("TOO EARLY", C.Orange)
			job.streak, job.mult = 0, 1
		elseif info.Far then
			local st = Businesses.Print.Stations[tonumber(info.Station) or job.station or 1]
			NotifyController.Show("Stand on the yellow mat at the " .. string.lower(st.Where) .. " (station " .. tostring(info.Station or job.station) .. ").", nil, "info")
		elseif info.Load and not job.toldLoad then
			job.toldLoad = true
			NotifyController.Show("Hold LOAD until the bar is full (your car must be parked in the bay).", nil, "info")
		end
		job.station = tonumber(info.Station) or job.station
		Print.show()
		return
	end
	job.station = tonumber(info.Station) or job.station
	job.streak = tonumber(info.Streak) or 0
	job.mult = tonumber(info.Mult) or 1
	if info.Grade == "Perfect" then
		Print.pop(job.streak >= 2 and string.format("PERFECT! ×%.2f", job.mult) or "PERFECT!", K.SWEET)
		sound("Checkpoint")
	else
		Print.pop("OK", C.Text)
	end
	local def = defOf(job.id)
	if def then
		Print.flutter(def, 3)
	end
	Print.show()
end

-- BusinessJob "Printed": a press run (the ka-chunk, the sheets, the pop, the stack).
function Print.onPrinted(info)
	local job = printJob()
	local def = defOf(job and job.id or "PrintShop")
	if job then
		job.holding, job.waitUntil = nil, nil
		job.station = 1
		job.streak = tonumber(info.Streak) or 0
		job.mult = tonumber(info.Mult) or 1
		job.dirty = tonumber(info.Dirty) or job.dirty
		job.stock = tonumber(info.Stock) or job.stock
		job.count = tonumber(info.Count) or job.count
	end
	if info.Grade == "Perfect" then
		Print.pop(string.format("PERFECT! ×%.2f", tonumber(info.Mult) or 1), K.SWEET)
	else
		Print.pop("OK", C.Text)
	end
	if def then
		sound("Stamp") -- (the press's ka-chunk)
		Print.flutter(def, 16)
		local amount = tonumber(info.Amount) or 0
		if amount > 0 then
			Print.dirtyPop(def, amount)
		end
	end
	if info.Full then
		NotifyController.Show("The back room is full! Load a launder run before you print more.", C.Gold, "money")
	elseif job and (job.dirty or 0) >= (job.carry or math.huge) and not job.toldLoad2 then
		job.toldLoad2 = true
		NotifyController.Show("A full load is ready: park in the LOADING bay and hold LOAD at the cash cart.", C.Gold, "info")
	end
	S.cashShown = nil
	Print.show()
end

-- BusinessJob "Loaded": the bags are in your car; the drop's ring and GPS.
function Print.onLoaded(info)
	local job = printJob()
	if not job then
		job = { kind = "Print", id = info.Id, earned = 0, count = 0, station = 1, streak = 0, mult = 1 }
		S.job = job
	end
	Card.close()
	job.holding = nil
	job.stage = "drive"
	job.bags = tonumber(info.Bags) or 0
	job.pos = typeof(info.Pos) == "Vector3" and info.Pos or nil
	job.name = info.Name
	job.grace = tonumber(info.Grace) or 20
	job.outAt = os.clock()
	job.dirty = tonumber(info.Dirty) or job.dirty
	S.cashShown = nil
	ui.hold.Visible = false
	ui.endJob.Visible = true
	if job.pos then
		Job.marker(job.pos)
		Job.setGPS("Drop: " .. tostring(info.Name or "the drop"), job.pos)
	end
	if not info.Resend then
		sound("Cash")
		NotifyController.Show(string.format("%s of fake cash loaded. Drop it at %s: keep away from the police (watch the HEAT meter).",
			money(job.bags), tostring(info.Name or "the drop")), C.Gold, "money")
	end
	Job.place()
end

-- BusinessJob "Laundered": the count-up, the stamp, the register.
function Print.onLaundered(info)
	local job = printJob()
	local pay, bonus = tonumber(info.Pay) or 0, tonumber(info.Bonus) or 0
	if job then
		job.earned = tonumber(info.Earned) or job.earned
		job.count = tonumber(info.Count) or job.count
		job.bags = 0
	end
	Job.marker(nil)
	sound("CashIn")
	Print.countUp(pay + bonus)
	HUDController.Stamp("LAUNDERED", info.Clean and ("Clean run · bonus " .. money(bonus)) or "Spotted: no clean-run bonus", C.Cash, "PRINT SHOP",
		{ Cash = pay + bonus })
end

-- Raid news (BusinessResult Raid / RaidBreached / RaidSeized / RaidHeld / RaidOver).
function Print.onRaid(info)
	local def = defOf(info.Id)
	if not def then
		return
	end
	local k, role = info.Kind, info.Role
	local w = Print.raidWords(def)
	local whose = role == "Owner" and ("your " .. w.whose) or (tostring(info.OwnerName or "someone") .. "'s " .. w.whose)
	local gpsName = "Raid: " .. (def.Brand or def.Name)
	if k == "Raid" then
		local left = clock((tonumber(info.Until) or serverNow()) - serverNow())
		if info.Switched then
			if role ~= "Cop" then
				NotifyController.Show("No cops took the warrant: an AI unit is on its way to " .. whose .. " instead.", C.Danger, "police")
			end
			return
		end
		sound("Spotted")
		if role == "Cop" then
			NotifyController.Show(string.format("DISPATCH: raid warrant on %s (%s). Breach the door within %s and seize the %s.", whose,
				def.BackRoom and "the boardwalk" or "the Backlot", left, w.stuff), C.Police, "police")
		elseif role == "Owner" then
			NotifyController.Show(string.format("Police are on their way to %s! Hold the door for %s, or %s.", whose, left, w.out),
				C.Danger, "police")
		else
			NotifyController.Show(string.format("Police are raiding %s! Get inside and help hold the door (%s).", whose, left), C.Danger, "police")
		end
		if not S.job or (S.job.kind == "Print" and S.job.stage == "shop" and role ~= "Cop") then
			Job.setGPS(gpsName, Businesses.DoorPosition(def))
		end
	elseif k == "RaidBreached" then
		sound("GateOpen")
		if role == "Cop" then
			NotifyController.Show(info.Ai and "The AI unit broke in." or ("The door's open! " .. w.searchVerb), C.Police, "police")
		else
			NotifyController.Show("The police broke in! Get inside and keep them off " .. string.lower(w.search) .. ".", C.Danger, "police")
		end
	elseif k == "RaidSeized" then
		local amount = money(tonumber(info.Amount) or 0)
		if role == "Cop" then
			HUDController.Stamp("SEIZED " .. amount, "Raid on " .. tostring(info.OwnerName or "the Backlot") .. "'s " .. w.whose, C.Police, "RAID",
				{ Cash = tonumber(info.Reward) or 0 })
		elseif role == "Owner" then
			HUDController.Stamp("RAIDED", "The police seized " .. amount .. " of dirty cash", C.Danger, w.stamp)
		else
			NotifyController.Show("The police seized " .. amount .. " of dirty cash from " .. whose .. ".", C.Orange, "warning")
		end
	elseif k == "RaidHeld" then
		local bonus, xp = tonumber(info.Bonus) or 0, tonumber(info.XP) or 0
		if bonus > 0 or xp > 0 then
			HUDController.Stamp("RAID FAILED", role == "Owner" and "You held the door" or ("You held " .. whose), C.Cash, w.stamp,
				{ Cash = bonus, XP = xp })
		else
			NotifyController.Show(whose:sub(1, 1):upper() .. whose:sub(2) .. " held off the raid!", C.Cash, "success")
		end
	elseif k == "RaidOver" then
		local why = info.Why
		if role == "Cop" then
			NotifyController.Show(why == "Gone" and "The suspect left: raid called off." or (why == "Held" and "They held the door: the warrant ran out."
				or "The warrant ran out."), nil, "police")
		elseif why == "Expired" then
			NotifyController.Show("The raid warrant ran out. Your stock is safe, for now.", C.Cash, "info")
		end
	end
	if k ~= "Raid" and k ~= "RaidBreached" and S.gpsName == gpsName then
		Job.clearGPS()
	end
end

-- Four times a second: the raid prompts (only an eligible cop sees them; the door's own prompt steps aside for
-- them during a warrant), the siren at a raided shop, the AI car's flashing light bar.
function Print.raidFx()
	local shops = Workspace:FindFirstChild("Shops")
	for _, m in ipairs(shops and shops:GetChildren() or {}) do
		local id = m:IsA("Model") and m:GetAttribute("BusinessId")
		local def = id and defOf(id)
		if def and Businesses.HasRaids(def) then
			local r = S.raids[id]
			local cop = r ~= nil and Print.copFor(r) and not r.ai
			for _, spec in ipairs({ { "BizBreachPrompt", "warrant" }, { "BizSearchPrompt", "search" } }) do
				local p = m:FindFirstChild(spec[1], true)
				if p and p:IsA("ProximityPrompt") then
					local want = cop and r.s == spec[2]
					if p.Enabled ~= want then
						p.Enabled = want
					end
				end
			end
			local door = m:FindFirstChild("BusinessDoor", true)
			if door and door:IsA("ProximityPrompt") then
				local want = not (cop and r.s == "warrant")
				if door.Enabled ~= want then
					door.Enabled = want
				end
			end
		end
	end
	-- The siren: one loop at the nearest raided shop within K.SIREN_RANGE.
	local root = myRoot()
	local best, bestD
	for id in pairs(S.raids) do
		local def = defOf(id)
		local d = def and root and (root.Position - def.Position).Magnitude
		if d and d <= K.SIREN_RANGE and (not bestD or d < bestD) then
			best, bestD = id, d
		end
	end
	if best ~= S.sirenId then
		if S.siren then
			S.siren:Destroy()
			S.siren = nil
		end
		S.sirenId = best
		local s = best and other("SoundClient")
		if s and type(s.Loop) == "function" then
			local def = defOf(best)
			local car = Workspace:FindFirstChild("BizRaid") and Workspace.BizRaid:FindFirstChild("BizRaidCar", true)
			local ok, snd = pcall(s.Loop, "Siren", (car and car:IsA("Model") and car.PrimaryPart) or Businesses.DoorPosition(def), 0.55)
			S.siren = ok and snd or nil
		end
	end
	-- The AI raid car's light bar, red and blue in turn (it isn't in Workspace.Vehicles, so VehicleFeel leaves it).
	local raid = Workspace:FindFirstChild("BizRaid")
	if raid then
		local on = math.floor(os.clock() * 4) % 2 == 0
		for _, d in ipairs(raid:GetDescendants()) do
			if d:IsA("BasePart") and (d.Name == "LightBarRed" or d.Name == "LightBarBlue") then
				local lit = (d.Name == "LightBarRed") == on
				d.Material = lit and Enum.Material.Neon or Enum.Material.SmoothPlastic
				d.Color = lit and (d.Name == "LightBarRed" and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(40, 110, 255)) or Color3.fromRGB(40, 40, 46)
			end
		end
	end
end

-- (The shift's summary card is every job's SHIFT REPORT now: Job.report, with the same lines for the Print Shop.)

------------------------------------------------------------------ boat tours (Coastline Boat Rentals, M4)

-- Its own screen pieces (built once): the tour guide's bubble and the camera's white flash. The photo gauge is the
-- Print Shop's heat bar (ui.heat), worded PHOTO or FISH, set under the strip's line while a photo stop is on.
function Tour.build()
	local guide = Instance.new("Frame")
	guide.Name = "TourGuide"
	Theme.Panel(guide, 0.2)
	guide.Visible = false
	guide.Parent = ui.gui
	ui.guide = guide
	ui.guideTag = label(guide, "Tag", 12, "Bold")
	ui.guideTag.TextColor3 = C.Gold
	ui.guideTag.Text = "GUIDE"
	ui.guideTag.Position = UDim2.fromOffset(10, 0)
	ui.guideTag.Size = UDim2.new(0, 46, 1, 0)
	ui.guideText = label(guide, "Words", 14, "Body")
	ui.guideText.TextTruncate = Enum.TextTruncate.AtEnd
	ui.guideText.Position = UDim2.fromOffset(56, 0)
	ui.guideText.Size = UDim2.new(1, -64, 1, 0)
	local flash = Instance.new("Frame")
	flash.Name = "CameraFlash"
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 50
	flash.Visible = false
	flash.Parent = ui.gui
	ui.flash = flash
end

-- Where its pieces sit (with Job.place): the guide's bubble and the photo gauge under the strip's line.
function Tour.place(touch)
	local job = S.job
	if not ui.guide or not job or job.kind ~= "Tour" then
		return
	end
	local sp, ss = ui.strip.AbsolutePosition, ui.strip.AbsoluteSize
	local y = sp.Y + ss.Y + 4 + (ui.sub.Visible and (K.SUB_H + 4) or 0)
	if ui.heat and ui.heat.Visible then
		ui.heat.Position = UDim2.fromOffset(sp.X + 12, y)
		ui.heat.Size = UDim2.fromOffset(math.max(160, math.min(ss.X - 24, 300)), 14)
		y += 18
	end
	ui.guide.Position = UDim2.fromOffset(sp.X + 8, y)
	ui.guide.Size = UDim2.fromOffset(math.clamp(ss.X - 16, 220, touch and 320 or 380), 26)
end

-- The worker's tour boat, and are they at its helm?
function Tour.boat()
	local job = S.job
	if not job or job.kind ~= "Tour" then
		return nil
	end
	local boat = job.boat
	if typeof(boat) == "Instance" and boat.Parent then
		return boat
	end
	-- (A boat just built can reach this device after the "Tour" that names it, which then says nil: find it by its
	-- attributes, the one tour boat locked to you.)
	local vehicles = Workspace:FindFirstChild("Vehicles")
	for _, v in ipairs(vehicles and vehicles:GetChildren() or {}) do
		if v:GetAttribute("BizTour") == true and v:GetAttribute("BizDriverUserId") == player.UserId then
			job.boat = v
			return v
		end
	end
	return nil
end

function Tour.atHelm()
	local boat = Tour.boat()
	local hum = myHum()
	local seat = boat and boat:FindFirstChild("DriverSeat")
	return seat ~= nil and hum ~= nil and hum.SeatPart == seat
end

-- The boat's flat position and speed (the driver's own device runs its physics), or nil.
function Tour.motion()
	local boat = Tour.boat()
	local chassis = boat and boat.PrimaryPart
	if not chassis then
		return nil, 0
	end
	return flat(chassis.Position), flat(chassis.AssemblyLinearVelocity).Magnitude
end

-- One buoy ring floating on the water: a see-through wall (a hollow CylinderHandleAdornment on an invisible
-- anchor), K.BUOYS bobbing buoys round it, a name tag, and (for the next ring) a light pillar. Local parts under
-- the camera. kind: "Pass" | "Photo" | "Fish" | "Dock"; strength 1 = the next ring, less = the one after it.
function Tour.ring(pos, kind, name, radius, strength, beam)
	local color = K.RING_COLOR[kind] or K.RING_COLOR.Pass
	local folder = Instance.new("Folder")
	folder.Name = "BizTourRing"
	local function part(pname, size, cf, c, alpha)
		local p = Instance.new("Part")
		p.Name = pname
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size = size
		p.CFrame = cf
		p.Color = c
		p.Material = Enum.Material.Neon
		p.Transparency = alpha
		p.Parent = folder
		return p
	end
	local anchor = part("Anchor", Vector3.new(1, 1, 1), CFrame.new(pos.X, K.WATER_Y + K.RING_H / 2 - 0.4, pos.Z), color, 1)
	local wall = Instance.new("CylinderHandleAdornment")
	wall.Name = "Wall"
	wall.Adornee = anchor
	wall.Height = K.RING_H
	wall.Radius = radius
	pcall(function()
		wall.InnerRadius = radius - K.RING_WALL -- (hollow, so it never fills the water it marks)
	end)
	wall.CFrame = CFrame.Angles(math.rad(90), 0, 0) -- (a handle cylinder runs along its Z: stand it up)
	wall.Color3 = color
	wall.Transparency = 1 - 0.45 * strength
	wall.ZIndex = 0
	wall.Parent = anchor
	for i = 1, K.BUOYS do
		local a = (i - 1) / K.BUOYS * math.pi * 2
		local at = Vector3.new(pos.X + math.cos(a) * radius, K.WATER_Y + 0.4, pos.Z + math.sin(a) * radius)
		local b = part("Buoy", Vector3.new(K.BUOY, K.BUOY, K.BUOY), CFrame.new(at), i % 2 == 0 and Color3.new(1, 1, 1) or color, strength >= 1 and 0 or 0.4)
		b.Shape = Enum.PartType.Ball
		b.Material = Enum.Material.SmoothPlastic
		-- Bobbing (one looping tween each, offset, so they don't move as one).
		task.delay((i % 4) * 0.2, function()
			if b.Parent then
				TweenService:Create(b, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ CFrame = CFrame.new(at + Vector3.new(0, 0.6, 0)) }):Play()
			end
		end)
	end
	if beam then
		part("Beam", Vector3.new(1.4, K.BEAM_H, 1.4), CFrame.new(pos.X, K.WATER_Y + K.BEAM_H / 2, pos.Z), color, 0.75)
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Adornee = anchor
	tag.Size = UDim2.fromOffset(200, 30)
	tag.StudsOffsetWorldSpace = Vector3.new(0, K.RING_H + 4, 0)
	tag.MaxDistance = strength >= 1 and 900 or 400
	tag.LightInfluence = 0
	local l = label(tag, "Words", 18, "Display")
	l.Size = UDim2.fromScale(1, 1)
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.4
	l.TextTransparency = strength >= 1 and 0 or 0.35
	l.Text = (kind == "Photo" and "PHOTO STOP") or (kind == "Fish" and "FISHING STOP") or (kind == "Dock" and "DOCK") or tostring(name or "")
	tag.Parent = anchor
	folder.Parent = Workspace.CurrentCamera
	return { folder = folder, wall = wall, radius = radius }
end

-- The rings for where the tour is now: the next stop (bright, with its pillar) and the one after it (dim); after
-- the last stop the dock ring.
function Tour.rings()
	local job = S.job
	for _, r in ipairs(job.ringList or {}) do
		r.folder:Destroy()
	end
	job.ringList = {}
	if job.stage ~= "tour" and job.stage ~= "board" then
		return
	end
	local TO = Businesses.Tour
	local strengths = { 1, 0.4 }
	for k = 0, 1 do
		local i = job.leg + k
		local s = job.stops[i]
		local r
		if s then
			r = Tour.ring(s.Pos, s.Kind, s.Name, TO.Radius, strengths[k + 1], k == 0)
		elseif i == #job.stops + 1 and job.dock then
			r = Tour.ring(job.dock, "Dock", "DOCK", TO.DockRadius, strengths[k + 1], k == 0)
		end
		if r then
			table.insert(job.ringList, r)
		end
	end
end

-- A ring just passed swells and fades (a copy at its place).
function Tour.burst(pos, kind, radius)
	local r = Tour.ring(pos, kind, "", radius, 1, false)
	for _, d in ipairs(r.folder:GetChildren()) do
		if d.Name == "Buoy" then
			d:Destroy()
		end
	end
	local tag = r.folder:FindFirstChild("Tag", true)
	if tag then
		tag:Destroy()
	end
	r.wall.Transparency = 0.2
	TweenService:Create(r.wall, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Radius = radius * 1.35, Transparency = 1 }):Play()
	pcall(function()
		TweenService:Create(r.wall, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { InnerRadius = radius * 1.35 - K.RING_WALL }):Play()
	end)
	task.delay(0.55, function()
		r.folder:Destroy()
	end)
end

-- The GPS line on the water: from the boat (through the slip's mouth while still in it) to the next stop, on
-- through the next two and the dock.
function Tour.path()
	local job = S.job
	if not job or job.kind ~= "Tour" or (job.stage ~= "tour" and job.stage ~= "board") then
		GPSClient.ClearPath(K.TOUR_PATH)
		return
	end
	local pos = Tour.motion() or (job.berth and flat(job.berth))
	if not pos then
		return
	end
	local points = { pos }
	if job.leg == 1 and job.mouth and job.berth and (pos - flat(job.berth)).Magnitude < 30 then
		table.insert(points, flat(job.mouth))
	end
	for i = job.leg, math.min(#job.stops, job.leg + 2) do
		table.insert(points, flat(job.stops[i].Pos))
	end
	if job.leg + 2 >= #job.stops and job.dock then
		table.insert(points, flat(job.dock)) -- (the way home: the dock ring just outside the slip)
	end
	if #points < 2 then
		table.insert(points, pos + Vector3.new(0, 0, 1))
	end
	local goal = job.stops[job.leg] and job.stops[job.leg].Pos or job.dock
	GPSClient.SetPath(K.TOUR_PATH, points, {
		Height = K.WATER_LINE_Y, Color = Color3.new(1, 1, 1), Goal = goal and flat(goal) or nil,
		GoalText = job.stops[job.leg] and tostring(job.leg) or "⚓",
	})
	job.pathAt = os.clock()
end

-- The tour guide's line, in its bubble for a few seconds.
function Tour.guide(text)
	if not ui.guide or type(text) ~= "string" or text == "" then
		return
	end
	ui.guideText.Text = text
	ui.guide.Visible = true
	Tour.place(Theme.IsTouch())
	S.guideToken = (S.guideToken or 0) + 1
	local token = S.guideToken
	task.delay(K.GUIDE_TIME, function()
		if S.guideToken == token and ui.guide then
			ui.guide.Visible = false
		end
	end)
end

-- The camera flashes on this screen (photos taken): n quick white blinks and the shutter.
function Tour.flashes(n)
	if not ui.flash then
		return
	end
	S.flashToken = (S.flashToken or 0) + 1
	local token = S.flashToken
	task.spawn(function()
		for _ = 1, n do
			if S.flashToken ~= token then
				return
			end
			sound("TourShutter")
			ui.flash.Visible = true
			ui.flash.BackgroundTransparency = 0.45
			TweenService:Create(ui.flash, TweenInfo.new(0.22), { BackgroundTransparency = 1 }):Play()
			task.wait(0.28)
		end
		if S.flashToken == token then
			ui.flash.Visible = false
		end
	end)
end

-- Everything of a tour on this device goes (the job's end, or a new one). job: the tour (default S.job).
function Tour.clear(job)
	job = job or S.job
	if job and job.ringList then
		for _, r in ipairs(job.ringList) do
			r.folder:Destroy()
		end
		job.ringList = {}
	end
	GPSClient.ClearPath(K.TOUR_PATH)
	if ui.heat then
		ui.heat.Visible = false
		ui.heatWord.Text = "HEAT"
	end
	if ui.guide then
		ui.guide.Visible = false
	end
	if ui.flash then
		ui.flash.Visible = false
	end
end

-- The strip: tag, what to do, the right-hand words, the edge colour.
function Tour.line(touch)
	local job = S.job
	local def = defOf(job.id)
	local pos, speed = Tour.motion()
	local right = ""
	local function dist(to)
		if not pos or not to then
			return ""
		end
		return GPSClient.FormatDistance((pos - flat(to)).Magnitude)
	end
	local edge = (job.special == "Celebrity" or job.special == "Sunset") and C.Gold or K.RING_COLOR.Dock
	if job.stage == "board" then
		if not Tour.atHelm() then
			local root = myRoot()
			local boat = Tour.boat()
			local d = (root and boat and boat.PrimaryPart) and flat(root.Position - boat.PrimaryPart.Position).Magnitude or nil
			return "BOAT TOUR", "WALK TO THE BOAT", d and GPSClient.FormatDistance(d) or "", edge
		end
		return "BOAT TOUR", fit({ "ALL ABOARD...", { string.upper(tostring(job.route or "")) } }), "", edge
	elseif job.stage == "dock" then
		return "BOAT TOUR", "DOCKING...", (job.earned or 0) > 0 and money(job.earned) or "", edge
	elseif job.stage == "after" then
		local hum = myHum()
		return "BOAT TOUR", (hum and hum.SeatPart == nil and not Tour.atHelm()) and "NEXT TOUR? BACK TO THE HELM" or "NEXT TOUR, OR END",
			(job.earned or 0) > 0 and money(job.earned) or "", edge
	end
	if not Tour.atHelm() then
		local boat = Tour.boat()
		local root = myRoot()
		local d = (root and boat and boat.PrimaryPart) and flat(root.Position - boat.PrimaryPart.Position).Magnitude or nil
		return "BOAT TOUR", "GET BACK IN THE BOAT!", d and GPSClient.FormatDistance(d) or "", C.Danger
	end
	local s = job.stops[job.leg]
	if not s then
		right = dist(job.dock)
		local near = pos and job.dock and (pos - flat(job.dock)).Magnitude <= Businesses.Tour.DockRadius + 20
		return "BOAT TOUR", near and "STOP IN THE DOCK RING" or fit({ "BACK TO THE DOCK", { string.upper(def and (def.Brand or "") or "") } }), right, edge
	end
	right = dist(s.Pos)
	if s.Kind == "Pass" then
		return "BOAT TOUR", fit({ "NEXT: " .. tostring(s.Name) }), right, edge
	end
	local rule = s.Kind == "Fish" and Businesses.Tour.Fish or Businesses.Tour.Photo
	local fish = s.Kind == "Fish"
	if job.photo then
		local fast = speed > rule.Speed
		local title = fast and (fish and "TOO FAST! STOP THE BOAT" or "TOO FAST! SLOW DOWN")
			or (speed <= rule.Perfect and (fish and "STAY STILL... LINES IN" or "HOLD IT STEADY...") or (fish and "SLOWER... STILL..." or "SLOWER FOR A PERFECT SHOT"))
		return fish and "FISHING" or "PHOTO STOP", title, touch and "" or (fish and "FISHING" or "PHOTO"), fast and C.Orange or K.RING_COLOR[s.Kind]
	end
	local d = pos and (pos - flat(s.Pos)).Magnitude or math.huge
	if d <= K.PHOTO_WARN then
		return fish and "FISHING" or "PHOTO STOP", fish and "FISHING STOP: STOP THE BOAT" or "PHOTO STOP: SLOW DOWN!", right, K.RING_COLOR[s.Kind]
	end
	return "BOAT TOUR", fit({ "NEXT: " .. tostring(s.Name) }), right, edge
end

-- The line under the strip: the tourists' mood (green / orange / red), the stops, par, the special, the streak.
-- Returns its parts, its colour and the colour for its first word (the mood).
function Tour.subParts(job)
	local parts = {}
	local mood = (tonumber(player:GetAttribute("BizTourHappy")) or math.floor((job.mood or 1) * 100 + 0.5)) / 100
	local moodColor = mood >= K.MOOD_GOOD and C.Cash or (mood >= K.MOOD_OK and C.Orange or C.Danger)
	local color = C.Text
	if job.stage == "tour" or job.stage == "board" then
		table.insert(parts, string.format("HAPPY %d%%", math.floor(mood * 100 + 0.5)))
		table.insert(parts, { string.format("STOP %d/%d", math.min(job.leg, #job.stops), #job.stops) })
		if job.stage == "tour" and job.goClock and job.par then
			local left = job.par - (os.clock() - job.goClock)
			table.insert(parts, { left >= 0 and ("PAR " .. clock(left)) or ("PAR +" .. clock(-left)) })
		end
	end
	local sp = job.special and Businesses.Tour.Specials[job.special]
	if sp then
		table.insert(parts, { job.celeb and ("CELEBRITY · " .. string.upper(job.celeb)) or sp.Name })
		table.insert(parts, { sp.Words })
		color = C.Gold
	end
	if (job.streak or 0) >= 2 then
		table.insert(parts, { "STREAK ×" .. job.streak })
	end
	return parts, color, (job.stage == "tour" or job.stage == "board") and moodColor or nil
end

-- Five times a second on a tour: the photo gauge (this device's own reading of the server's rule), the GPS line
-- kept near the boat, the AFTER panel at the dock.
function Tour.tick()
	local job = S.job
	if not job or job.kind ~= "Tour" then
		return
	end
	local pos, speed = Tour.motion()
	local s = job.stops[job.leg]
	-- The photo (or fishing) gauge: the heat bar, worded PHOTO / FISH.
	local photoOn = job.stage == "tour" and job.photo ~= nil and s ~= nil and s.Kind ~= "Pass" and pos ~= nil
	if ui.heat then
		ui.heat.Visible = photoOn
	end
	if photoOn then
		local rule = s.Kind == "Fish" and Businesses.Tour.Fish or Businesses.Tour.Photo
		local now = os.clock()
		local dt = math.clamp(now - (job.photoAt or now), 0, 0.5)
		job.photoAt = now
		local inside = (pos - flat(s.Pos)).Magnitude <= Businesses.Tour.Radius + rule.Slack
		local grade
		job.photo, grade = Businesses.PhotoStep(job.photo, dt, inside, speed, s.Kind)
		if grade then
			-- (this device thinks it's done: hold the bar full until the server's verdict comes)
			job.photo = { hold = rule.Hold, steady = job.photo.steady, entered = true, done = true }
		end
		ui.heatWord.Text = s.Kind == "Fish" and "FISH" or "PHOTO"
		ui.heatWord.TextColor3 = C.Text
		ui.heatFill.Size = UDim2.fromScale(math.clamp(job.photo.hold / rule.Hold, 0.02, 1), 1)
		ui.heatFill.BackgroundColor3 = speed > rule.Speed and C.Danger or (speed <= rule.Perfect and K.SWEET or C.Orange)
		Tour.place(Theme.IsTouch())
	end
	-- The GPS line: redrawn from the boat now and then when it's well off it.
	if job.stage == "tour" and os.clock() - (job.pathAt or 0) >= K.REPLAN then
		local off = GPSClient.PathName() == K.TOUR_PATH and GPSClient.PathProgress() or nil
		if GPSClient.PathName() ~= K.TOUR_PATH or (off and off > K.OFF_LINE) then
			Tour.path()
		else
			job.pathAt = os.clock()
		end
	end
	-- Between tours, at the dock: the AFTER panel (NEXT TOUR | END).
	local show = job.stage == "after" and not S.card and os.clock() >= (S.afterWait or 0)
	if show and not ui.after.Visible then
		ui.afterTitle.Text = job.lastTitle or string.format('NEXT TOUR?  <font color="#%s">+%s</font>', C.Cash:ToHex(), money(job.earned or 0))
		ui.afterSub.Text = job.lastSub or "this shift so far"
		Job.place()
	end
	ui.after.Visible = show
end

-- BusinessJob "Tour": a new tour at the dock (Stage "board": the tourists wait on the pier, the route is set), or
-- between two (Stage "after": the AFTER panel).
function Tour.onTour(info)
	Card.close()
	Wash.clear(true)
	local old = S.job
	local fresh = not old or old.kind ~= "Tour" or old.id ~= info.Id
	if info.Stage == "after" and not fresh then
		old.stage = "after"
		old.earned = tonumber(info.Earned) or old.earned
		old.count = tonumber(info.Count) or old.count
		old.streak = tonumber(info.Streak) or old.streak
		Tour.clear()
		return
	end
	if old and old.kind == "Tour" then
		Tour.clear()
	end
	local stops = {}
	for i, s in ipairs(type(info.Stops) == "table" and info.Stops or {}) do
		if typeof(s.Pos) == "Vector3" then
			stops[i] = { Name = s.Name, Pos = s.Pos, Line = s.Line, Kind = s.Kind or "Pass" }
		end
	end
	S.job = {
		kind = "Tour", id = info.Id, stage = info.Stage == "after" and "after" or "board", stops = stops, leg = 1,
		dock = typeof(info.Dock) == "Vector3" and info.Dock or nil, mouth = typeof(info.Mouth) == "Vector3" and info.Mouth or nil,
		berth = typeof(info.Berth) == "Vector3" and info.Berth or nil, special = info.Special, celeb = info.Celeb, par = tonumber(info.Par),
		route = info.Route, routeId = info.RouteId, tourists = tonumber(info.Tourists) or 0, earned = tonumber(info.Earned) or 0,
		count = tonumber(info.Count) or 0, streak = tonumber(info.Streak) or 0, owner = info.Owner, level = tonumber(info.Level) or 1,
		boat = typeof(info.Boat) == "Instance" and info.Boat or nil, ringList = {}, tours = tonumber(info.Tours) or 0,
		lastTitle = not fresh and old.lastTitle or nil, lastSub = not fresh and old.lastSub or nil,
	}
	ui.hold.Visible = false
	ui.after.Visible = false
	ui.afterSub.Text = ""
	Job.marker(nil)
	Job.clearGPS()
	if fresh then
		Job.reportClose()
		NotifyController.Show("Boat tours: drive the tourists through the buoys, slow right down in the PHOTO rings, and keep it smooth. They rate the ride!",
			nil, "info")
	end
	local sp = info.Special and Businesses.Tour.Specials[info.Special]
	if sp then
		local words = {
			Celebrity = string.format("CELEBRITY TOUR: %s is aboard! A ★★★ tour tips ×3.", tostring(info.Celeb or "a star")),
			Fishing = "FISHING PARTY: a slow, relaxed trip to the fishing spots. Stop dead still for the bites. Bonus at the end!",
			Sunset = "SUNSET TOUR: the sun's going down, and the tourists pay ×1.3 for the view.",
		}
		sound("PhoneText")
		NotifyController.Show(words[info.Special] or sp.Name, C.Gold, "money")
	end
	ui.endJob.Visible = true
	Tour.rings()
	Tour.path()
	Job.place()
end

-- BusinessJob "TourGo": all aboard, the boat is free and the clock runs (Leg: where a resent tour is).
function Tour.onGo(info)
	local job = S.job
	if not job or job.kind ~= "Tour" then
		return
	end
	job.stage = "tour"
	job.goClock = os.clock()
	job.par = tonumber(info.Par) or job.par
	job.leg = tonumber(info.Leg) or job.leg or 1
	job.photo = nil
	if not info.Resend then
		sound("TourHorn")
		Job.pop("ALL ABOARD!", K.RING_COLOR.Dock)
		Tour.guide(job.stops[1] and ("First stop: " .. string.lower(tostring(job.stops[1].Name)) .. ". Hold on to your hats!") or "Off we go!")
	end
	Tour.rings()
	Tour.path()
end

-- BusinessJob "TourStop": a pass ring counted (Index), on to the next (Next; nil = back to the dock).
function Tour.onStop(info)
	local job = S.job
	if not job or job.kind ~= "Tour" then
		return
	end
	local i = tonumber(info.Index) or job.leg
	local s = job.stops[i]
	if s then
		Tour.burst(s.Pos, s.Kind, Businesses.Tour.Radius)
		Tour.guide(s.Line)
	end
	sound("Checkpoint")
	job.leg = tonumber(info.Next) or (#job.stops + 1)
	Tour.rings()
	Tour.path()
	if not info.Next then
		NotifyController.Show("Last stop done: back to the dock! Stop in the aqua ring.", nil, "info")
	end
end

-- BusinessJob "TourPhotoOn": inside a photo (or fishing) ring: the gauge.
function Tour.onPhotoOn(info)
	local job = S.job
	if not job or job.kind ~= "Tour" then
		return
	end
	local s = job.stops[tonumber(info.Index) or job.leg]
	job.photo = { hold = 0, steady = 0, entered = true }
	job.photoAt = os.clock()
	if s then
		Tour.guide(s.Line)
	end
	sound("Click")
end

-- BusinessJob "TourPhoto": the server's grade for a photo (or fishing) stop, and on to the next.
function Tour.onPhoto(info)
	local job = S.job
	if not job or job.kind ~= "Tour" then
		return
	end
	local i = tonumber(info.Index) or job.leg
	local s = job.stops[i]
	local fish = info.Kind == "Fish"
	if info.Grade == "Perfect" then
		Job.pop(fish and "CAUGHT A BIG ONE!" or "PERFECT SHOT!", K.SWEET)
		sound("Checkpoint")
		Tour.flashes(fish and 1 or 3)
	elseif info.Grade == "Ok" then
		Job.pop(fish and "A NIBBLE!" or "NICE SHOT!", C.Text)
		Tour.flashes(fish and 0 or 2)
	else
		Job.pop(fish and "THEY GOT AWAY!" or "MISSED THE PHOTO!", C.Orange)
		NotifyController.Show(fish and "Too fast for the fish! Stop dead still inside the green ring next time."
			or "Missed it! Slow right down inside the pink ring until the PHOTO bar fills.", nil, "info")
	end
	if s then
		Tour.burst(s.Pos, s.Kind, Businesses.Tour.Radius)
	end
	job.photo = nil
	job.leg = tonumber(info.Next) or (#job.stops + 1)
	if ui.heat then
		ui.heat.Visible = false
	end
	Tour.rings()
	Tour.path()
end

-- BusinessJob "TourMood": the tourists didn't like that (a hard turn, a ram, running aground).
function Tour.onMood(info)
	local why = info.Why
	Job.shakeSub()
	if why == "Ram" then
		sound("Crash")
	elseif why == "Beach" then
		sound("Splash")
		NotifyController.Show("You ran aground! The tourists hate that. Back off into deeper water.", C.Orange, "warning")
	end
end

-- BusinessJob "TourPaid": docked. The rating stamp (the server's), the money counting up, the tourists cheer
-- (the server's bubbles), confetti for ★★★; the AFTER panel's words for when they've stepped off.
function Tour.onPaid(info)
	local job = S.job
	local pay, tip, bonus = tonumber(info.Pay) or 0, tonumber(info.Tip) or 0, tonumber(info.Bonus) or 0
	local stars = math.clamp(math.floor(tonumber(info.Stars) or 1), 1, 3)
	local streak, mult = tonumber(info.Streak) or 0, tonumber(info.Mult) or 1
	local total = pay + tip + bonus
	if job and job.kind == "Tour" then
		job.stage = "dock"
		job.earned = tonumber(info.Earned) or job.earned
		job.count = tonumber(info.Count) or job.count
		job.streak = streak
		job.photo = nil
	end
	Tour.clear()
	sound("CashIn")
	Job.countUp(total)
	local sp = info.Special and Businesses.Tour.Specials[info.Special]
	local title = (stars == 3 and "★★★ TOUR") or (stars == 2 and "★★ GREAT TOUR") or "★ TOUR DONE"
	local bits = { "tip " .. money(tip) }
	if bonus > 0 then
		table.insert(bits, "bonus " .. money(bonus))
	end
	if streak >= 2 then
		table.insert(bits, string.format("streak ×%.1f", mult))
	end
	if info.Special == "Celebrity" and stars == 3 then
		table.insert(bits, 1, tostring(info.Celeb or "The star") .. " loved it")
	end
	HUDController.Stamp(title, table.concat(bits, " · "), stars == 3 and K.MEDAL.Gold or C.Cash, sp and sp.Name or "BOAT TOUR", { Cash = total })
	if stars == 3 then
		local boat = Tour.boat()
		local core = boat and boat.PrimaryPart
		if core then
			Fx.confetti(core.Position)
		end
	end
	-- What earned the stars (the AFTER panel's line): what was missing for the next one.
	local miss = {}
	if not info.OnTime then
		table.insert(miss, "faster")
	end
	local allPerfect = true
	for _, g in ipairs(type(info.Grades) == "table" and info.Grades or {}) do
		allPerfect = allPerfect and g == "Perfect"
	end
	if not allPerfect then
		table.insert(miss, "PERFECT photos")
	end
	if (tonumber(info.Mood) or 1) < Businesses.Tour.Mood.StarAt then
		table.insert(miss, "a smoother ride")
	end
	if job and job.kind == "Tour" then
		job.lastTitle = string.format('<font color="#%s">+%s</font>  %s', C.Cash:ToHex(), money(total), starsText(stars))
		job.lastSub = rich(#miss > 0 and ("for ★★★: " .. table.concat(miss, ", ")) or (streak >= 2 and string.format("★★★ streak ×%.1f · keep it going", mult) or "perfect tour!"))
	end
	if tonumber(info.Broke) then
		NotifyController.Show(string.format("Streak over (%d ★★★ tours in a row).", tonumber(info.Broke)), nil, "info")
	elseif streak >= 2 and mult > 1 then
		NotifyController.Show(string.format("★★★ streak ×%d: tips ×%.1f!", streak, mult), C.Gold, "success")
	end
end

------------------------------------------------------------------ VIP pickups and the club (the Afterglow Nightclub, M5)

-- The worker's limo, and are they at its wheel?
function Vip.limo()
	local job = S.job
	if not job or job.kind ~= "Vip" then
		return nil
	end
	local limo = job.limo
	if typeof(limo) == "Instance" and limo.Parent then
		return limo
	end
	-- (a limo just built can reach this device after the "Vip" that names it: find it by its attributes)
	local vehicles = Workspace:FindFirstChild("Vehicles")
	for _, v in ipairs(vehicles and vehicles:GetChildren() or {}) do
		if v:GetAttribute("BizVip") == true and v:GetAttribute("BizDriverUserId") == player.UserId then
			job.limo = v
			return v
		end
	end
	return nil
end

function Vip.atWheel()
	local limo = Vip.limo()
	local hum = myHum()
	local seat = limo and limo:FindFirstChild("DriverSeat")
	return seat ~= nil and hum ~= nil and hum.SeatPart == seat
end

-- The limo's flat position (or yours, out of it).
function Vip.where()
	local limo = Vip.limo()
	local chassis = limo and limo.PrimaryPart
	if chassis then
		return flat(chassis.Position)
	end
	local root = myRoot()
	return root and flat(root.Position) or nil
end

-- Studs to the nearest paparazzi car after you (the server's NPC drivers: attribute BizPapFor), or nil.
function Vip.papDist()
	local at = Vip.where()
	local vehicles = Workspace:FindFirstChild("Vehicles")
	local best
	for _, v in ipairs(vehicles and vehicles:GetChildren() or {}) do
		if v:GetAttribute("BizPapFor") == player.UserId then
			local chassis = v:IsA("Model") and v.PrimaryPart
			if chassis and at then
				local d = (flat(chassis.Position) - at).Magnitude
				best = best and math.min(best, d) or d
			end
		end
	end
	return best
end

-- The red carpet's mark: a pink ring the size of a GOOD stop with a dot for PERFECT, and a beam (local parts).
function Vip.mark(pos)
	if ui.vipMark then
		ui.vipMark:Destroy()
		ui.vipMark = nil
	end
	if not pos then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "BizVipMark"
	local function part(name, size, cf, color, alpha, shape)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Size = size
		p.CFrame = cf
		p.Transparency = alpha
		if shape then
			p.Shape = shape
		end
		p.Parent = folder
		return p
	end
	local st = Businesses.Vip.Stop
	part("GoodRing", Vector3.new(0.2, st.Good * 2, st.Good * 2), CFrame.new(pos.X, 0.4, pos.Z) * CFrame.Angles(0, 0, math.rad(90)), K.VIP_PINK, 0.7,
		Enum.PartType.Cylinder)
	part("PerfectDot", Vector3.new(0.25, st.Perfect * 2, st.Perfect * 2), CFrame.new(pos.X, 0.45, pos.Z) * CFrame.Angles(0, 0, math.rad(90)), K.MEDAL.Gold,
		0.45, Enum.PartType.Cylinder)
	part("Beam", Vector3.new(1.2, 120, 1.2), CFrame.new(pos.X, 60, pos.Z), K.VIP_PINK, 0.75)
	folder.Parent = Workspace.CurrentCamera
	ui.vipMark = folder
end

-- Everything of a VIP shift on this device goes (the job's end).
function Vip.clear()
	Vip.mark(nil)
	Job.marker(nil)
	if ui.flash then
		ui.flash.Visible = false
	end
end

-- The strip: tag, what to do, the right-hand words, the edge colour.
function Vip.line(touch)
	local job = S.job
	local def = defOf(job.id)
	local pos = Vip.where()
	local function dist(to)
		return (pos and to) and GPSClient.FormatDistance((pos - flat(to)).Magnitude) or ""
	end
	local edge = job.special and K.MEDAL.Gold or K.VIP_PINK
	local tag = "VIP"
	if (job.stage == "pickup" or job.stage == "ride") and not Vip.atWheel() then
		local limo = Vip.limo()
		local root = myRoot()
		local d = (root and limo and limo.PrimaryPart) and flat(root.Position - limo.PrimaryPart.Position).Magnitude or nil
		return tag, job.everIn and "GET BACK IN THE LIMO!" or "GET IN THE LIMO", d and GPSClient.FormatDistance(d) or "",
			job.everIn and C.Danger or edge
	end
	if job.stage == "pickup" then
		return tag, fit({ "PICK UP " .. string.upper(tostring(job.name or "THE VIP")), { string.upper(tostring(job.place or "")) } }), dist(job.pos), edge
	elseif job.stage == "board" then
		return tag, fit({ string.upper(tostring(job.name or "THE VIP")) .. " IS GETTING IN..." }), "", edge
	elseif job.stage == "ride" then
		local pd = job.pap == "chase" and Vip.papDist() or nil
		local d = (pos and job.carpet) and (pos - flat(job.carpet)).Magnitude or math.huge
		if d <= 70 then
			return tag, "STOP ON THE VIP MARK", touch and "" or dist(job.carpet), edge
		end
		if pd then
			return "PAPARAZZI", "LOSE THE PAPARAZZI!", GPSClient.FormatDistance(pd), C.Orange
		end
		return tag, fit({ "TO THE RED CARPET", { string.upper(def and (def.Brand or "") or "") } }), dist(job.carpet), edge
	elseif job.stage == "carpet" then
		return tag, "RED CARPET!", (job.earned or 0) > 0 and money(job.earned) or "", edge
	end
	-- After a VIP, at the club.
	return tag, Vip.atWheel() and "NEXT VIP, OR END" or "NEXT VIP? BACK TO THE LIMO", (job.earned or 0) > 0 and money(job.earned) or "", edge
end

-- The line under the strip: the VIP's comfort (green / orange / red), par, the paparazzi, the special, night, the
-- streak. Returns its parts, its colour and the colour for its first word (the comfort).
function Vip.subParts(job)
	local parts = {}
	local color = C.Text
	local first = nil
	if job.stage == "ride" then
		local c = (tonumber(player:GetAttribute("BizVipComfort")) or math.floor((job.comfort or 1) * 100 + 0.5)) / 100
		first = c >= K.MOOD_GOOD and C.Cash or (c >= K.MOOD_OK and C.Orange or C.Danger)
		table.insert(parts, string.format("COMFORT %d%%", math.floor(c * 100 + 0.5)))
		if job.par and job.rideClock then
			local left = job.par - (os.clock() - job.rideClock)
			table.insert(parts, { left >= 0 and ("PAR " .. clock(left)) or ("PAR +" .. clock(-left)) })
		end
		if job.pap == "chase" then
			table.insert(parts, { "PAPARAZZI!" })
		elseif job.pap == "lost" then
			table.insert(parts, { "LOST THEM ✓" })
		elseif job.pap == "coming" then
			table.insert(parts, { "PAPARAZZI COMING" })
		end
	end
	local sp = job.special and Businesses.Vip.Specials[job.special]
	if sp then
		table.insert(parts, { sp.Name })
		table.insert(parts, { sp.Words })
		color = C.Gold
	end
	if job.night then
		table.insert(parts, { string.format("NIGHT ×%.2f", Businesses.Vip.NightMult) })
	end
	if (job.streak or 0) >= 2 then
		table.insert(parts, { "STREAK ×" .. job.streak })
	end
	return parts, color, first
end

-- Five times a second on the shift: the GPS and the markers for where the VIP is now, the AFTER panel at the club.
function Vip.tick()
	local job = S.job
	if not job or job.kind ~= "Vip" then
		return
	end
	if Vip.atWheel() then
		job.everIn = true
	end
	local want = (job.stage == "pickup" and "pickup") or ((job.stage == "ride" or job.stage == "board") and "ride") or nil
	if want ~= job.markFor then
		job.markFor = want
		if want == "pickup" and job.pos then
			Vip.mark(nil)
			Job.marker(job.pos)
			Job.setGPS("VIP: " .. tostring(job.name or "pickup"), job.pos)
		elseif want == "ride" and job.carpet then
			Job.marker(nil)
			Vip.mark(job.carpet)
			local def = defOf(job.id)
			Job.setGPS("Red carpet: " .. (def and (def.Brand or def.Name) or "the club"), job.carpet)
		else
			Job.marker(nil)
			Vip.mark(nil)
			Job.clearGPS()
		end
	end
	-- At the club between VIPs: the AFTER panel (NEXT VIP | END).
	local show = job.stage == "after" and not S.card and os.clock() >= (S.afterWait or 0)
	if show and not ui.after.Visible then
		ui.afterTitle.Text = job.lastTitle or string.format('NEXT VIP?  <font color="#%s">+%s</font>', C.Cash:ToHex(), money(job.earned or 0))
		ui.afterSub.Text = job.lastSub or "this shift so far"
		Job.place()
	end
	ui.after.Visible = show
end

-- BusinessJob "Vip": a new VIP waiting (Stage "pickup"), or between two at the club (Stage "after").
function Vip.onVip(info)
	Card.close()
	Wash.clear(true)
	local old = S.job
	local fresh = not old or old.kind ~= "Vip" or old.id ~= info.Id
	if info.Stage == "after" and not fresh then
		old.stage = "after"
		old.earned = tonumber(info.Earned) or old.earned
		old.count = tonumber(info.Count) or old.count
		old.streak = tonumber(info.Streak) or old.streak
		return
	end
	S.job = {
		kind = "Vip", id = info.Id, stage = info.Stage == "after" and "after" or "pickup", name = info.Name, place = info.Place, placeKind = info.Kind,
		pos = typeof(info.Pos) == "Vector3" and info.Pos or nil, carpet = typeof(info.Carpet) == "Vector3" and info.Carpet or nil,
		special = info.Special, night = info.Night == true, level = tonumber(info.Level) or 1, owner = info.Owner, earned = tonumber(info.Earned) or 0,
		count = tonumber(info.Count) or 0, streak = tonumber(info.Streak) or 0, limo = typeof(info.Limo) == "Instance" and info.Limo or nil,
		vips = tonumber(info.Vips) or 0, everIn = not fresh and old.everIn or nil,
		lastTitle = not fresh and old.lastTitle or nil, lastSub = not fresh and old.lastSub or nil,
	}
	ui.hold.Visible = false
	ui.after.Visible = false
	ui.afterSub.Text = ""
	if fresh then
		Job.reportClose()
		NotifyController.Show("VIP pickups: drive the club's limo to the celebrity, then bring them to the red carpet. Drive smooth, and stop right on the VIP mark!",
			nil, "info")
	end
	local sp = info.Special and Businesses.Vip.Specials[info.Special]
	if sp then
		local words = {
			Superstar = "A SUPERSTAR tonight: %s! A ★★★ arrival tips ×3.",
			Tabloid = "%s is a TABLOID STAR: the paparazzi will follow. Lose them for a double bonus!",
			Late = "%s is LATE FOR THE SHOW: beat the clock and the tip is doubled.",
		}
		sound("PhoneText")
		NotifyController.Show(string.format(words[info.Special] or "%s", tostring(info.Name or "The VIP")), C.Gold, "money")
	end
	ui.endJob.Visible = true
	S.job.markFor = nil
	Vip.tick()
	Job.place()
end

-- BusinessJob "VipAboard": the VIP got in; the ride back starts (the clock, the comfort, maybe paparazzi).
function Vip.onAboard(info)
	local job = S.job
	if not job or job.kind ~= "Vip" then
		return
	end
	job.stage = "ride"
	job.par = tonumber(info.Par) or job.par
	job.rideClock = os.clock()
	job.night = info.Night == true
	job.pap = info.Pap and "coming" or nil
	job.comfort = 1
	if not info.Resend then
		sound("Door")
		task.delay(0.4, function()
			sound("Horn", nil, 0.6)
		end)
		Job.pop("VIP ABOARD!", K.VIP_PINK)
		if info.Line then
			NotifyController.Show(string.format("%s: \"%s\"", tostring(info.Name or "VIP"), tostring(info.Line)), nil, "info")
		end
	end
	Vip.tick()
end

-- BusinessJob "VipPap": the paparazzi are after you.
function Vip.onPap(info)
	local job = S.job
	if job and job.kind == "Vip" then
		job.pap = "chase"
	end
	sound("Spotted")
	local n = tonumber(info.Cars) or 1
	NotifyController.Show(string.format("PAPARAZZI! %s on your tail. Get %d studs away from %s to lose %s, for a bonus.",
		n == 1 and "A car is" or (n .. " cars are"), Businesses.Vip.Pap.LoseDist, n == 1 and "it" or "them", n == 1 and "it" or "them"), C.Orange, "warning")
end

-- BusinessJob "VipLost": LOST THEM!
function Vip.onLost(info)
	local job = S.job
	if job and job.kind == "Vip" then
		job.pap = "lost"
	end
	sound("LostCops")
	HUDController.Stamp("LOST THEM!", "The paparazzi gave up · +" .. money(tonumber(info.Bonus) or 0) .. " at the red carpet", K.MEDAL.Gold, "PAPARAZZI")
end

-- BusinessJob "VipComfort": the VIP didn't like that (a hard turn, a crash, a jump, cameras).
function Vip.onComfort(info)
	Job.shakeSub()
	if info.Why == "Ram" then
		sound("Crash")
	elseif info.Why == "Flash" then
		Tour.flashes(1)
	end
end

-- BusinessJob "VipPaid": the red carpet. The stamp (the server's grade), the press's flashes on your screen, the
-- pay counting up, confetti for ★★★; the AFTER panel's words for once the VIP has walked in.
function Vip.onPaid(info)
	local job = S.job
	local pay, tip, bonus = tonumber(info.Pay) or 0, tonumber(info.Tip) or 0, tonumber(info.Bonus) or 0
	local stars = math.clamp(math.floor(tonumber(info.Stars) or 1), 1, 3)
	local streak, mult = tonumber(info.Streak) or 0, tonumber(info.Mult) or 1
	local total = pay + tip + bonus
	if job and job.kind == "Vip" then
		job.stage = "carpet"
		job.earned = tonumber(info.Earned) or job.earned
		job.count = tonumber(info.Count) or job.count
		job.streak = streak
		job.pap = nil
	end
	Vip.mark(nil)
	Job.marker(nil)
	Job.clearGPS()
	sound("Passed")
	Tour.flashes(4)
	Job.countUp(total)
	local stopWord = (info.Stop == "Perfect" and "PERFECT STOP") or (info.Stop == "Good" and "GOOD STOP") or "OK STOP"
	local title = (stars == 3 and "★★★ RED CARPET") or (stars == 2 and "★★ RED CARPET") or "★ RED CARPET"
	local bits = { stopWord, "tip " .. money(tip) }
	if bonus > 0 then
		table.insert(bits, "lost them +" .. money(bonus))
	end
	if info.Night then
		table.insert(bits, string.format("night ×%.2f", Businesses.Vip.NightMult))
	end
	if streak >= 2 then
		table.insert(bits, string.format("streak ×%.1f", mult))
	end
	if info.Special == "Superstar" and stars == 3 then
		table.insert(bits, 1, tostring(info.Name or "The star") .. " loved it")
	end
	local sp = info.Special and Businesses.Vip.Specials[info.Special]
	HUDController.Stamp(title, table.concat(bits, " · "), stars == 3 and K.MEDAL.Gold or K.VIP_PINK, sp and sp.Name or "VIP ARRIVAL", { Cash = total })
	if stars == 3 then
		local limo = Vip.limo()
		local core = limo and limo.PrimaryPart
		if core then
			Fx.confetti(core.Position)
		end
	end
	-- What was missing for ★★★ (the AFTER panel's line).
	local miss = {}
	if not info.OnTime then
		table.insert(miss, "faster")
	end
	if (tonumber(info.Comfort) or 1) < Businesses.Vip.Comfort.StarAt then
		table.insert(miss, "a smoother ride")
	end
	if info.Stop ~= "Perfect" then
		table.insert(miss, "stop on the gold dot")
	end
	if job and job.kind == "Vip" then
		job.lastTitle = string.format('<font color="#%s">+%s</font>  %s', C.Cash:ToHex(), money(total), starsText(stars))
		job.lastSub = rich(#miss > 0 and ("for ★★★: " .. table.concat(miss, ", ")) or (streak >= 2 and string.format("★★★ streak ×%.1f · keep it going", mult) or "perfect arrival!"))
	end
	if info.Pap and not info.Lost then
		NotifyController.Show("The paparazzi got their shots at the door. Lose them on the way next time for the bonus!", nil, "info")
	end
	if tonumber(info.Broke) then
		NotifyController.Show(string.format("Streak over (%d ★★★ arrivals in a row).", tonumber(info.Broke)), nil, "info")
	elseif streak >= 2 and mult > 1 then
		NotifyController.Show(string.format("★★★ streak ×%d: tips ×%.1f!", streak, mult), C.Gold, "success")
	end
end

-- Am I inside the club (player attribute BizClub, the server's)?
function Club.inside()
	return player:GetAttribute("BizClub") ~= nil
end

-- SkyClient's rain emitter round the camera (HouseClient switches it off in homes and penthouse rooms), or nil.
function Club.rain()
	local camera = Workspace.CurrentCamera
	local cloud = camera and camera:FindFirstChild("RainCloud")
	local rain = cloud and cloud:FindFirstChild("Rain")
	return (rain and rain:IsA("ParticleEmitter")) and rain or nil
end

-- Four times a second: the club's own prompts (WASH only for its owners; the rope's words), and inside the club its
-- dance floor and wall lights (this device's own animation, only while you're in there).
function Club.tick()
	local shops = Workspace:FindFirstChild("Shops")
	for _, m in ipairs(shops and shops:GetChildren() or {}) do
		local id = m:IsA("Model") and m:GetAttribute("BusinessId")
		local def = id and defOf(id)
		if def and def.BackRoom then
			local mineHere = mine(id) ~= nil
			local wash = m:FindFirstChild("BizWashPrompt", true)
			if wash and wash:IsA("ProximityPrompt") and wash.Enabled ~= mineHere then
				wash.Enabled = mineHere
			end
			local rope = m:FindFirstChild("BizServicePrompt", true)
			if rope and rope:IsA("ProximityPrompt") then
				local _, whose = shownOwner(id)
				local pass = Businesses.TimeLeft(player:GetAttribute("BizCoverUntil"), serverNow()) > 0
				local words = (whose == "mine" or whose == "crew") and "Enter the club (free)"
					or (pass and "Enter the club (paid)" or (def.Service.Name .. " " .. money(def.Service.Price)))
				if rope.ActionText ~= words then
					rope.ActionText = words
				end
			end
		end
	end
	if not Club.inside() then
		return
	end
	-- SkyClient's rain follows the camera through any roof: none in the club (HouseClient does the same for homes).
	local rain = Club.rain()
	if rain and rain.Enabled then
		rain.Enabled = false
	end
	local club = Workspace:FindFirstChild("BizClubInterior")
	if not club then
		return
	end
	-- The tiles and the wall washes, found once (and again now and then: the club may have been rebuilt).
	if S.clubModel ~= club or os.clock() - (S.clubScanAt or 0) > 5 then
		S.clubModel, S.clubScanAt = club, os.clock()
		S.clubTiles, S.clubGlows = {}, {}
		for _, d in ipairs(club:GetDescendants()) do
			if d:IsA("BasePart") then
				if d:GetAttribute("DanceTile") then
					table.insert(S.clubTiles, d)
				elseif d:GetAttribute("ClubGlow") then
					table.insert(S.clubGlows, d)
				end
			end
		end
	end
	local beat = math.floor(os.clock() * 2.2)
	local palette = { Color3.fromRGB(255, 62, 165), Color3.fromRGB(60, 230, 255), Color3.fromRGB(170, 100, 255), Color3.fromRGB(255, 214, 10) }
	for _, d in ipairs(S.clubTiles) do
		if d.Parent and not S.hidden[d] then
			d.Color = palette[((tonumber(d:GetAttribute("DanceTile")) or 1) * 7 + beat) % #palette + 1]
		end
	end
	for _, d in ipairs(S.clubGlows) do
		if d.Parent then
			d.Transparency = (beat % 2 == 0) and 0.7 or 0.45
		end
	end
end

-- The club's line on the strip when no job has it: inside the club (and your VIP booth's clock).
function Club.line()
	if not Club.inside() then
		return nil
	end
	local left = Businesses.TimeLeft(player:GetAttribute("BizBoothUntil"), serverNow())
	if left > 0 then
		return "VIP", "YOUR VIP BOOTH", clock(left), left <= Businesses.Club.BoothWarn and C.Orange or K.MEDAL.Gold
	end
	return "CLUB", "AFTERGLOW · DANCE FLOOR", "", K.VIP_PINK
end

-- The back room's words for the card and the EMPIRE app: dirty cash, the wash, a raid on it. e = BusinessState's.
function Club.backRoomLine(e)
	local dirty, stock = tonumber(e.Dirty) or 0, tonumber(e.Stock) or 1
	local washAt = tonumber(e.WashAt)
	local ready = not washAt or washAt <= serverNow()
	return string.format('<font color="#%s">Back room %s / %s</font> · %s', K.BILL:ToHex(), money(dirty), money(stock),
		ready and ("WASH up to " .. money(tonumber(e.Wash) or 0) .. " at the safe") or ("WASH again in " .. clock(washAt - serverNow())))
end

local function readRaids()
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("BizRaids") or "{}")
	end)
	S.raids = (ok and type(decoded) == "table") and decoded or {}
	local phone = other("PhoneUI")
	if phone and type(phone.Refresh) == "function" then
		pcall(phone.Refresh, "Empire")
	end
end

------------------------------------------------------------------ server events

local function onJob(kind, info)
	if type(info) ~= "table" then
		info = {}
	end
	if kind == "Wash" then
		Card.close()
		Wash.start(info)
	elseif kind == "WashStep" then
		Wash.onStep(info)
	elseif kind == "WashPaid" then
		Wash.onPaid(info)
	elseif kind == "Detail" then
		Detail.onStart(info)
	elseif kind == "Dent" then
		Detail.onDent(info)
	elseif kind == "DetailPaid" then
		Detail.onPaid(info)
	elseif kind == "Rush" then
		Rush.onStart(info)
	elseif kind == "RushStep" then
		Rush.onStep(info)
	elseif kind == "RushLeg" then
		Rush.onLeg(info)
	elseif kind == "RushPaid" then
		Rush.onPaid(info)
	elseif kind == "Print" then
		Print.onShop(info)
	elseif kind == "PrintStep" then
		Print.onStep(info)
	elseif kind == "Printed" then
		Print.onPrinted(info)
	elseif kind == "Loaded" then
		Print.onLoaded(info)
	elseif kind == "Spotted" then
		sound("Spotted")
		local stars = tonumber(info.Stars) or 1
		NotifyController.Show(string.format("SPOTTED! %s (%d star%s). Lose them, or make the drop anyway.",
			info.How == "Tip" and "Somebody tipped off the police" or "A patrol saw the bags", stars, stars == 1 and "" or "s"), C.Danger, "police")
	elseif kind == "Laundered" then
		Print.onLaundered(info)
	elseif kind == "BagsLost" then
		sound("Failed")
		NotifyController.Show(string.format("The bags are gone: %s of dirty cash lost%s.", money(tonumber(info.Amount) or 0),
			info.Why == "Arrested" and " (the police took them)" or ""), C.Danger, "warning")
	elseif kind == "BagsBack" then
		NotifyController.Show("Bags unloaded back into the stock (" .. money(tonumber(info.Amount) or 0) .. ").", nil, "info")
	elseif kind == "Tour" then
		Tour.onTour(info)
	elseif kind == "TourGo" then
		Tour.onGo(info)
	elseif kind == "TourStop" then
		Tour.onStop(info)
	elseif kind == "TourPhotoOn" then
		Tour.onPhotoOn(info)
	elseif kind == "TourPhoto" then
		Tour.onPhoto(info)
	elseif kind == "TourMood" then
		Tour.onMood(info)
	elseif kind == "TourPaid" then
		Tour.onPaid(info)
	elseif kind == "TourSeat" then
		Job.place() -- (at the helm: the strip says ALL ABOARD next)
	elseif kind == "Vip" then
		Vip.onVip(info)
	elseif kind == "VipAboard" then
		Vip.onAboard(info)
	elseif kind == "VipPap" then
		Vip.onPap(info)
	elseif kind == "VipLost" then
		Vip.onLost(info)
	elseif kind == "VipComfort" then
		Vip.onComfort(info)
	elseif kind == "VipPaid" then
		Vip.onPaid(info)
	elseif kind == "Ended" then
		Job.finish(info)
	end
end

local function onResult(info)
	if type(info) ~= "table" then
		return
	end
	local def = defOf(info.Id)
	local short = def and def.Short or "business"
	local k = info.Kind
	if k == "Bought" and def then
		Card.close()
		sound("Success")
		HUDController.Stamp("YOU OWN IT", "The " .. def.Name .. " is yours", C.Gold, "EMPIRE")
		NotifyController.Show(def.Hint or "Press Manage at the door: START JOB to work there. The register fills while you play.", nil, "info")
	elseif k == "Upgraded" and def then
		sound("Success")
		local lv = def.Levels[Businesses.ClampLevel(info.Level)]
		HUDController.Stamp("LEVEL " .. tostring(info.Level), lv and lv.Adds or def.Name, C.Gold, string.upper(short))
	elseif k == "Collected" then
		sound("CashIn")
		NotifyController.Show("+" .. money(tonumber(info.Amount) or 0) .. " from your " .. short .. " register.", C.Cash, "money")
	elseif k == "Full" and def then
		NotifyController.Show("Your " .. short .. " register is full. Collect it!", C.Gold, "money")
	elseif k == "Customer" then
		sound("CashIn")
		NotifyController.Show(string.format("%s got %s at your %s +%s", tostring(info.Buyer or "Someone"), tostring(info.Service or "a shine"), short,
			money(tonumber(info.Amount) or 0)), C.Cash, "money")
	elseif k == "Shined" then
		sound("Success")
		NotifyController.Show("Sparkling clean for 30 minutes! (-" .. money(tonumber(info.Price) or 0) .. ")"
			.. (info.Owner and (" " .. tostring(info.Owner) .. " says thanks.") or ""), C.Cash, "success")
	elseif k == "ColdBrew" then
		sound("Success")
		local CB = Businesses.ColdBrew
		S.brewUntil = tonumber(info.Until) or S.brewUntil
		NotifyController.Show(string.format("Cold brew! +%d%% sprint stamina for %d minutes. (-%s)%s", math.floor(CB.Stamina * 100 + 0.5),
			math.floor(CB.Seconds / 60), money(tonumber(info.Price) or 0), info.Owner and (" " .. tostring(info.Owner) .. " says thanks.") or ""),
			C.Cash, "success")
	elseif k == "CrewCut" then
		sound("Cash")
		NotifyController.Show(string.format("%s worked your %s: +%s crew cut", tostring(info.Worker or "A crewmate"), short,
			money(tonumber(info.Amount) or 0)), C.Cash, "crew")
	elseif k == "BreakIn" and def then
		local untilT = tonumber(info.Until) or (serverNow() + Businesses.BreakIn.Time)
		local isMine = info.Owner == player.UserId
		S.alarm[def.Id] = { untilT = untilT, ownerName = info.OwnerName, mine = isMine }
		sound("Spotted")
		local where = isMine and ("your " .. short) or (tostring(info.OwnerName) .. "'s " .. short)
		NotifyController.Show(string.format("Someone's breaking into %s! Get there in %s: point a gun at them or knock them down.",
			where, clock(untilT - serverNow())), C.Danger, "police")
		if not S.job then
			Job.setGPS("Break-in: " .. (def.Brand or def.Name), Businesses.DoorPosition(def))
		end
	elseif k == "RobberStopped" then
		sound("CashIn")
		local left = tonumber(info.Left) or 0
		NotifyController.Show("Robber stopped! +" .. money(tonumber(info.Reward) or 0) .. (left > 0 and (" (" .. left .. " left)") or ""), C.Cash, "success")
	elseif k == "BreakInStopped" and def then
		S.alarm[def.Id] = nil
		if S.gpsName and string.sub(S.gpsName, 1, 9) == "Break-in:" then
			Job.clearGPS()
		end
		HUDController.Stamp("BREAK-IN STOPPED", info.Owner == player.UserId and ("Your " .. short .. " is safe") or
			(tostring(info.OwnerName) .. "'s " .. short .. " is safe"), C.Cash)
	elseif k == "BreakInLost" and def then
		S.alarm[def.Id] = nil
		if S.gpsName and string.sub(S.gpsName, 1, 9) == "Break-in:" then
			Job.clearGPS()
		end
		local amount = money(tonumber(info.Amount) or 0)
		NotifyController.Show(info.Owner == player.UserId and ("The robbers got away with " .. amount .. " from your " .. short .. " register.")
			or ("The robbers got away with " .. amount .. " from " .. tostring(info.OwnerName) .. "'s " .. short .. "."), C.Orange, "warning")
	elseif k == "Raid" or k == "RaidBreached" or k == "RaidSeized" or k == "RaidHeld" or k == "RaidOver" then
		Print.onRaid(info)
	elseif k == "RushHour" and def then
		-- RUSH HOUR at a café (yours, or the one you're working at): a stamp while you're on its job, else a toast.
		local secs = math.max(0, (tonumber(info.Until) or serverNow()) - serverNow())
		local boost = math.floor((tonumber(info.Boost) or Businesses.Rush.RushHour.TipBoost) * 100 + 0.5)
		local whose = info.Owner == player.UserId and ("your " .. (def.Brand or def.Name)) or (tostring(info.OwnerName or "your crewmate") .. "'s " .. (def.Brand or def.Name))
		if S.job and S.job.kind == "Rush" and S.job.id == def.Id then
			HUDController.Stamp("RUSH HOUR", string.format("+%d%% tips for %s", boost, clock(secs)), C.Orange, string.upper(def.Brand or def.Name))
		else
			sound("PhoneText")
			NotifyController.Show(string.format("RUSH HOUR at %s: +%d%% on every rush-order tip for %s!", whose, boost, clock(secs)), C.Orange, "money")
		end
	elseif k == "RushHourOver" and def then
		if S.job and S.job.kind == "Rush" and S.job.id == def.Id then
			NotifyController.Show("Rush hour's over. Tips are back to normal.", nil, "info")
		end
	elseif k == "Rented" then
		-- The jet ski rental (M4): its toast; the strip counts the time down (player attribute BizRentalUntil).
		sound("Success")
		local secs = math.max(0, (tonumber(info.Until) or serverNow()) - serverNow())
		NotifyController.Show(string.format("%s rented for %s! (-%s) Ride it anywhere on the water.%s", tostring(info.Label or "Jet ski"), clock(secs),
			money(tonumber(info.Price) or 0), info.Owner and (" " .. tostring(info.Owner) .. " says thanks.") or ""), C.Cash, "success")
	elseif k == "RentalWarn" then
		sound("PhoneText")
		NotifyController.Show(string.format("%s left on your %s rental!", clock(tonumber(info.Left) or 60), string.lower(tostring(info.Label or "jet ski"))),
			C.Orange, "warning")
	elseif k == "RentalOver" then
		local why = ({
			Time = "Time's up: your %s rental is over. Thanks for riding!",
			Left = "You left your %s, so it went back to the rental dock.",
			Gone = "Your rented %s is gone.",
			Arrested = "Your rented %s went back to the rental dock.",
		})[info.Why or ""]
		if why then
			NotifyController.Show(string.format(why, string.lower(tostring(info.Label or "jet ski"))), nil, "info")
		end
	elseif k == "ClubIn" then
		-- The Afterglow Nightclub (M5): in the club, the booth, the back room's wash.
		sound("Success")
		NotifyController.Show(info.Free and "Welcome to Afterglow! Dance, mingle, book a VIP booth. LEAVE takes you back out."
			or string.format("Welcome to Afterglow! (-%s) Your pass lets you back in free for %d minutes.%s", money(tonumber(info.Price) or 0),
				math.floor(Businesses.Club.CoverValid / 60), info.Owner and (" " .. tostring(info.Owner) .. " says thanks.") or ""), K.VIP_PINK, "success")
	elseif k == "ClubOut" then
		if info.Why == "Wanted" then
			NotifyController.Show("The bouncers put you out: you're wanted.", C.Danger, "police")
		end
	elseif k == "BoothBooked" then
		sound("Success")
		NotifyController.Show(string.format("The VIP booth is yours and your crew's for %s!%s", clock((tonumber(info.Until) or serverNow()) - serverNow()),
			info.Free and " (On the house: it's your club.)" or (" (-" .. money(tonumber(info.Price) or 0) .. ")")), K.MEDAL.Gold, "success")
	elseif k == "BoothCrew" then
		NotifyController.Show(string.format("%s booked the VIP booth at Afterglow for the crew (%s)!", tostring(info.Name or "Your crewmate"),
			clock((tonumber(info.Until) or serverNow()) - serverNow())), C.Purple, "crew")
	elseif k == "BoothWarn" then
		NotifyController.Show(clock(tonumber(info.Left) or 60) .. " left on your VIP booth!", C.Orange, "warning")
	elseif k == "BoothOver" then
		NotifyController.Show("Your VIP booth time is up. Thanks for partying at Afterglow!", nil, "info")
	elseif k == "Washed" then
		sound("CashIn")
		Job.countUp(tonumber(info.Amount) or 0)
		HUDController.Stamp("WASHED", "Through the tills, clean · " .. money(tonumber(info.Dirty) or 0) .. " still in the safe", C.Cash, "BACK ROOM",
			{ Cash = tonumber(info.Amount) or 0 })
	elseif k == "RankUp" then
		sound("Success")
		HUDController.Stamp("EMPIRE RANK " .. tostring(info.Rank), info.Unlock and ("Unlocked: " .. tostring(info.Unlock)) or "Keep building your empire", C.Gold, "EMPIRE")
	elseif k == "No" then
		local text = K.MSG[info.Reason or ""]
		if info.Reason == "Locked" and def then
			text = "Reach Empire rank " .. def.Unlock .. " to buy the " .. def.Name .. "."
		elseif info.Reason == "WashWait" then
			text = "The tills can only hide so much at once: WASH again in " .. clock(tonumber(info.Left) or 0) .. "."
		end
		if text then
			NotifyController.Show(text, nil, "warning")
		end
		S.afterWait = nil
		Wash.show() -- (NEXT CAR / DELIVER refused after a wash: the AFTER panel comes back; Detail.backTick after a delivery)
	end
	local phone = other("PhoneUI")
	if phone and type(phone.Refresh) == "function" then
		pcall(phone.Refresh, "Empire")
	end
end

local function onState(info)
	if type(info) ~= "table" then
		return
	end
	S.state = info
	if S.card then
		Card.fill()
	end
	Fx.dressAll()
	local phone = other("PhoneUI")
	if phone and type(phone.Refresh) == "function" then
		pcall(phone.Refresh, "Empire")
	end
end

local function readOwners()
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(ReplicatedStorage:GetAttribute("BizOwners") or "{}")
	end)
	S.owners = (ok and type(decoded) == "table") and decoded or {}
	Fx.dressAll()
end

------------------------------------------------------------------ robbers (poses, and a gun pointed at one)

function Fx.robbers()
	local npcs = Workspace:FindFirstChild("NPCs")
	if not npcs then
		return
	end
	local combat = other("CombatClient")
	local aiming, from, look, gunAt = false, nil, nil, nil
	if combat and type(combat.Aiming) == "function" then
		local ok, a, f, l, g = pcall(combat.Aiming)
		if ok then
			aiming, from, look, gunAt = a, f, l, g
		end
	end
	for _, m in ipairs(npcs:GetChildren()) do
		if m.Name == "BizRobber" and m:IsA("Model") then
			-- The pose (PoseClient, if it's there).
			local want = m:GetAttribute("Pose")
			local shown = S.robberPoses[m]
			if (shown and shown.name or nil) ~= want then
				if shown and shown.handle then
					pcall(function()
						shown.handle:Stop()
					end)
				end
				local handle
				local pose = want and other("PoseClient")
				if pose then
					pcall(function()
						handle = pose.Play(m, want)
					end)
				end
				S.robberPoses[m] = want and { name = want, handle = handle } or nil
			end
			-- A gun on it: ask the server to scare it off (it checks it's yours or your crewmate's).
			local head = m:FindFirstChild("Head")
			if aiming and head and m:GetAttribute("NPCKind") == "BizRobber" and look and os.clock() - S.lastScare >= K.SCARE_GAP then
				local owner = Players:GetPlayerByUserId(m:GetAttribute("BizOwner") or 0)
				local to = head.Position - (from or head.Position)
				local reach = (head.Position - (gunAt or head.Position)).Magnitude
				if (owner == player or isCrewmate(owner)) and reach <= K.SCARE_REACH and to.Magnitude > 1 and to.Unit:Dot(look) > K.SCARE_CONE then
					S.lastScare = os.clock()
					request("Scare", nil, m)
				end
			end
		end
	end
end

------------------------------------------------------------------ public

function BusinessClient.On()
	return S.on
end

-- A card, or the wash mini-game while a car is in the bay (CombatClient and InteractClient ask).
function BusinessClient.IsOpen()
	if S.card ~= nil and ui.card ~= nil and ui.card.Visible then
		return true
	end
	-- Only while you're actually washing: the AFTER panel (NEXT CAR / DELIVER / END, stage "paid") and waiting for
	-- a car ("wait", "arrive") don't count, so F still gets you into your car and a gun still comes up for a
	-- break-in (the review found both blocked).
	-- The rush orders' GRAB hold, while it shows at the shelf (its F is ours, and a gun stays down there).
	if S.job ~= nil and (S.job.kind == "Rush" or S.job.kind == "Print") and ui.hold ~= nil and ui.hold.Visible then
		return true -- (and the Print Shop's HOLD at a station or the cash cart)
	end
	local w = S.wash
	return w ~= nil and w.stage ~= "arrive" and w.stage ~= "paid" and w.stage ~= "wait"
end

function BusinessClient.Owned()
	local list = {}
	for _, def in ipairs(Businesses.List) do
		local e = def.Enabled and mine(def.Id)
		if e then
			-- A shady business's dirty cash and raid, as the line under its name (PhoneUI shows Extra there).
			local extra, extraColor
			local dirty, stock = tonumber(e.Dirty) or 0, tonumber(e.Stock) or 0
			if def.Kind == "Shady" or def.BackRoom then
				local r = S.raids[def.Id]
				local word = def.BackRoom and "BACK ROOM" or "DIRTY"
				if type(r) == "table" and r.o == player.UserId then
					extra = string.format("RAID! %s  ·  %s %s", clock((tonumber(r.u) or serverNow()) - serverNow()), word, money(dirty))
					extraColor = C.Danger
				elseif def.BackRoom then
					-- (M5: the club's night x2 and its back room)
					extra = string.format("+$%d a minute%s  ·  %s %s / %s", math.floor((tonumber(e.Rate) or 0) + 0.5), e.Night and " (NIGHT ×2)" or "", word,
						money(dirty), money(stock))
				else
					extra = string.format("+$%d a minute  ·  DIRTY %s / %s", math.floor((tonumber(e.Rate) or 0) + 0.5), money(dirty), money(stock))
				end
			end
			table.insert(list, {
				Id = def.Id, Name = def.Name, Short = def.Short, Level = Businesses.ClampLevel(e.Level), Register = liveRegister(def.Id),
				Cap = tonumber(e.Cap) or 0, Rate = tonumber(e.Rate) or 0, Busy = e.Busy == true, Next = tonumber(e.Next),
				Lifetime = tonumber(e.Lifetime) or 0, JobsDone = tonumber(e.JobsDone) or 0, Pos = Businesses.DoorPosition(def),
				Dirty = (def.Kind == "Shady" or def.BackRoom) and dirty or nil, Stock = (def.Kind == "Shady" or def.BackRoom) and stock or nil, Extra = extra,
				ExtraColor = extraColor,
			})
		end
	end
	return list
end

function BusinessClient.ForSale()
	local list = {}
	local rank = empireRank()
	for _, def in ipairs(Businesses.List) do
		if def.Enabled and def.Position and not mine(def.Id) then
			local locked = not Businesses.Unlocked(def, rank)
			table.insert(list, {
				Id = def.Id, Name = def.Name, Price = def.Price, Unlock = def.Unlock or 1, Locked = locked,
				Pos = Businesses.DoorPosition(def), Trickle = def.Levels[1].Trickle,
				-- (M4: a business that needs a higher Empire rank says so first: "Unlocks at Empire 2")
				JobLine = locked and string.format("Unlocks at Empire %d (you're %d) · %s", def.Unlock or 1, rank, def.JobLine or "") or def.JobLine,
			})
		end
	end
	return list
end

function BusinessClient.ComingSoon()
	local list = {}
	for _, def in ipairs(Businesses.List) do
		if not def.Enabled then
			table.insert(list, { Id = def.Id, Name = def.Name, Price = def.Price, Unlock = def.Unlock or 1, JobLine = def.JobLine, Kind = def.Kind })
		end
	end
	return list
end

function BusinessClient.Empire()
	local xp = empireXP()
	local rank, share, into, need = Businesses.RankProgress(xp)
	local nextUnlock
	for r = rank + 1, E.MaxRank do
		if E.Unlocks[r] then
			nextUnlock = "Rank " .. r .. ": " .. E.Unlocks[r]
			break
		end
	end
	return { Rank = rank, XP = math.floor(xp), Share = share, Into = math.floor(into), Need = need, Next = nextUnlock,
		Title = player:GetAttribute("EmpireTitle"), RemoteCollect = rank >= E.RemoteCollect, RemoteRank = E.RemoteCollect }
end

function BusinessClient.RouteTo(id)
	local def = defOf(id)
	if not def or not def.Position then
		return false
	end
	GPSClient.SetTarget(def.Name, Businesses.DoorPosition(def))
	return true
end

function BusinessClient.Collect(id)
	request("Collect", id, "Remote")
end

-- The businesses' map blips (MinimapClient, MapClient): your own get a gold ring, a break-in flashes red.
function BusinessClient.MapBlips()
	local list = {}
	if not S.on then
		return list
	end
	local alarms = {}
	for id in string.gmatch(player:GetAttribute("BizAlarm") or "", "[^,]+") do
		alarms[id] = true
	end
	for _, def in ipairs(Businesses.List) do
		if def.Enabled and def.Position then
			table.insert(list, {
				Id = def.Id, Name = def.Name, Pos = Businesses.DoorPosition(def), Letter = def.MapLetter or "$",
				Color = def.MapColor or C.Gold, Owned = mine(def.Id) ~= nil, Alarm = alarms[def.Id] == true,
			})
		end
	end
	return list
end

------------------------------------------------------------------ start

local function build()
	ui.gui = Instance.new("ScreenGui")
	ui.gui.Name = "Business"
	ui.gui.ResetOnSpawn = false
	ui.gui.IgnoreGuiInset = true
	ui.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	ui.gui.DisplayOrder = K.DISPLAY_ORDER
	ui.gui.Parent = player:WaitForChild("PlayerGui")
	Card.build()
	Job.build()
	Print.build()
	Tour.build()
end

local function start()
	S.on = true
	build()
	Remotes.OnClient("BusinessCard", function(info)
		if type(info) == "table" then
			Card.open(info)
		end
	end)
	Remotes.OnClient("BusinessState", onState)
	Remotes.OnClient("BusinessResult", onResult)
	Remotes.OnClient("BusinessJob", onJob)
	request("State")
	readOwners()
	ReplicatedStorage:GetAttributeChangedSignal("BizOwners"):Connect(readOwners)
	readRaids()
	ReplicatedStorage:GetAttributeChangedSignal("BizRaids"):Connect(readRaids)
	-- Crews change who counts as "your crewmate" for the props and the plates.
	ReplicatedStorage:GetAttributeChangedSignal("Crews"):Connect(Fx.dressAll)
	player:GetAttributeChangedSignal("Crew"):Connect(Fx.dressAll)
	Workspace:GetAttributeChangedSignal("BizTestCrew"):Connect(Fx.dressAll)
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		if S.card then
			Card.fill()
		end
	end)
	player:GetAttributeChangedSignal("EmpireXP"):Connect(function()
		local phone = other("PhoneUI")
		if phone and type(phone.Refresh) == "function" then
			pcall(phone.Refresh, "Empire")
		end
	end)
	player:GetAttributeChangedSignal("InHome"):Connect(function()
		if player:GetAttribute("InHome") == true then
			Card.close()
		end
	end)
	player:GetAttributeChangedSignal("BizClub"):Connect(function()
		Card.close() -- (M5: in or out of the club: LEAVE in END JOB's place while you're in)
		local rain = Club.rain()
		if rain and not Club.inside() then
			-- (out again: the rain as HouseClient would have it)
			rain.Enabled = player:GetAttribute("InHome") ~= true and player:GetAttribute("InApartment") == nil
		end
		if not S.job then
			ui.endJob.Visible = Club.inside()
			ui.endJob.Text = Club.inside() and "LEAVE" or "END JOB"
		end
		Job.place()
	end)
	-- Level props as they stream in, and again after SkyClient switches the night lights (it would light a
	-- hidden prop's lamp).
	CollectionService:GetInstanceAddedSignal("BizProp"):Connect(function(part)
		if part:IsA("BasePart") then
			Fx.setProp(part, Fx.propWanted(part))
		end
	end)
	Workspace:GetAttributeChangedSignal("IsNight"):Connect(function()
		task.delay(0.3, Fx.applyProps)
		task.delay(8, Fx.applyProps) -- (after the dusk wave)
	end)
	task.spawn(function()
		local shops = Workspace:WaitForChild("Shops", 60)
		if shops then
			shops.DescendantAdded:Connect(function(d)
				if d:IsA("Model") and d:GetAttribute("BusinessId") then
					task.defer(Fx.dressSite, d)
				elseif d.Name == "OwnerPlate" or d.Name == "BusinessDoor" then
					local m = d:FindFirstAncestorWhichIsA("Model")
					while m and not m:GetAttribute("BusinessId") do
						m = m:FindFirstAncestorWhichIsA("Model")
					end
					if m then
						task.defer(Fx.dressSite, m)
					end
				end
			end)
			Fx.dressAll()
		end
	end)
	-- Re-place for a new screen size or kind of input (the phone layout).
	local function replace()
		if S.card then
			Card.layout()
		end
		Job.place()
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(replace)
	UserInputService.LastInputTypeChanged:Connect(replace)
	player:GetAttributeChangedSignal("PreviewTouch"):Connect(replace)
	-- Keys: the card (X / B close, Enter / Y its first button) and HOLD (F / RT).
	UserInputService.InputBegan:Connect(function(input, processed)
		local key = input.KeyCode
		local hum = myHum()
		local seated = hum ~= nil and hum.SeatPart ~= nil
		if S.card and not seated then
			if key == Enum.KeyCode.ButtonB or (key == Enum.KeyCode.X and not processed) then
				Card.close()
				return
			end
			if not processed and not RobloxMenu.IsOpen()
				and (key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter or key == Enum.KeyCode.ButtonY) then
				local fn = S.actions[1]
				if fn and ui.buttons[1].Visible then
					fn()
				end
				return
			end
		end
		if (S.wash or Rush.canGrab() or Print.canHold()) and not seated and not processed and (key == Enum.KeyCode.F or key == Enum.KeyCode.ButtonR2) then
			Job.holdBegin()
		end
		-- The shift report: Enter / gamepad Y = CONTINUE, X / gamepad B = DONE (never from behind Roblox's menu).
		if S.report and ui.report.Visible and not S.card and not processed and not RobloxMenu.IsOpen() then
			if key == Enum.KeyCode.Return or key == Enum.KeyCode.KeypadEnter or key == Enum.KeyCode.ButtonY then
				Job.reportContinue()
			elseif key == Enum.KeyCode.X or key == Enum.KeyCode.ButtonB then
				Job.reportClose()
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local h = Job.holding()
		if not h then
			return
		end
		if h.pointer then
			if input == h.pointer or input.UserInputType == Enum.UserInputType.MouseButton1 and h.pointer.UserInputType == Enum.UserInputType.MouseButton1 then
				Job.holdEnd()
			end
		elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
			Job.holdEnd()
		end
	end)
	-- The cold brew's "wore off" toast (the attribute is the server's).
	player:GetAttributeChangedSignal("ColdBrewUntil"):Connect(function()
		local untilT = player:GetAttribute("ColdBrewUntil")
		S.brewUntil = type(untilT) == "number" and untilT or nil
	end)
	-- Every frame: the hold bar. Four / five times a second: the card, the strip, prompts, robbers.
	RunService.RenderStepped:Connect(function()
		Wash.step()
		Wash.spread() -- (only while scrubbing: SCRUB buttons kept apart on screen)
		Rush.step()
		Print.step()
	end)
	local lastFast, lastSlow = 0, 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastFast >= 0.2 then
			lastFast = now
			local ok, err = pcall(function()
				local c = S.card
				if c then
					local root = myRoot()
					local hum = myHum()
					local def = defOf(c.id)
					-- (the server's own rule for the buttons: within Reach of the lot's middle; a little inside it)
					local d = root and (root.Position - def.Position)
					if not root or not def or (hum and hum.SeatPart) or math.abs(d.Y) > 25
						or flat(d).Magnitude > Businesses.Reach - 2 then
						Card.close()
					else
						Card.live()
					end
				end
				for id, a in pairs(S.alarm) do
					if a.untilT < serverNow() - 2 then
						S.alarm[id] = nil
					end
				end
				Rush.tick()
				Print.tick()
				Detail.backTick()
				Tour.tick()
				Vip.tick()
				Club.tick()
				Job.strip()
				-- The shift report goes when you sit down (getting in your car).
				if ui.report.Visible then
					local h = myHum()
					if h and h.SeatPart then
						Job.reportClose()
					end
				end
				if S.job then
					Job.place()
				end
				Fx.prompts()
				Fx.robbers()
				Print.raidFx()
			end)
			if not ok then
				warn("[BusinessClient] " .. tostring(err))
			end
		end
		if now - lastSlow >= 1 then
			lastSlow = now
			local ok, err = pcall(Fx.shineTick)
			if not ok then
				warn("[BusinessClient] shine: " .. tostring(err))
			end
			local okCash, errCash = pcall(Print.cash)
			if not okCash then
				warn("[BusinessClient] print shop: " .. tostring(errCash))
			end
			if S.brewUntil and serverNow() >= S.brewUntil then
				S.brewUntil = nil
				NotifyController.Show("Your cold brew wore off.", nil, "info")
			end
			-- The EMPIRE app's registers keep filling while it's open: redraw it every few seconds.
			S.appTick = (S.appTick or 0) + 1
			if S.appTick % 5 == 0 and next(S.state and S.state.List or {}) ~= nil then
				local phone = other("PhoneUI")
				if phone and type(phone.Refresh) == "function" then
					pcall(phone.Refresh, "Empire")
				end
			end
		end
	end)
	-- A new character: the wash's local car and buttons go (the server ends the job too).
	player.CharacterAdded:Connect(function()
		Card.close()
	end)
end

function BusinessClient.Init()
	-- Off until the server says the feature runs here (the launch switch).
	-- (No timeout: a slow server start used to leave this device without businesses for the session.)
	local started = false
	local function tryStart()
		if started or ReplicatedStorage:GetAttribute("BusinessesOn") ~= true then
			return
		end
		started = true
		local ok, err = pcall(start)
		if not ok then
			warn("[BusinessClient] failed to start: " .. tostring(err))
		end
	end
	ReplicatedStorage:GetAttributeChangedSignal("BusinessesOn"):Connect(tryStart)
	tryStart()
end

return BusinessClient
