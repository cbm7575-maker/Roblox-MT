-- MapService (ModuleScript, ServerScriptService.Services.MapService)
-- Tells every client where things are, so the phone's GPS and the minimap work even for places that
-- aren't streamed in yet.
--   ReplicatedStorage attribute "Places": JSON list of { n = name, k = kind label, c = category, x, z, id, g }.
--     Categories: "Activity" (races, stunts, drift, taxi), "Service" (hideout, chop shop, spray, fence,
--     police, dealers, homes, the apartment towers' street doors: ApartmentService.Towers), "Heist"
--     (every heist site; id = the site's name in Workspace.Heists), "Business" (player businesses' doors,
--     BusinessService.Places; id = the business id: BusinessClient.MapBlips draws them on both maps).
--     g = group, for "the nearest one" (TutorialClient's SHOW ME): "Race" (street races), "BoatRace",
--     "Stunt"; nil for everything else. Names SHOW ME uses as they are: "Chop Shop", "AutoNeon Motors",
--     "Hideout", "Drift Zone", "Taxi Stand", "Rustwater Loft".
--   ReplicatedStorage attribute "OpenHeists": comma list of heist site names robbable right now
--     (refreshed every 2 seconds from the site attributes HeistService sets).
--   ReplicatedStorage attribute "MapShapes": JSON { t = ground tiles, b = building footprints }, each
--     { x, z, sx, sz, yaw (degrees), c = colour index into MAP_COLORS on the client } for the minimap.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Activities = require(ReplicatedStorage.Shared.Config.Activities)
local Heists = require(ReplicatedStorage.Shared.Config.Heists)
local Housing = require(ReplicatedStorage.Shared.Config.Housing)

local MapService = {}

local SERVICE_NAMES = {
	Hideout = "Hideout",
	ChopShop = "Chop Shop",
	SprayAndGo = "Spray & Go",
	PoliceLot = "Police HQ",
}

local SERVICE_KINDS = {
	Hideout = "Bank your bag, change clothes",
	ChopShop = "Deliver boosted cars",
	SprayAndGo = "New paint, lose a star",
	PoliceLot = "Police station",
}

local function pos(inst)
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		return inst:GetPivot().Position
	end
	return nil
end

local function collect()
	local places = {}
	local function add(name, kind, category, p, id, group)
		if p then
			table.insert(places, { n = name, k = kind, c = category, x = math.floor(p.X), z = math.floor(p.Z), id = id,
				g = group })
		end
	end
	for _, race in ipairs(Activities.Races or {}) do
		add(race.Name, "Street race", "Activity", race.Start, nil, race.Boat and "BoatRace" or "Race")
	end
	-- The Lucky Wheel downtown (SpinService builds it at start-up): the daily free spin.
	local okW, wheel = pcall(function()
		return require(game:GetService("ServerScriptService").Services.SpinService).Place
	end)
	if okW and type(wheel) == "table" and wheel.Pos then
		add(wheel.Name, wheel.Kind, "Activity", wheel.Pos)
	end
	for _, stunt in ipairs(Activities.Stunts or {}) do
		add(stunt.Name, "Stunt jump", "Activity", stunt.Ramp, nil, "Stunt")
	end
	local acts = Workspace:FindFirstChild("Activities")
	if acts then
		add("Drift Zone", "Drift scoring", "Activity", acts:FindFirstChild("DriftZone") and pos(acts.DriftZone))
		add("Taxi Stand", "Taxi job", "Activity", acts:FindFirstChild("TaxiStand") and pos(acts.TaxiStand))
		add("Car Meet", "Show your ride · every 8 min", "Activity", acts:FindFirstChild("CarMeet") and pos(acts.CarMeet))
		add("Courier Depot", "Delivery job", "Activity", acts:FindFirstChild("CourierDepot") and pos(acts.CourierDepot))
	end
	-- Dealerships (DealershipService builds them before MapService starts) and homes for sale.
	local okD, dealers = pcall(function()
		return require(game:GetService("ServerScriptService").Services.DealershipService).Places
	end)
	for _, p in ipairs(okD and dealers or {}) do
		add(p.Name, p.Kind, "Service", p.Pos)
	end
	-- The Coast Arms gun shop (CombatService builds it before MapService starts).
	local okZ, zap = pcall(function()
		return require(game:GetService("ServerScriptService").Services.CombatService).Place
	end)
	if okZ and type(zap) == "table" and zap.Pos then
		add(zap.Name or "Coast Arms", zap.Kind or "Guns & body armor", "Service", zap.Pos)
	end
	-- The apartment towers anyone can tour (ApartmentService picks and builds them before MapService
	-- starts): each one's street door.
	local okA, towers = pcall(function()
		return require(game:GetService("ServerScriptService").Services.ApartmentService).Towers()
	end)
	for _, tower in ipairs(okA and type(towers) == "table" and towers or {}) do
		add(tower.Name, tower.Kind or "Penthouse tour", "Service", tower.Door)
	end
	for _, h in ipairs(Housing.List) do
		add(h.Name, "Home for sale · " .. Housing.ShortPrice(h.Price), "Service", Housing.DoorPosition(h))
	end
	-- Player businesses (BusinessService builds them before MapService starts; none while the feature is off):
	-- category "Business", id = the business id (the clients' letter, colour, gold ring and break-in flash).
	local okB, businesses = pcall(function()
		return require(game:GetService("ServerScriptService").Services.BusinessService).Places()
	end)
	for _, p in ipairs(okB and type(businesses) == "table" and businesses or {}) do
		add(p.Name, p.Kind, "Business", p.Pos, p.Id)
	end
	local spawns = Workspace:FindFirstChild("Spawns")
	if spawns then
		for key, name in pairs(SERVICE_NAMES) do
			local inst = spawns:FindFirstChild(key)
			add(name, SERVICE_KINDS[key], "Service", inst and pos(inst))
		end
	end
	local sites = Workspace:FindFirstChild("Heists")
	if sites then
		for _, site in ipairs(sites:GetChildren()) do
			local def = Heists.Types[site:GetAttribute("HeistId")]
			local label = def and def.Display or site.Name
			if def and def.Display == "ATM" then
				label = "ATM " .. site.Name:gsub("ATM", "#")
			end
			local kind = def and ("Tier " .. def.Tier .. " heist") or "Heist"
			if def and def.MinRank and def.MinRank > 1 then
				kind ..= " · rank " .. def.MinRank -- say it before anyone drives there (owner feedback)
			end
			add(label, kind, "Heist", pos(site), site.Name)
		end
	end
	return places
end

-- Ground material -> minimap colour key (MinimapClient has the palette).
local GROUND_KEYS = {
	[Enum.Material.Grass] = "grass", [Enum.Material.Sand] = "sand", [Enum.Material.Concrete] = "concrete",
	[Enum.Material.WoodPlanks] = "wood", [Enum.Material.Pavement] = "paving", -- Marina Row after Restyle
}

local function shapes()
	local tiles, buildings = {}, {}
	local function rect(list, cf, sx, sz, key)
		local _, yaw = cf:ToEulerAnglesYXZ()
		table.insert(list, {
			math.floor(cf.X), math.floor(cf.Z), math.floor(sx), math.floor(sz), math.floor(math.deg(yaw)), key,
		})
	end
	local city = Workspace:FindFirstChild("City")
	local ground = city and city:FindFirstChild("Ground")
	if ground then
		for _, p in ipairs(ground:GetChildren()) do
			if p:IsA("BasePart") then
				rect(tiles, p.CFrame, p.Size.X, p.Size.Z, GROUND_KEYS[p.Material] or "grass")
			end
		end
	end
	local art = city and city:FindFirstChild("Art")
	-- ArtGen's buildings plus Restyle's street-front infill and block fill (flat car parks and parks
	-- fail the height test and stay open ground, which is right).
	for _, folderName in ipairs({ "Buildings", "Infill", "BlockFill" }) do
		local folder = art and art:FindFirstChild(folderName)
		for _, m in ipairs(folder and folder:GetChildren() or {}) do
			if m:IsA("Model") then
				local cf, size = m:GetBoundingBox()
				if size.X >= 14 and size.Z >= 14 and size.Y >= 10 then
					rect(buildings, cf, size.X, size.Z, "building")
				end
			end
		end
	end
	-- Runtime-built lots (dealerships, homes, player businesses) aren't in City.Art: add their big pieces too.
	-- (In Workspace.Shops only the businesses, "Business_<Id>": the gun shop's footprint is left as it was.)
	for _, name in ipairs({ "Dealerships", "Homes", "Shops" }) do
		local root = Workspace:FindFirstChild(name)
		for _, m in ipairs(root and root:GetChildren() or {}) do
			if name == "Shops" and string.sub(m.Name, 1, 9) ~= "Business_" then
				continue
			end
			for _, p in ipairs(m:GetDescendants()) do
				-- Tall walls, or a roof slab (the showroom's walls are thin, but its Roof is its footprint).
				if p:IsA("BasePart") and (p.Size.Y >= 10 or p.Name == "Roof") and p.Size.X >= 14 and p.Size.Z >= 14 then
					rect(buildings, p.CFrame, p.Size.X, p.Size.Z, "building")
				end
			end
		end
	end
	return { t = tiles, b = buildings }
end

function MapService.Init()
	ReplicatedStorage:SetAttribute("Places", HttpService:JSONEncode(collect()))
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(shapes())
	end)
	if ok then
		ReplicatedStorage:SetAttribute("MapShapes", encoded)
	end
	task.spawn(function()
		while true do
			local open = {}
			local sites = Workspace:FindFirstChild("Heists")
			if sites then
				for _, site in ipairs(sites:GetChildren()) do
					if site:GetAttribute("Robbable") then
						table.insert(open, site.Name)
					end
				end
			end
			table.sort(open)
			local s = table.concat(open, ",")
			if ReplicatedStorage:GetAttribute("OpenHeists") ~= s then
				ReplicatedStorage:SetAttribute("OpenHeists", s)
			end
			task.wait(2)
		end
	end)
end

return MapService
