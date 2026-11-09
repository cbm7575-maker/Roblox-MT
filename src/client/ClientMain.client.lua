-- ClientMain (LocalScript, StarterPlayerScripts.ClientMain): starts every client controller.
-- In Studio only, hold Left Alt and press a number key to spawn a test car: 1-9, 0, -, = map to the first
-- 12 vehicles in Config order (Hidden street cars skipped). Plain number keys are left to the hotbar
-- (1 fists, 2 blaster).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local controllers = script.Parent:WaitForChild("Controllers")

-- Phones play sideways (owner, Nov 3: the game came up vertical). LandscapeSensor turns with the phone
-- between the two sideways ways but never stands up; the place's StarterGui had Sensor, which let a
-- phone held upright play in portrait.
Players.LocalPlayer:WaitForChild("PlayerGui").ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor

local ORDER = {
	"DriveController",
	"PromptGate", -- hides on-foot prompts (Rob, Pick lock...) while you sit in any seat
	"VehicleVisuals",
	"VehicleFeel", -- body lean, car lights, driver pose (needs DriveController; SettingsClient / PoseClient looked up softly)
	"DriveUI",
	"NotifyController",
	"SettingsClient",
	"PoseClient", -- code-made poses on any character + this device's half of limp falls (needs nothing; others call it)
	"SoundClient",
	"ImpactClient", -- needs DriveController + SoundClient
	"TeamUI",
	"HUDController",
	"HeistClient",
	"FeedController",
	"LawClient",
	"WardrobeUI",
	"ActivityClient",
	"SkyClient",
	"AmbienceClient", -- area names, sound beds, background life, the dusk neon wave (needs SettingsClient)
	"PoliceHeliClient", -- draws PoliceHeliService's helicopters: rotor, beacons, night searchlight, sound (SettingsClient looked up softly)
	"GPSClient",
	"ObjectiveClient", -- needs HUDController + GPSClient
	"HouseClient",
	"BusinessClient", -- Empire: business cards, the wash mini-game, level props, alerts (needs HUD, Notify, GPS; LawClient softly)
	"PhoneUI",
	"DealerClient",
	"InteractClient", -- needs PhoneUI (IsOpen) + DriveUI + ImpactClient
	"TrafficClient",
	"PropClient", -- street furniture you plow through (needs DriveController; uses SoundClient, SettingsClient, VehicleFeel, AmbienceClient when they exist)
	"TutorialClient",
	"ShopClient",
	"OfferClient", -- right-moment pass offers (needs HUDController, NotifyController, SettingsClient)
	"SpinClient", -- the daily spin wheel and its 2X pills (needs HUDController, NotifyController; PhoneUI, CombatClient's pills softly)
	"DailyClient", -- the login streak's 7-day calendar card (needs HUDController, NotifyController)
	"MinimapClient",
	"MapClient", -- the big map: tap the minimap (or M) to see the whole city and set a waypoint (needs MinimapClient, GPSClient)
	"ProgressClient",
	"CrewClient",
	"RideClient", -- riding together: HOP IN for anyone's car (strangers ask the driver), INVITE from the driver's seat
	"MissionClient",
	"BigScoreClient", -- the crew heist's strip, checklist, marker, prompts and sounds (needs HUDController, GPSClient, NotifyController; SoundClient looked up softly)
	"PedClient",
	"CombatClient", -- fists and guns (needs HUD, Notify, Sound, ImpactClient, PedClient)
	"RespawnClient", -- the death screen and its RESPAWN button (needs HUDController, SoundClient)
	"WeaponWheel", -- hold Tab / D-pad left: the weapon wheel (needs CombatClient; PhoneUI, SoundClient looked up softly)
	"LocomotionClient", -- on-foot feel: sprint + stamina, lean, footsteps, landings, shoulder camera (last: it only reads the others)
}

for _, name in ipairs(ORDER) do
	local module = controllers:WaitForChild(name, 5)
	if not module then
		warn("[ClientMain] missing controller " .. name)
		continue
	end
	local ok, err = pcall(function()
		local c = require(module)
		if c.Init then
			c.Init()
		end
	end)
	if not ok then
		warn("[ClientMain] " .. name .. " failed to start: " .. tostring(err))
	end
end

if RunService:IsStudio() then
	local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
	local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
	local spawnCar = Remotes.Event("RequestSpawnCar")
	local testCars = {}
	for _, def in ipairs(Vehicles.List) do
		if not def.Hidden then -- street cars only come from carjacking
			table.insert(testCars, def)
		end
	end
	local keys = {
		Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six,
		Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine, Enum.KeyCode.Zero, Enum.KeyCode.Minus, Enum.KeyCode.Equals,
	}
	UserInputService.InputBegan:Connect(function(input, processed)
		-- Needs Left Alt held: the Backpack reads 1/2 for fists/blaster without marking them processed.
		if processed or not UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
			return
		end
		for i, key in ipairs(keys) do
			if input.KeyCode == key and testCars[i] then
				spawnCar:FireServer(testCars[i].Id)
			end
		end
	end)
	-- The Studio MCP runs sandboxed (it can't fire remotes or require modules): it sets this player's
	-- attribute "NCClient" to a JSON array instead and reads the answer from "NCClientResult".
	--   ["fire","RequestSpawnCar","Vortex"]            fire a remote
	--   ["call","PhoneUI","Open","Garage"]             call a controller's function
	--   ["get","DriveController","Status","Speed"]     read a value inside a controller
	-- Argument helpers: {"v3":[x,y,z]} a Vector3, {"c3":[r,g,b]} a Color3 (0-255), {"inst":"path"} an
	-- Instance, "$char" your character, "$nil" a nil (JSON arrays can't hold one).
	local me = Players.LocalPlayer
	local serial = 0
	me:GetAttributeChangedSignal("NCClient"):Connect(function()
		local raw = me:GetAttribute("NCClient")
		if type(raw) ~= "string" or raw == "" then
			return
		end
		me:SetAttribute("NCClient", nil)
		serial += 1
		local ok, res = pcall(function()
			local args = HttpService:JSONDecode(raw)
			local n = #args
			for i = 1, n do
				local v = args[i]
				if v == "$nil" then
					args[i] = nil
				elseif type(v) == "table" and v.c3 then
					args[i] = Color3.fromRGB(v.c3[1], v.c3[2], v.c3[3])
				elseif type(v) == "table" and v.v3 then
					args[i] = Vector3.new(v.v3[1], v.v3[2], v.v3[3])
				elseif type(v) == "table" and v.inst then
					-- { "inst": "Workspace.Vehicles.Gatorback" }: an Instance by its path from game
					local at = game
					for part in string.gmatch(v.inst, "[^%.]+") do
						at = at and (at:FindFirstChild(part) or (at == game and game:GetService(part)) or nil)
					end
					args[i] = at
				elseif v == "$char" then
					args[i] = me.Character
				end
			end
			local cmd = args[1]
			if cmd == "fire" then
				Remotes.Event(args[2]):FireServer(table.unpack(args, 3, n))
				return "fired"
			elseif cmd == "call" then
				local c = require(controllers:FindFirstChild(args[2]))
				local out = table.pack(c[args[3]](table.unpack(args, 4, n)))
				for i = 1, out.n do
					out[i] = tostring(out[i])
				end
				return table.concat(out, ", ", 1, out.n)
			elseif cmd == "get" then
				local v = require(controllers:FindFirstChild(args[2]))
				for i = 3, n do
					v = v[args[i]]
				end
				return v
			end
			error("unknown command " .. tostring(cmd))
		end)
		me:SetAttribute("NCClientResult", serial .. (ok and " ok " or " ERR ") .. tostring(res))
	end)
	print("[ClientMain] Studio test keys: hold Left Alt + 1-9, 0, -, = to spawn cars; E or F enters, F exits, Space drifts, Shift nitro, R flips")
end
print("[ClientMain] client ready for " .. Players.LocalPlayer.Name)
