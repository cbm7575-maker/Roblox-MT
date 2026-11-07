-- CombatService (ModuleScript, ServerScriptService.Services.CombatService)
-- Fists and guns, nothing gory. A gun that takes someone's health to 0 KILLS them (they come back with
-- the death screen's RESPAWN button: RespawnService); fists KNOCK them OUT and they get back up. Numbers
-- live in Config.Combat. The client only asks; every hit is decided here.
--   * Tools (given on spawn, side change, purchase; checked again every 2 s):
--       citizens  "Fists" (everyone) + every gun they own (Combat.GunOrder: Pistol, SMG, Shotgun, Rifle),
--                 bought once at Coast Arms and saved as data.gear.guns[id] = true. An old Stun Blaster
--                 (data.gear.blaster) becomes the Pistol.
--       cops      the "Service Pistol" only (free; it only works on citizens with 2+ stars). They keep
--                 their taser (ArrestService).
--       prisoners and anyone in passive mode: nothing.
--     A gun Tool has a Handle, an Attachment "Muzzle" at the barrel tip (its -Z points out of the
--     barrel) holding a ParticleEmitter "Flash" (a short flame burst) and a PointLight "Light"
--     (CombatClient fires them), and the attributes NCCombat = "Gun", GunId, Ammo (rounds in the
--     magazine, owned here), ReloadUntil (server time), AimPitch (degrees) and AimUp (true while
--     raised). Fists carry Swing (a count of accepted swings).
--     How a gun looks: the place's own mesh, ServerStorage.GunModels.<Pistol | SMG | Shotgun | Rifle>
--     (the Service Pistol shares "Pistol"). Those models are used as the mesh generator left them: one
--     MeshPart ("body_geom"), the whole gun, upright, its barrel along the part's Z axis, nothing marked
--     on it. A copy of that part IS the Handle; Tool.Grip (where the hand holds it) and the Muzzle are
--     worked out from its size, and which end is the barrel is measured once with a few rays
--     (measureMesh; the shop's wall shows the same meshes). Optional attributes on a model put it
--     right by hand: BarrelZ (1 | -1), Grip (CFrame), Muzzle (Vector3); see meshGun. A model rigged the
--     old way (a "Handle" part: -Z = barrel, +Y = up, plus a "Muzzle" attachment) is used as it is.
--     Only when the place has no model for a gun is it built from a few Parts (GUN_BUILD).
--     AimPitch / AimUp / Swing are looks only: every other player's CombatClient shows that player's
--     arms from them (gun low, gun up and where it points, a straight right or left). A shot raises
--     the gun; the player's own device says the rest ("Aim" below). A gun the server raised for a shot
--     comes down again by itself 1.2 s after the last one, unless that device has said it is aiming.
--   * CombatAction remote (client -> server), 25 a second at most:
--       ("Punch", suggestedVictim?)                 nearest valid player 7 studs in front, no wall between
--       ("Fire", gunId, aimPoint, suggestedVictim?) one shot: rays from your head toward the aim point
--       ("Reload", gunId)                           refills the magazine after the gun's reload time
--       ("Aim", pitchDegrees, raised)               where the gun in hand points (looks only; its own
--                                                   limit of 10 a second, outside the 25)
--     A shot is checked in this order: the gun is in your hand, alone (two Tools held at once by an
--     exploit never fire or punch), and belongs to your side; it has been in the hand for 0.12 s
--     (Config DrawTime x 0.6: swapping guns never stacks their fire rates); you may fight right now
--     (not seated, swimming, passive, down, in a safe zone or spawn-protected); the magazine isn't
--     empty or reloading; the gun's own fire-rate limit (1.15x its rate; a gun with no burst, the
--     shotgun, may instead fire up to 0.15 s early, for jittery phone taps) and one limit shared by
--     all guns (14 a second with 3 in hand: what the fastest gun alone may do). Then the server
--     spreads the pellets itself (its own Random), casts each one (walls, doors and smoke block; hats
--     and dropped cash don't), and may accept the target the client picked when the shot passed within
--     a few studs of them (lag). Damage falls off past 60% of the range. Unequipping cancels a reload;
--     each Tool keeps its rounds.
--   * Health and armor: attribute "Daze" (0-100) is the damage taken, shown as HEALTH = 100 - Daze. It
--     heals 15 a second after 4 s without a hit. "Armor" (0-100, citizens only, saved as
--     data.gear.armor, bought at Coast Arms) soaks up damage first, fists included.
--     At 0 health from a gun you die (kill): the body falls limp for good (RagdollService, opts.Dead) and
--     its health goes to 0 K.KILL_DELAY later; HEALTH shows 0 until the new body. What follows the death
--     is ArrestService's (a wanted player with police within 120 studs is arrested on the spot) and
--     RespawnService's (RESPAWN). At 0 health from fists you're knocked out (ImpactService.KnockDown,
--     5 s on the ground), health refills, and you're immune to combat for 10 s after getting up
--     (attribute CombatSafeUntil, server time; firing a shot or landing a hit ends it early).
--     Swimmers can't fall over: a punch leaves them at 5 health and the next hit once they're out of the
--     water does it (a gun kills them where they are). "Swimming" means the Swimming humanoid state
--     (which the player's own device reports) AND
--     terrain water at their body, so faking the state on land does nothing.
--     Bailing out mid-fight (the Reset button, a side switch, leaving) counts as being knocked out: the
--     bag and wallet still drop and the attacker gets the heat and the bounty (going by what you were
--     when last hit). Getting arrested mid-fight doesn't: the cops already took the bag.
--   * Money from a knockout or a kill (the same for both):
--       - Bag: carrying $50+ in the robbery bag, 25% of it (at least $50) drops as a glowing duffel.
--       - Wallet: a citizen also drops 2% of their Cash ($20-$400) as a small wallet, at most once
--         every 120 s per victim (never when leaving the game: their save is already being written).
--       - Both lie in Workspace.DroppedBags for 60 s. Citizens on foot grab them into their own bag (+1
--         heat when it isn't theirs); a cop returns them to the bank (the money is gone; evidence reward up
--         to $100, never more than half). Walking over one only picks it up for its owner, cops and
--         wanted players. Models carry the attributes Kind ("Bag" | "Wallet") and Amount.
--       - Bounty: knocking out or killing a WANTED citizen pays their PAID stars x $200 from the system (cops:
--         "ko_bounty", citizens: "vigilante"), once per wanted spell (WantedSince) and at most once per
--         victim every 5 minutes. Fight stars pay nothing, so friends can't fire into the air and farm
--         each other, and a friend who stays wanted can't be knocked out for cash over and over.
--   * Heat (all through combatHeat, counted in CombatStars; fists and stolen pickups give at most 2 stars,
--     guns at most 3): knocking out someone who isn't wanted +1, a cop +2; the first hit on a cop +1
--     right away; firing a gun where someone hears it +1 at most every 20 s (within 70 studs of a road's
--     centre line, or 150 studs of a player cop or patrol car; not while defending yourself).
--     Knocking out a wanted player (vigilante) or whoever threw the first hit (self-defence): no heat.
--     Cops never start a "fight" in that sense: shooting back at a cop is never self-defence.
--   * No combat for or against: prisoners, anyone in a car, in passive mode, in a safe zone, within 20 s
--     of spawning or leaving their home (SpawnSafeUntil), already down, tasered or immune. Crewmates
--     can't hit each other. Swimmers can't attack (they can't be knocked out, so it would be one-sided).
--   * Safe zones (attribute InSafeZone, checked twice a second): 60 studs around team spawns, the
--     Hideout and Police HQ; dealerships (+20), homes (+10) and anyone inside one (InHome); the Car Meet
--     lot; Coast Arms (+10); the Lucky Wheel's stage (+12). Zone boxes are cached and rebuilt when those folders change.
--   * Passive mode (phone SETTINGS -> SettingsService -> CombatService.RequestPassive): refused while
--     wanted, carrying a bag, hurt, down, just after swinging or firing, or on duty as a cop; 60 s before
--     turning it back on, 10 s before turning it off. Getting heat or a bag, or starting a crime (Rob,
--     Prep, Pick lock), turns it off by itself. Saved as data.settings.Passive.
--   * Coast Arms: the gun store built at start-up (Workspace.Shops.GunShop). Its counter has one prompt
--     ("GunShopBrowse"); CombatClient opens the shop panel from it. Remote GunShopBuy(itemId: a gun id or
--     "Armor"): citizen, at the counter, not owned / armor not full, rank, cash.
-- Player attributes set here: Daze, Armor, Guns ("Pistol,Rifle"; nil until the save loads), Passive,
-- InSafeZone, SpawnSafeUntil, CombatSafeUntil, CombatStars.
-- Remote CombatFx (server -> client): "Hit", "Punch", "Shot", "HitMark", "Reload", "KO", "Killed" (to the
-- one who died: RespawnClient's death screen), "KOd" (to the attacker; Killed = true for a kill), "Fled",
-- "Grabbed", "Returned", "Bought".
-- (Luau allows 200 locals at a script's top level: constants live in the table K, state in the table S.)
-- Public:
--   CombatService.Place = { Name, Kind, Pos }         for MapService's GPS list
--   CombatService.RequestPassive(player, on) -> bool
--   CombatService.LastAggro(player) -> os.clock() of their last accepted swing or shot (or nil), "Fists" | "Gun"
--   CombatService.CrimeHeat(player, amount, reason, withGun) -> stars added (fight stars, capped as above)
--   CombatService.IsSafe(player) -> bool (safe zone, home or prisoner)
--   CombatService.ShotDead(player) -> bool (their current body was killed by a gun)

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local RoadGraph = require(ReplicatedStorage.Shared.Util.RoadGraph)
local Theme = require(ReplicatedStorage.Shared.Util.Theme)
local DataService = require(ServerScriptService.Services.DataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local HeatService = require(ServerScriptService.Services.HeatService)
local ImpactService = require(ServerScriptService.Services.ImpactService)
local SettingsService = require(ServerScriptService.Services.SettingsService)

-- Limp bodies for kills (RagdollService). Optional, as in ImpactService: without it a killed body just
-- dies where it stands.
local RagdollService
do
	local module = ServerScriptService.Services:FindFirstChild("RagdollService")
	local ok, result = pcall(function()
		return module and require(module)
	end)
	RagdollService = (ok and type(result) == "table") and result or nil
end

local CombatService = {}

local SHOP = Combat.Shop
-- The shop's front faces west: local -Z = west, local +X = north (see buildShop).
local SHOP_FRAME = CFrame.lookAt(SHOP.Center, SHOP.Center + Vector3.new(-1, 0, 0))

CombatService.Place = { Name = SHOP.Name, Kind = SHOP.Kind, Pos = (SHOP_FRAME * CFrame.new(0, 0, -12)).Position }

local FISTS = Combat.Fists
local HEAT = Combat.Heat

-- LUAU LIMIT: a script may hold at most 200 locals at its top level (it once stopped this file from
-- loading at all). So the plain constants live in ONE table, K, and the remembered state in ONE
-- table, S: a new constant is K.NAME = ..., a new per-player table is S.name = {}, and anything only
-- one function needs is a local inside that function (the shop's colours: buildShop). Functions, the
-- services and the few names used everywhere stay real locals.
local K = {}
K.ATTR = Combat.ToolAttribute
K.GUN_ATTR, K.AMMO_ATTR, K.RELOAD_ATTR = Combat.GunAttribute, Combat.AmmoAttribute, Combat.ReloadAttribute
K.AIM_ATTR, K.AIMUP_ATTR, K.SWING_ATTR = Combat.AimAttribute, Combat.AimUpAttribute, Combat.SwingAttribute
K.TICK = 0.25 -- health regeneration; safe zones every other tick; tools every 8th
K.KILL_DELAY = 0.1 -- seconds from a kill's fall to its death: the body's own device lies it down first (Ragdoll.Fall refuses a dead body)
K.DEAD = table.freeze({ Dead = true }) -- RagdollService.KnockDown opts for a body that is about to die
K.ZONE_REFRESH = 30 -- seconds: rebuild the zone cache even if nothing announced a change
K.MAX_BAGS = 40 -- dropped bags and wallets together
K.PUNCH_FX_RANGE = 120 -- studs: who is sent punch effects (the "POW!" shows up to 120)
K.REFUSE_GAP = 2.5 -- seconds between "you can't hit that" toasts per player
K.RATE_SLACK = 1.15 -- the server lets a gun fire this much faster than its Interval (network jitter)
-- Seconds a gun must have been in the hand before it fires. The client waits the whole DrawTime (0.2 s);
-- the server asks for 0.6 of it (0.12 s), so a draw that reached us 80 ms late on a phone still shoots.
K.DRAW_MIN = (Combat.DrawTime or 0.2) * 0.6
K.ANY_GUN_RATE, K.ANY_GUN_BURST = 14, 3 -- every gun together: what the fastest one alone may do (the Squall: 13.5 a second, 3 in hand)
K.AIM_HOLD = ((Combat.Aim and Combat.Aim.StrafeHold) or 0.8) + 0.4 -- seconds after its last shot a gun the server raised stays up
K.HAT_REFRESH = 0.5 -- seconds the list of everyone's hats is reused (automatic fire asks for it a lot)
K.WITNESS_GAP = 1 -- seconds between "did anyone hear that?" checks per shooter
K.MESH_TRIES = 4 -- how often a gun mesh is measured before the server settles for a guess (barrelWay)
K.WALL_SCALE = 2 -- the shop wall shows the gun meshes this much bigger than life (they read from the counter)
-- Holding one of these prompts starts a crime: passive mode ends right away (HeistService, CarBoostService,
-- BigScoreService: hacking the van, starting the drill).
K.CRIME_PROMPTS = { RobPrompt = true, PrepPrompt = true, PickLockPrompt = true, HackPrompt = true, DrillPrompt = true }
-- Economy reasons for the shop (Telemetry reads them).
K.GUN_REASON = { Pistol = "gun_pistol", SMG = "gun_smg", Shotgun = "gun_shotgun", Rifle = "gun_rifle" }
K.GUN_KEY = {} -- [gun id] = its RateLimit key (made once, not on every shot)
-- People the server put in the street that can be hit (Workspace.NPCs models with the attribute
-- NPCKind), and the service that decides what a hit on each kind does (hitNPC).
-- (BizRobber: a business break-in's robbers; only their owner and crew can knock them down.)
K.NPC_OWNERS = { Officer = "PoliceOfficerService", Clerk = "HeistService", BizRobber = "BusinessService" }
K.THREAT_MEMORY = 8 -- seconds a wanted citizen who fired a gun may be shot by a cop at 1 star (victimProblem)
for id in pairs(Combat.Guns) do
	K.GUN_KEY[id] = "Gun_" .. id
end
-- The dropped duffel keeps its bright look so it can be found from across a street.
K.PINK = Color3.fromRGB(255, 62, 165)
K.GOLD = Color3.fromRGB(255, 214, 10)
K.DARK = Color3.fromRGB(18, 14, 30)
K.PLUM = Color3.fromRGB(70, 44, 104)
K.TRUNK = Color3.fromRGB(180, 140, 95)
K.LEAF = Color3.fromRGB(70, 170, 90)
-- Part-built guns: dark metal and polymer.
K.GUN_METAL = Color3.fromRGB(44, 46, 50)
K.GUN_POLY = Color3.fromRGB(24, 25, 28)
K.GUN_STEEL = Color3.fromRGB(92, 96, 102)
K.FLASH = Color3.fromRGB(255, 226, 150)

local notify, fxRemote
local rng = Random.new() -- pellet spread: picked here, never by the client
local S = {}
S.zones = {} -- { { circle = true, pos, r } | { cf, half } }
S.zonesDirty = true
S.zonesBuiltAt = 0
S.watchedFolders = setmetatable({}, { __mode = "k" })
S.lastHitAt = {} -- [player] = os.clock() of the last hit they took (regeneration, fleeing)
S.lastAttacker = {} -- [player] = who hit them last (a mid-fight reset counts as their knockout)
S.lastHitInfo = {} -- [player] = { cop, civ, wanted, paid, since, gun }: what they were when last hit, and with what
-- [player] = the body a gun killed (until their next body): nothing more is taken from it, it can't be hit,
-- it doesn't heal. Weak and never cleared on leaving: a body that goes after its player does still counts.
S.killed = setmetatable({}, { __mode = "k" })
S.carHitAt = setmetatable({}, { __mode = "k" }) -- [player] = os.clock() a car last hurt them (CarHit: Combat.CarHit.Gap)
S.lastAttack = {} -- [player] = os.clock() they last landed a hit or fired (passive lock)
S.lastAggroAt = {} -- [player] = os.clock() of their last accepted swing or shot, hit or miss
S.lastAggroKind = {} -- [player] = "Fists" | "Gun"
local feuds = {} -- [a][b] = [b][a] = { by = who threw the first hit, at = os.clock() of the latest }
S.lastSwing = {} -- [player] = os.clock()
S.lastRefusal = {} -- [player] = os.clock()
S.lastGunfire = {} -- [player] = os.clock() of their last gunfire star
S.lastWitness = {} -- [player] = os.clock() of the last "did anyone hear that?" check
S.pedVictims = {} -- [player] = { n = pedestrians knocked over lately, at = os.clock() of the last } (PedService counts them)
S.copHitAt = {} -- [attacker] = { [cop] = os.clock() }
S.passiveOnAt = {} -- [player] = os.clock() passive was turned on
S.passiveOffAt = {} -- [player] = os.clock() passive was turned off
S.walletAt = {} -- [UserId] = os.clock() they last dropped a wallet (kept across a rejoin)
S.bountyAt = {} -- [UserId] = { since = their WantedSince, at = os.clock() } of the last bounty paid on them (kept across a rejoin)
local leaving = setmetatable({}, { __mode = "k" }) -- [player] = true once PlayerRemoving has fired
local bags = {} -- list of dropped bag / wallet records, oldest first
local bagFolder
local buyPoints = {} -- positions a purchase is accepted near
S.warnedModels = {} -- [text] = true once a problem with a ServerStorage.GunModels entry was reported
-- [name of a model in ServerStorage.GunModels] = { tries, way = 1 | -1 | nil, tip = { [1] = y, [-1] = y } }:
-- what measuring its mesh found (measureMesh, barrelWay)
S.meshShape = {}
-- [gun Tool] = { drawn = os.clock() it last went into a hand, shot = os.clock() of its last shot,
-- held = its owner's device says it is raised, lowering = a lowerLater thread is waiting } (makeGun)
local gunState = setmetatable({}, { __mode = "k" })
S.hatCache, S.hatCacheAt = {}, -math.huge

local function now()
	return Workspace:GetServerTimeNow()
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function finite(v)
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

-- Humanoid and root of a living character, or nil.
local function body(player)
	local char = player and player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return nil
	end
	return hum, root
end

K.WATER_PROBE = Vector3.new(2, 2, 2) -- half-size of the box checked for water around a body

-- Is there terrain water (the ocean or the prison moat) around this spot? The server always holds all
-- the terrain, so streaming doesn't matter here.
local function inWater(pos)
	if not finite(pos) then
		return false
	end
	local region = Region3.new(pos - K.WATER_PROBE, pos + K.WATER_PROBE):ExpandToGrid(4)
	local ok, materials, occupancy = pcall(Workspace.Terrain.ReadVoxels, Workspace.Terrain, region, 4)
	if not ok then
		return false
	end
	local size = materials.Size
	for x = 1, size.X do
		for y = 1, size.Y do
			for z = 1, size.Z do
				if materials[x][y][z] == Enum.Material.Water and occupancy[x][y][z] > 0 then
					return true
				end
			end
		end
	end
	return false
end

-- Really swimming? The humanoid state comes from the player's own device, so it only counts in water.
local function swimming(hum, root)
	return hum:GetState() == Enum.HumanoidStateType.Swimming and inWater(root.Position)
end

local function isPassive(player)
	return player:GetAttribute("Passive") == true
end

-- Is this server-time attribute (SpawnSafeUntil, KnockedUntil...) still in the future?
local function running(player, name)
	local t = player:GetAttribute(name)
	return type(t) == "number" and t > now()
end

local function isDown(player)
	return running(player, "KnockedUntil") or running(player, "StunnedUntil")
end

local function refuse(player, key)
	if not key then
		return
	end
	local t = os.clock()
	if t - (S.lastRefusal[player] or 0) >= K.REFUSE_GAP then
		S.lastRefusal[player] = t
		notify:FireClient(player, key)
	end
end

------------------------------------------------------------------ heat and fights

-- Every star that fighting gives goes through here. Fighting on its own never adds more than `cap`
-- stars (Combat.Heat.Cap for fists and stolen pickups, GunCap for anything done with a gun); the
-- attribute CombatStars counts them (the Heat listener in onPlayer trims it as heat goes down) so the
-- arrest bounty and the knockout bounty can leave them out and friends can't farm either.
-- Returns how many stars it really added (0 at the cap).
local function combatHeat(player, amount, reason, cap)
	if player:GetAttribute("Side") ~= "Civilian" then
		return 0
	end
	local mine = player:GetAttribute("CombatStars") or 0
	local n = math.min(amount, (cap or HEAT.Cap) - mine)
	if n <= 0 then
		return 0
	end
	local before = HeatService.GetHeat(player)
	HeatService.Add(player, n, reason)
	local added = HeatService.GetHeat(player) - before -- (heat tops out at 5)
	if added > 0 then
		player:SetAttribute("CombatStars", mine + added)
	end
	return math.max(added, 0)
end

-- The fight between two players, if one of them hit the other in the last SelfDefence seconds.
local function feudBetween(a, b)
	local f = feuds[a] and feuds[a][b]
	if f and os.clock() - f.at < HEAT.SelfDefence then
		return f
	end
	return nil
end

-- Remember who threw the first hit, so the one who fights back isn't the one who gets the heat.
local function noteFeud(attacker, victim)
	local f = feudBetween(attacker, victim)
	if f then
		f.at = os.clock()
		return
	end
	f = { by = attacker, at = os.clock() }
	feuds[attacker] = feuds[attacker] or {}
	feuds[victim] = feuds[victim] or {}
	feuds[attacker][victim] = f
	feuds[victim][attacker] = f
end

-- Is this player in a fight right now that somebody else started? (Shooting back isn't a crime.)
local function defending(player)
	local mine = feuds[player]
	if not mine then
		return false
	end
	local t = os.clock()
	for _, f in pairs(mine) do
		if f.by ~= player and t - f.at < HEAT.SelfDefence then
			return true
		end
	end
	return false
end

------------------------------------------------------------------ safe zones

local function addCircle(list, pos, r)
	table.insert(list, { circle = true, pos = pos, r = r })
end

local function addBox(list, inst, margin, extraUp)
	local ok, cf, size = pcall(function()
		if inst:IsA("Model") then
			return inst:GetBoundingBox()
		elseif inst:IsA("BasePart") then
			return inst.CFrame, inst.Size
		end
		return nil
	end)
	if ok and cf and size then
		table.insert(list, { cf = cf, half = size / 2 + Vector3.new(margin, margin + (extraUp or 0), margin) })
	end
end

local function rebuildZones()
	local list = {}
	local safe = Combat.SafeZone -- (not "S": that is this script's state table)
	local spawns = Workspace:FindFirstChild("Spawns")
	for _, inst in ipairs(spawns and spawns:GetChildren() or {}) do
		if inst:IsA("SpawnLocation") then
			addCircle(list, inst.Position, safe.SpawnRadius) -- team spawns (car pads are plain Parts)
		elseif inst:IsA("Model") and (inst.Name == "Hideout" or inst.Name == "PoliceLot") then
			local ok, cf, size = pcall(inst.GetBoundingBox, inst)
			if ok then
				-- The big neon pads are 90 wide: cover the whole pad, at least SpawnRadius around it.
				addCircle(list, cf.Position, math.max(safe.SpawnRadius, flat(size).Magnitude / 2 + 5))
			end
		end
	end
	local dealers = Workspace:FindFirstChild("Dealerships")
	for _, m in ipairs(dealers and dealers:GetChildren() or {}) do
		addBox(list, m, safe.DealerMargin, 20)
	end
	local homes = Workspace:FindFirstChild("Homes")
	for _, m in ipairs(homes and homes:GetChildren() or {}) do
		addBox(list, m, safe.HomeMargin, 20)
	end
	local acts = Workspace:FindFirstChild("Activities")
	local meet = acts and acts:FindFirstChild("CarMeet")
	if meet then
		addBox(list, meet, 2, 20)
	end
	-- The Lucky Wheel's plaza (SpinService): a crowd watching a spin shouldn't get robbed.
	local wheel = Workspace:FindFirstChild("LuckyWheel")
	if wheel then
		addBox(list, wheel, safe.WheelMargin or 12, 20)
	end
	local shops = Workspace:FindFirstChild("Shops")
	local store = shops and shops:FindFirstChild(SHOP.Model)
	if store then
		addBox(list, store, safe.ShopMargin, 20)
	end
	S.zones = list
	S.zonesDirty = false
	S.zonesBuiltAt = os.clock()
end

local function markDirty()
	S.zonesDirty = true
end

-- Rebuild the cache when a watched folder gains or loses a lot (and again a moment later, in case the
-- new model is still being filled in).
local function watchFolder(folder)
	if S.watchedFolders[folder] then
		return
	end
	S.watchedFolders[folder] = true
	local function changed()
		markDirty()
		task.delay(3, markDirty)
	end
	folder.ChildAdded:Connect(changed)
	folder.ChildRemoved:Connect(changed)
end

K.WATCH = { Spawns = true, Dealerships = true, Homes = true, Activities = true, Shops = true }

local function inZone(pos)
	for _, z in ipairs(S.zones) do
		if z.circle then
			local d = pos - z.pos
			if math.abs(d.Y) < 60 and flat(d).Magnitude <= z.r then
				return true
			end
		else
			local rel = z.cf:PointToObjectSpace(pos)
			if math.abs(rel.X) <= z.half.X and math.abs(rel.Y) <= z.half.Y and math.abs(rel.Z) <= z.half.Z then
				return true
			end
		end
	end
	return false
end

local function isSafe(player, root)
	if player:GetAttribute("InHome") == true or player:GetAttribute("Side") == "Prisoner" then
		return true
	end
	if player:GetAttribute("BizClub") ~= nil then
		return true -- inside the Afterglow Nightclub (BusinessJobs.Nightclub): no fights on the dance floor
	end
	return root ~= nil and inZone(root.Position)
end

------------------------------------------------------------------ gun models

local function newPart(parent, name, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local GUN_LOOK = {
	Metal = { K.GUN_METAL, Enum.Material.Metal },
	Poly = { K.GUN_POLY, Enum.Material.SmoothPlastic },
	Steel = { K.GUN_STEEL, Enum.Material.Metal },
}
K.BARREL_TURN = CFrame.Angles(0, math.rad(90), 0) -- cylinders run along X; turn them to run along the barrel (Z)

-- One block of a gun: studs, measured from the middle of the grip (the Handle). -Z is forward (the
-- barrel), +Y is up. `tilt`: degrees about X (a positive tilt drops the back end / sweeps the bottom forward).
local function box(name, look, sx, sy, sz, x, y, z, tilt)
	return { name = name, look = look, size = Vector3.new(sx, sy, sz), pos = Vector3.new(x, y, z), tilt = tilt }
end

-- One round piece running along the barrel.
local function tube(name, look, diameter, length, x, y, z)
	return { name = name, look = look, size = Vector3.new(length, diameter, diameter), pos = Vector3.new(x, y, z), round = true }
end

-- The part-built guns, by Combat.Guns[...].Class (used when ServerStorage.GunModels has no model for
-- a gun). Handle = the grip's size; Muzzle = the barrel tip; Grip = Tool.Grip (where the hand sits in
-- the Handle); Mid = the middle of the whole gun (the shop's wall display centres on it). Rough
-- lengths: Pistol 1.3, SMG 2.2, Shotgun 3.6, Rifle 3.5 studs.
-- Mesh: for the ready-made mesh of that class instead (meshGun), which comes with nothing marked on it:
--   Hand = { along, up }  where the right hand holds it, measured from the middle of the mesh's box:
--                         a share of its length (+ = toward the barrel tip) and of its height (+ = up)
--   Bore = up             how high the barrel sits, the same way; only used when the mesh couldn't be
--                         measured (measureMesh finds the real tip)
-- These are the same spots the part-built guns have, as shares of their own boxes. If a mesh sits
-- wrong in the hand, change its two Hand numbers here (or give that model a "Grip" attribute).
local GUN_BUILD = {
	Pistol = {
		Handle = Vector3.new(0.26, 0.78, 0.4),
		Muzzle = Vector3.new(0, 0.52, -1.03),
		Grip = CFrame.new(0, -0.05, 0),
		Mid = Vector3.new(0, 0.2, -0.35),
		Mesh = { Hand = { -0.26, -0.14 }, Bore = 0.34 },
		Parts = {
			box("Slide", "Metal", 0.3, 0.3, 1.25, 0, 0.5, -0.3),
			box("Frame", "Poly", 0.27, 0.14, 0.95, 0, 0.32, -0.33),
			tube("Barrel", "Steel", 0.14, 0.12, 0, 0.52, -0.97),
			box("Guard", "Poly", 0.1, 0.05, 0.42, 0, 0.02, -0.42),
			box("Guard", "Poly", 0.1, 0.26, 0.05, 0, 0.14, -0.62),
			box("Trigger", "Steel", 0.06, 0.18, 0.05, 0, 0.15, -0.36),
			box("RearSight", "Poly", 0.2, 0.06, 0.08, 0, 0.68, 0.24),
			box("FrontSight", "Poly", 0.06, 0.06, 0.08, 0, 0.68, -0.85),
			box("MagBase", "Metal", 0.28, 0.08, 0.44, 0, -0.43, 0),
		},
	},
	SMG = {
		Handle = Vector3.new(0.26, 0.75, 0.38),
		Muzzle = Vector3.new(0, 0.55, -1.32),
		Grip = CFrame.new(0, -0.05, 0),
		Mid = Vector3.new(0, 0.3, -0.21),
		Mesh = { Hand = { -0.12, -0.12 }, Bore = 0.22 },
		Parts = {
			box("Receiver", "Metal", 0.34, 0.42, 1.3, 0, 0.55, -0.3),
			tube("Barrel", "Steel", 0.2, 0.35, 0, 0.55, -1.125),
			box("Mag", "Poly", 0.2, 0.85, 0.3, 0, -0.06, -0.6),
			box("Rail", "Poly", 0.16, 0.06, 0.9, 0, 0.79, -0.3),
			box("RearSight", "Poly", 0.14, 0.1, 0.08, 0, 0.87, 0.1),
			box("FrontSight", "Poly", 0.06, 0.12, 0.06, 0, 0.88, -0.85),
			box("StockRod", "Steel", 0.1, 0.1, 0.45, 0, 0.62, 0.575),
			box("StockPad", "Poly", 0.24, 0.45, 0.08, 0, 0.5, 0.84),
			box("Guard", "Poly", 0.1, 0.05, 0.3, 0, 0.12, -0.33),
			box("Trigger", "Steel", 0.06, 0.16, 0.05, 0, 0.24, -0.3),
		},
	},
	Shotgun = {
		Handle = Vector3.new(0.26, 0.7, 0.38),
		Muzzle = Vector3.new(0, 0.62, -2.42),
		Grip = CFrame.new(0, -0.05, 0),
		Mid = Vector3.new(0, 0.3, -0.58),
		Mesh = { Hand = { -0.16, -0.12 }, Bore = 0.25 },
		Parts = {
			box("Receiver", "Metal", 0.32, 0.42, 1.1, 0, 0.52, -0.3),
			tube("Barrel", "Steel", 0.2, 1.55, 0, 0.62, -1.625),
			tube("MagTube", "Metal", 0.18, 1.35, 0, 0.42, -1.525),
			box("Pump", "Poly", 0.3, 0.28, 0.7, 0, 0.4, -1.45),
			box("Stock", "Poly", 0.24, 0.36, 0.95, 0, 0.42, 0.7, 6),
			box("StockPad", "Poly", 0.26, 0.44, 0.08, 0, 0.36, 1.2),
			box("Bead", "Steel", 0.06, 0.06, 0.06, 0, 0.75, -2.34),
			box("Guard", "Poly", 0.1, 0.05, 0.34, 0, 0.1, -0.36),
			box("Guard", "Poly", 0.1, 0.24, 0.05, 0, 0.2, -0.53),
			box("Trigger", "Steel", 0.06, 0.16, 0.05, 0, 0.22, -0.32),
		},
	},
	Rifle = {
		Handle = Vector3.new(0.26, 0.72, 0.36),
		Muzzle = Vector3.new(0, 0.68, -2.52),
		Grip = CFrame.new(0, -0.05, 0),
		Mid = Vector3.new(0, 0.35, -0.75),
		Mesh = { Hand = { -0.18, -0.2 }, Bore = 0.2 },
		Parts = {
			box("Lower", "Metal", 0.3, 0.3, 1.0, 0, 0.45, -0.3),
			box("Upper", "Metal", 0.3, 0.26, 1.2, 0, 0.72, -0.35),
			box("Handguard", "Poly", 0.32, 0.32, 0.95, 0, 0.68, -1.42),
			tube("Barrel", "Steel", 0.12, 0.5, 0, 0.68, -2.14),
			tube("Brake", "Metal", 0.17, 0.16, 0, 0.68, -2.42),
			box("Mag", "Poly", 0.2, 0.8, 0.36, 0, -0.04, -0.62, 8),
			tube("BufferTube", "Metal", 0.16, 0.7, 0, 0.7, 0.6),
			box("Stock", "Poly", 0.24, 0.5, 0.5, 0, 0.58, 0.75),
			box("Rail", "Poly", 0.14, 0.05, 1.9, 0, 0.875, -0.9),
			box("RearSight", "Poly", 0.12, 0.14, 0.08, 0, 0.96, 0.05),
			box("FrontSight", "Poly", 0.08, 0.16, 0.08, 0, 0.97, -1.8),
			box("Guard", "Poly", 0.1, 0.05, 0.26, 0, 0.1, -0.31),
			box("Trigger", "Steel", 0.06, 0.16, 0.05, 0, 0.2, -0.3),
		},
	},
}

-- A gun part never bumps, blocks a ray or weighs anything: it's only there to be seen.
local function gunPart(p, anchored)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Anchored = anchored == true
end

local function weldTo(handle, p)
	local w = Instance.new("Weld")
	w.Part0 = handle
	w.Part1 = p
	w.C0 = handle.CFrame:ToObjectSpace(p.CFrame)
	w.Parent = p
end

-- The flash and the light at the barrel tip (CombatClient fires them; they stay off by themselves).
local function muzzleFx(muzzle)
	local flash = muzzle:FindFirstChild("Flash")
	if flash and not flash:IsA("ParticleEmitter") then
		flash:Destroy()
		flash = nil
	end
	if not flash then
		-- A short hot burst of flame at the tip (Roblox's own fire texture), not a glitter of stars.
		flash = Instance.new("ParticleEmitter")
		flash.Name = "Flash"
		flash.Texture = "rbxasset://textures/particles/fire_main.dds"
		flash.Color = ColorSequence.new(Color3.fromRGB(255, 236, 190), Color3.fromRGB(255, 160, 60))
		flash.LightEmission = 1
		flash.LightInfluence = 0
		flash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0.3) })
		flash.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
		flash.Lifetime = NumberRange.new(0.03, 0.05)
		flash.Speed = NumberRange.new(0, 2)
		flash.SpreadAngle = Vector2.new(18, 18)
		flash.Rotation = NumberRange.new(0, 360)
		flash.EmissionDirection = Enum.NormalId.Front -- the attachment's -Z = out of the barrel
		flash.LockedToPart = true
		flash.Parent = muzzle
	end
	flash.Rate = 0
	local light = muzzle:FindFirstChild("Light")
	if light and not light:IsA("PointLight") then
		light:Destroy()
		light = nil
	end
	if not light then
		light = Instance.new("PointLight")
		light.Name = "Light"
		light.Color = K.FLASH
		light.Range = 12
		light.Brightness = 4
		light.Shadows = false
		light.Parent = muzzle
	end
	light.Enabled = false
end

-- Build one gun from parts at `base` (the grip's CFrame). `anchored`: a display piece for the shop
-- wall (no welds); otherwise every part is welded to the Handle for a Tool. Returns the Handle, the
-- Muzzle attachment and the build table.
local function buildGun(parent, class, base, scale, anchored)
	local spec = GUN_BUILD[class] or GUN_BUILD.Pistol
	local s = scale or 1
	local handle = newPart(parent, "Handle", spec.Handle * s, base, K.GUN_POLY)
	gunPart(handle, anchored)
	for _, d in ipairs(spec.Parts) do
		local look = GUN_LOOK[d.look]
		local cf = base * CFrame.new(d.pos * s)
		if d.round then
			cf *= K.BARREL_TURN
		elseif d.tilt then
			cf *= CFrame.Angles(math.rad(d.tilt), 0, 0)
		end
		local p = newPart(parent, d.name, d.size * s, cf, look[1], look[2])
		if d.round then
			p.Shape = Enum.PartType.Cylinder
		end
		gunPart(p, anchored)
		if not anchored then
			weldTo(handle, p)
		end
	end
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = spec.Muzzle * s
	muzzle.Parent = handle
	-- (No hand marks on the gun: PoseClient's "Aim" and "LowReady" place both hands from the body's own
	-- size, and the gun rides in the right hand by Tool.Grip.)
	return handle, muzzle, spec
end

-- Feel out the shape of a gun mesh. Nothing on a generated mesh says which end is the barrel, so a
-- see-through copy stands far above the map for a moment and rays drop onto it from above and from
-- below, near both of its ends. (They meet its collision shape, which follows the mesh. Where that is
-- only a box, both ends come out alike and nothing is learned.) Returns:
--   way   1 or -1: the end of the part's own Z axis the barrel is at (a gun is slim at the barrel and
--         tall at the grip and the stock), or nil when the two ends are too alike to tell
--   tip   { [1] = y, [-1] = y }: how high the middle of each end sits, in studs from the part's middle
--         (the barrel's own height, at the barrel end)
local function measureMesh(part)
	local probe = part:Clone()
	probe:ClearAllChildren()
	probe.Name = "GunMeshProbe"
	probe.Anchored = true
	probe.CanCollide = false
	probe.CanTouch = false
	probe.CanQuery = true
	probe.Transparency = 1
	local y0 = 4000
	probe.CFrame = CFrame.new(0, y0, 0) -- (no turn: the part's own axes are the world's here)
	probe.Parent = Workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { probe }
	local size = probe.Size
	local reach = size.Y / 2 + 1
	local down, up = Vector3.new(0, -2 * reach, 0), Vector3.new(0, 2 * reach, 0)
	-- How tall the gun is at `z` along it, and how high the middle of what is there sits.
	local function slice(z)
		local top = Workspace:Raycast(Vector3.new(0, y0 + reach, z), down, params)
		local bottom = Workspace:Raycast(Vector3.new(0, y0 - reach, z), up, params)
		if not top or not bottom then
			return 0, nil
		end
		return math.max(top.Position.Y - bottom.Position.Y, 0), (top.Position.Y + bottom.Position.Y) / 2 - y0
	end
	local tall, tip = { [1] = 0, [-1] = 0 }, {}
	local ok, err = pcall(function()
		for _, side in ipairs({ 1, -1 }) do
			for _, share in ipairs({ 0.44, 0.38, 0.32 }) do
				local height = slice(side * size.Z * share)
				tall[side] += height
			end
			local _, middle = slice(side * size.Z * 0.47)
			tip[side] = middle
		end
	end)
	probe:Destroy() -- (always, whatever the rays did)
	if not ok then
		error(err, 0)
	end
	local way = nil
	local most = math.max(tall[1], tall[-1])
	if most > 0 and math.abs(tall[1] - tall[-1]) > 0.2 * most then
		way = tall[1] < tall[-1] and 1 or -1
	end
	return way, tip
end

-- Which end of its own Z axis this gun model's barrel is at (1 or -1), and how high the barrel tip
-- sits (studs from the part's middle; nil = not known).
--   part   a copy of the model's gun part
--   name   the model's name in ServerStorage.GunModels (what is learned is kept under it)
--   set    the model's "BarrelZ" attribute: a number settles the way by hand
-- Without the attribute the mesh is measured, up to K.MESH_TRIES times (right after start-up its
-- collision shape may not be there yet). While that hasn't told, the barrel is taken to point along
-- -Z, like a Handle's, and one warning says how to turn it round by hand.
local function barrelWay(part, name, set)
	local shape = S.meshShape[name]
	if not shape then
		shape = { tries = 0, tip = {} }
		S.meshShape[name] = shape
	end
	if not shape.way and shape.tries < K.MESH_TRIES then
		shape.tries += 1
		local ok, way, tip = pcall(measureMesh, part)
		if ok then
			shape.way = way
			shape.tip = type(tip) == "table" and tip or shape.tip
		end
	end
	local way = shape.way
	if type(set) == "number" and set ~= 0 then
		way = set > 0 and 1 or -1
	elseif not way then
		way = -1
		if not S.warnedModels["way:" .. name] then
			S.warnedModels["way:" .. name] = true
			warn("[CombatService] couldn't tell which end of ServerStorage.GunModels." .. name .. " is the barrel: taking it to"
				.. " point along the part's -Z. If it sits backwards in the hand, give that model the number attribute"
				.. " BarrelZ = 1 (or BarrelZ = -1 if it sits right, so this isn't said again).")
		end
	end
	-- (The tips are only believed when the ends could be told apart: a box has both of them at its middle.)
	return way, shape.way and shape.tip[way] or nil
end

-- This gun's ready-made model, put into `parent`: a Tool, or (wall = the CFrame of the gun's middle,
-- its -Z = where the barrel should point) an anchored display piece, K.WALL_SCALE times life size.
-- The model is ServerStorage.GunModels.<gun.Model or gun.Id>:
--   * As the mesh generator leaves it: a Model holding one MeshPart ("body_geom") that is the whole
--     gun, standing upright, its barrel along the part's Z axis. Nothing on it is marked, so the copy
--     of that part becomes the Handle as it is, and where the hand goes and where the barrel ends are
--     worked out from its size (GUN_BUILD[class].Mesh) and its measured shape (barrelWay).
--   * Or rigged by hand: a BasePart "Handle" (the grip: -Z = barrel, +Y = up) and an Attachment
--     "Muzzle" at the barrel tip are used exactly as they are; other parts are welded to the Handle.
-- Attributes on the model overrule the working-out (all optional):
--   BarrelZ (number)   1: the barrel points along the gun part's +Z; -1: along its -Z
--   Grip (CFrame)      Tool.Grip, as it is
--   Muzzle (Vector3)   the barrel tip, in the gun part's own space
-- Returns Tool.Grip for it, or nil when the place has no usable model (the caller builds from parts).
local function meshGun(parent, gun, wall)
	local folder = ServerStorage:FindFirstChild("GunModels")
	local name = gun.Model or gun.Id
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return nil
	end
	local cloned, clone = pcall(template.Clone, template)
	if not cloned then
		clone = nil
	end
	-- The gun part: one named "Handle", else the generator's "body_geom", else the biggest part there.
	local main = nil
	if clone and clone:IsA("BasePart") then
		main = clone
	elseif clone then
		for _, wanted in ipairs({ "Handle", "body_geom" }) do
			local found = clone:FindFirstChild(wanted, true)
			if not main and found and found:IsA("BasePart") then
				main = found
			end
		end
		if not main then
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("BasePart") and (not main or d.Size.Magnitude > main.Size.Magnitude) then
					main = d
				end
			end
		end
	end
	if not main then
		if clone then
			clone:Destroy()
		end
		if not S.warnedModels[name] then
			S.warnedModels[name] = true
			warn("[CombatService] ServerStorage.GunModels." .. name .. " holds no part to use as the gun (or can't be copied:"
				.. " Archivable off): using the part-built gun instead")
		end
		return nil
	end
	-- Old joints and scripts go. Any other part is welded to the gun part exactly where it sits now.
	local others = {}
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") and d ~= main then
			table.insert(others, d)
		end
	end
	if wall and #others > 0 then
		clone:Destroy() -- (the wall only shows one-piece meshes: the part-built gun hangs there instead)
		return nil
	end
	local function setting(key) -- an attribute of the model, else of its gun part
		local value = template:GetAttribute(key)
		if value == nil then
			value = main:GetAttribute(key)
		end
		return value
	end
	local muzzle = clone:FindFirstChild("Muzzle", true)
	if muzzle and not muzzle:IsA("Attachment") then
		muzzle = nil
	end
	local spec = GUN_BUILD[gun.Class] or GUN_BUILD.Pistol
	local rigged = main.Name == "Handle" and muzzle ~= nil
	local way, tipY = -1, nil
	if rigged then
		local set = setting("BarrelZ")
		way = (type(set) == "number" and set > 0) and 1 or -1 -- (a Handle's barrel is its -Z unless told otherwise)
	else
		way, tipY = barrelWay(main, name, setting("BarrelZ"))
	end
	-- A part whose barrel runs along its +Z is turned half way round in the hand, and so is what is marked on it.
	local turn = way > 0 and CFrame.Angles(0, math.pi, 0) or CFrame.new()
	local size = main.Size
	main.Name = "Handle"
	if wall then
		gunPart(main, true)
		main.Size = size * K.WALL_SCALE
		main.CFrame = wall * turn
		main.Parent = parent
		if clone ~= main then
			clone:Destroy()
		end
		return spec.Grip
	end
	gunPart(main, false)
	for _, p in ipairs(others) do
		gunPart(p, false)
		weldTo(main, p)
	end
	if not muzzle then
		local at = setting("Muzzle")
		if typeof(at) ~= "Vector3" then
			-- The very front of the mesh, as high as its barrel (measured; else the class's usual share).
			at = Vector3.new(0, tipY or spec.Mesh.Bore * size.Y, way * size.Z / 2)
		end
		muzzle = Instance.new("Attachment")
		muzzle.Name = "Muzzle"
		muzzle.CFrame = CFrame.new(at) * turn -- (its -Z points out of the barrel: the flash goes that way)
		muzzle.Parent = main
	end
	muzzleFx(muzzle)
	local grip = setting("Grip")
	if typeof(grip) ~= "CFrame" then
		if rigged then
			grip = spec.Grip
		else
			local hand = spec.Mesh.Hand
			grip = CFrame.new(0, hand[2] * size.Y, way * hand[1] * size.Z) * turn
		end
	end
	main.Parent = parent -- a Tool only finds a Handle that is its own child
	if clone ~= main then
		for _, c in ipairs(clone:GetChildren()) do
			c.Parent = parent
		end
		clone:Destroy()
	end
	return grip
end

------------------------------------------------------------------ tools

local function makeFists()
	local tool = Instance.new("Tool")
	tool.Name = FISTS.Name
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = "Fists"
	tool:SetAttribute(K.ATTR, "Fists")
	return tool
end

local function makeGun(gun)
	local tool = Instance.new("Tool")
	tool.Name = gun.Name
	tool.ToolTip = gun.Name
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	-- CombatClient fires from its own buttons: a tap that only drags the camera on a phone must never shoot.
	tool.ManualActivationOnly = true
	tool:SetAttribute(K.ATTR, "Gun")
	tool:SetAttribute(K.GUN_ATTR, gun.Id)
	tool:SetAttribute(K.AMMO_ATTR, gun.Mag)
	-- The place's own mesh for this gun when it has one, else the part-built one. (pcall: whatever a
	-- model in the place turns out to hold, nobody is left without their gun.)
	local ok, grip = pcall(meshGun, tool, gun, nil)
	if ok and grip then
		tool.Grip = grip
	else
		if not ok then
			tool:ClearAllChildren() -- (whatever half of the model made it in)
			local name = gun.Model or gun.Id
			if not S.warnedModels["error:" .. name] then
				S.warnedModels["error:" .. name] = true
				warn("[CombatService] ServerStorage.GunModels." .. name .. " couldn't be used (" .. tostring(grip)
					.. "): using the part-built gun instead")
			end
		end
		-- Built at the origin. With this grip the Handle's -Z points where the arm points, so the barrel
		-- faces forward in the held-out pose.
		local _, muzzle, spec = buildGun(tool, gun.Class, CFrame.new(), 1, false)
		muzzleFx(muzzle)
		tool.Grip = spec.Grip
	end
	local st = { shot = 0, held = false }
	gunState[tool] = st
	-- Putting the gun away cancels a reload (the magazine keeps what it had) and lowers it for everyone.
	tool.Unequipped:Connect(function()
		st.held = false
		for _, name in ipairs({ K.RELOAD_ATTR, K.AIM_ATTR, K.AIMUP_ATTR }) do
			if tool:GetAttribute(name) ~= nil then
				tool:SetAttribute(name, nil)
			end
		end
	end)
	-- When it last went into a hand: any move out of the Backpack counts, however it got there (the
	-- backpack's own equip, or an exploit parenting it straight into the character). onFire refuses a
	-- gun that has only just arrived, so nobody empties four guns' fire-rate limits in one go.
	tool.AncestryChanged:Connect(function(child, parent)
		if child == tool and parent ~= nil and not parent:IsA("Backpack") then
			st.drawn = os.clock()
			st.held = false
		end
	end)
	return tool
end

local function findFists(char)
	if not char then
		return nil
	end
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") and c:GetAttribute(K.ATTR) == "Fists" then
			return c
		end
	end
	return nil
end

-- The gun Tool with this id that the character is holding (equipped Tools sit in the character), or nil.
local function heldGun(char, gunId)
	if not char then
		return nil
	end
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") and c:GetAttribute(K.ATTR) == "Gun" and c:GetAttribute(K.GUN_ATTR) == gunId then
			return c
		end
	end
	return nil
end

-- Is `tool` the only Tool in this character? Roblox's backpack only ever puts one in the hand; an
-- exploiter can parent several, and each gun has its own fire-rate bucket, so two in hand would add up.
local function onlyTool(char, tool)
	for _, c in ipairs(char:GetChildren()) do
		if c ~= tool and c:IsA("Tool") then
			return false
		end
	end
	return true
end

-- Where a held gun points, for everyone's view of the shooter's arms (attributes AimPitch / AimUp,
-- CombatClient poses them). Degrees, rounded to steps of 2 so a still hand never sends anything.
local function setAim(tool, pitch, up)
	pitch = math.clamp(math.floor(pitch / 2 + 0.5) * 2, -80, 80)
	if tool:GetAttribute(K.AIM_ATTR) ~= pitch then
		tool:SetAttribute(K.AIM_ATTR, pitch)
	end
	local raised = up and true or nil
	if tool:GetAttribute(K.AIMUP_ATTR) ~= raised then
		tool:SetAttribute(K.AIMUP_ATTR, raised)
	end
end

-- A gun the server raised for a shot comes down again K.AIM_HOLD seconds after its last one, unless its
-- owner's device has said meanwhile that it is being aimed (then that device lowers it: onAim). One
-- waiting thread per burst, however many shots are in it. st: the gun's gunState record.
local function lowerLater(tool, st)
	if st.lowering then
		return
	end
	st.lowering = true
	task.spawn(function()
		while tool.Parent ~= nil do
			local left = st.shot + K.AIM_HOLD - os.clock()
			if left <= 0 then
				break
			end
			task.wait(left)
		end
		st.lowering = false
		if not st.held and tool.Parent ~= nil and tool:GetAttribute(K.AIMUP_ATTR) ~= nil then
			tool:SetAttribute(K.AIMUP_ATTR, nil)
		end
	end)
end

-- The saved gear table, with anything missing filled in (older saves have no guns or armor).
local function gearOf(data)
	if type(data.gear) ~= "table" then
		data.gear = {}
	end
	local gear = data.gear
	if type(gear.guns) ~= "table" then
		gear.guns = {}
	end
	local armor = gear.armor
	if type(armor) ~= "number" or armor ~= armor then
		armor = 0
	end
	gear.armor = math.clamp(math.floor(armor + 0.5), 0, Combat.ArmorMax)
	return gear
end

-- [gun id] = true for every gun this player owns, or nil while their save is still loading.
local function ownedGuns(player)
	local data = DataService.Get(player)
	local gear = data and data.gear
	if type(gear) ~= "table" or type(gear.guns) ~= "table" then
		return nil
	end
	return gear.guns
end

-- The "Guns" attribute: owned citizen guns in shop order, comma-separated ("" for none).
local function gunsString(guns)
	local list = {}
	for _, id in ipairs(Combat.GunOrder) do
		if guns[id] == true then
			table.insert(list, id)
		end
	end
	return table.concat(list, ",")
end

-- What a combat Tool is: "Fists", a gun id, or nil for any other Tool (the taser, robber tools).
-- A combat Tool of a kind that no longer exists (the retired Stun Blaster) gets a key nobody wants,
-- so syncTools takes it away.
local function toolKey(tool)
	local kind = tool:GetAttribute(K.ATTR)
	if kind == "Fists" then
		return "Fists"
	elseif kind == "Gun" then
		return tool:GetAttribute(K.GUN_ATTR) or "Retired"
	elseif kind ~= nil then
		return "Retired"
	end
	return nil
end

S.wantList, S.haveSet = {}, {} -- scratch for syncTools (it runs for every player every 2 s)

-- Give or take away the combat tools so they match the rules right now. Safe to call any time.
--   citizen, not passive: Fists, then every owned gun in shop order (hotbar 1, 2, 3...)
--   cop: the Service Pistol
--   prisoner, passive, no side yet: nothing
local function syncTools(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local char = player.Character
	if not backpack or not char then
		return
	end
	local want, have = S.wantList, S.haveSet
	table.clear(want)
	table.clear(have)
	local side = player:GetAttribute("Side")
	if side == "Cop" then
		table.insert(want, Combat.CopGun)
	elseif side == "Civilian" and not isPassive(player) then
		table.insert(want, "Fists")
		local guns = ownedGuns(player)
		if guns then
			for _, id in ipairs(Combat.GunOrder) do
				if guns[id] == true then
					table.insert(want, id)
				end
			end
		end
	end
	-- The one in the hand first, so a spare in the backpack is the one that goes.
	for pass = 1, 2 do
		for _, c in ipairs((pass == 1 and char or backpack):GetChildren()) do
			if c:IsA("Tool") then
				local key = toolKey(c)
				if key ~= nil then
					if have[key] or not table.find(want, key) then
						c:Destroy() -- not allowed right now, or a spare
					else
						have[key] = true
					end
				end
			end
		end
	end
	for _, key in ipairs(want) do
		if not have[key] then
			local tool = key == "Fists" and makeFists() or makeGun(Combat.Guns[key])
			tool.Parent = backpack
		end
	end
end

------------------------------------------------------------------ armor

local function savedArmor(player)
	local data = DataService.Get(player)
	local gear = data and data.gear
	local v = type(gear) == "table" and gear.armor or nil
	if type(v) ~= "number" or v ~= v then
		return 0
	end
	return math.clamp(math.floor(v + 0.5), 0, Combat.ArmorMax)
end

-- The attribute follows the side: a citizen wears what they bought; cops and prisoners show 0 (the
-- saved armor waits for them).
local function refreshArmor(player)
	local value = player:GetAttribute("Side") == "Civilian" and savedArmor(player) or 0
	if player:GetAttribute("Armor") ~= value then
		player:SetAttribute("Armor", value)
	end
end

-- A citizen's armor changed (a hit, a purchase): save it and show it.
local function setArmor(player, value)
	value = math.clamp(math.floor(value + 0.5), 0, Combat.ArmorMax)
	local data = DataService.Get(player)
	if data then
		gearOf(data).armor = value
	end
	if player:GetAttribute("Armor") ~= value then
		player:SetAttribute("Armor", value)
	end
end

------------------------------------------------------------------ passive mode

local function setPassive(player, on)
	player:SetAttribute("Passive", on)
	if on then
		S.passiveOnAt[player] = os.clock()
	else
		S.passiveOffAt[player] = os.clock()
	end
	local data = DataService.Get(player)
	if data then
		data.settings = data.settings or {}
		data.settings.Passive = on
		SettingsService.Mirror(player)
	end
	syncTools(player)
end

-- The phone's SETTINGS toggle (through SettingsService). Returns true if the state is now `on`.
function CombatService.RequestPassive(player, on)
	on = on == true
	if isPassive(player) == on then
		return true
	end
	local t = os.clock()
	if on then
		if player:GetAttribute("Side") == "Cop" then
			notify:FireClient(player, "PassiveCop")
			return false
		elseif HeatService.GetHeat(player) > 0 then
			notify:FireClient(player, "PassiveHasHeat")
			return false
		elseif EconomyService.GetCarried(player) > 0 then
			notify:FireClient(player, "PassiveHasBag")
			return false
		elseif (player:GetAttribute("Daze") or 0) > 0 or isDown(player) or t - (S.lastAttack[player] or -math.huge) < Combat.Passive.FightLock then
			-- Only your own hits and shots lock you: someone being picked on can go passive once they're back up.
			notify:FireClient(player, "PassiveInFight")
			return false
		elseif t - (S.passiveOffAt[player] or -math.huge) < Combat.Passive.OnCooldown then
			notify:FireClient(player, "PassiveCooldownOn")
			return false
		end
	elseif t - (S.passiveOnAt[player] or -math.huge) < Combat.Passive.OffCooldown then
		notify:FireClient(player, "PassiveCooldownOff")
		return false
	end
	setPassive(player, on)
	notify:FireClient(player, on and "PassiveOn" or "PassiveOff")
	return true
end

-- Heat, a bag or a cop's badge ends passive mode on its own.
local function autoPassiveOff(player, key)
	if isPassive(player) then
		setPassive(player, false)
		notify:FireClient(player, key)
	end
end

------------------------------------------------------------------ effects

-- Send an effect to everyone within `range` studs of `pos` (plus anyone in `always`).
local function fxNear(pos, range, always, ...)
	for _, p in ipairs(Players:GetPlayers()) do
		local _, root = body(p)
		if table.find(always, p) or (root and (root.Position - pos).Magnitude <= range) then
			fxRemote:FireClient(p, ...)
		end
	end
end

-- Send an effect to everyone but `except` within `range` studs of `a` (or of `b`, when given). The
-- shooter draws their own shot at once, so they are never sent it back.
local function fxOthers(except, range, a, b, ...)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= except then
			local _, root = body(p)
			if root and ((root.Position - a).Magnitude <= range or (b ~= nil and (root.Position - b).Magnitude <= range)) then
				fxRemote:FireClient(p, ...)
			end
		end
	end
end

local function setDaze(player, value)
	value = math.clamp(math.floor(value + 0.5), 0, Combat.DazeMax)
	if player:GetAttribute("Daze") ~= value then
		player:SetAttribute("Daze", value)
	end
end

------------------------------------------------------------------ dropped bags and wallets

local function money(amount)
	local s = tostring(math.floor(amount))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return "$" .. out
end

local function removeBag(rec)
	rec.gone = true
	local i = table.find(bags, rec)
	if i then
		table.remove(bags, i)
	end
	if rec.model then
		rec.model:Destroy()
	end
end

local function refreshBag(rec)
	rec.prompt.ActionText = "Grab " .. money(rec.amount)
	rec.label.Text = money(rec.amount)
	rec.model:SetAttribute("Amount", rec.amount)
end

-- One set of rules for both pickups (rec.kind = "Bag" | "Wallet").
local function grabBag(player, rec)
	if rec.gone or rec.busy or rec.amount <= 0 then
		return
	end
	if not RateLimit.Allow(player, "GrabBag", 4, 4) then
		return -- (touches fire many times a second)
	end
	local side = player:GetAttribute("Side")
	if side == "Prisoner" then
		return
	end
	local hum, root = body(player)
	if not hum then
		return
	end
	if hum.SeatPart then
		refuse(player, "CombatInCar")
		return
	end
	if isDown(player) or (root.Position - rec.pos).Magnitude > 14 then
		return
	end
	if player == rec.owner and os.clock() < rec.ownerWait then
		return -- still seeing stars
	end
	local wallet = rec.kind == "Wallet"
	if side == "Cop" and player ~= rec.owner then
		-- Returned to the bank: the cash is gone. The evidence reward is never more than half of it, so
		-- knocking a friend out for a cop to hand in always loses money. (A cop's own bag: taken back
		-- below, like anyone's.)
		rec.busy = true -- marked before paying: nothing below yields
		local reward = math.min(Combat.Drop.CopReward, math.floor(rec.amount * Combat.Drop.CopShare))
		rec.amount = 0
		removeBag(rec)
		if reward > 0 then
			EconomyService.AddCash(player, reward, "evidence")
		end
		fxRemote:FireClient(player, "Returned", { Reward = reward, Kind = rec.kind })
		return
	end
	if EconomyService.GetCarried(player) >= EconomyService.CarryLimit(player) then
		refuse(player, "DroppedBagFull")
		return
	end
	rec.busy = true -- marked before paying: nothing below yields
	local fits = EconomyService.AddCarried(player, rec.amount, wallet and "grabbed_wallet" or "grabbed_bag")
	rec.amount -= fits
	local stolen = player ~= rec.owner
	local stars = 0 -- (none when fighting stars are already at the cap, or heat at 5)
	if fits > 0 and stolen then
		stars = combatHeat(player, Combat.Drop.Heat, wallet and "stolen_wallet" or "stolen_bag", HEAT.Cap)
	end
	if fits > 0 then
		fxRemote:FireClient(player, "Grabbed", { Amount = fits, Stolen = stolen, Left = rec.amount, Stars = stars, Kind = rec.kind })
	end
	if rec.amount <= 0 then
		removeBag(rec)
	else
		rec.busy = false
		refreshBag(rec)
	end
end

-- The glowing duffel. Returns the part that is touched / holds the prompt, and the amount label.
local function buildDuffel(m, pos, yaw)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local bag = newPart(m, "Bag", Vector3.new(3, 1.7, 1.7), base * CFrame.new(0, 0.85, 0), K.PLUM, Enum.Material.Fabric,
		{ Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = true })
	newPart(m, "Stripe", Vector3.new(0.35, 1.8, 1.8), base * CFrame.new(0, 0.85, 0), K.GOLD, Enum.Material.Neon,
		{ Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false })
	for _, x in ipairs({ -0.55, 0.55 }) do
		newPart(m, "Strap", Vector3.new(0.18, 0.7, 0.18), base * CFrame.new(x, 1.95, 0), K.PINK, nil,
			{ Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	newPart(m, "Strap", Vector3.new(1.3, 0.18, 0.18), base * CFrame.new(0, 2.3, 0), K.PINK, nil,
		{ Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false })
	local ring = newPart(m, "Glow", Vector3.new(0.1, 5, 5), CFrame.new(pos + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)), K.GOLD,
		Enum.Material.Neon, { Shape = Enum.PartType.Cylinder, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 0.55 })
	local light = Instance.new("PointLight")
	light.Color = K.GOLD
	light.Range = 10
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = ring
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(K.GOLD)
	sparkle.LightEmission = 1
	sparkle.Rate = 6
	sparkle.Lifetime = NumberRange.new(0.6, 1)
	sparkle.Speed = NumberRange.new(1, 2)
	sparkle.Size = NumberSequence.new(0.4)
	sparkle.SpreadAngle = Vector2.new(60, 60)
	sparkle.Parent = bag
	local gui = Instance.new("BillboardGui")
	gui.Name = "Amount"
	gui.Size = UDim2.fromScale(5, 1.4) -- studs, so it shrinks with distance
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = K.GOLD
	label.TextStrokeColor3 = K.DARK
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	gui.Parent = bag
	return bag, label
end

-- A small dark billfold with a strip of green showing. It's tiny, so an unseen box around it takes the
-- touch and holds the prompt, and a soft green light helps find it at night.
local function buildBillfold(m, pos, yaw)
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	local touch = newPart(m, "Wallet", Vector3.new(3, 2, 3), base * CFrame.new(0, 1, 0), K.DARK, nil,
		{ Transparency = 1, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = true })
	local fold = newPart(m, "Billfold", Vector3.new(1.1, 0.22, 0.8), base * CFrame.new(0, 0.13, 0), Color3.fromRGB(40, 30, 26), nil,
		{ Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false })
	newPart(m, "Cash", Vector3.new(0.9, 0.06, 0.5), base * CFrame.new(0.06, 0.27, 0.05), Theme.Color.Cash, nil,
		{ Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false })
	local light = Instance.new("PointLight")
	light.Color = Theme.Color.Cash
	light.Range = 7
	light.Brightness = 0.9
	light.Shadows = false
	light.Parent = fold
	local gui = Instance.new("BillboardGui")
	gui.Name = "Amount"
	gui.Size = UDim2.fromScale(3.2, 1) -- studs, so it shrinks with distance
	gui.StudsOffset = Vector3.new(0, 1.2, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.Font.Display
	label.TextScaled = true
	label.TextColor3 = Theme.Color.Cash
	label.TextStrokeColor3 = Theme.Color.Shadow
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = touch
	return touch, label
end

-- A pickup on the ground at `pos` holding exactly `amount` (already taken from `owner`).
-- kind: "Bag" (the robbery bag's share) or "Wallet" (pocket cash).
local function spawnBag(pos, amount, owner, yaw, kind)
	while #bags >= K.MAX_BAGS do
		removeBag(bags[1])
	end
	local wallet = kind == "Wallet"
	local rec = { kind = wallet and "Wallet" or "Bag", amount = amount, owner = owner, pos = pos,
		ownerWait = os.clock() + Combat.KOSeconds + Combat.Drop.OwnerWait }
	local m = Instance.new("Model")
	m.Name = wallet and "DroppedWallet" or "DroppedBag"
	m:SetAttribute("Kind", rec.kind)
	local touch, label
	if wallet then
		touch, label = buildBillfold(m, pos, yaw)
	else
		touch, label = buildDuffel(m, pos, yaw)
	end
	m.PrimaryPart = touch
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BagGrab"
	prompt.ObjectText = wallet and "Wallet" or "Dropped bag"
	prompt.HoldDuration = 0.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = touch
	rec.model, rec.prompt, rec.label = m, prompt, label
	refreshBag(rec)
	prompt.Triggered:Connect(function(p)
		grabBag(p, rec)
	end)
	touch.Touched:Connect(function(hit)
		local model = hit:FindFirstAncestorOfClass("Model")
		local p = model and Players:GetPlayerFromCharacter(model)
		-- Walking over it only picks it up for its owner, a cop, or someone already wanted. Everyone
		-- else has to mean it (the hold prompt), so nobody gets a star by brushing past.
		if p and (p == rec.owner or p:GetAttribute("Side") == "Cop" or (not isPassive(p) and HeatService.GetHeat(p) > 0)) then
			grabBag(p, rec)
		end
	end)
	pcall(function()
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	m.Parent = bagFolder
	table.insert(bags, rec)
	task.delay(Combat.Drop.Lifetime, function()
		if not rec.gone then
			removeBag(rec) -- nobody claimed it: the cash is gone
		end
	end)
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = false

local function groundAt(spot)
	local hit = Workspace:Raycast(spot + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), groundParams)
	return hit and hit.Position or (spot - Vector3.new(0, 3, 0))
end

-- Where a knocked-out player's cash lands: the bag a couple of studs toward the attacker, the wallet
-- a step beside it, both on the ground.
local function groundSpots(root, toward)
	local exclude = { bagFolder, Workspace:FindFirstChild("Vehicles") }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	groundParams.FilterDescendantsInstances = exclude
	local step = toward.Magnitude > 0.1 and toward.Unit or Vector3.zero
	local side = step.Magnitude > 0.5 and Vector3.new(-step.Z, 0, step.X) or Vector3.new(1, 0, 0)
	local spot = root.Position + step * 2.5
	return groundAt(spot), groundAt(spot + side * 1.5)
end

-- Take the drop out of the victim's bag and put it on the ground at `pos`. Returns the amount dropped.
local function dropBag(victim, pos)
	local carried = EconomyService.GetCarried(victim)
	if carried < Combat.Drop.Min then
		return 0 -- pocket change stays put (no $1 bags to farm)
	end
	local share = math.max(math.floor(carried * Combat.Drop.Share + 0.5), Combat.Drop.Min)
	share = math.min(share, carried)
	if share <= 0 then
		return 0
	end
	-- Take everything, give back the rest: whatever doesn't fit back goes in the bag too, so no money
	-- is ever lost or made.
	local taken = EconomyService.TakeCarried(victim, "knocked_out")
	local back = taken - share
	local kept = back > 0 and EconomyService.AddCarried(victim, back, "knocked_out_kept") or 0
	local amount = taken - kept
	if amount <= 0 then
		return 0
	end
	spawnBag(pos, amount, victim, math.random() * math.pi * 2, "Bag")
	return amount
end

-- A little of the victim's banked Cash drops as a wallet (citizens only; the caller checks that).
-- Never more than they have, and not again for Wallet.VictimGap seconds, so nobody can be picked
-- clean by being knocked out over and over. Returns the amount dropped.
local function dropWallet(victim, pos)
	local W = Combat.Wallet
	local cash = EconomyService.GetCash(victim)
	if cash < W.Min then
		return 0
	end
	local t = os.clock()
	local last = S.walletAt[victim.UserId]
	if last and t - last < W.VictimGap then
		return 0
	end
	local amount = math.min(cash, math.clamp(math.floor(cash * W.Share + 0.5), W.Min, W.Max))
	if amount <= 0 or not EconomyService.Spend(victim, amount, "wallet_dropped") then
		return 0
	end
	S.walletAt[victim.UserId] = t
	spawnBag(pos, amount, victim, math.random() * math.pi * 2, "Wallet")
	return amount
end

------------------------------------------------------------------ hits

-- Why this attacker can't fight right now: a Notify key, false for a silent no, or nil if they can.
-- needFists: a punch (citizens only, Fists in the hand). A shot checks its own gun and side first.
local function attackerProblem(player, needFists)
	if needFists and player:GetAttribute("Side") ~= "Civilian" then
		return false
	end
	local hum, root = body(player)
	if not hum then
		return false
	end
	if hum.SeatPart then
		return "CombatInCar"
	end
	if swimming(hum, root) then
		return "CombatSwimming" -- swimmers can't be knocked out (knockOut), so they can't fight either
	end
	if needFists then
		local fists = findFists(player.Character)
		if not fists or not onlyTool(player.Character, fists) then
			return false -- Fists have to be in their hand, and nothing else with them (see onlyTool)
		end
	end
	if isPassive(player) then
		return "CombatPassiveYou"
	end
	if isDown(player) then
		return false
	end
	if isSafe(player, root) then
		return "CombatSafeZone"
	end
	if running(player, "SpawnSafeUntil") then
		return "CombatSpawnYou"
	end
	return nil
end

-- Why this victim can't be hit: a Notify key for the attacker, false for a silent no, nil if they can.
-- gun: the gun used (nil for a punch). A gun with MinStars (the cops' Service Pistol) only works on
-- citizens wanted that much.
local function victimProblem(attacker, victim, gun)
	local side = victim:GetAttribute("Side")
	if side == "Prisoner" then
		return "CombatPrisoner"
	end
	if side ~= "Civilian" and side ~= "Cop" then
		return false
	end
	if gun and gun.MinStars then
		-- (Owner, Oct 30: player cops may do what the AI officers do. A wanted citizen with a gun in hand,
		-- or who fired one in the last K.THREAT_MEMORY seconds, may be shot from 1 star.)
		local heat = side == "Civilian" and HeatService.GetHeat(victim) or 0
		local threat = heat >= 1 and S.lastAggroKind[victim] == "Gun" and os.clock() - (S.lastAggroAt[victim] or -math.huge) < K.THREAT_MEMORY
		for _, c in ipairs((heat >= 1 and not threat and victim.Character) and victim.Character:GetChildren() or {}) do
			threat = threat or (c:IsA("Tool") and c:GetAttribute(K.ATTR) == "Gun")
		end
		if heat < gun.MinStars and not threat then
			return "CopHoldFire"
		end
	end
	local hum, root = body(victim)
	if not hum or hum.SeatPart or S.killed[victim] == victim.Character then
		return false
	end
	if isPassive(victim) then
		return "CombatPassiveThem"
	end
	if isSafe(victim, root) then
		return "CombatSafeZone"
	end
	if running(victim, "SpawnSafeUntil") then
		return "CombatSpawnThem"
	end
	if isDown(victim) or running(victim, "CombatSafeUntil") then
		return false
	end
	local crew = attacker:GetAttribute("Crew")
	if crew ~= nil and crew == victim:GetAttribute("Crew") then
		return false -- crewmates never hit each other
	end
	return nil
end

------------------------------------------------------------------ line of sight

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- Every hat and hair in the game. Rebuilt at most twice a second: an automatic gun asks for it a dozen
-- times a second, and a hat that is half a second old in the list still gets passed through.
local function hats()
	local t = os.clock()
	if t - S.hatCacheAt > K.HAT_REFRESH then
		S.hatCacheAt = t
		table.clear(S.hatCache)
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p.Character
			if char then
				for _, a in ipairs(char:GetChildren()) do
					if a:IsA("Accessory") then
						table.insert(S.hatCache, a)
					end
				end
			end
		end
	end
	return S.hatCache
end

-- Everything a bullet or a punch passes through: the attacker, every hat and hair, dropped bags and
-- wallets, plus `extra` (the victim's own body, when checking the way to them). A fresh list each time:
-- firstSolid adds to it.
local function boltIgnore(shooter, extra)
	local list = table.clone(hats())
	if shooter.Character then
		table.insert(list, shooter.Character)
	end
	table.insert(list, bagFolder)
	if extra then
		table.insert(list, extra)
	end
	return list
end

-- Does this part stop a bullet or a punch? Solid or visible parts do. Invisible walk-through parts
-- (triggers, zones, the hidden landmark placeholders) don't, except smoke clouds (RobberToolsService,
-- Workspace.Smoke): they block sight, the same way they block tasers.
local function blocks(inst)
	if inst.CanCollide or inst.Transparency < 0.95 then
		return true
	end
	local smoke = Workspace:FindFirstChild("Smoke")
	return smoke ~= nil and inst:IsDescendantOf(smoke)
end

-- The first thing a ray really hits, skipping parts that don't block (`ignore` is a list; it grows).
-- Returns the RaycastResult (a player's body or a blocking part), or nil for a clear line. The second
-- result is set when it gave up after too many see-through parts in a row: treat that as blocked.
local function firstSolid(origin, vector, ignore)
	local left = vector.Magnitude
	if left < 0.05 then
		return nil, nil
	end
	local dir = vector.Unit
	local from = origin
	for _ = 1, 8 do
		rayParams.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(from, dir * left, rayParams)
		if not hit then
			return nil, nil
		end
		local inst = hit.Instance
		local model = inst:FindFirstAncestorOfClass("Model")
		if (model and Players:GetPlayerFromCharacter(model)) or blocks(inst) then
			return hit, nil
		end
		table.insert(ignore, inst)
		left -= (hit.Position - from).Magnitude
		from = hit.Position
		if left <= 0.05 then
			return nil, nil
		end
	end
	return nil, from
end

-- Is the way from the attacker's chest to the victim's clear (no wall, door, window or floor between)?
local function clearBetween(attacker, fromRoot, victim, toRoot)
	local up = Vector3.new(0, 1.5, 0)
	local a = fromRoot.Position + up
	local hit, stuck = firstSolid(a, toRoot.Position + up - a, boltIgnore(attacker, victim.Character))
	return hit == nil and stuck == nil
end

------------------------------------------------------------------ who heard that?

-- Is this spot within `reach` studs (flat) of a road's centre line? Pedestrians live on each player's
-- own device, so the server can't see them: "on or near a street" stands in for "people around".
-- Plain numbers only: this runs while guns are firing.
local function nearStreet(pos, reach)
	local nodes = RoadGraph.Nodes
	if #nodes == 0 then
		return false
	end
	local px, pz = pos.X, pos.Z
	local reach2 = reach * reach
	for i, a in ipairs(nodes) do
		local edges = RoadGraph.Edges[i]
		if edges then
			for j in pairs(edges) do
				local b = nodes[j]
				if i < j and b then
					local abx, abz = b.X - a.X, b.Z - a.Z
					local len2 = abx * abx + abz * abz
					local t = len2 > 0 and math.clamp(((px - a.X) * abx + (pz - a.Z) * abz) / len2, 0, 1) or 0
					local dx, dz = px - (a.X + abx * t), pz - (a.Z + abz * t)
					if dx * dx + dz * dz <= reach2 then
						return true
					end
				end
			end
		end
	end
	return false
end

-- Did anyone hear a shot fired at `pos`? A player cop or a patrol car close by, or the street.
local function witnessed(pos)
	local range = HEAT.GunfireCopRange
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("Side") == "Cop" then
			local _, root = body(p)
			if root and (root.Position - pos).Magnitude <= range then
				return true, true
			end
		end
	end
	local cars = Workspace:FindFirstChild("Vehicles")
	for _, car in ipairs(cars and cars:GetChildren() or {}) do
		if car:GetAttribute("AIPolice") and car:IsA("Model") then
			local chassis = car.PrimaryPart
			if chassis and (chassis.Position - pos).Magnitude <= range then
				return true, true
			end
		end
	end
	return nearStreet(pos, HEAT.GunfireStreet), false -- (second value: was it the police themselves who heard it?)
end

-- How many pedestrians this player has knocked over lately (CombatService.PedVictim counts them).
-- Forgotten Ped.VictimMemory seconds after the last one, and when the cops lose them (onPlayer).
local function pedVictims(player)
	local v = S.pedVictims[player]
	if v and os.clock() - v.at > (Combat.Ped.VictimMemory or 180) then
		S.pedVictims[player] = nil
		v = nil
	end
	return v and v.n or 0
end

-- A citizen fired a gun: one star at most every GunfireGap seconds, when someone heard it and they
-- aren't shooting back at whoever started it.
local function gunfireHeat(player, origin, hitPlayer)
	if player:GetAttribute("Side") ~= "Civilian" then
		return
	end
	local t = os.clock()
	if t - (S.lastGunfire[player] or -math.huge) < HEAT.GunfireGap or t - (S.lastWitness[player] or -math.huge) < K.WITNESS_GAP then
		return
	end
	S.lastWitness[player] = t
	local heard, byPolice = witnessed(origin)
	if defending(player) or not heard then
		return
	end
	-- Owner's rule: the street only calls the police once a second pedestrian is down (Ped.FreeVictims).
	-- Until then a shot the street heard brings nobody. Police who hear it themselves, and a shot that
	-- hits another player, count at once as they always did.
	if not byPolice and not hitPlayer and pedVictims(player) <= (Combat.Ped.FreeVictims or 0) then
		return
	end
	S.lastGunfire[player] = t
	combatHeat(player, HEAT.Gunfire, "gunfire", HEAT.GunCap)
end

------------------------------------------------------------------ knockouts

-- Heat for whoever landed the knockout: none for knocking out a wanted player (vigilante), or the one
-- who threw the first hit in this fight (self-defence). `snap` (from onFled, may be nil): what the
-- victim was when last hit, since a side switch changes their side before the character goes.
-- withGun: the last hit was a bullet (the higher star cap).
local function koHeat(attacker, victim, snap, withGun)
	local f = feudBetween(attacker, victim)
	if f and f.by == victim then
		return
	end
	local cop = victim:GetAttribute("Side") == "Cop"
	local wanted = HeatService.GetHeat(victim) > 0
	if snap then
		cop, wanted = snap.cop, wanted or snap.wanted
	end
	local cap = withGun and HEAT.GunCap or HEAT.Cap
	if cop then
		combatHeat(attacker, HEAT.KOCop, "knocked_out_cop", cap)
	elseif not wanted then
		combatHeat(attacker, HEAT.KO, "knocked_out", cap)
	end
end

-- Knocking out a wanted citizen pays a bounty from the system: `paid` stars (the ones real crimes gave
-- them: fight stars pay nothing, so nobody farms a friend) x PerStar. Once per wanted spell (`since` =
-- their WantedSince when it happened: a knockout doesn't end the chase, so a friend who stays wanted
-- would otherwise pay out every few minutes), and never twice within VictimGap seconds either.
-- Returns the amount and "Bounty" (cops) or "Vigilante" (citizens), or 0.
local function payBounty(attacker, victim, paid, wasCitizen, since)
	if not wasCitizen or type(paid) ~= "number" or paid < 1 then
		return 0, nil
	end
	local side = attacker:GetAttribute("Side")
	if side ~= "Cop" and side ~= "Civilian" then
		return 0, nil
	end
	local t = os.clock()
	local last = S.bountyAt[victim.UserId]
	if last and ((since ~= nil and last.since == since) or t - last.at < Combat.Bounty.VictimGap) then
		return 0, nil
	end
	S.bountyAt[victim.UserId] = { since = since, at = t }
	local cop = side == "Cop"
	local amount = EconomyService.AddCash(attacker, paid * Combat.Bounty.PerStar, cop and "ko_bounty" or "vigilante")
	return amount, cop and "Bounty" or "Vigilante"
end

-- A gun took their health to 0 (or a car did: CombatService.CarHit): they die. The money, heat and
-- bounty go exactly as for a knockout, then the body falls limp for good and its health goes to 0
-- K.KILL_DELAY later. After that the death is ArrestService's (police right there: an arrest on the
-- spot) and RespawnService's (RESPAWN); onFled, which every death runs, does nothing for this body
-- (S.killed). attacker: nil when nobody did it (traffic, an AI patrol): no heat, bounty or ELIMINATED
-- then. gun: the gun table, or { Name, Cause (the death screen's line), Ragdoll (RagdollService's
-- reason) } for something else. Returns true.
local function kill(attacker, victim, hum, root, dir, speed, gun)
	local char = victim.Character
	S.killed[victim] = char
	setDaze(victim, Combat.DazeMax) -- (HEALTH 0 until the new body)
	S.lastHitAt[victim] = nil
	S.lastAttacker[victim] = nil
	S.lastHitInfo[victim] = nil
	local citizen = victim:GetAttribute("Side") == "Civilian"
	local bagPos, walletPos = groundSpots(root, flat(-dir)) -- (a little toward the attacker)
	local dropped = dropBag(victim, bagPos)
	local wallet = citizen and dropWallet(victim, walletPos) or 0
	local bounty, bountyKind = 0, nil
	if attacker then
		koHeat(attacker, victim, nil, true)
		bounty, bountyKind = payBounty(attacker, victim, HeatService.PaidStars(victim), citizen, victim:GetAttribute("WantedSince"))
	end
	fxRemote:FireClient(victim, "Killed", { By = attacker and attacker.DisplayName or nil, Gun = gun.Name, Cause = gun.Cause,
		Dropped = dropped, Wallet = wallet })
	if attacker then
		fxRemote:FireClient(attacker, "KOd", { Name = victim.DisplayName, Dropped = dropped, Wallet = wallet, Bounty = bounty,
			BountyKind = bountyKind, Killed = true })
	end
	if RagdollService then
		-- (The same hop as a knockout's fall: ImpactService.)
		local ok, err = pcall(RagdollService.KnockDown, victim, nil, dir * math.clamp(speed * 0.25, 10, 22) + Vector3.new(0, 14, 0),
			gun.Ragdoll or "shot", K.DEAD)
		if not ok then
			warn("[CombatService] ragdoll: " .. tostring(err))
		end
	end
	task.delay(K.KILL_DELAY, function()
		if hum.Parent and hum.Health > 0 and victim.Character == char then
			hum.Health = 0
		end
	end)
	return true
end

-- Health hit 0. gun: the gun that did it (nil for fists: a knockout; a gun kills). Returns true if they
-- went down.
local function knockOut(attacker, victim, dir, speed, gun)
	local hum, root = body(victim)
	if root and gun then
		return kill(attacker, victim, hum, root, dir, speed, gun)
	end
	-- A swimmer's own device refuses to tip them over (ImpactClient), so don't count it as a knockout.
	-- (Only in real water: a state faked on land still gets knocked out here.)
	-- (The last word tells RagdollService what did it: neither a bullet nor a punch is braced for.)
	if not root or swimming(hum, root)
		or not ImpactService.KnockDown(victim, dir, speed, Combat.KOSeconds, gun and "shot" or "punch") then
		setDaze(victim, Combat.DazeMax - 5) -- couldn't fall right now (just got up, swimming): next hit does it
		return false
	end
	setDaze(victim, 0)
	S.lastHitAt[victim] = nil
	S.lastAttacker[victim] = nil
	S.lastHitInfo[victim] = nil
	victim:SetAttribute("CombatSafeUntil", now() + Combat.KOSeconds + Combat.ImmuneAfterKO)
	local citizen = victim:GetAttribute("Side") == "Civilian"
	local bagPos, walletPos = groundSpots(root, flat(-dir)) -- (a little toward the attacker)
	local dropped = dropBag(victim, bagPos)
	local wallet = citizen and dropWallet(victim, walletPos) or 0
	koHeat(attacker, victim, nil, gun ~= nil)
	local bounty, bountyKind = payBounty(attacker, victim, HeatService.PaidStars(victim), citizen, victim:GetAttribute("WantedSince"))
	fxRemote:FireClient(victim, "KO", { By = attacker.DisplayName, Gun = gun and gun.Name or FISTS.Name, Dropped = dropped, Wallet = wallet })
	fxRemote:FireClient(attacker, "KOd", { Name = victim.DisplayName, Dropped = dropped, Wallet = wallet, Bounty = bounty, BountyKind = bountyKind })
	return true
end

-- The character went away mid-fight (hurt, or hit in the last FleeWindow seconds): the Reset button,
-- a side switch (TeamService respawns you) or leaving the game. It counts as a knockout, so bailing
-- out never saves the bag or the wallet, or the attacker's heat and bounty; those go by what they were
-- when last hit. Getting arrested (jailed and respawned as a prisoner) isn't bailing out: nothing
-- happens. Safe to run twice for one bail-out: the second time finds nothing to do.
local function onFled(player, char)
	if S.killed[player] == char then
		return -- shot dead: kill already dropped and paid everything
	end
	local attacker = S.lastAttacker[player]
	local snap = S.lastHitInfo[player]
	local fleeing = (player:GetAttribute("Daze") or 0) > 0 or os.clock() - (S.lastHitAt[player] or -math.huge) < Combat.FleeWindow
	S.lastHitAt[player] = nil
	S.lastAttacker[player] = nil
	S.lastHitInfo[player] = nil
	setDaze(player, 0)
	if player:GetAttribute("Side") == "Prisoner" then
		return -- (ArrestService already took the bag and cleared the heat; Side is set before the respawn)
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not fleeing or not root or not root:IsA("BasePart") then
		return
	end
	local _, attackerRoot = body(attacker)
	local toward = attackerRoot and flat(attackerRoot.Position - root.Position) or Vector3.zero
	local bagPos, walletPos = groundSpots(root, toward)
	local dropped = dropBag(player, bagPos)
	local here = player.Parent == Players and not leaving[player]
	local citizen = player:GetAttribute("Side") == "Civilian"
	if snap then
		citizen = snap.civ == true
	end
	-- No wallet from someone leaving the game: their save may already be on its way out, and Cash taken
	-- now could come back with them (free money on the ground).
	local wallet = (citizen and here) and dropWallet(player, walletPos) or 0
	if (dropped > 0 or wallet > 0) and here then
		fxRemote:FireClient(player, "Fled", { Dropped = dropped, Wallet = wallet })
	end
	if attacker and attacker.Parent == Players and not leaving[attacker] then
		koHeat(attacker, player, snap, snap ~= nil and snap.gun ~= nil)
		local bounty, bountyKind = payBounty(attacker, player, snap and snap.paid or 0, citizen, snap and snap.since or nil)
		fxRemote:FireClient(attacker, "KOd", { Name = player.DisplayName, Dropped = dropped, Wallet = wallet, Bounty = bounty,
			BountyKind = bountyKind, Fled = true })
	end
end

------------------------------------------------------------------ people the server put in the street

-- A hit on one of them (an officer, a shop clerk): the service that owns that kind decides what it does
-- (looked up when first needed: they require this module). Returns true if it counted.
local function hitNPC(attacker, model, damage, dir, kind)
	local owner = K.NPC_OWNERS[model:GetAttribute("NPCKind")]
	local module = owner and ServerScriptService.Services:FindFirstChild(owner)
	local ok, svc = pcall(function()
		return module and require(module)
	end)
	if not ok or type(svc) ~= "table" or type(svc.NPCHit) ~= "function" then
		return false
	end
	local ran, counted = pcall(svc.NPCHit, model, attacker, damage, dir, kind)
	if not ran then
		warn("[CombatService] " .. tostring(owner) .. ".NPCHit: " .. tostring(counted))
		return false
	end
	return counted == true
end

-- The hittable NPC a part belongs to (a living model straight under Workspace.NPCs with an NPCKind), or nil.
local function npcOf(inst)
	local npcs = Workspace:FindFirstChild("NPCs")
	if not npcs or not inst:IsDescendantOf(npcs) then
		return nil
	end
	local model = inst:FindFirstAncestorOfClass("Model")
	while model and model.Parent ~= npcs do
		model = model:FindFirstAncestorOfClass("Model")
	end
	local hum = model and model:GetAttribute("NPCKind") ~= nil and model:FindFirstChildOfClass("Humanoid")
	return (hum and hum.Health > 0) and model or nil
end

------------------------------------------------------------------ punches and shots

-- A hit that passed every check. kind: "Punch" | "Gun"; damage: the whole hit (a shotgun's pellets
-- added up); gun: the gun table for a bullet. Returns the damage, whether armor took all of it, and
-- whether the victim went down.
local function landHit(attacker, victim, kind, dir, pos, damage, gun)
	local t = os.clock()
	local side = victim:GetAttribute("Side")
	local attackerCop = attacker:GetAttribute("Side") == "Cop"
	S.lastAttack[attacker] = t
	S.lastHitAt[victim] = t
	S.lastAttacker[victim] = attacker
	local info = S.lastHitInfo[victim]
	if not info then
		info = {}
		S.lastHitInfo[victim] = info
	end
	info.cop = side == "Cop"
	info.civ = side == "Civilian"
	info.wanted = HeatService.GetHeat(victim) > 0
	info.paid = HeatService.PaidStars(victim)
	info.since = victim:GetAttribute("WantedSince") -- which wanted spell (one bounty each: payBounty)
	info.gun = gun
	if not attackerCop then
		-- (A cop shooting a wanted player isn't "starting a fight": knocking that cop out still costs stars.)
		noteFeud(attacker, victim)
	end
	if attacker:GetAttribute("CombatSafeUntil") ~= nil then
		attacker:SetAttribute("CombatSafeUntil", nil) -- landing a hit ends your own after-knockout immunity
	end
	if side == "Cop" then
		S.copHitAt[attacker] = S.copHitAt[attacker] or setmetatable({}, { __mode = "k" })
		if t - (S.copHitAt[attacker][victim] or -math.huge) > HEAT.CopMemory then
			combatHeat(attacker, HEAT.HitCop, "hit_cop", gun and HEAT.GunCap or HEAT.Cap)
		end
		S.copHitAt[attacker][victim] = t
	end
	-- Armor first (citizens only: the attribute is 0 for everyone else), then health.
	local armor = side == "Civilian" and (victim:GetAttribute("Armor") or 0) or 0
	local absorbed = math.clamp(armor, 0, damage)
	if absorbed > 0 then
		setArmor(victim, armor - absorbed)
	end
	local rest = damage - absorbed
	local daze = math.min(Combat.DazeMax, (victim:GetAttribute("Daze") or 0) + rest)
	local _, attackerRoot = body(attacker)
	fxRemote:FireClient(victim, "Hit", { Kind = kind, Gun = gun and gun.Id or nil, By = attacker, Damage = damage,
		From = attackerRoot and attackerRoot.Position or pos })
	if kind == "Punch" then
		fxNear(pos, K.PUNCH_FX_RANGE, { attacker, victim }, "Punch", attacker, victim, pos)
	end
	local down = false
	if daze >= Combat.DazeMax then
		down = knockOut(attacker, victim, dir, gun and 45 or 30, gun)
	else
		setDaze(victim, daze)
	end
	return damage, rest <= 0, down
end

-- Players within `range` in front of `root` (flat distance), nearest first. `suggested` gets a little
-- extra range and a wider cone (the client turned to face them; the server may not have seen it yet).
local function punchCandidates(attacker, root, suggested)
	local list = {}
	local look = flat(root.CFrame.LookVector)
	look = look.Magnitude > 0.05 and look.Unit or Vector3.new(0, 0, -1)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= attacker then
			local _, r = body(p)
			if r then
				local rel = r.Position - root.Position
				local d = flat(rel).Magnitude
				local isPick = p == suggested
				local range = FISTS.Range + (isPick and FISTS.Slack or 0)
				local cone = isPick and 0 or FISTS.Cone
				if d <= range and math.abs(rel.Y) < 6 and (d < 1 or flat(rel).Unit:Dot(look) > cone) then
					table.insert(list, { p = p, d = d, root = r })
				end
			end
		end
	end
	table.sort(list, function(a, b)
		return a.d < b.d
	end)
	return list
end

-- Bare hands: the attack key (CombatClient: X, or a click / R2 with nothing held) throws a punch without
-- picking Fists first. Nothing in the hand and Fists in the backpack: they go into the hand here, so
-- the punch below finds them (the client equips them too, but that arrives later than this request).
local function bareHands(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local pack = player:FindFirstChildOfClass("Backpack")
	if not hum or not pack or hum.SeatPart or char:FindFirstChildOfClass("Tool") then
		return
	end
	for _, c in ipairs(pack:GetChildren()) do
		if c:IsA("Tool") and c:GetAttribute(K.ATTR) == "Fists" then
			hum:EquipTool(c)
			return
		end
	end
end

local function onPunch(player, suggested, bare)
	local t = os.clock()
	if t - (S.lastSwing[player] or 0) < FISTS.Cooldown * 0.8 then
		return -- (a little slack for network jitter)
	end
	if bare == true and player:GetAttribute("Side") == "Civilian" then
		bareHands(player)
	end
	local problem = attackerProblem(player, true)
	if problem ~= nil then
		refuse(player, problem)
		return
	end
	S.lastSwing[player] = t
	S.lastAggroAt[player], S.lastAggroKind[player] = t, "Fists" -- a swing counts, hit or miss (PedService)
	player:SetAttribute("Surrender", nil) -- (hands up and swinging is no surrender: PoliceOfficerService)
	-- Everyone else's CombatClient throws the jab (or the cross) on this player's arms when it changes.
	local fists = findFists(player.Character)
	if fists then
		fists:SetAttribute(K.SWING_ATTR, (fists:GetAttribute(K.SWING_ATTR) or 0) + 1)
	end
	local _, root = body(player)
	if typeof(suggested) ~= "Instance" or not suggested:IsA("Player") then
		suggested = nil
	end
	local firstProblem
	for _, c in ipairs(punchCandidates(player, root, suggested)) do
		local why = victimProblem(player, c.p, nil)
		if why == nil and not clearBetween(player, root, c.p, c.root) then
			why = false -- a wall, door, window or floor in the way: just a whiff
		end
		if why == nil then
			local dir = flat(c.root.Position - root.Position)
			landHit(player, c.p, "Punch", dir.Magnitude > 0.1 and dir.Unit or flat(root.CFrame.LookVector), c.root.Position, FISTS.Damage, nil)
			return
		elseif firstProblem == nil then
			firstProblem = why
		end
	end
	-- No player in reach: someone the server put in the street (an officer, a clerk) right in front?
	local npcs = firstProblem == nil and Workspace:FindFirstChild("NPCs")
	if npcs then
		local look = flat(root.CFrame.LookVector)
		look = look.Magnitude > 0.05 and look.Unit or Vector3.new(0, 0, -1)
		local best, bestD, bestRoot
		for _, m in ipairs(npcs:GetChildren()) do
			local r = m:IsA("Model") and m:GetAttribute("NPCKind") ~= nil and m:FindFirstChild("HumanoidRootPart")
			if r and r:IsA("BasePart") then
				local rel = r.Position - root.Position
				local d = flat(rel).Magnitude
				if d <= FISTS.Range + FISTS.Slack and math.abs(rel.Y) < 6 and (d < 1 or flat(rel).Unit:Dot(look) > FISTS.Cone)
					and (not bestD or d < bestD) then
					best, bestD, bestRoot = m, d, r
				end
			end
		end
		if best then
			local dir = flat(bestRoot.Position - root.Position)
			if hitNPC(player, best, FISTS.Damage, dir.Magnitude > 0.1 and dir.Unit or look, "Punch") then
				fxNear(bestRoot.Position, K.PUNCH_FX_RANGE, { player }, "Punch", player, nil, bestRoot.Position)
				return
			end
		end
	end
	refuse(player, firstProblem) -- why the nearest one couldn't be hit (a whiff says nothing)
end

-- The client's aim assist picked this player: accept them if the shot (from `origin` along the unit
-- vector `dir`) passed within `slack` studs of them and nothing blocks the way to them (they moved a
-- little between the client's frame and ours). `ignore`: boltIgnore(shooter, their character).
local function lagCheck(origin, dir, victim, range, slack, ignore)
	local _, r = body(victim)
	if not r then
		return nil
	end
	local to = r.Position - origin
	local along = to:Dot(dir) -- how far down the shot they are
	if along < 0.5 or along > range + 4 then
		return nil
	end
	if (to - dir * along).Magnitude > slack then
		return nil -- the shot passed too far from them
	end
	local hit, stuck = firstSolid(origin, to, ignore)
	if hit or stuck then
		return nil -- a wall (even behind see-through parts) or another player in the way
	end
	return r.Position
end

-- One trigger pull. The client says which gun and where it aims, and may name who it thinks it hit;
-- ammo, spread, damage, the shot's start and who is really hit are all decided here.
local function onFire(player, gunId, aim, suggested)
	local gun = Combat.Gun(gunId)
	if not gun or typeof(aim) ~= "Vector3" or not finite(aim) then
		return
	end
	if typeof(suggested) ~= "Instance" or not suggested:IsA("Player") or suggested == player then
		suggested = nil
	end
	local char = player.Character
	local tool = heldGun(char, gun.Id)
	if not tool or not onlyTool(char, tool) or player:GetAttribute("Side") ~= gun.Side then
		return
	end
	-- Only just drawn (or never seen going into a hand): not yet. Each gun has its own fire-rate limit,
	-- so without this an exploit could swap through every gun it owns and empty them all in one frame.
	-- (CombatClient waits the whole Combat.DrawTime, so an honest draw never gets here early.)
	local st = gunState[tool]
	if not st or os.clock() - (st.drawn or math.huge) < K.DRAW_MIN then
		return
	end
	local problem = attackerProblem(player, false)
	if problem ~= nil then
		refuse(player, problem)
		return
	end
	local ammo = tool:GetAttribute(K.AMMO_ATTR)
	local reloadUntil = tool:GetAttribute(K.RELOAD_ATTR)
	if type(ammo) ~= "number" or ammo <= 0 or (type(reloadUntil) == "number" and reloadUntil > now()) then
		return
	end
	-- A gun with one shot in hand (the shotgun) has no burst to soak up a phone's jitter: it may fire up
	-- to 0.15 s early instead. The magazine and the reload still cap what it can do over time.
	local rate = (gun.Burst or 1) <= 1 and 1 / math.max(gun.Interval - 0.15, gun.Interval * 0.6) or K.RATE_SLACK / gun.Interval
	if not RateLimit.Allow(player, K.GUN_KEY[gun.Id], rate, gun.Burst) then
		return
	end
	-- ...and one limit shared by every gun: whatever is swapped in, the shots together never come
	-- faster than the fastest gun alone could fire them.
	if not RateLimit.Allow(player, "GunAny", K.ANY_GUN_RATE, K.ANY_GUN_BURST) then
		return
	end
	-- Accepted: the round is spent whatever it hits.
	tool:SetAttribute(K.AMMO_ATTR, ammo - 1)
	local t = os.clock()
	st.shot = t
	S.lastAggroAt[player], S.lastAggroKind[player] = t, "Gun"
	S.lastAttack[player] = t -- the passive lock starts on any shot, hit or miss
	player:SetAttribute("Surrender", nil) -- (nor is shooting)
	if player:GetAttribute("CombatSafeUntil") ~= nil then
		-- Shooting ends your own after-knockout immunity, hit or miss: nobody fires from behind it.
		player:SetAttribute("CombatSafeUntil", nil)
	end

	local _, root = body(player)
	local head = char:FindFirstChild("Head")
	local origin = (head and head:IsA("BasePart")) and head.Position or (root.Position + Vector3.new(0, 1.5, 0))
	local dir = aim - origin
	dir = dir.Magnitude >= 0.5 and dir.Unit or root.CFrame.LookVector
	if not st.held then
		-- Everyone sees the gun come up where it fired. (While the shooter's own device reports its aim,
		-- that is what shows, and that device lowers the gun again: onAim. Otherwise lowerLater does.)
		setAim(tool, math.deg(math.asin(math.clamp(dir.Y, -1, 1))), true)
		lowerLater(tool, st)
	end

	local pellets = gun.Pellets
	local ends, onBody = table.create(pellets), table.create(pellets)
	local victims, damages, spots -- made on the first body hit
	local npcHits -- [NPC model] = { damage, spot }: pellets on people the server put in the street
	local ignore = boltIgnore(player)
	local lagIgnore -- made the first time the suggested target is checked
	for i = 1, pellets do
		local d = Combat.SpreadDir(dir, gun.Spread, rng)
		local hit, stuck = firstSolid(origin, d * gun.Range, ignore)
		local endPos, victim
		local npc
		if hit then
			endPos = hit.Position
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			victim = model and Players:GetPlayerFromCharacter(model) or nil
			npc = not victim and npcOf(hit.Instance) or nil
			if npc then
				npcHits = npcHits or {}
				local rec = npcHits[npc] or { 0, endPos }
				rec[1] += Combat.DamageAt(gun, (endPos - origin).Magnitude)
				npcHits[npc] = rec
			end
		else
			endPos = stuck or (origin + d * gun.Range)
		end
		if not victim and suggested then
			lagIgnore = lagIgnore or boltIgnore(player, suggested.Character)
			local at = lagCheck(origin, d, suggested, gun.Range, gun.LagStuds, lagIgnore)
			if at then
				endPos, victim = at, suggested
			end
		end
		ends[i] = endPos
		onBody[i] = victim ~= nil or npc ~= nil
		if victim then
			local damage = Combat.DamageAt(gun, (endPos - origin).Magnitude)
			if not victims then
				victims, damages, spots = {}, {}, {}
			end
			local k = table.find(victims, victim)
			if k then
				damages[k] += damage
			else
				table.insert(victims, victim)
				table.insert(damages, damage)
				table.insert(spots, endPos)
			end
		end
	end

	fxOthers(player, Combat.Fx.ShotRange, origin, ends[1], "Shot", player, gun.Id, origin, ends, onBody)
	gunfireHeat(player, origin, victims ~= nil and #victims > 0)

	if victims then
		local push = flat(dir)
		for k, victim in ipairs(victims) do
			local why = victimProblem(player, victim, gun)
			if why == nil then
				local dealt, armorOnly, down = landHit(player, victim, "Gun", push, spots[k], damages[k], gun)
				fxRemote:FireClient(player, "HitMark", { Victim = victim, Damage = dealt, ArmorOnly = armorOnly, Down = down, Pos = spots[k] })
			else
				refuse(player, why) -- the round is spent and the shot is seen; it just does nothing
			end
		end
	end
	for model, rec in pairs(npcHits or {}) do
		if hitNPC(player, model, rec[1], flat(dir), "Gun") then
			fxRemote:FireClient(player, "HitMark", { Damage = rec[1], Pos = rec[2] })
		end
	end
end

-- Refill the magazine after gun.Reload seconds, if the gun is still in their hand by then.
local function onReload(player, gunId)
	local gun = Combat.Gun(gunId)
	if not gun then
		return
	end
	local char = player.Character
	local tool = heldGun(char, gun.Id)
	if not tool or not onlyTool(char, tool) or player:GetAttribute("Side") ~= gun.Side then
		return
	end
	local ammo = tool:GetAttribute(K.AMMO_ATTR)
	local reloadUntil = tool:GetAttribute(K.RELOAD_ATTR)
	local t = now()
	if type(ammo) ~= "number" or ammo >= gun.Mag or (type(reloadUntil) == "number" and reloadUntil > t) then
		return
	end
	local doneAt = t + gun.Reload
	tool:SetAttribute(K.RELOAD_ATTR, doneAt)
	local _, root = body(player)
	if root then
		fxOthers(player, Combat.Fx.ReloadRange, root.Position, nil, "Reload", player, gun.Id)
	end
	task.delay(gun.Reload, function()
		-- Unequipping clears ReloadUntil and a new reload writes a new time: only finish our own.
		if tool:GetAttribute(K.RELOAD_ATTR) ~= doneAt then
			return
		end
		if tool.Parent == char then
			tool:SetAttribute(K.AMMO_ATTR, gun.Mag)
		end
		tool:SetAttribute(K.RELOAD_ATTR, nil)
	end)
end

-- ("Aim", pitch, up): where the gun in hand points and whether it is raised, so everyone sees the arms
-- follow (CombatClient sends it when either changes). Looks only: nothing is decided from it.
local function onAim(player, pitch, up)
	if not RateLimit.Allow(player, "GunAim", 10, 10) then
		return
	end
	if type(pitch) ~= "number" or pitch ~= pitch or type(up) ~= "boolean" then
		return
	end
	local char = player.Character
	for _, c in ipairs(char and char:GetChildren() or {}) do
		if c:IsA("Tool") and c:GetAttribute(K.ATTR) == "Gun" then
			local st = gunState[c]
			if st then
				st.held = up -- (raised by the player: lowerLater leaves it up until they say otherwise)
			end
			setAim(c, pitch, up)
			return
		end
	end
end

local function onAction(player, action, a, b, c)
	if action == "Aim" then
		onAim(player, a, b) -- (its own limit, checked first: a pose update never uses up the shots' budget)
		return
	end
	if not RateLimit.Allow(player, "CombatAction", 25, 30) then
		return
	end
	if action == "Punch" then
		onPunch(player, a, b)
	elseif action == "Fire" then
		onFire(player, a, b, c)
	elseif action == "Reload" then
		onReload(player, a)
	end
end

------------------------------------------------------------------ Coast Arms

local function surfaceText(p, face, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = face
	gui.LightInfluence = 0
	gui.Brightness = 1.6
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.MaxDistance = 400
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.Font.Display
	label.TextScaled = true
	label.TextColor3 = color or Theme.Color.Text
	label.Text = text
	label.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.1, 0), UDim.new(0.1, 0)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.04, 0), UDim.new(0.04, 0)
	pad.Parent = label
	gui.Parent = p
end

local function glow(p, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = p
end

-- GunShopBuy(itemId): a gun id from Combat.GunOrder, or "Armor". Asked from the shop panel's BUY button.
local function onBuy(player, itemId)
	if not RateLimit.Allow(player, "GunShopBuy", 1, 2) then
		return
	end
	local data = DataService.Get(player)
	if not data then
		return
	end
	if player:GetAttribute("Side") ~= "Civilian" then
		notify:FireClient(player, "GunShopCivOnly")
		return
	end
	local _, root = body(player)
	local near = false
	for _, pos in ipairs(buyPoints) do
		if root and (root.Position - pos).Magnitude <= SHOP.BuyRange then
			near = true
		end
	end
	if not near then
		notify:FireClient(player, "GunShopTooFar")
		return
	end
	if type(itemId) ~= "string" then
		return
	end
	local gun = table.find(Combat.GunOrder, itemId) ~= nil and Combat.Guns[itemId] or nil
	local armorItem = Combat.ArmorItem
	if not gun and itemId ~= armorItem.Id then
		return
	end
	local gear = gearOf(data)
	if gun then
		if gear.guns[gun.Id] == true then
			notify:FireClient(player, "GunOwned")
			return
		end
		if not Combat.RankOk(player, gun) then
			notify:FireClient(player, "GunNeedsRank")
			return
		end
		if not EconomyService.Spend(player, gun.Price, K.GUN_REASON[gun.Id] or ("gun_" .. string.lower(gun.Id))) then
			notify:FireClient(player, "NotEnoughCash")
			return
		end
		gear.guns[gun.Id] = true
		player:SetAttribute("Guns", gunsString(gear.guns))
		-- (pcall: the cash is spent and the gun is theirs whatever happens to the Tool: the stamp and the
		-- save below must still go out. The 2 s tool check tries again.)
		local ok, err = pcall(syncTools, player)
		if not ok then
			warn("[CombatService] tools for " .. player.Name .. ": " .. tostring(err))
		end
	else
		if gear.armor >= Combat.ArmorMax then
			notify:FireClient(player, "ArmorFull")
			return
		end
		if not EconomyService.Spend(player, armorItem.Price, "body_armor") then
			notify:FireClient(player, "NotEnoughCash")
			return
		end
		setArmor(player, Combat.ArmorMax)
	end
	-- (Passive players get no tools: the stamp tells them how to get it into their hotbar.)
	fxRemote:FireClient(player, "Bought", { Item = itemId, Passive = isPassive(player) })
	task.spawn(DataService.SaveNow, player) -- a purchase: save it right away
end

-- A palm: the city art's palm mesh (ServerStorage.ArtAssets.PalmTree) if there is one, else parts.
local function palm(parent, pos, scale)
	local assets = ServerStorage:FindFirstChild("ArtAssets")
	local template = assets and assets:FindFirstChild("PalmTree")
	if template and template:IsA("BasePart") then
		local p = template:Clone()
		p.Anchored = true
		p.CanTouch = false
		p.CastShadow = false
		p.Size = template.Size * scale
		p.CFrame = CFrame.new(pos + Vector3.new(0, p.Size.Y / 2, 0)) * CFrame.Angles(0, math.rad(40), 0)
		p.Parent = parent
		return
	end
	local h = 18 * scale
	local base = CFrame.new(pos) * CFrame.Angles(math.rad(6), math.rad(40), 0)
	newPart(parent, "Trunk", Vector3.new(h, 1.3 * scale, 1.3 * scale), base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		K.TRUNK, nil, { Anchored = true, Shape = Enum.PartType.Cylinder, CanTouch = false })
	local top = base * CFrame.new(0, h, 0)
	for f = 1, 6 do
		newPart(parent, "Frond", Vector3.new(2 * scale, 0.3, 9 * scale),
			top * CFrame.Angles(0, math.rad(f * 60), 0) * CFrame.new(0, 0, -4 * scale) * CFrame.Angles(math.rad(-18), 0, 0),
			K.LEAF, nil, { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false })
	end
end

-- Warn (only) if the shop overlaps something already in the city, so the lead can move it.
local function checkLot(cf, size)
	local list = {}
	for _, n in ipairs({ "City", "Heists", "Spawns", "Activities", "Dealerships", "Homes" }) do
		local f = Workspace:FindFirstChild(n)
		if f then
			table.insert(list, f)
		end
	end
	if #list == 0 then
		return
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = list
	local hits = Workspace:GetPartBoundsInBox(cf, size, params)
	if #hits > 0 then
		local names = {}
		for i = 1, math.min(#hits, 4) do
			table.insert(names, hits[i]:GetFullName())
		end
		warn(string.format("[CombatService] the Coast Arms lot overlaps %d existing part(s), e.g. %s", #hits, table.concat(names, ", ")))
	end
end

-- Coast Arms: a plain stucco gun store with an open serving window over a counter, facing west to
-- the road. Local frame (SHOP_FRAME): -Z = west (front), +X = north; the lot is x -20..20, z -28..28
-- (the same footprint the old shop had, so nothing around it moves).
local function buildShop()
	-- The shop's own colours (kept in here: the script's top level is near Luau's 200-local limit).
	local CONCRETE = Color3.fromRGB(150, 150, 146) -- forecourt
	local STUCCO = Color3.fromRGB(224, 212, 190) -- walls: warm off-white
	local STUCCO_DARK = Color3.fromRGB(176, 164, 144) -- kerb, pillars, planters
	local CHARCOAL = Color3.fromRGB(38, 40, 44) -- counter, header, roof, canopy, gun wall
	local STEEL = Color3.fromRGB(120, 124, 130)
	local FLOOR = Color3.fromRGB(96, 96, 100)
	local WOOD = Color3.fromRGB(126, 90, 58) -- counter top
	local PAPER = Color3.fromRGB(236, 232, 220) -- parking lines, the target
	local SAFETY = Color3.fromRGB(232, 190, 40) -- bollards
	local SIGN_RED = Color3.fromRGB(168, 36, 40)
	local WARM = Color3.fromRGB(255, 226, 176) -- lights
	local NAVY = Color3.fromRGB(34, 44, 68) -- the vest
	local OLIVE = Color3.fromRGB(86, 94, 60) -- ammo boxes and crates...
	local TAN = Color3.fromRGB(178, 150, 110) -- ...two kinds
	local shops = Workspace:FindFirstChild("Shops") or Instance.new("Folder")
	shops.Name = "Shops"
	shops.Parent = Workspace
	for _, name in ipairs({ SHOP.Model, "ZapShack" }) do -- (the second: the shop this one replaced, in an old place file)
		local old = shops:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	table.clear(buyPoints)
	local m = Instance.new("Model")
	m.Name = SHOP.Model
	m:SetAttribute("PlaceName", SHOP.Name)
	m:SetAttribute("PlaceKind", SHOP.Kind)
	local function at(x, y, z)
		return SHOP_FRAME * CFrame.new(x, y, z)
	end
	local function part(name, size, cf, color, material, props)
		props = props or {}
		props.Anchored = true
		if props.CanTouch == nil then
			props.CanTouch = false
		end
		return newPart(m, name, size, cf, color, material, props)
	end
	local function deco(name, size, cf, color, material)
		return part(name, size, cf, color, material, { CanCollide = false, CanQuery = false })
	end
	local function cylinder(name, diameter, height, cf, color, material, props)
		local p = part(name, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.rad(90)), color, material, props)
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	-- Concrete over the whole lot, a kerb along the road, parking lines in front.
	local pave = part("Forecourt", Vector3.new(40, 0.3, 56), at(0, 0.15, 0), CONCRETE, Enum.Material.Concrete)
	m.PrimaryPart = pave
	part("Kerb", Vector3.new(40, 0.3, 0.6), at(0, 0.3, -27.7), STUCCO_DARK, Enum.Material.Concrete)
	for _, x in ipairs({ -12, -4, 4, 12 }) do
		deco("ParkLine", Vector3.new(0.3, 0.05, 9), at(x, 0.32, -19), PAPER)
	end
	deco("Mat", Vector3.new(14, 0.1, 3), at(0, 0.35, -1.5), CHARCOAL)
	-- Bollards between the parking and the counter (wide gaps to walk through).
	for _, x in ipairs({ -9, -3, 3, 9 }) do
		cylinder("Bollard", 0.9, 3.2, at(x, 0.3 + 1.6, -7), SAFETY, Enum.Material.Concrete)
	end

	-- The building: x -13..13, z 2..24, walls 13 high.
	local H = 13.3
	part("Floor", Vector3.new(24, 0.2, 20.4), at(0, 0.4, 13.2), FLOOR, Enum.Material.Concrete)
	part("BackWall", Vector3.new(26, H, 1), at(0, H / 2, 23.5), STUCCO, nil, { CastShadow = true })
	for _, s in ipairs({ -1, 1 }) do
		part("SideWall", Vector3.new(1, H, 21), at(s * 12.5, H / 2, 13.5), STUCCO, nil, { CastShadow = true })
		part("Pillar", Vector3.new(2, H, 1.6), at(s * 12, H / 2, 2.8), STUCCO_DARK, Enum.Material.Concrete)
	end
	-- Counter under the open serving window, with a till.
	part("Counter", Vector3.new(22, 3.4, 1.6), at(0, 1.7 + 0.3, 2.8), CHARCOAL, Enum.Material.Metal)
	part("CounterTop", Vector3.new(23, 0.4, 2.8), at(0, 3.9, 2.6), WOOD, Enum.Material.Wood)
	part("Till", Vector3.new(1.6, 1.1, 1.3), at(7.5, 4.65, 3), CHARCOAL)
	deco("TillScreen", Vector3.new(1.2, 0.8, 0.12), at(7.5, 5.45, 3.2) * CFrame.Angles(math.rad(-15), 0, 0), STEEL, Enum.Material.Metal)
	-- Header over the window, the shutter's box under it, the roof on top.
	part("Header", Vector3.new(26, 3.5, 1), at(0, H - 1.75, 2.5), CHARCOAL, nil, { CastShadow = true })
	deco("ShutterBox", Vector3.new(22, 0.9, 0.9), at(0, H - 3.95, 2.45), STEEL, Enum.Material.Metal)
	part("Roof", Vector3.new(28, 0.8, 24), at(0, H + 0.4, 13), CHARCOAL, Enum.Material.Concrete, { CastShadow = true })
	-- A flat steel canopy over the customers, hung on two rods.
	part("Canopy", Vector3.new(24, 0.3, 4.6), at(0, 9.4, -0.2), CHARCOAL, Enum.Material.Metal, { CanCollide = false, CastShadow = true })
	for _, s in ipairs({ -1, 1 }) do
		deco("CanopyRod", Vector3.new(0.15, 0.15, 4.6), at(s * 11.5, 10.4, -0.1) * CFrame.Angles(math.rad(-23), 0, 0), STEEL, Enum.Material.Metal)
	end
	local fascia = deco("Fascia", Vector3.new(24, 0.9, 0.2), at(0, 9.1, -2.55), CHARCOAL, Enum.Material.Metal)
	surfaceText(fascia, Enum.NormalId.Front, "GUNS  ·  BODY ARMOR", Theme.Color.Dim)

	-- The sign on the roof's front edge, facing the road (above the canopy, so it reads from the
	-- forecourt too), and a pole sign drivers can read from both ways.
	local sign = deco("Sign", Vector3.new(20, 3.4, 0.5), at(0, H + 0.8 + 1.7, 2.2), SIGN_RED)
	surfaceText(sign, Enum.NormalId.Front, string.upper(SHOP.Name))
	glow(sign, WARM, 22, 0.9)
	part("SignPole", Vector3.new(0.7, 13, 0.7), at(-16, 0.3 + 6.5, -22), STEEL, Enum.Material.Metal)
	local roadSign = deco("RoadSign", Vector3.new(0.5, 3.2, 8), at(-16, 14.6, -22), SIGN_RED)
	surfaceText(roadSign, Enum.NormalId.Left, string.upper(SHOP.Name))
	surfaceText(roadSign, Enum.NormalId.Right, string.upper(SHOP.Name))

	-- Inside: a steel wall with one of each gun on it (bigger than life, so they read from the counter),
	-- a vest, a shelf of ammo boxes, two crates, a paper target and a strip light.
	part("GunWall", Vector3.new(22, 6.6, 0.3), at(0, 7.8, 22.85), CHARCOAL, Enum.Material.Metal)
	local scale = 1.8 -- (the part-built ones; a mesh hangs K.WALL_SCALE times life size)
	local sideOn = CFrame.Angles(0, math.rad(90), 0) -- the barrel along the wall
	for _, d in ipairs({ { "Rifle", -5.2, 9.5 }, { "Shotgun", 5.2, 9.5 }, { "SMG", -5.4, 6.5 }, { "Pistol", 0.8, 6.5 } }) do
		local class, x, y = d[1], d[2], d[3] -- (these four classes are gun ids too)
		local spec = GUN_BUILD[class]
		local display = Instance.new("Model")
		display.Name = "Display" .. class
		-- Turned side-on and centred on (x, y): the gun's own mesh when the place has one, else the
		-- part-built one. (pcall: a model that can't be used must never stop the shop from being built.)
		local ok, shown = pcall(meshGun, display, Combat.Guns[class], at(x, y, 22.3) * sideOn)
		if not ok or not shown then
			display:ClearAllChildren()
			buildGun(display, class, at(x - spec.Mid.Z * scale, y - spec.Mid.Y * scale, 22.3) * sideOn, scale, true)
		end
		display.Parent = m
	end
	deco("Vest", Vector3.new(2.4, 2.6, 0.7), at(7, 6.1, 22.3), NAVY, Enum.Material.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		deco("VestStrap", Vector3.new(0.6, 0.8, 0.7), at(7 + s * 0.8, 7.8, 22.3), NAVY, Enum.Material.Fabric)
	end
	deco("VestPlate", Vector3.new(1.6, 1.3, 0.15), at(7, 6.2, 21.9), CHARCOAL)
	part("Shelf", Vector3.new(22, 0.3, 1.6), at(0, 3.6, 22.1), STEEL, Enum.Material.Metal)
	for i = 0, 6 do
		part("AmmoBox", Vector3.new(1.6, 0.9, 1.1), at(-9 + i * 3, 4.2, 22.1), i % 2 == 0 and OLIVE or TAN)
	end
	part("Crate", Vector3.new(3, 2, 2.2), at(-9.5, 1.5, 14), OLIVE, Enum.Material.Wood)
	part("Crate", Vector3.new(3, 2, 2.2), at(-9.5, 1.5, 17), TAN, Enum.Material.Wood)
	for i, ring in ipairs({ { 4, PAPER }, { 2.8, CHARCOAL }, { 1.6, PAPER }, { 0.6, SIGN_RED } }) do
		-- (Cylinders run along X, which is across this side wall: flat discs, one on top of the other.)
		local disc = deco("TargetRing", Vector3.new(0.1, ring[1], ring[1]), at(11.95 - i * 0.03, 7.5, 12), ring[2])
		disc.Shape = Enum.PartType.Cylinder
	end
	local strip = part("CeilingLight", Vector3.new(20, 0.2, 1), at(0, H - 0.2, 12), WARM, Enum.Material.Neon, { CanCollide = false, CanQuery = false })
	local sl = Instance.new("SurfaceLight")
	sl.Face = Enum.NormalId.Bottom
	sl.Range = 16
	sl.Angle = 120
	sl.Brightness = 1.2
	sl.Color = WARM
	sl.Shadows = false
	sl.Parent = strip

	-- The counter prompt. CombatClient opens the shop panel when it triggers; buying goes through
	-- GunShopBuy, which checks the distance to this part.
	local counterPoint = part(SHOP.BuyPoint, Vector3.new(1, 1, 1), at(0, 3, 0.8), K.DARK, nil,
		{ Transparency = 1, CanCollide = false, CanQuery = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = SHOP.Prompt
	prompt.ActionText = "Browse"
	prompt.ObjectText = SHOP.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = counterPoint
	table.insert(buyPoints, counterPoint.Position)

	-- A palm in a planter at each end of the forecourt.
	for _, s in ipairs({ -1, 1 }) do
		part("Planter", Vector3.new(5, 1.6, 5), at(s * 16, 0.3 + 0.8, -10), STUCCO_DARK, Enum.Material.Concrete)
		palm(m, (at(s * 16, 1.9, -10)).Position, 1)
	end

	checkLot(CFrame.new(SHOP.Center + Vector3.new(0, 8.2, 0)), Vector3.new(56, 15.6, 40))
	m.Parent = shops
end

------------------------------------------------------------------ players

local function onCharacter(player, char)
	player:SetAttribute("SpawnSafeUntil", now() + Combat.SpawnProtection)
	player:SetAttribute("CombatSafeUntil", nil)
	S.killed[player] = nil
	setDaze(player, 0)
	S.lastHitAt[player] = nil
	S.lastAttacker[player] = nil
	S.lastHitInfo[player] = nil
	-- The Backpack is replaced on every spawn: give the tools once it's there (new Tools, full magazines).
	task.defer(function()
		if player:WaitForChild("Backpack", 5) and player.Character == char then
			syncTools(player)
		end
	end)
	-- How a gun sits in the hand: Roblox welds the Handle to the hand's RightGripAttachment (C0) and
	-- Tool.Grip (C1). On standard R15 and R6 bodies that attachment is turned -90 degrees about X, which
	-- Tool.Grip and the poses assume. Some avatar bodies ship it turned differently and hold every gun
	-- backwards or sideways: put the standard turn back now and whenever a tool comes into the hand
	-- (its position is kept; the server's change reaches every device).
	local function normalizeGrip()
		local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
		local att = hand and hand:FindFirstChild("RightGripAttachment")
		if not att or not att:IsA("Attachment") then
			return
		end
		local want = CFrame.new(att.Position) * CFrame.Angles(math.rad(-90), 0, 0)
		if att.CFrame ~= want then
			att.CFrame = want
		end
		local weld = hand:FindFirstChild("RightGrip")
		if weld and weld:IsA("JointInstance") and weld.C0 ~= want then
			weld.C0 = want -- already holding a tool: fix it in place
		end
	end
	task.defer(normalizeGrip)
	char.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			task.defer(normalizeGrip) -- after Roblox makes the RightGrip weld
		end
	end)
	-- Resetting mid-fight counts as a knockout (onFled).
	task.spawn(function()
		local hum = char:WaitForChild("Humanoid", 10)
		if hum and hum:IsA("Humanoid") then
			hum.Died:Connect(function()
				onFled(player, char)
			end)
		end
	end)
end

local function onPlayer(player)
	player:SetAttribute("Daze", 0)
	if player:GetAttribute("Armor") == nil then
		player:SetAttribute("Armor", 0) -- (the saved armor arrives with the save: onLoaded)
	end
	player:SetAttribute("Passive", player:GetAttribute("Passive") == true)
	player.CharacterAdded:Connect(function(char)
		onCharacter(player, char)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	-- A live character taken away mid-fight (a side switch respawns you, or leaving) counts too. After a
	-- knockout-by-reset onFled has already run, so this finds nothing to do.
	player.CharacterRemoving:Connect(function(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			onFled(player, char)
		end
	end)
	player.ChildAdded:Connect(function(c)
		if c:IsA("Backpack") then
			task.defer(syncTools, player)
		end
	end)
	player:GetAttributeChangedSignal("Side"):Connect(function()
		if player:GetAttribute("Side") == "Cop" then
			autoPassiveOff(player, "PassiveCop")
		end
		refreshArmor(player) -- cops and prisoners show 0; a citizen gets theirs back
		syncTools(player)
	end)
	player:GetAttributeChangedSignal("Heat"):Connect(function()
		local heat = player:GetAttribute("Heat") or 0
		if heat > 0 then
			autoPassiveOff(player, "PassiveAutoOff")
		end
		-- Stars from fighting go when the heat goes (all at once when the cops lose you, or one at a
		-- time with a disguise): never count more of them than there are stars.
		local mine = player:GetAttribute("CombatStars")
		if mine and mine > heat then
			player:SetAttribute("CombatStars", heat > 0 and heat or nil)
		end
		-- The cops have lost them (or caught them): the next pedestrian is "the first one" again.
		if heat <= 0 then
			S.pedVictims[player] = nil
		end
	end)
	player:GetAttributeChangedSignal("Carried"):Connect(function()
		if (player:GetAttribute("Carried") or 0) > 0 then
			autoPassiveOff(player, "PassiveAutoOff")
		end
	end)
	-- Walking out of your home counts as arriving: 20 s of protection.
	local wasHome = player:GetAttribute("InHome") == true
	player:GetAttributeChangedSignal("InHome"):Connect(function()
		local home = player:GetAttribute("InHome") == true
		if wasHome and not home then
			player:SetAttribute("SpawnSafeUntil", now() + Combat.SpawnProtection)
		end
		wasHome = home
	end)
end

-- Saved passive mode comes back only if the player could turn it on right now: a slow load gives
-- them time to rob, get heat or start a fight first.
local function canRestorePassive(player)
	return player:GetAttribute("Side") ~= "Cop" and HeatService.GetHeat(player) <= 0 and EconomyService.GetCarried(player) <= 0
		and (player:GetAttribute("Daze") or 0) <= 0 and not isDown(player)
		and os.clock() - (S.lastAttack[player] or -math.huge) >= Combat.Passive.FightLock
end

local function onLoaded(player, data)
	local gear = gearOf(data)
	-- The Stun Blaster is retired: whoever bought one owns the Pistol instead.
	if gear.blaster == true then
		gear.guns.Pistol = true
	end
	gear.blaster = nil
	player:SetAttribute("Guns", gunsString(gear.guns))
	refreshArmor(player)
	local saved = type(data.settings) == "table" and data.settings.Passive == true
	if saved and not isPassive(player) then
		if canRestorePassive(player) then
			setPassive(player, true)
			notify:FireClient(player, "PassiveOn") -- a reminder: nobody can hit you, you can't fight
			return
		end
		data.settings.Passive = false -- things changed while the save was loading
		SettingsService.Mirror(player)
		if player:GetAttribute("Side") ~= "Cop" then
			notify:FireClient(player, "PassiveNotRestored")
		end
	end
	syncTools(player)
end

local function onLeave(player)
	-- Leaving mid-fight counts as a knockout. Whether the character goes before or after this event
	-- isn't promised, so do it here too (onFled only acts once), with `leaving` set so nothing is taken
	-- from a save that may already be on its way out.
	leaving[player] = true
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		onFled(player, char)
	end
	S.lastHitAt[player] = nil
	S.lastAttacker[player] = nil
	S.lastHitInfo[player] = nil
	S.lastAttack[player] = nil
	S.lastAggroAt[player] = nil
	S.lastAggroKind[player] = nil
	S.lastGunfire[player] = nil
	S.lastWitness[player] = nil
	S.pedVictims[player] = nil
	for p, a in pairs(S.lastAttacker) do
		if a == player then
			S.lastAttacker[p] = nil
		end
	end
	for other in pairs(feuds[player] or {}) do
		if feuds[other] then
			feuds[other][player] = nil
		end
	end
	feuds[player] = nil
	S.lastSwing[player] = nil
	S.lastRefusal[player] = nil
	S.copHitAt[player] = nil
	S.passiveOnAt[player] = nil
	S.passiveOffAt[player] = nil
	for _, rec in ipairs(bags) do
		if rec.owner == player then
			rec.owner = nil -- the bag stays; anyone can take it
		end
	end
end

-- Health regeneration every tick, safe zones every other tick, a tool check every 2 s.
local function tick(dt, n)
	if S.zonesDirty or os.clock() - S.zonesBuiltAt > K.ZONE_REFRESH then
		rebuildZones()
	end
	local t = os.clock()
	for _, p in ipairs(Players:GetPlayers()) do
		local daze = p:GetAttribute("Daze") or 0
		if daze > 0 and t - (S.lastHitAt[p] or 0) >= Combat.DrainDelay and S.killed[p] == nil then
			setDaze(p, math.max(0, daze - Combat.DrainPerSecond * dt))
		end
		if n % 2 == 0 then
			local _, root = body(p)
			local safe = p:GetAttribute("Side") ~= "Prisoner" and isSafe(p, root)
			if p:GetAttribute("InSafeZone") ~= safe then
				p:SetAttribute("InSafeZone", safe)
			end
		end
		if n % 8 == 0 then
			-- (pcall: one player's tools going wrong must never skip everyone after them in the list)
			local ok, err = pcall(syncTools, p)
			if not ok then
				warn("[CombatService] tools for " .. p.Name .. ": " .. tostring(err))
			end
		end
	end
	-- Once a minute: forget wallet and bounty times that have run out (they are kept by UserId across
	-- a rejoin, so nothing else ever clears them). A bounty is remembered while its wanted spell lasts.
	if n % 240 == 0 then
		for id, at in pairs(S.walletAt) do
			if t - at > Combat.Wallet.VictimGap then
				S.walletAt[id] = nil
			end
		end
		for id, rec in pairs(S.bountyAt) do
			if t - rec.at > Combat.Bounty.VictimGap then
				local p = Players:GetPlayerByUserId(id)
				if not p or rec.since == nil or p:GetAttribute("WantedSince") ~= rec.since then
					S.bountyAt[id] = nil
				end
			end
		end
	end
end

------------------------------------------------------------------ for other services

-- When this player last swung or fired (os.clock(), hit or miss) and with what ("Fists" | "Gun").
-- Nil if they haven't. PedService: a pedestrian's wallet only pays someone who just did that.
function CombatService.LastAggro(player)
	return S.lastAggroAt[player], S.lastAggroKind[player]
end

-- PedService: this player just knocked a pedestrian over (a punch or a bullet). The first
-- Ped.FreeVictims bring nobody; the one after that puts Combat.Heat.PedVictim stars on them (the police
-- start coming), and from then on gunfire and wallets count as before. Returns how many they have
-- knocked over lately.
function CombatService.PedVictim(player)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return 0
	end
	local n = pedVictims(player) + 1
	S.pedVictims[player] = { n = n, at = os.clock() }
	if n == (Combat.Ped.FreeVictims or 0) + 1 then
		combatHeat(player, HEAT.PedVictim or 1, "ped_assault", S.lastAggroKind[player] == "Gun" and HEAT.GunCap or HEAT.Cap)
	end
	return n
end

-- How many pedestrians this player has knocked over lately (PedService: is a wallet still free of stars?).
function CombatService.PedVictims(player)
	return pedVictims(player)
end

-- Stars for a crime that counts as fighting (free stars: no bounty for them). The same caps as
-- everything else here: Combat.Heat.GunCap with a gun, Cap without. Returns the stars added.
function CombatService.CrimeHeat(player, amount, reason, withGun)
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(amount) ~= "number" or amount ~= amount then
		return 0
	end
	return combatHeat(player, math.floor(amount), tostring(reason), withGun and HEAT.GunCap or HEAT.Cap)
end

-- In a safe zone, at home, or a prisoner: no combat, no crime money.
function CombatService.IsSafe(player)
	local _, root = body(player)
	return isSafe(player, root)
end

-- A car hit someone on foot (ImpactService: a player's car, an AI patrol, or street traffic as told by
-- the victim's own device). Damage by the speed of the hit (Config Combat.CarHit): a bump takes a
-- little, a fast hit most of the bar, and a second hard one, or being run over again while down, kills
-- (a real death, as from a gun: kill). The same protections as a fight: safe zones, spawn protection,
-- and from another player's car, passive mode and crewmates. driver: the player at the wheel (nil for
-- AI patrols and traffic); what: the car's name; downAlready: they were lying in the road before this
-- hit (it takes Combat.CarHit.Downed of the damage). selfReported: the victim's own device told us
-- (street traffic): it never takes the last point of health, so it can't be a way to die on cue and
-- rob an attacker of the knockout. Returns the damage taken.
function CombatService.CarHit(victim, speed, dir, driver, what, downAlready, selfReported)
	local cfg = Combat.CarHit
	if not cfg or not fxRemote or typeof(victim) ~= "Instance" or not victim:IsA("Player") or victim.Parent ~= Players then
		return 0
	end
	speed = tonumber(speed) or 0
	if speed ~= speed or speed < cfg.MinSpeed then
		return 0
	end
	if typeof(driver) ~= "Instance" or not driver:IsA("Player") or driver == victim or driver.Parent ~= Players then
		driver = nil
	end
	local hum, root = body(victim)
	local side = victim:GetAttribute("Side")
	if not hum or hum.SeatPart or S.killed[victim] == victim.Character or (side ~= "Civilian" and side ~= "Cop") then
		return 0
	end
	if isSafe(victim, root) or running(victim, "SpawnSafeUntil") then
		return 0
	end
	if driver then
		local crew = driver:GetAttribute("Crew")
		if isPassive(victim) or isPassive(driver) or (crew ~= nil and crew == victim:GetAttribute("Crew")) then
			return 0
		end
		-- A cop's car hurts only wanted citizens, like a cop's gun (ImpactService then skips the knock-down too).
		if driver:GetAttribute("Side") == "Cop" and (side ~= "Civilian" or HeatService.GetHeat(victim) < 1) then
			return 0
		end
	end
	local t = os.clock()
	if t - (S.carHitAt[victim] or -math.huge) < cfg.Gap then
		return 0
	end
	S.carHitAt[victim] = t
	local damage = math.min(cfg.Max, cfg.Damage + (math.min(speed, 400) - cfg.MinSpeed) * cfg.PerSpeed)
	if downAlready then
		damage *= cfg.Downed
	end
	damage = math.floor(damage + 0.5)
	-- Body armor (citizens only) soaks part of it, then health.
	local armor = side == "Civilian" and (victim:GetAttribute("Armor") or 0) or 0
	local soak = math.clamp(math.floor(damage * cfg.ArmorShare), 0, armor)
	if soak > 0 then
		setArmor(victim, armor - soak)
	end
	S.lastHitAt[victim] = t -- (health only starts coming back Combat.DrainDelay after this)
	if driver then
		S.lastAttacker[victim] = driver -- (a Reset now counts as the driver's knockout: onFled)
	end
	local push = typeof(dir) == "Vector3" and flat(dir) or Vector3.zero
	push = (push.Magnitude > 0.05 and push.Magnitude < math.huge) and push.Unit or flat(root.CFrame.LookVector)
	local daze = (victim:GetAttribute("Daze") or 0) + damage - soak
	if selfReported then
		daze = math.min(daze, Combat.DazeMax - 1)
	end
	if daze >= Combat.DazeMax then
		local name = (type(what) == "string" and what ~= "") and what or "a car"
		kill(driver, victim, hum, root, push, speed, { Name = name, Ragdoll = "car",
			Cause = driver and ("Run over by " .. driver.DisplayName) or ("Hit by " .. name) })
	else
		setDaze(victim, daze)
		-- (From: where the car came from, for the red bar toward it)
		fxRemote:FireClient(victim, "Hit", { Kind = "Car", By = driver, Damage = damage, From = root.Position - push * 4 })
	end
	return damage
end

-- An AI officer's round (PoliceOfficerService): everyone near sees and hears it ("Shot" with no shooter
-- and the cops' Service Pistol), and when it landed on `victim` it hurts like a player's shot: armor
-- first, then health, and at 0 a real death ("Shot by the police"; with them right there that is an
-- arrest on the spot: ArrestService.GaveUp). Never someone seated, in a safe zone, just spawned or not a
-- wanted citizen. Returns true if it hurt them.
function CombatService.PoliceShot(victim, origin, endPos, onBody, damage)
	if not fxRemote or typeof(origin) ~= "Vector3" or typeof(endPos) ~= "Vector3" then
		return false
	end
	fxNear(origin, Combat.Fx.ShotRange, {}, "Shot", nil, Combat.CopGun, origin, { endPos }, { onBody == true })
	if onBody ~= true or typeof(victim) ~= "Instance" or not victim:IsA("Player") or victim.Parent ~= Players then
		return false
	end
	local hum, root = body(victim)
	if not hum or hum.SeatPart or S.killed[victim] == victim.Character or victim:GetAttribute("Side") ~= "Civilian"
		or HeatService.GetHeat(victim) <= 0 or isSafe(victim, root) or running(victim, "SpawnSafeUntil") then
		return false
	end
	damage = math.clamp(tonumber(damage) or 0, 0, 100)
	S.lastHitAt[victim] = os.clock()
	local armor = victim:GetAttribute("Armor") or 0
	local absorbed = math.clamp(armor, 0, damage)
	if absorbed > 0 then
		setArmor(victim, armor - absorbed)
	end
	fxRemote:FireClient(victim, "Hit", { Kind = "Gun", Gun = Combat.CopGun, Damage = damage, From = origin })
	local daze = (victim:GetAttribute("Daze") or 0) + damage - absorbed
	if daze >= Combat.DazeMax then
		local dir = flat(root.Position - origin)
		kill(nil, victim, hum, root, dir.Magnitude > 0.1 and dir.Unit or flat(root.CFrame.LookVector), 45,
			{ Name = "Service Pistol", Cause = "Shot by the police", Ragdoll = "shot" })
	else
		setDaze(victim, daze)
	end
	return true
end

-- Was their current body killed (kill: shot dead, or a car)? ArrestService words the arrest on the spot by it.
function CombatService.ShotDead(player)
	return player.Character ~= nil and S.killed[player] == player.Character
end

function CombatService.Init()
	notify = Remotes.Event("Notify")
	fxRemote = Remotes.Event("CombatFx")
	Remotes.Event("CombatAction").OnServerEvent:Connect(onAction)
	Remotes.Event("GunShopBuy").OnServerEvent:Connect(onBuy)

	bagFolder = Workspace:FindFirstChild("DroppedBags") or Instance.new("Folder")
	bagFolder.Name = "DroppedBags"
	bagFolder:ClearAllChildren()
	bagFolder.Parent = Workspace

	local ok, err = pcall(buildShop)
	if not ok then
		warn("[CombatService] Coast Arms failed to build: " .. tostring(err))
	end

	-- Zone cache: watch the folders that hold safe places (some are built after us).
	for name in pairs(K.WATCH) do
		local f = Workspace:FindFirstChild(name)
		if f then
			watchFolder(f)
		end
	end
	Workspace.ChildAdded:Connect(function(c)
		if K.WATCH[c.Name] then
			watchFolder(c)
			markDirty()
		end
	end)
	Workspace.ChildRemoved:Connect(function(c)
		if K.WATCH[c.Name] then
			markDirty()
		end
	end)
	rebuildZones()

	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(onLeave)
	DataService.OnLoaded(onLoaded)

	-- Starting a crime ends passive mode the moment the hold begins, not when the loot arrives.
	local function crimeStarted(prompt, p)
		if K.CRIME_PROMPTS[prompt.Name] and typeof(p) == "Instance" and p:IsA("Player") and p:GetAttribute("Side") == "Civilian" then
			autoPassiveOff(p, "PassiveAutoOff")
		end
	end
	ProximityPromptService.PromptButtonHoldBegan:Connect(crimeStarted)
	ProximityPromptService.PromptTriggered:Connect(crimeStarted) -- (in case a hold time is ever 0)

	task.spawn(function()
		local last, n = os.clock(), 0
		while true do
			task.wait(K.TICK)
			local t = os.clock()
			n += 1
			local ok2, err2 = pcall(tick, t - last, n)
			last = t
			if not ok2 then
				warn("[CombatService] " .. tostring(err2))
			end
		end
	end)
end

-- Give a citizen gun for free (the daily spin wheel, SpinService). Returns true if it's now theirs, false if
-- they already had it, the id isn't a citizen gun, or their save isn't loaded. Rank isn't checked here: the
-- wheel only offers guns their rank can buy.
function CombatService.GiveGun(player, gunId)
	local gun = table.find(Combat.GunOrder, gunId) ~= nil and Combat.Guns[gunId] or nil
	local data = DataService.Get(player)
	if not gun or not data then
		return false
	end
	local gear = gearOf(data)
	if gear.guns[gun.Id] == true then
		return false
	end
	gear.guns[gun.Id] = true
	player:SetAttribute("Guns", gunsString(gear.guns))
	local ok, err = pcall(syncTools, player)
	if not ok then
		warn("[CombatService] tools for " .. player.Name .. ": " .. tostring(err))
	end
	return true
end

return CombatService
