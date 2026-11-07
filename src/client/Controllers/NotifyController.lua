-- NotifyController (ModuleScript, StarterPlayerScripts.Controllers.NotifyController)
-- Personal toast messages in the HUD's Toasts zone ("street" look, Shared.Util.Theme): small flat dark
-- cards with a thin coloured bar down the left edge and a small icon for the category (warning !,
-- police ★, prison #, money $, success ✓, info i, crew +), white Body text. Colour means something:
-- orange = a problem, red = the cops, green = cash / done, gold = a reward, grey = information.
-- A card slides in and fades in, then fades out after ~4 s; at most 3 show at once.
--   PC / gamepad: bottom-left, the stack grows UP from just above the minimap (newest at the bottom),
--     never higher than SPLIT of the screen height (the Coast Feed's column comes down to there).
--   Phone: top-left, the stack grows DOWN from under the minimap and vitals (newest on top) and stops
--     well above Roblox's thumbstick. The Coast Feed's posts join this same stack on phones, and on a PC
--     whose chat window covers the feed's own column (Stack, as "low" cards).
--   When the stack runs out of room (or has 3 cards) a card goes: the oldest feed post first, else the
--   oldest toast. Your own toasts always win over feed posts, so a post that finds the stack full of
--   them is dropped (it stays in the phone's Feed app); otherwise the newest card always shows. It is
--   re-placed when the screen size or input type changes.
-- The server sends a key (never raw text); the words live in Messages so they're easy to change.
-- Toasts never take touches (Active = false, no buttons), so they can't block a tap on a phone.
-- Public API:
--   NotifyController.Messages                      key -> text
--   NotifyController.Categories                    key -> category ("warning", "police", "prison",
--                                                  "money", "success", "info", "crew")
--   NotifyController.Show(text, color?, category?) a toast. color: optional accent for non-alert
--                                                  categories (old neon colours are fine: see Tone);
--                                                  category: guessed from the words when left out.
--   NotifyController.Stack(slot, fade, lifetime?, low?)  put a ready-made card in the stack
--                                                  (FeedController): slot = a Frame (Size 1,0,0,0,
--                                                  AutomaticSize Y) holding a Frame "Card"; fade = {
--                                                  [instance] = { prop = hidden value } } for every property
--                                                  that fades in and out (built in its shown state);
--                                                  lifetime in seconds; low = true for a card that gives way
--                                                  to toasts (feed posts). The slot is destroyed if it
--                                                  can't get in.
--   NotifyController.Tone(color) -> the Theme colour that means the same as a caller's colour (old neon
--                                                  pink / mint / gold / orange / red...), or nil for none
--                                                  (the old cyan "info" colour also gives nil).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local Theme = require(ReplicatedStorage.Shared.Util.Theme)

local player = Players.LocalPlayer

local NotifyController = {}

NotifyController.Messages = {
	CarSank = "Your car sank! Tap CAR to get it back.",
	CarRemoved = "Your car was removed.",
	NoCarWhileWanted = "The cops can see you! Break line of sight before calling a car.",
	CarCooldown = "Your car is on its way... try again in a few seconds.",
	CarNoRoom = "No room for your car here. Try an open road.",
	CopsFull = "The police force is full right now. Try again in a moment!",
	TeamHasHeat = "Lose your heat before going on or off duty.",
	TeamInPrison = "You can't go on duty from prison.",
	TeamCooldown = "Wait a few seconds before switching duty again.",
	ShakeCopsFirst = "The cops can see you! Lose them before you bank.",
	LostTheCops = "You lost the cops! Heat cleared.",
	RookieChase = "First job: the cops go easy on you. Drive away and get out of sight to lose them!",
	SpinUsed = "You've had today's free spin. The Lucky Wheel gives you another one tomorrow!",
	SpinLoading = "Your save is still loading. Try the wheel again in a moment.",
	WheelBusy = "Someone's spinning the Lucky Wheel. Wait for it to stop, then it's your turn!",
	WheelTooFar = "Step up to the Lucky Wheel's podium to spin.",
	TiresPopped = "Tires popped! You're slow for a few seconds.",
	NoSpikes = "No spike strips left. They recharge every 30 seconds.",
	Released = "You served your time. Welcome back to Port Solana.",
	VentJammed = "The vent is jammed. Try again in a few seconds.",
	Disguised = "New look! The cops lost your description. (-1 star)",
	Resprayed = "Fresh paint! -$500, and the cops lost your car. (-1 star)",
	SprayNoCash = "Spray & Go costs $500. Bank some cash first.",
	CarBoosted = "Car boosted! Deliver it to the Chop Shop at the Docks.",
	NoSmoke = "Smoke is recharging (30 seconds).",
	RaceNeedCar = "Races start in your own car. Drive onto the pad!",
	RaceNeedBoat = "This race is on the water: bring a boat (PHONE > GARAGE > LAUNCH).",
	TrackerPing = "This car had a GPS tracker! The cops know where you are.",
	CarNotOwned = "You don't own that car yet. Visit AutoNeon Motors downtown (PHONE > GPS > PLACES)!",
	BuyAtDealer = "Cars are sold at AutoNeon Motors downtown and boats at Marina Boat Sales (PHONE > GPS > PLACES).",
	NotEnoughCash = "Not enough cash for that.",
	CarNeedsPass = "That car comes with a game pass.",
	CarNeedsRank = "Reach police rank 5 to unlock that car.",
	NeedsPass_VIP = "That paint comes with the VIP pass (PHONE > SHOP).",
	NeedsPass_NeonGarage = "That glow color comes with the Neon Garage pass (PHONE > SHOP).",
	NeedsUnlock_Streak7 = "Log in 7 days in a row to unlock Streak Sunset paint!",
	NeedsUnlock_CivRank10 = "Reach free-roam rank 10 to unlock Neon Legend paint.",
	NeedsUnlock_CopRank10 = "Reach police rank 10 to unlock the Midnight Blue livery.",
	NeedsUnlock_Rank20 = "Reach rank 20 to unlock gold rims.",
	BankNeedsRank = "The Coastal Bank needs free-roam rank 3. Earn XP by robbing stores, racing, stunts, taxi/courier jobs and missions (PHONE > GOALS).",
	NeedPrep_CoastalBank = "The vault's locked tight. Cut the power first: the fuse box is on the bank's east wall.",
	NeedPrep_SeaDream = "The yacht's alarm is armed. Disable the security panel on the boarding deck first.",
	CrewJoined = "Crew updated! Rob together for +20% cash.",
	TreasureFound = "You dug up some treasure! Cash added.",
	CarMeetLike = "Someone liked your ride! +$150",
	CarMeetFan = "A fan loved your ride! +$150",
	MissionBusy = "Finish what you're doing first (and lose any heat).",
	MissionCooldown = "Take a breather: new missions in a few seconds.",
	UFOWave = "They waved back. +$500 (don't tell anyone)",
	CrewLeft = "Someone left your crew.",
	CrewFull = "That crew is full (4 max).",
	CrewInviteSent = "Invite sent!",
	CrewInvitePending = "They already have an invite waiting.",
	CrewDeclined = "Your crew invite was declined.",
	HomeWanted = "Lose the cops first! You can't go home while you're wanted.",
	ApartmentWanted = "Lose the cops before you head upstairs.",
	HomeAlreadyOwned = "This is already your home! Press Enter home at the door.",
	HomeUseGarage = "You're at home: pick a car in your garage, or step outside first.",
	HomeTooFar = "Walk up to the front door to buy this home.",
	CombatInCar = "Hop out of your car first.",
	NoGunToAim = "No gun to aim yet: Coast Arms sells them (PHONE > GPS). [X] punches.",
	PoliceOnFoot = "Police on foot! They taser runners: put your hands up (HANDS UP) to give up without a fight.",
	CoastGuard = "Coast Guard on the way! Their boats chase you on the water: head for land to lose them.",
	CoastGuardSwim = "The Coast Guard is pulling you out of the water!",
	PoliceHeli = "Police helicopter incoming! Hide from it (tunnels, bridges, garages) or outrun it.",
	RaceChallengeLevel = "Line up side by side first, then challenge again.",
	StoreRobHint = "Point your gun at the clerk to rob the store (hold [Z] or right mouse).",
	StoreRobLeft = "You walked out: the clerk ducked behind the counter. No bag.",
	StoreRobOff = "The robbery's off.",
	StoreRobClerkDown = "The clerk's down: nobody to fill the bag. Hold [Rob] at the till to grab it yourself.",
	DrillBusy = "Someone's drill is already on this safe.",
	DrillJammed = "You left the drill and it jammed. Set it again.",
	SurrenderNoPolice = "Hands up for who? No police nearby.",
	CombatSafeZone = "No fighting in safe zones: spawns, shops, homes, the Hideout and Police HQ.",
	CombatPassiveYou = "You're in passive mode. Turn it off in PHONE > SETTINGS to fight.",
	CombatPassiveThem = "That player is in passive mode: they can't be hit.",
	CombatSpawnYou = "You just arrived! You can fight in a few seconds.",
	CombatSpawnThem = "They just arrived. Give them a few seconds.",
	CombatPrisoner = "Prisoners can't be hit.",
	PassiveOn = "Passive mode ON: nobody can hit you, and you can't fight.",
	PassiveOff = "Passive mode OFF. Fists up!",
	PassiveHasHeat = "Lose your heat before going passive.",
	PassiveHasBag = "Bank your bag at the Hideout before going passive.",
	PassiveInFight = "You can't go passive in the middle of a fight!",
	PassiveCooldownOn = "You just turned passive mode off. You can turn it back on in a minute.",
	PassiveCooldownOff = "Passive mode just started. You can turn it off in a few seconds.",
	PassiveCop = "Cops on duty can't use passive mode.",
	PassiveAutoOff = "Passive mode is off: you're up to no good now!",
	PassiveNotRestored = "Passive mode didn't come back on: you were wanted, carrying a bag or in a fight. Turn it on in PHONE > SETTINGS.",
	CopHoldFire = "Hold fire: not wanted.",
	GunShopTooFar = "Walk up to the Coast Arms counter to buy.",
	GunShopCivOnly = "Coast Arms only sells to free-roam players.",
	GunOwned = "You already own that one. It's in your hotbar.",
	GunNeedsRank = "That one needs a higher free-roam rank.",
	ArmorFull = "Your body armor is already full.",
	PedsQuiet = "The street has gone quiet. Wallets are empty for a while.",
	DroppedBagFull = "Your bag is full! Bank it at the Hideout before grabbing more.",
	CombatSwimming = "Swim to shore first: no fighting from the water.",
	CuffTooFast = "Too fast to cuff! Taser runners, or wait for drivers to stop.",
	CopDazed = "You're still seeing stars! Wait a moment, then try again.",
	PrepTaken = "Another crew just did this step! Check the panel's timer: it frees up in under 45 seconds.",
	PrepAlreadyDone = "Your crew already did this step! Go start the main job before the window runs out.",
	JobNeedCar = "Shifts start in your own car: drive onto the stand or depot!",
	ActivityCivOnly = "Races and job shifts are for free-roam players only.",
	ActivityWanted = "Lose the cops first! No races or job shifts while you're wanted.",
	JackCooldown = "Easy there! Wait a few seconds before taking another car.",
	JackBlocked = "Something's in the way of that car. Try another one!",
	JackTooClose = "The Chop Shop won't buy a car taken right outside. Bring one from across town!",
	JackSaleCooldown = "The Chop Shop just bought a street car from you. Bring the next one in a couple of minutes!",
	GetOutFirst = "Get out of your car first (F or EXIT), then try again.",
	PedLootSafe = "You can't take wallets inside a safe zone.",
	ResetCuffed = "Resetting with the cops this close counts as giving up. You're cuffed!",
	ShotCuffed = "Shot down with the cops right there: you're under arrest!",
	MissionCivOnly = "Missions are for free-roam players only.",
	FriendArrived = "Your friend just joined your server!",
	FriendArrivedCrew = "Your friend just joined! We sent them a crew invite.",
	FriendMeetup = "You spawned right next to your friend. Have fun!",
	FriendInServer = "Your friend is in this server! Open the CREW app to team up.",
	FriendJoinFailed = "Couldn't join that server. Try again in a moment!",
	FriendServerFull = "That server is full. Try again later!",
	FriendJoinWanted = "Lose the cops before joining a friend.",
	FriendJoinBag = "Bank your bag cash first: it can't come with you!",
	FriendJoinPrison = "No leaving prison to visit friends!",
	FriendJoinStudio = "Joining friends only works in the live game.",
	CoplayBonus = "Co-op bonus: +$2,000 for playing with a friend today!",
	SquadUnlocked = "Squad paint unlocked for playing with friends on 3 days! Find it in GARAGE > STYLE.",
	NeedsUnlock_Squad = "Play with a Roblox friend on 3 different days to unlock Squad paint.",
	CarNeedsHeists = "That ride unlocks after more big heists (Coastal Bank or Sea Dream). The dealer shows how many!",
	TuneWanted = "The cops can see you! Lose them before tuning.",
	DriftZoneNear = "Drift zone ahead! Slide your car sideways on the pad to earn cash.",
	-- The Big Score (BigScoreService, started from PHONE > CREW)
	BigScoreNeedCrew = "The Big Score needs a crew of 2 or more free-roam players who are ready. Invite people in PHONE > CREW.",
	BigScoreRank = "The Big Score unlocks at free-roam rank 3. Earn XP with robberies, races, jobs and missions (PHONE > GOALS).",
	BigScoreCooldown = "You're laying low after the last big job. PHONE > CREW shows when you can go again.",
	BigScoreBusy = "A crew is on the Big Score right now. Try again once it's over!",
	BigScoreCivOnly = "The Big Score is for free-roam players only.",
	BigScoreWanted = "Lose the cops before you start the Big Score.",
	BigScoreSync = "Too slow! Both gate consoles have to be held at the same time. Count it down together and try again.",
	BigScoreLoseCops = "The cops can see you! Break line of sight before you drive the van into the Hideout.",
	BigScoreNotYours = "That's another crew's job. Only the Big Score crew can do that.",
	BigScoreCarrying = "You're already carrying a gold bar. Load it into the van first!",
	BigScoreVanFar = "Back the van up closer to the vault door, then load the gold.",
	BigScoreNoBars = "No gold left on the pile!",
	-- Street races with others and race challenges (RaceService)
	RaceLobbyIn = "You're in this race already. It starts when the banner's countdown ends.",
	RaceLobbyFull = "That race is full. Catch the next one!",
	RaceLobbyLeft = "You drove away from the start, so you're out of that race.",
	RaceGridFull = "No room on the starting grid: you're out of this race.",
	RaceSpotted = "The cops spotted the race! Finish it, then lose them.",
	RaceChallengeNeedCar = "Race challenges are made from the wheel of your own car.",
	RaceChallengeNoOne = "No driver close enough to challenge. Pull up next to one!",
	RaceChallengeBusy = "That driver already has a race challenge waiting.",
	RaceChallengeWait = "Wait for an answer to your last race challenge first.",
	RaceChallengeCooldown = "They just said no. Give them a moment before you ask again.",
	RaceChallengeGone = "Your rival isn't close enough for a rematch.",
	RaceChallengeOff = "The race challenge is off.",
	RaceChallengeFar = "Too far apart to race: pull up next to each other and try again.",
	RaceChallengeNoRoute = "No race route from here. Try again on a bigger road!",
}

-- Which icon / accent each server key uses. A key missing here (new keys added later) gets its
-- category guessed from its words, so forgetting to add one here still looks sensible.
NotifyController.Categories = {
	CarSank = "warning",
	CarRemoved = "info",
	NoCarWhileWanted = "police",
	CarCooldown = "info",
	CarNoRoom = "warning",
	CopsFull = "info",
	TeamHasHeat = "police",
	TeamInPrison = "prison",
	TeamCooldown = "info",
	ShakeCopsFirst = "police",
	LostTheCops = "success",
	RookieChase = "police",
	SpinUsed = "info",
	SpinLoading = "info",
	WheelBusy = "info",
	WheelTooFar = "info",
	TiresPopped = "police",
	NoSpikes = "warning",
	Released = "prison",
	VentJammed = "prison",
	Disguised = "success",
	Resprayed = "success",
	SprayNoCash = "money",
	CarBoosted = "success",
	NoSmoke = "info",
	RaceNeedCar = "info",
	RaceNeedBoat = "info",
	TrackerPing = "police",
	CarNotOwned = "info",
	BuyAtDealer = "info",
	NotEnoughCash = "money",
	CarNeedsPass = "info",
	CarNeedsRank = "info",
	NeedsPass_VIP = "info",
	NeedsPass_NeonGarage = "info",
	NeedsUnlock_Streak7 = "info",
	NeedsUnlock_CivRank10 = "info",
	NeedsUnlock_CopRank10 = "info",
	NeedsUnlock_Rank20 = "info",
	BankNeedsRank = "info",
	NeedPrep_CoastalBank = "warning",
	NeedPrep_SeaDream = "warning",
	CrewJoined = "crew",
	TreasureFound = "money",
	CarMeetLike = "money",
	CarMeetFan = "money",
	MissionBusy = "warning",
	MissionCooldown = "info",
	UFOWave = "money",
	CrewLeft = "crew",
	CrewFull = "crew",
	CrewInviteSent = "crew",
	CrewInvitePending = "crew",
	CrewDeclined = "crew",
	HomeWanted = "police",
	ApartmentWanted = "police",
	HomeAlreadyOwned = "info",
	HomeUseGarage = "info",
	HomeTooFar = "info",
	CombatInCar = "info",
	NoGunToAim = "info",
	PoliceOnFoot = "police",
	CoastGuard = "police",
	CoastGuardSwim = "police",
	PoliceHeli = "police",
	RaceChallengeLevel = "info",
	StoreRobHint = "info",
	StoreRobLeft = "warning",
	StoreRobOff = "warning",
	StoreRobClerkDown = "warning",
	DrillBusy = "info",
	DrillJammed = "warning",
	SurrenderNoPolice = "info",
	CombatSafeZone = "info",
	CombatPassiveYou = "info",
	CombatPassiveThem = "info",
	CombatSpawnYou = "info",
	CombatSpawnThem = "info",
	CombatPrisoner = "prison",
	PassiveOn = "success",
	PassiveOff = "info",
	PassiveHasHeat = "police",
	PassiveHasBag = "money",
	PassiveInFight = "warning",
	PassiveCooldownOn = "info",
	PassiveCooldownOff = "info",
	PassiveCop = "police",
	PassiveAutoOff = "warning",
	PassiveNotRestored = "info",
	CopHoldFire = "info",
	GunShopTooFar = "info",
	GunShopCivOnly = "info",
	GunOwned = "info",
	GunNeedsRank = "info",
	ArmorFull = "info",
	PedsQuiet = "warning",
	DroppedBagFull = "money",
	CombatSwimming = "info",
	CuffTooFast = "police",
	CopDazed = "warning",
	PrepTaken = "warning",
	PrepAlreadyDone = "info",
	JobNeedCar = "info",
	ActivityCivOnly = "info",
	ActivityWanted = "police",
	JackCooldown = "warning",
	JackBlocked = "warning",
	JackTooClose = "warning",
	JackSaleCooldown = "money",
	GetOutFirst = "warning",
	PedLootSafe = "info",
	ResetCuffed = "warning",
	ShotCuffed = "police",
	MissionCivOnly = "info",
	FriendArrived = "crew",
	FriendArrivedCrew = "crew",
	FriendMeetup = "crew",
	FriendInServer = "crew",
	FriendJoinFailed = "warning",
	FriendServerFull = "warning",
	FriendJoinWanted = "police",
	FriendJoinBag = "money",
	FriendJoinPrison = "prison",
	FriendJoinStudio = "info",
	CoplayBonus = "money",
	SquadUnlocked = "success",
	NeedsUnlock_Squad = "info",
	CarNeedsHeists = "info",
	TuneWanted = "police",
	DriftZoneNear = "info",
	BigScoreNeedCrew = "crew",
	BigScoreRank = "info",
	BigScoreCooldown = "info",
	BigScoreBusy = "info",
	BigScoreCivOnly = "info",
	BigScoreWanted = "police",
	BigScoreSync = "warning",
	BigScoreLoseCops = "police",
	BigScoreNotYours = "warning",
	BigScoreCarrying = "info",
	BigScoreVanFar = "warning",
	BigScoreNoBars = "info",
	RaceLobbyIn = "info",
	RaceLobbyFull = "info",
	RaceLobbyLeft = "warning",
	RaceGridFull = "warning",
	RaceSpotted = "police",
	RaceChallengeNeedCar = "info",
	RaceChallengeNoOne = "info",
	RaceChallengeBusy = "info",
	RaceChallengeWait = "info",
	RaceChallengeCooldown = "info",
	RaceChallengeGone = "info",
	RaceChallengeOff = "warning",
	RaceChallengeFar = "info",
	RaceChallengeNoRoute = "info",
}

local C = Theme.Color

-- Icon + accent per category. Alert styles always use their own colour so danger looks the same
-- everywhere; the others take the caller's colour (through Tone) when one is given.
local STYLES = {
	warning = { Icon = "!", Color = C.Orange, Alert = true },
	police = { Icon = "★", Color = C.Danger, Alert = true },
	prison = { Icon = "#", Color = C.Orange, Alert = true },
	money = { Icon = "$", Color = C.Cash },
	success = { Icon = "✓", Color = C.Cash },
	info = { Icon = "i", Color = C.Dim },
	crew = { Icon = "+", Color = C.Purple },
}

-- Word clues (Lua patterns) for guessing a category when a caller doesn't pass one.
local PRISON_WORDS = { "prison", "jail", "confiscat" }
local SUCCESS_WORDS = { "unlocked", "arrived", "%f[%a]done%f[%A]", "complete" }
local POLICE_WORDS = { "%f[%a]cops?%f[%A]", "police", "dispatch", "tracker", "zapped", "taser", "wanted", "%f[%a]heat%f[%A]" }
local CREW_WORDS = { "crew", "friend", "invite" }
local SOON_WORDS = { "coming soon" }
local MONEY_WORDS = { "%$", "cash", "earned" }

local GAP = 6 -- pixels between cards
local MAX_TOASTS = 3
local LIFETIME = 4
local CARD_ALPHA = 0.3 -- see-through, like every street panel
local SLIDE = 18 -- pixels a card slides in from (and half that on its way out)
local SPLIT = 0.42 -- PC: the stack reaches no higher than this share of the screen (FeedController's column ends there)
local THUMB_SMALL, THUMB_BIG = 110, 190 -- phone: pixels kept free above the bottom edge for Roblox's thumbstick
local IN = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local OUT = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local gui, holder, list
local grow = "Up" -- which way the stack grows now (the zone's Grow)
local room = 200 -- pixels the stack may fill now
local toasts = {} -- oldest first: { slot, fade = { [instance] = { prop = hidden value } }, low = feed post }
local order = 0

-- The Theme colour that means what a caller's colour meant. Callers still pass the old neon colours
-- (pink, mint, gold, orange, red...) as well as Theme ones; this keeps "colour means something": red =
-- danger, orange = a problem, gold = a reward, green = cash / good news, blue = police, pink = the brand.
-- The old neon cyan was the generic "info" colour, so it gives nil (the category's own colour).
function NotifyController.Tone(color)
	if typeof(color) ~= "Color3" then
		return nil
	end
	local h, s, v = color:ToHSV()
	if s < 0.25 or v < 0.2 then
		return C.Text
	elseif h < 0.035 or h >= 0.96 then
		return C.Danger
	elseif h < 0.1 then
		return C.Orange
	elseif h < 0.19 then
		return C.Gold
	elseif h < 0.47 then
		return C.Cash
	elseif h < 0.535 then
		return nil
	elseif h < 0.7 then
		return C.Police
	elseif h < 0.8 then
		return C.Purple
	end
	return C.Brand
end

local function hasAny(text, words)
	for _, w in ipairs(words) do
		if string.find(text, w) then
			return true
		end
	end
	return false
end

-- Existing callers only pass (text, color): pick an icon from the words first, then the colour.
-- Order matters: "CHALLENGE DONE: escape the cops" is good news, not a police alert.
local function guessCategory(text, color)
	local lower = string.lower(text)
	if hasAny(lower, PRISON_WORDS) then
		return "prison"
	elseif hasAny(lower, SUCCESS_WORDS) then
		return "success"
	elseif hasAny(lower, POLICE_WORDS) then
		return "police"
	elseif hasAny(lower, CREW_WORDS) then
		return "crew"
	end
	local tone = NotifyController.Tone(color)
	if tone == C.Danger then
		return "warning" -- red text is always a problem ("Bag full!")
	end
	if hasAny(lower, SOON_WORDS) then
		return "info"
	elseif hasAny(lower, MONEY_WORDS) then
		return "money"
	end
	if tone == C.Orange then
		return "warning" -- orange = something went wrong (race cancelled, missed jump)
	end
	return "info"
end

-- The Toasts ScreenGui's own size (the box its zone is laid out in), else the camera's view.
local function screenSize()
	local size = gui and gui.AbsoluteSize
	if size and size.X > 0 and size.Y > 0 then
		return size
	end
	local cam = Workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(844, 390)
end

-- 13 px on a 390-tall phone (the smallest the HUD uses), 16 px on a 1080p monitor.
local function textSize()
	return math.clamp(math.floor(screenSize().Y * 0.034), 13, 16)
end

-- Fade helpers. `fade` maps an instance to the values it has while hidden; the card is built in its
-- shown state, so fadeIn reads those values first, hides it and tweens back.
local function fadeIn(fade, info)
	for inst, hidden in pairs(fade) do
		local shown = {}
		for prop, value in pairs(hidden) do
			shown[prop] = inst[prop]
			inst[prop] = value
		end
		TweenService:Create(inst, info, shown):Play()
	end
end

local function fadeOut(fade, info)
	for inst, hidden in pairs(fade) do
		if inst.Parent then
			TweenService:Create(inst, info, hidden):Play()
		end
	end
end

-- Pieces that use the Subtitle zone now and then (paths under PlayerGui): TutorialClient's guide line
-- (its goal strip sits at the top, so only a piece reaching down into the zone counts), MissionClient's
-- step line, ImpactClient's KNOCKED DOWN caption.
local SUBTITLE_PIECES = { { "Tutorial", "Next" }, { "Mission", "Step" }, { "ImpactFx", "KnockedDown" } }
local function subtitleInUse(subTop)
	local playerGui = player:FindFirstChild("PlayerGui")
	for _, path in ipairs(SUBTITLE_PIECES) do
		local sg = playerGui and playerGui:FindFirstChild(path[1])
		local obj = sg and sg:FindFirstChild(path[2])
		if obj and obj:IsA("GuiObject") and obj.Visible and sg:IsA("ScreenGui") and sg.Enabled
			and obj.AbsolutePosition.Y - sg.AbsolutePosition.Y + obj.AbsoluteSize.Y > subTop then
			return true
		end
	end
	return false
end

-- Put the stack in the Toasts zone for this screen and work out how much room it has.
local function layout()
	if not holder then
		return
	end
	local touch = Theme.IsTouch()
	local z = Theme.Zone("Toasts", touch)
	local vp = screenSize()
	local edge = z.Pos.Y.Scale * vp.Y + z.Pos.Y.Offset -- the stack's fixed end (its bottom when it grows up)
	grow = z.Grow or "Down"
	if grow == "Up" then
		room = edge - math.floor(vp.Y * SPLIT)
	else
		local thumb = math.min(vp.X, vp.Y) <= 500 and THUMB_SMALL or THUMB_BIG
		room = vp.Y - thumb - edge
		-- Narrow phones: the Subtitle zone reaches under this column. While something shows there the stack
		-- stops above it (it still keeps the newest card: the max(room, 40) below, then trim()).
		local sub = Theme.Zone("Subtitle", touch)
		local subW = sub.Size.X.Scale * vp.X + sub.Size.X.Offset
		local subH = sub.Size.Y.Scale * vp.Y + sub.Size.Y.Offset
		local subLeft = sub.Pos.X.Scale * vp.X + sub.Pos.X.Offset - sub.Anchor.X * subW
		local subTop = sub.Pos.Y.Scale * vp.Y + sub.Pos.Y.Offset - sub.Anchor.Y * subH
		if subLeft < z.Pos.X.Offset + z.Size.X.Offset and subtitleInUse(subTop) then
			room = math.min(room, subTop - 4 - edge)
		end
	end
	room = math.max(math.floor(room), 40)
	Theme.Place(holder, "Toasts", touch)
	holder.Size = UDim2.new(holder.Size.X.Scale, holder.Size.X.Offset, 0, room)
	list.VerticalAlignment = grow == "Up" and Enum.VerticalAlignment.Bottom or Enum.VerticalAlignment.Top
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Toasts"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- zone coordinates: y = 0 is the very top of the screen
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")
	holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Active = false
	holder.Parent = gui
	list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, GAP)
	list.Parent = holder
	layout()
end

local function removeToast(t)
	local i = table.find(toasts, t)
	if i then
		table.remove(toasts, i)
	end
	t.slot:Destroy()
end

-- The card to drop when the stack is too full: the oldest feed post, else the oldest toast. (The
-- player's own messages matter more than news from the rest of the server.)
local function victim()
	for _, t in ipairs(toasts) do
		if t.low then
			return t
		end
	end
	return toasts[1]
end

-- Drop cards while the stack is taller than its room (short phones). Keeps at least one.
local function trim()
	if not holder then
		return
	end
	local total = 0
	for i, t in ipairs(toasts) do
		total += t.slot.AbsoluteSize.Y + (i > 1 and GAP or 0)
	end
	while #toasts > 1 and total > room do
		local v = victim()
		total -= v.slot.AbsoluteSize.Y + GAP
		removeToast(v)
	end
end

-- (see the header)
function NotifyController.Stack(slot, fade, lifetime, low)
	if typeof(slot) ~= "Instance" or not slot:IsA("GuiObject") then
		return
	end
	if not gui then
		build()
	end
	layout()
	low = low == true
	-- At most 3 cards on screen: make room (a feed post never pushes out one of your own toasts).
	while #toasts >= MAX_TOASTS do
		local v = victim()
		if low and not v.low then
			slot:Destroy()
			return
		end
		removeToast(v)
	end
	order += 1
	slot.LayoutOrder = grow == "Up" and order or -order -- the newest sits nearest the stack's fixed end
	slot.Active = false
	local t = { slot = slot, fade = type(fade) == "table" and fade or {}, low = low }
	table.insert(toasts, t)
	fadeIn(t.fade, IN)
	local card = slot:FindFirstChild("Card")
	local rest = card and card:IsA("GuiObject") and card.Position
	if rest then
		card.Position = rest + UDim2.fromOffset(-SLIDE, 0)
		TweenService:Create(card, IN, { Position = rest }):Play()
	end
	slot.Parent = holder
	-- Wrapped heights are only known after a frame, then make sure the stack still fits.
	task.defer(function()
		task.wait()
		if slot.Parent then
			trim()
		end
	end)
	task.delay(type(lifetime) == "number" and lifetime or LIFETIME, function()
		if not slot.Parent then
			return -- already pushed out by newer cards
		end
		fadeOut(t.fade, OUT)
		if rest then
			TweenService:Create(card, OUT, { Position = rest + UDim2.fromOffset(-SLIDE / 2, 0) }):Play()
		end
		task.wait(0.45)
		if slot.Parent then
			removeToast(t)
		end
	end)
end

-- text: what to say. color (optional): accent for non-alert toasts. category (optional):
-- "warning", "police", "prison", "money", "success", "info" or "crew" (guessed when left out).
function NotifyController.Show(text, color, category)
	if type(text) ~= "string" or text == "" then
		return
	end
	if typeof(color) ~= "Color3" then
		color = nil
	end
	category = (type(category) == "string" and STYLES[category]) and category or guessCategory(text, color)
	local style = STYLES[category]
	local accent = (not style.Alert and NotifyController.Tone(color)) or style.Color

	local ts = textSize()
	local padY = math.max(7, math.floor(ts * 0.5))
	local textLeft = 34 -- bar, gap, icon, gap

	local slot = Instance.new("Frame")
	slot.Name = "Toast"
	slot.Size = UDim2.fromScale(1, 0)
	slot.AutomaticSize = Enum.AutomaticSize.Y
	slot.BackgroundTransparency = 1
	slot.Active = false

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	Theme.Panel(card, CARD_ALPHA)
	card.Active = false
	card.Parent = slot

	-- The thin category bar down the left edge (inset so it stays inside the small corners).
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(0, 4)
	bar.Size = UDim2.new(0, 3, 1, -8)
	bar.BackgroundColor3 = accent
	bar.BorderSizePixel = 0
	bar.Active = false
	Theme.Corners(bar, 2)
	bar.Parent = card

	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.Position = UDim2.fromOffset(11, padY)
	icon.Size = UDim2.fromOffset(16, ts)
	Theme.Text(icon, ts, "Bold")
	icon.TextColor3 = accent
	icon.Text = style.Icon
	icon.Active = false
	icon.Parent = card

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Position = UDim2.fromOffset(textLeft, 0)
	label.Size = UDim2.new(1, -(textLeft + 10), 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y -- wraps onto more lines instead of shrinking
	Theme.Text(label, ts, "Body")
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = text
	label.Active = false
	label.Parent = card
	local lp = Instance.new("UIPadding")
	lp.PaddingTop, lp.PaddingBottom = UDim.new(0, padY), UDim.new(0, padY)
	lp.Parent = label

	local fade = {
		[card] = { BackgroundTransparency = 1 },
		[bar] = { BackgroundTransparency = 1 },
		[icon] = { TextTransparency = 1 },
		[label] = { TextTransparency = 1 },
	}
	for _, l in ipairs({ icon, label }) do
		local shadow = l:FindFirstChild("Shadow")
		if shadow then
			fade[shadow] = { Transparency = 1 }
		end
	end
	NotifyController.Stack(slot, fade, LIFETIME)
end

-- Fallback words for server keys that never got a message (new passes, unlocks or heist preps).
local function fallbackText(key)
	if string.sub(key, 1, 10) == "NeedsPass_" then
		return "That comes with a game pass (PHONE > SHOP).", "info"
	elseif string.sub(key, 1, 12) == "NeedsUnlock_" then
		return "You haven't unlocked that yet. Keep playing!", "info"
	elseif string.sub(key, 1, 9) == "NeedPrep_" then
		return "Do the prep job first.", "warning"
	end
	return nil
end

function NotifyController.Init()
	if not gui then
		build()
	end
	-- Re-place when the screen size or the kind of device changes (rotating a phone, resizing the
	-- window, plugging a mouse into a tablet).
	local function relayout()
		layout()
		trim()
	end
	local camConn
	local function watchCamera()
		if camConn then
			camConn:Disconnect()
		end
		local cam = Workspace.CurrentCamera
		if cam then
			camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(relayout)
		end
		relayout()
	end
	watchCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(relayout)
	UserInputService:GetPropertyChangedSignal("MouseEnabled"):Connect(relayout)

	Remotes.OnClient("Notify", function(key)
		if type(key) ~= "string" then
			return
		end
		local text = NotifyController.Messages[key]
		local category = NotifyController.Categories[key]
		if not text then
			text, category = fallbackText(key)
		end
		if text then
			NotifyController.Show(text, nil, category)
		end
	end)
end

return NotifyController
