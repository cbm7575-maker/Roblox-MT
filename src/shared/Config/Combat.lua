-- Combat (ModuleScript, ReplicatedStorage.Shared.Config.Combat)
-- Combat numbers, shared by CombatService / PedService (server) and CombatClient / PedClient (client).
-- Fists and guns, nothing gory. Hits fill a server-owned damage meter (player attribute "Daze", 0-100)
-- that every screen shows as HEALTH (100 - Daze) and that heals by itself. What happens at 0 health
-- depends on the hit that got you there (owner's call, 2026-10-29):
--   * a GUN kills you: the body falls limp and stays down, and the death screen (RespawnClient) has a
--     RESPAWN button (Combat.Death);
--   * FISTS knock you out for a few seconds (the same fall and dizzy stars as a car bump), and you get up.
-- Either way you drop part of your robbery bag and a small wallet.
-- ARMOR (attribute "Armor", 0-100, bought at the shop) soaks up damage before health does.
--   * Citizens: Fists (free) and the guns in Combat.GunOrder, bought once at Coast Arms.
--   * Cops: the taser (ArrestService) and a free Service Pistol that only works on wanted citizens.
-- Helpers (attributes only, safe on both sides; the server re-checks everything itself):
--   Combat.Hittable(player, serverNow) -> can this player be hit right now?
--   Combat.Gun(id)                     -> the gun table, or nil for anything that isn't a gun id
--   Combat.ToolGun(tool)               -> the gun table of a gun Tool (its GunId attribute), or nil
--   Combat.Health(player)              -> 0..100
--   Combat.ArmorOf(player)             -> 0..100
--   Combat.Owns(player, id)            -> does the "Guns" attribute list this gun?
--   Combat.RankOk(player, gun)         -> free-roam rank high enough to buy it?
--   Combat.DamageAt(gun, distance)     -> damage of one pellet at this distance (whole number, 1 or more)
--   Combat.SpreadDir(dir, degrees, rng) -> a unit vector picked evenly inside a cone around dir
--   Combat.Stats(gun)                  -> damage, fire rate, range as 0..1 (the shop's three bars)
-- How it looks: a gun is held low in both hands, comes up to the eye while you aim or fire and goes
-- back down for the reload; fists throw a straight right, then a left. No uploaded animations: every
-- CombatClient shows it with PoseClient's poses ("LowReady", "Aim", "Point"): on your own character
-- straight from your camera and trigger, on everyone else's from the three look-only Tool attributes
-- below (the server sets them: from each shot and swing, and from what that player's device says about
-- its aim). Without PoseClient the plain Roblox tool hold and the old slash swing show.
-- (The guns' shapes aren't in here: CombatService builds each gun Tool from the place's own mesh,
-- ServerStorage.GunModels.<Model or Id>, and from a few parts when the place has none.)

local Combat = {}

-- Tools. These attributes are set on each combat Tool so code finds them by kind, not by name.
Combat.ToolAttribute = "NCCombat" -- "Fists" | "Gun"
Combat.GunAttribute = "GunId" -- on gun Tools: a key of Combat.Guns
Combat.AmmoAttribute = "Ammo" -- on gun Tools: rounds in the magazine (the server owns it)
Combat.ReloadAttribute = "ReloadUntil" -- on gun Tools: server time the reload ends; nil when not reloading
-- How everyone else sees you hold it (looks only; set by the server, read by every CombatClient):
Combat.AimAttribute = "AimPitch" -- on gun Tools: degrees up (+) or down (-) the gun points, in steps of 2
Combat.AimUpAttribute = "AimUp" -- on gun Tools: true while it is raised (aiming or firing), else nil
Combat.SwingAttribute = "Swing" -- on Fists: counts accepted swings (odd = right hand, even = left)

Combat.Fists = {
	Name = "Fists",
	Range = 7, -- studs from your root to theirs
	Cone = 0.35, -- dot product: how far in front of you they must be
	Slack = 1.5, -- extra studs the server allows for the target the client picked (network lag)
	Damage = 34, -- three punches knock someone out (no armor)
	Cooldown = 0.45, -- seconds between swings
}

-- Guns. Made-up names only. Bought once (Price, free-roam Rank), saved in data.gear.guns.
--   Auto     hold the trigger to keep firing
--   Damage   per pellet, before the distance falloff (Combat.Falloff)
--   Interval seconds between shots; the server allows 1.15x that rate, with Burst shots in hand (a
--            Burst 1 gun instead takes a shot up to 0.15 s early, so a phone's jittery taps still count)
--   Spread   half-angle of the cone in degrees
--   LagStuds how far from the shot's line the target the client picked may be (they moved a little)
--   Recoil   camera kick in degrees per shot (client)
--   MinStars (cop gun) only works on citizens with this many stars
--   Model    which gun model to hold (ServerStorage.GunModels.<Model>), when it isn't the one named
--            like the Id (the Service Pistol looks like the Pistol)
Combat.Guns = {
	Pistol = { Id = "Pistol", Name = "Coast 9", Class = "Pistol", Side = "Civilian", Price = 2500, Rank = 1, Auto = false,
		Damage = 22, Pellets = 1, Interval = 0.22, Range = 120, Mag = 12, Reload = 1.3, Spread = 0.4, Burst = 2, LagStuds = 3,
		Recoil = 1.0, Sound = "GunPistol" },
	SMG = { Id = "SMG", Name = "Squall", Class = "SMG", Side = "Civilian", Price = 9000, Rank = 1, Auto = true,
		Damage = 11, Pellets = 1, Interval = 0.085, Range = 90, Mag = 30, Reload = 1.8, Spread = 2.0, Burst = 3, LagStuds = 3,
		Recoil = 0.5, Sound = "GunSMG" },
	Shotgun = { Id = "Shotgun", Name = "Gatorbite", Class = "Shotgun", Side = "Civilian", Price = 16000, Rank = 1, Auto = false,
		Damage = 9, Pellets = 8, Interval = 0.9, Range = 45, Mag = 6, Reload = 2.4, Spread = 5.0, Burst = 1, LagStuds = 2,
		Recoil = 2.2, Sound = "GunShotgun" },
	Rifle = { Id = "Rifle", Name = "Tarpon Carbine", Class = "Rifle", Side = "Civilian", Price = 32000, Rank = 5, Auto = true,
		Damage = 17, Pellets = 1, Interval = 0.11, Range = 200, Mag = 30, Reload = 2.0, Spread = 0.7, Burst = 3, LagStuds = 3,
		Recoil = 0.8, Sound = "GunRifle" },
	Service = { Id = "Service", Name = "Service Pistol", Class = "Pistol", Side = "Cop", Price = 0, Rank = 1, Auto = false,
		Damage = 22, Pellets = 1, Interval = 0.22, Range = 120, Mag = 12, Reload = 1.3, Spread = 0.4, Burst = 2, LagStuds = 3,
		Recoil = 1.0, Sound = "GunPistol", MinStars = 2, Model = "Pistol" },
}
Combat.GunOrder = { "Pistol", "SMG", "Shotgun", "Rifle" } -- citizen guns: hotbar order and shop order
Combat.CopGun = "Service"
-- Seconds after a gun goes into the hand before it can fire. The client waits this long; the server
-- refuses anything sooner than 0.6 of it (0.12 s: room for a draw that arrives late from a phone), so
-- swapping guns never stacks their fire rates.
Combat.DrawTime = 0.2

-- Health (player attribute "Daze" = damage taken, 0-100, server-owned; HEALTH shown = 100 - Daze).
Combat.DazeMax = 100
Combat.DrainDelay = 4 -- seconds without a hit before health starts coming back
Combat.DrainPerSecond = 15
Combat.KOSeconds = 5 -- on the ground when knocked out
Combat.ImmuneAfterKO = 10 -- seconds after getting up before combat can touch you again
Combat.SpawnProtection = 8 -- seconds after spawning or leaving your home (was 20: a new arrival's punches and shots did nothing for that long)
Combat.BarRange = 80 -- health bars show over hurt players this close
Combat.FleeWindow = 8 -- bailing out (Reset, side switch, leaving) this soon after a hit, or while hurt, counts as a knockout

-- Death (a gun took your health to 0, or any other way a body dies: Esc > Reset, a long fall). Roblox's
-- own 5 s respawn is off; RespawnService brings you back (RespawnClient's death screen).
Combat.Death = {
	RespawnAfter = 2, -- seconds dead before RESPAWN can be pressed (the fall plays first)
	AutoRespawn = 10, -- seconds dead before you come back by yourself (under the 12 s a dead body's fall lasts on its own device: PoseClient)
}

-- Cars hitting people on foot (CombatService.CarHit, from ImpactService): a player's car, an AI patrol,
-- or street traffic (that one is told by the victim's own device). Damage grows with the speed of the
-- hit: a bump at walking-pace traffic speed takes a little, a fast hit most of a bar, and a second hard
-- one (or being run over again while down) kills. Studs per second; the car HUD shows mph.
Combat.CarHit = {
	MinSpeed = 20, -- slower is a nudge: no damage (and no knock-down either: ImpactService)
	Damage = 8, -- at MinSpeed...
	PerSpeed = 0.75, -- ...plus this much per stud/s above it (40 -> 23, 60 -> 38, 90 -> 61)
	Max = 85, -- one hit never does more: a single hit from full health never kills
	Downed = 0.6, -- someone already lying in the road takes this share (run over again)
	Gap = 1, -- seconds before the same body can be hurt by a car again
	ArmorShare = 0.5, -- body armor soaks at most this share of a car hit (it stops bullets, not bumpers)
}

-- Armor (player attribute "Armor", 0-100, server-owned): takes the damage first, fists included.
-- Citizens only (saved as data.gear.armor); it shows 0 for cops and prisoners.
Combat.ArmorMax = 100
Combat.ArmorItem = { Id = "Armor", Name = "Body Armor", Price = 1500, Sound = "BodyArmor" } -- refills to 100
-- Bullets lose power far away: full damage up to Start x Range, then a straight line down to Min x
-- damage at the end of the range.
Combat.Falloff = { Start = 0.6, Min = 0.5 }

-- Dropped bag: a knockout spills part of the robbery bag as a glowing duffel pickup.
Combat.Drop = {
	Share = 0.25,
	Min = 50, -- nothing drops from a bag smaller than this; otherwise at least this much drops
	Lifetime = 60, -- seconds before an unclaimed bag (or wallet) vanishes
	CopReward = 100, -- a cop who returns it to the bank earns up to this...
	CopShare = 0.5, -- ...but never more than this share of the bag (a staged knockout never pays)
	Heat = 1, -- grabbing someone else's dropped cash is stealing
	OwnerWait = 1, -- the owner can grab it back this long after getting up
}

-- Dropped wallet: a knocked-out citizen also drops a little of their banked Cash. Same pickup rules
-- as the bag (Combat.Drop).
Combat.Wallet = {
	Share = 0.02,
	Min = 20, -- nobody with less Cash than this drops a wallet; otherwise at least this much
	Max = 400,
	VictimGap = 120, -- seconds before the same player can drop another one (no picking on one player)
}

-- Bounty: knocking out a wanted citizen pays PerStar x their PAID stars (HeatService.PaidStars: the
-- stars real crimes gave them, not fight stars), from the system. Cops get it as a bounty, citizens
-- as vigilante pay.
Combat.Bounty = {
	PerStar = 200,
	VictimGap = 300, -- one bounty per wanted player every this many seconds
}

-- Pedestrians (PedClient runs them on each device; PedService decides the money). One you punch or
-- shoot falls over, runs off and drops a wallet.
Combat.Ped = {
	Min = 50, -- dollars in a wallet...
	Max = 100,
	Gap = 2.5, -- seconds between payouts for one player
	Window = 600, -- per player, every this many seconds...
	WindowMax = 900, -- ...wallets pay at most this much; then they are empty
	Range = 14, -- studs (flat) from the wallet the server accepts a pickup from
	AggroWindow = 25, -- you must have swung or fired this recently
	WalletLife = 20, -- seconds a wallet lies there (client)
	PickupRange = 6, -- walk this close to take it (client)
	QuietFor = 60, -- after "Empty": no wallets drop for this long (client)
	ScareRange = 60, -- gunfire makes pedestrians this close run (client)
	HitRadius = 2.2, -- a shot passing this close to a pedestrian hits them (client)
	-- Owner's rule: the police only start coming after the SECOND pedestrian you knock over. The first
	-- FreeVictims bring nobody (no star for the shot the street heard, none for their wallet); the next
	-- one puts a star on you (Combat.Heat.PedVictim: that one's own wallet adds none) and from then on
	-- gunfire and wallets count as usual.
	FreeVictims = 1,
	VictimMemory = 180, -- seconds after the last one before the count starts again (it also starts again once the cops have lost you)
}

-- Heat for the attacker. Knocking out a wanted player is vigilante work: no heat. Knocking out
-- someone who threw the first hit in your fight is self-defence: no heat either.
Combat.Heat = {
	KO = 1, -- knocking out a player who isn't wanted
	KOCop = 2, -- knocking out a cop
	HitCop = 1, -- the first hit on a cop (once per cop every CopMemory seconds)
	CopMemory = 20,
	Cap = 2, -- fist fights and stolen pickups never give more stars than this (attribute CombatStars counts them)
	GunCap = 3, -- ...and anything done with a gun never more than this
	SelfDefence = 30, -- seconds a fight is remembered (who threw the first hit)
	Gunfire = 1, -- firing a gun where someone can hear it (a street, or a cop nearby)
	GunfireGap = 20, -- at most one gunfire star every this many seconds
	GunfireCopRange = 150, -- a player cop or a patrol car this close hears it
	GunfireStreet = 70, -- so does the street: this close (flat) to a road's centre line
	PedLoot = 1, -- taking a pedestrian's wallet (not for the first Ped.FreeVictims + 1 pedestrians)
	PedVictim = 1, -- knocking over one pedestrian too many (the one after Ped.FreeVictims)
}

-- Passive mode (phone SETTINGS, saved as data.settings.Passive, attribute "Passive").
Combat.Passive = {
	OnCooldown = 60, -- after turning it off, wait this long to turn it back on
	OffCooldown = 10, -- after turning it on, wait this long to turn it off
	FightLock = 15, -- no going passive this soon after swinging or firing (being hit doesn't lock you)
}

-- Safe zones (player attribute "InSafeZone", server-owned).
Combat.SafeZone = {
	SpawnRadius = 60, -- around team spawns, the Hideout and Police HQ
	DealerMargin = 20, -- around each dealership's bounding box
	HomeMargin = 10, -- around each home's bounding box
	ShopMargin = 10, -- around Coast Arms
	WheelMargin = 12, -- around the Lucky Wheel (SpinService): people stand around watching spins
}

-- Coast Arms, the gun store (built by CombatService): lot centre, the front faces west toward the
-- road at x -300.
Combat.Shop = {
	Name = "Coast Arms",
	Kind = "Guns & body armor",
	Center = Vector3.new(-250, 0, -330),
	BuyRange = 14, -- studs from the counter the server accepts a purchase from
	Model = "GunShop", -- Workspace.Shops.GunShop
	Prompt = "GunShopBrowse", -- the counter's ProximityPrompt (CombatClient opens the shop panel)
	BuyPoint = "BuyPoint", -- the part at the counter that holds the prompt
}

-- Aiming (client).
Combat.Aim = {
	ZoomFOV = 50,
	NormalFOV = 70,
	ZoomTime = 0.15,
	Shoulder = Vector3.new(2.3, 0.7, 0), -- camera offset with a gun out, as the view sees it: right, up, back
	AssistMouse = 1.5, -- degrees: snap to a player this close to the aim ray
	AssistTouch = 5,
	AssistGamepad = 5,
	-- Camera distance with a gun out (studs): never first person (the shoulder offset would sit beside
	-- the head), never far away, and pulled in to ZoomAim while aiming.
	ZoomMin = 6,
	ZoomMax = 11,
	ZoomAim = 8,
	-- With a gun out you run freely (gun held low); aiming or firing turns you to the crosshair, slows
	-- you to WalkSpeed and keeps you facing it for StrafeHold seconds after the last shot. (The slow-down
	-- is asked of LocomotionClient.SetCap; without that controller there is none.)
	-- WalkSpeed stays clear of 10: under 10 studs/s the police count you as stopped (ArrestService's
	-- cuffs, AIPoliceService's arrest timer). At exactly 10 a wanted player who walked while shooting
	-- back was cuffed on the move. 12 leaves the same room as the out-of-breath jog (Animations.lua).
	WalkSpeed = 12,
	StrafeHold = 0.8,
	-- Touch and gamepad: pressing AIM turns the camera onto the nearest player you could hit within
	-- LockAngle degrees of the crosshair, over about LockTime seconds. (A mouse aims itself.)
	LockAngle = 20,
	LockTime = 0.25,
	-- Touch: degrees the camera turns per pixel the thumb holding FIRE drags (less while zoomed, in step
	-- with the FOV), so an automatic gun can follow a target without letting go of the trigger.
	TouchLook = 0.3,
}

-- Effects.
Combat.Fx = {
	ShotRange = 300, -- studs: who is sent other players' shots
	ReloadRange = 120, -- studs: who hears a reload
	TracerTime = 0.06, -- seconds a tracer stays on screen
	MaxTracers = 24, -- tracers alive at once (pooled)
}

local TIMERS = { "SpawnSafeUntil", "CombatSafeUntil", "KnockedUntil", "StunnedUntil" }

-- Attribute-only check (server time `now`): Civilian or Cop, not passive, not in a safe zone or at
-- home, not spawn-protected or post-knockout immune, not knocked over or tasered.
function Combat.Hittable(player, now)
	local side = player:GetAttribute("Side")
	if side ~= "Civilian" and side ~= "Cop" then
		return false
	end
	if player:GetAttribute("Passive") == true or player:GetAttribute("InSafeZone") == true or player:GetAttribute("InHome") == true then
		return false
	end
	for _, name in ipairs(TIMERS) do
		local t = player:GetAttribute(name)
		if type(t) == "number" and t > now then
			return false
		end
	end
	return true
end

function Combat.Gun(id)
	if type(id) ~= "string" then
		return nil
	end
	return Combat.Guns[id]
end

function Combat.ToolGun(tool)
	if typeof(tool) ~= "Instance" then
		return nil
	end
	return Combat.Gun(tool:GetAttribute(Combat.GunAttribute))
end

function Combat.Health(player)
	local daze = player:GetAttribute("Daze")
	return math.clamp(Combat.DazeMax - (type(daze) == "number" and daze or 0), 0, Combat.DazeMax)
end

function Combat.ArmorOf(player)
	local armor = player:GetAttribute("Armor")
	return type(armor) == "number" and math.clamp(armor, 0, Combat.ArmorMax) or 0
end

-- Player attribute "Guns": the owned citizen guns, comma-separated ("Pistol,Rifle"). A plain find
-- (no patterns), with commas on both ends so "SMG" never matches inside another id.
function Combat.Owns(player, id)
	if type(id) ~= "string" or id == "" then
		return false
	end
	local owned = player:GetAttribute("Guns")
	if type(owned) ~= "string" then
		return false
	end
	return string.find("," .. owned .. ",", "," .. id .. ",", 1, true) ~= nil
end

function Combat.RankOk(player, gun)
	return (player:GetAttribute("CivRank") or 1) >= (gun.Rank or 1)
end

function Combat.DamageAt(gun, distance)
	local F = Combat.Falloff
	local share = 1
	local from = gun.Range * F.Start
	if distance > from then
		local t = math.clamp((distance - from) / math.max(gun.Range - from, 0.001), 0, 1)
		share = 1 - (1 - F.Min) * t
	end
	return math.max(1, math.floor(gun.Damage * share + 0.5))
end

-- A unit vector picked evenly (by area) inside the cone of half-angle `degrees` around the unit
-- vector `dir`. `rng` is a Random: the server's for real shots, the client's own for what it draws.
function Combat.SpreadDir(dir, degrees, rng)
	local angle = math.rad(degrees) * math.sqrt(rng:NextNumber())
	local roll = rng:NextNumber() * math.pi * 2
	-- (Straight up or down, lookAt has no "up" to lean on: give it a sideways one.)
	local up = math.abs(dir.Y) > 0.99 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	return (CFrame.lookAt(Vector3.zero, dir, up) * CFrame.Angles(0, 0, roll) * CFrame.Angles(angle, 0, 0)).LookVector
end

-- The shop's three bars: damage per trigger pull, shots per second, range, each as 0..1 of the best.
function Combat.Stats(gun)
	return math.clamp(gun.Damage * gun.Pellets / 72, 0, 1), math.clamp((1 / gun.Interval) / (1 / 0.085), 0, 1),
		math.clamp(gun.Range / 200, 0, 1)
end

return Combat
