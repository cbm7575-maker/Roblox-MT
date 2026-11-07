-- Main (Script, ServerScriptService.Main): starts every server service in order.
-- Each service is a ModuleScript in ServerScriptService.Services with an optional Init().

local ServerScriptService = game:GetService("ServerScriptService")

local ORDER = {
	"WorldService",
	"VehicleService",
	"VehicleGuard",
	"TeamService",
	"RespawnService", -- loads characters (Roblox's own respawn is off): on joining, and the death screen's RESPAWN
	"AnimationService", -- walk / run / idle sets on every character (Config.Animations)
	"EconomyService",
	"DataService",
	"GarageService",
	"TutorialService",
	"ShopService",
	"DailyService",
	"SpinService", -- the daily spin wheel (Config.Spin): cash, 2X CASH / 2X XP, a free gun or car
	"ProgressService",
	"JourneyService", -- goal chains after the tutorial (Road to the Coast)
	"CrewService",
	"RideService", -- HOP IN with strangers (a "let them in?" card) and INVITE from the driver's seat (after CrewService)
	"FriendsService", -- invite / join friends, co-play bonus
	"EventService",
	"MissionService",
	"PedService",
	"SettingsService",
	"HeatService",
	"HeistService",
	"HideoutService",
	"ArrestService",
	"PrisonService",
	"RobberToolsService",
	"PoliceOfficerService", -- officers on foot: ride in the patrol cars, get out, chase, cuff or shoot (before AIPoliceService)
	"AIPoliceService",
	"PoliceHeliService", -- the police helicopter at 5 stars (an eye for HeatService; after AIPoliceService)
	"DisguiseService",
	"CarBoostService",
	"CarjackService", -- street carjacking (moving traffic + car-park break-ins)
	"BigScoreService", -- The Big Score crew heist: builds Workspace.BigScore, runs the armored van
	"RagdollService", -- limp falls for players + the "Pose" attribute (before ImpactService, which calls it)
	"ImpactService", -- car hits, knockdowns, GET IN
	"PropService", -- street furniture cars plow through (collision group "Props", remote PropHit)
	"CombatService", -- guns and knockouts + the Coast Arms shop (before MapService so the GPS lists the shop)
	"RaceService",
	"RaceAIService", -- NPC racers for RaceService's street races (drives them on Heartbeat)
	"RobberBotService", -- 2 NPC robbers for player cops to chase (after ArrestService and RaceAIService, which drives their cars)
	"StuntService",
	"DriftService",
	"JobService",
	"CarMeetService", -- before MapService: it builds the lot MapService lists
	"DealershipService", -- before MapService: AutoNeon Motors + Marina Boat Sales
	"HousingService", -- homes for sale (after GarageService / VehicleService)
	"ApartmentService", -- apartment towers you can tour (after the lots it keeps clear of; MapService lists them)
	"CityDressingService", -- Look 4.0 billboards, road wear and tall palms (after every lot it keeps clear of)
	-- Empire: player businesses (after CrewService, JobService, CombatService; builds into Workspace.Shops before
	-- ApartmentService and CityDressingService keep clear of it, and before MapService lists it)
	"BusinessService",
	"MapService",
	"DebugService", -- Studio only
}

local services = ServerScriptService:WaitForChild("Services")
for _, name in ipairs(ORDER) do
	local module = services:WaitForChild(name, 5)
	if not module then
		warn("[Main] missing service " .. name)
		continue
	end
	local ok, err = pcall(function()
		local service = require(module)
		if service.Init then
			service.Init()
		end
	end)
	if not ok then
		warn("[Main] " .. name .. " failed to start: " .. tostring(err))
	end
end
print("[Main] server ready")
