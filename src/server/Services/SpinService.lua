-- SpinService (ModuleScript, ServerScriptService.Services.SpinService)
-- The daily spin and the Lucky Wheel (Config.Spin; owner, Nov 6 2026). One free spin per UTC day: cash,
-- 2X CASH, 2X XP, a free gun, or (1 in 18) a Solana GT. The spin happens at a real wheel in the city (owner:
-- "an actual wheel that everyone will go to and can spin. People can watch them spin"):
--   * The Lucky Wheel (Workspace.LuckyWheel, built here at start-up, ModelStreamingMode Persistent so every
--     player has it): a stage, an upright 18-slice wheel facing the downtown spawn, rim bulbs, a sign above
--     ("LUCKY WHEEL" over a status line), an odds board beside it, and a podium in front with the SPIN
--     prompt. Its Face part is blank: each client draws the slices on it (SpinClient) and turns them.
--   * One spin at a time. A spin sets the model's attributes SpinFrom, SpinTo (degrees, Config.Spin.Target),
--     SpinSeconds, SpinSlice, SpinBy (display name), SpinUser and last SpinStart (server time, Lead seconds
--     ahead); every client eases the wheel from SpinFrom to SpinTo over the same seconds, so everyone around
--     sees the same spin. Angle = where it rests now. Busy = true from the start until ShowResult seconds
--     after it stops. The sign's status line says "<NAME> IS SPINNING..." then "<NAME> WON <PRIZE>!".
--   * Big wins (the car, cash from Wheel.BigWin up) go on everyone's city feed (Feed "WheelWin").
-- Saved in data.spin = {
--   day = the UTC day of the last spin (Config.Spin.Day),
--   pending = { slice = i, plan = {...} } while a prize is still to be paid (the wheel is turning),
--   boosts = { Cash = seconds left, XP = seconds left } (play time: only counts down while online),
--   n = spins so far, cars = times the car slice came up,
--   bonus = bonus spins waiting (the login streak's extras, Config.Daily: used after the day's free spin) }.
-- Player attributes:
--   SpinReady       true while today's spin is unused or a bonus spin is waiting (only once the save has loaded)
--   SpinNextAt      when the next spin unlocks (unix seconds), while SpinReady is false
--   SpinBonus       bonus spins waiting (nil when none)
--   BoostCashUntil  when 2X CASH ends (Workspace:GetServerTimeNow() seconds); nil when it's off
--   BoostXPUntil    the same for 2X XP
--   (EconomyService and ProgressService read the two Until attributes to double what they pay.)
-- Remotes: SpinResult (server -> the spinner): { Slice = i, Plan = { Kind, Cash?, Car?, CarName?, Gun?,
--   GunName?, Boost?, Minutes?, Owned? }, StopAt = server time the wheel stops, NextAt, Bonus = bonus spins left }. The prize is paid
--   when the wheel stops (so the HUD's cash doesn't give it away). Today is marked used, and the pending prize
--   saved, before the wheel moves: leaving mid-spin pays it on the next join.
--   Refusals are Notify keys: SpinLoading, SpinUsed, WheelBusy, WheelTooFar.
-- The slice is picked by a uniform random number from 1 to 18 on the server: what the wheel shows is the
-- odds. Telemetry: Spin_<what> (Spin_Cash 1000, Spin_Car, Spin_CarOwned, Spin_Gun, Spin_GunFallback,
-- Spin_BoostCash, Spin_BoostXP), and the cash itself as "spin:<kind>" economy events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Spin = require(ReplicatedStorage.Shared.Config.Spin)
local Combat = require(ReplicatedStorage.Shared.Config.Combat)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local DataService = require(ServerScriptService.Services.DataService)
local EconomyService = require(ServerScriptService.Services.EconomyService)
local Telemetry = require(ServerScriptService.Services.Telemetry)

local SpinService = {}

local BOOST_KINDS = { "Cash", "XP" }
local SAVE_BOOSTS_EVERY = 5 -- seconds: how often the boosts' time left is written into the save
local DAY_CHECK_EVERY = 30 -- seconds: players online past midnight UTC get the new day's spin
local W = Spin.Wheel

local rng = Random.new()
local forced = nil -- Studio tests only (ForceNext): the slice the next spin lands on
local result, notify, feed

-- The wheel's state (mirrored onto Workspace.LuckyWheel's attributes once the model exists).
local wheel = { busy = false, angle = 0, model = nil, status = nil, podium = nil }

-- (Services loaded on first use: GarageService and CombatService start after this one.)
local function service(name)
	return require(ServerScriptService.Services[name])
end

local function serverNow()
	return Workspace:GetServerTimeNow()
end

local function record(data)
	if type(data.spin) ~= "table" then
		data.spin = {}
	end
	local s = data.spin
	if type(s.boosts) ~= "table" then
		s.boosts = {}
	end
	return s
end

------------------------------------------------------------------ boosts

-- Seconds of this boost left (0 when off).
function SpinService.BoostLeft(player, kind)
	local untilT = player:GetAttribute("Boost" .. kind .. "Until")
	return type(untilT) == "number" and math.max(0, untilT - serverNow()) or 0
end

-- Add `seconds` to a boost (on top of what's left of it).
local function addBoost(player, data, kind, seconds)
	local left = SpinService.BoostLeft(player, kind) + seconds
	player:SetAttribute("Boost" .. kind .. "Until", serverNow() + left)
	record(data).boosts[kind] = math.floor(left)
end

-- Write what's left of each boost into the save, and switch off the ones that ran out.
local function saveBoosts(player, data)
	local s = record(data)
	for _, kind in ipairs(BOOST_KINDS) do
		local left = SpinService.BoostLeft(player, kind)
		if left > 0 then
			s.boosts[kind] = math.floor(left)
		else
			s.boosts[kind] = nil
			if player:GetAttribute("Boost" .. kind .. "Until") ~= nil then
				player:SetAttribute("Boost" .. kind .. "Until", nil)
			end
		end
	end
end

------------------------------------------------------------------ the day's spin

local function today()
	return Spin.Day(os.time())
end

local function bonusLeft(s)
	return math.max(0, math.floor(tonumber(s.bonus) or 0))
end

local function publishReady(player, data)
	local s = record(data)
	local bonus = bonusLeft(s)
	local ready = type(s.day) ~= "number" or s.day < today() or bonus > 0
	player:SetAttribute("SpinReady", ready)
	player:SetAttribute("SpinNextAt", (not ready) and Spin.NextAt(os.time()) or nil)
	player:SetAttribute("SpinBonus", bonus > 0 and bonus or nil)
end

-- The login streak's extras (DailyService, Config.Daily): `n` bonus spins at the Lucky Wheel, kept in the
-- save until used (after the day's free spin).
function SpinService.AddBonusSpins(player, data, n)
	n = math.floor(tonumber(n) or 0)
	if n <= 0 or type(data) ~= "table" then
		return
	end
	local s = record(data)
	s.bonus = bonusLeft(s) + n
	publishReady(player, data)
end

-- The login streak's 2X boosts: `minutes` of play time added to a 2X CASH / 2X XP boost.
function SpinService.GrantBoost(player, data, kind, minutes)
	minutes = tonumber(minutes) or 0
	if (kind ~= "Cash" and kind ~= "XP") or minutes <= 0 or type(data) ~= "table" then
		return
	end
	addBoost(player, data, kind, minutes * 60)
	Telemetry.Custom(player, "Streak_Boost" .. kind, minutes)
end

-- What a slice gives this player right now (a dry run: nothing is paid).
local function planFor(player, slice)
	if slice.Kind == "Cash" then
		return { Kind = "Cash", Cash = slice.Cash }
	elseif slice.Kind == "Car" then
		local owned = service("GarageService").Owns(player, Spin.Car)
		local def = Vehicles.ById[Spin.Car]
		return { Kind = "Car", Car = Spin.Car, CarName = def and def.DisplayName or Spin.Car, Owned = owned,
			Cash = owned and Spin.CarFallback or nil }
	elseif slice.Kind == "Gun" then
		local data = DataService.Get(player)
		local guns = data and type(data.gear) == "table" and type(data.gear.guns) == "table" and data.gear.guns or {}
		for _, id in ipairs(Spin.GunOrder) do
			local gun = Combat.Guns[id]
			if gun and guns[id] ~= true and Combat.RankOk(player, gun) then
				return { Kind = "Gun", Gun = id, GunName = gun.Name }
			end
		end
		return { Kind = "Gun", Owned = true, Cash = Spin.GunFallback }
	elseif slice.Kind == "Boost" then
		return { Kind = "Boost", Boost = slice.Boost, Minutes = Spin.BoostMinutes }
	end
	return { Kind = "Cash", Cash = 1000 }
end

-- Pay a plan (checked again: the gun or car may have become theirs while the wheel turned).
local function pay(player, data, plan)
	local s = record(data)
	if plan.Kind == "Cash" then
		EconomyService.AddCash(player, plan.Cash, "spin:cash")
		Telemetry.Custom(player, "Spin_Cash", plan.Cash)
	elseif plan.Kind == "Car" then
		s.cars = (s.cars or 0) + 1
		if not plan.Owned and service("GarageService").Give(player, plan.Car) then
			Telemetry.Custom(player, "Spin_Car", 1)
		else
			EconomyService.AddCash(player, Spin.CarFallback, "spin:car")
			Telemetry.Custom(player, "Spin_CarOwned", Spin.CarFallback)
		end
	elseif plan.Kind == "Gun" then
		if plan.Gun and service("CombatService").GiveGun(player, plan.Gun) then
			Telemetry.Custom(player, "Spin_Gun", 1)
		else
			EconomyService.AddCash(player, Spin.GunFallback, "spin:gun")
			Telemetry.Custom(player, "Spin_GunFallback", Spin.GunFallback)
		end
	elseif plan.Kind == "Boost" then
		addBoost(player, data, plan.Boost, plan.Minutes * 60)
		Telemetry.Custom(player, "Spin_Boost" .. plan.Boost, plan.Minutes)
	end
end

local function payPending(player, data)
	local s = record(data)
	local pending = s.pending
	if type(pending) ~= "table" or type(pending.plan) ~= "table" then
		s.pending = nil
		return
	end
	s.pending = nil -- (cleared first: a payout that throws must never pay twice)
	local ok, err = pcall(pay, player, data, pending.plan)
	if not ok then
		warn("[SpinService] paying " .. player.Name .. ": " .. tostring(err))
	end
	DataService.SaveNow(player)
end

-- What the sign and the feed call a prize.
local function prizeWords(plan)
	if plan.Kind == "Cash" or (plan.Owned and plan.Cash) then
		local n = tostring(math.floor(plan.Cash or 0)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		return "$" .. n
	elseif plan.Kind == "Car" then
		return "A " .. string.upper(tostring(plan.CarName or plan.Car))
	elseif plan.Kind == "Gun" then
		return "A FREE " .. string.upper(tostring(plan.GunName or "GUN"))
	elseif plan.Kind == "Boost" then
		return "2X " .. string.upper(tostring(plan.Boost))
	end
	return "A PRIZE"
end
SpinService.PrizeWords = prizeWords

local function setStatus(text)
	if wheel.status then
		wheel.status.Text = text
	end
end

local function mirror(key, value)
	if wheel.model then
		wheel.model:SetAttribute(key, value)
	end
end

-- Close enough to the podium to spin (the prompt reaches 10 studs; this is the server's own check).
-- (A table field, so logic tests can stand in for it.)
function SpinService.InRange(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not wheel.podium then
		return false
	end
	return (root.Position - wheel.podium.Position).Magnitude <= W.Range
end

-- The wheel's state: { Busy, Angle }.
function SpinService.WheelState()
	return { Busy = wheel.busy, Angle = wheel.angle }
end

-- A spin at the Lucky Wheel (its podium's prompt, or a test). Returns true if the wheel started.
function SpinService.SpinAt(player)
	if not RateLimit.Allow(player, "Spin", 1, 2) then
		return false
	end
	local data = DataService.Get(player)
	if not data then
		notify:FireClient(player, "SpinLoading")
		return false
	end
	local s = record(data)
	local dailyUsed = type(s.day) == "number" and s.day >= today()
	if (dailyUsed and bonusLeft(s) <= 0) or s.pending ~= nil then
		notify:FireClient(player, "SpinUsed")
		publishReady(player, data)
		return false
	end
	if wheel.busy then
		notify:FireClient(player, "WheelBusy")
		return false
	end
	if not SpinService.InRange(player) then
		notify:FireClient(player, "WheelTooFar")
		return false
	end
	local index = forced or rng:NextInteger(1, #Spin.Slices)
	forced = nil
	local plan = planFor(player, Spin.Slices[index])
	if dailyUsed then
		s.bonus = bonusLeft(s) - 1 -- the day's free spin first, then a waiting bonus spin
		if s.bonus <= 0 then
			s.bonus = nil
		end
		Telemetry.Custom(player, "Spin_Bonus", 1)
	end
	s.day = today()
	s.n = (s.n or 0) + 1
	s.pending = { slice = index, plan = plan }
	publishReady(player, data)
	task.spawn(DataService.SaveNow, player)

	wheel.busy = true
	local from = wheel.angle
	local to = Spin.Target(from, index, (rng:NextNumber() * 2 - 1) * Spin.Jitter, Spin.Turns)
	local start = serverNow() + W.Lead
	mirror("Busy", true)
	mirror("SpinFrom", from)
	mirror("SpinTo", to)
	mirror("SpinSeconds", Spin.Seconds)
	mirror("SpinSlice", index)
	mirror("SpinBy", player.DisplayName)
	mirror("SpinUser", player.UserId)
	mirror("SpinStart", start) -- (last: clients start the turn when this one changes)
	setStatus(string.upper(player.DisplayName) .. " IS SPINNING...")
	result:FireClient(player, { Slice = index, Plan = plan, StopAt = start + Spin.Seconds, NextAt = Spin.NextAt(os.time()),
		Bonus = bonusLeft(s) })

	task.delay(W.Lead + Spin.Seconds, function()
		wheel.angle = to % 360
		mirror("Angle", wheel.angle)
		-- (Gone already? The save's pending prize is paid on their next join.)
		if player.Parent == Players and DataService.Get(player) == data and s.pending ~= nil then
			payPending(player, data)
		end
		local words = prizeWords(plan)
		setStatus(string.upper(player.DisplayName) .. " WON " .. words .. "!")
		if plan.Kind == "Car" and not plan.Owned then
			feed:FireAllClients("WheelWin", { Name = player.DisplayName, Prize = "a " .. tostring(plan.CarName or plan.Car) })
		elseif plan.Kind == "Cash" and (plan.Cash or 0) >= W.BigWin then
			feed:FireAllClients("WheelWin", { Name = player.DisplayName, Prize = words })
		end
		task.delay(W.ShowResult, function()
			wheel.busy = false
			mirror("Busy", false)
			setStatus("FREE SPIN EVERY DAY")
		end)
	end)
	return true
end

-- Studio only (play tests): the next spin lands on slice `index`. Does nothing in a live game.
function SpinService.ForceNext(index)
	if RunService:IsStudio() and Spin.Slices[index] then
		forced = index
	end
end

------------------------------------------------------------------ the Lucky Wheel (built once, at start-up)

local INK = Color3.fromRGB(20, 12, 40)
local GOLD = Color3.fromRGB(240, 200, 80)
local STAGE = Color3.fromRGB(34, 28, 48)
local WHITE = Color3.fromRGB(245, 245, 245)

local function part(parent, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props or {}) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function label(parent, name, text, font, color, pos, size, align)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position, l.Size = pos, size
	l.FontFace = font
	l.Text = text
	l.TextColor3 = color
	l.TextScaled = true
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	local st = Instance.new("UIStroke")
	st.Color = INK
	st.Thickness = 3
	st.Parent = l
	l.Parent = parent
	return l
end

local function surface(p, face, canvas)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = canvas
	g.LightInfluence = 0
	g.MaxDistance = 600
	g.Parent = p
	return g
end

local function build()
	local old = Workspace:FindFirstChild("LuckyWheel")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "LuckyWheel"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- every player has it, near or far
	local BANGERS = Font.new("rbxasset://fonts/families/Bangers.json")
	local OSWALD = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
	local OSWALD_LIGHT = Font.new("rbxasset://fonts/families/Oswald.json")

	-- The ground's height under the stage (city ground, kerbs, plazas).
	local hit = Workspace:Raycast(Vector3.new(W.Pos.X, 300, W.Pos.Z), Vector3.new(0, -400, 0))
	local gy = hit and hit.Position.Y or 0.1
	local base = CFrame.lookAt(Vector3.new(W.Pos.X, gy, W.Pos.Z), Vector3.new(W.Face.X, gy, W.Face.Z))
	local d = W.Size

	local stage = part(model, "Stage", Vector3.new(d + 8, 1, 12), base * CFrame.new(0, 0.5, 0), STAGE)
	part(model, "Trim", Vector3.new(d + 8, 0.3, 0.4), base * CFrame.new(0, 0.85, -6.05), GOLD,
		{ Material = Enum.Material.Neon, CanCollide = false })
	model.PrimaryPart = stage
	local hubCF = base * CFrame.new(0, 1 + W.Hub, 0)
	-- The stand: a post behind the wheel and a foot on the stage.
	part(model, "Post", Vector3.new(1.6, W.Hub, 1.6), base * CFrame.new(0, 1 + W.Hub / 2, 1.8), INK)
	part(model, "Foot", Vector3.new(6, 1.2, 4), base * CFrame.new(0, 1.6, 1.8), INK)
	-- The wheel's back and rim: a gold disc (a cylinder turned to face the plaza).
	part(model, "Rim", Vector3.new(1.4, d + 1.2, d + 1.2), hubCF * CFrame.new(0, 0, 0.75) * CFrame.Angles(0, math.rad(90), 0), GOLD,
		{ Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal })
	-- The face the clients draw on: see-through, a hair in front of the rim, 3 studs wider than the wheel so
	-- the pointer drawn over the top of the rim fits on it.
	local face = part(model, "Face", Vector3.new(d + 3, d + 3, 0.1), hubCF * CFrame.new(0, 0, -0.05), INK,
		{ Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	face:SetAttribute("Diameter", d)
	-- Bulbs round the rim (SpinClient chases them while it turns).
	local bulbs = Instance.new("Folder")
	bulbs.Name = "Bulbs"
	bulbs.Parent = model
	for i = 1, 24 do
		local a = math.rad((i - 1) * 15)
		local r = d / 2 + 0.35
		part(bulbs, "Bulb" .. i, Vector3.new(0.7, 0.7, 0.7), hubCF * CFrame.new(math.sin(a) * r, math.cos(a) * r, -0.15),
			Color3.fromRGB(255, 236, 170), { Shape = Enum.PartType.Ball, Material = Enum.Material.Neon, CanCollide = false })
	end
	-- The sign over the wheel.
	local sign = part(model, "Sign", Vector3.new(17, 4.2, 0.6), hubCF * CFrame.new(0, d / 2 + 3.4, 0.6), STAGE)
	local sg = surface(sign, Enum.NormalId.Front, Vector2.new(850, 210))
	label(sg, "Title", "LUCKY WHEEL", BANGERS, GOLD, UDim2.fromScale(0.03, 0.02), UDim2.fromScale(0.94, 0.6))
	wheel.status = label(sg, "Status", "FREE SPIN EVERY DAY", OSWALD, WHITE, UDim2.fromScale(0.03, 0.62), UDim2.fromScale(0.94, 0.34))
	-- The odds board beside the stage: every prize and how many slices pay it.
	local board = part(model, "OddsBoard", Vector3.new(7, 9, 0.4), base * CFrame.new(d / 2 + 6.5, 5.5, -1), STAGE)
	part(model, "BoardLeg", Vector3.new(0.8, 1, 0.8), base * CFrame.new(d / 2 + 6.5, 0.5, -1), INK)
	local bg = surface(board, Enum.NormalId.Front, Vector2.new(350, 450))
	label(bg, "Head", "PRIZES", BANGERS, GOLD, UDim2.fromScale(0.05, 0.02), UDim2.fromScale(0.9, 0.13))
	local rows = {
		{ (Spin.Label({ Kind = "Car" })), Spin.Count("Car") }, { "$10,000", Spin.Count("Cash", 10000) },
		{ "FREE GUN", Spin.Count("Gun") }, { "2X CASH 30 MIN", Spin.Count("Boost", "Cash") },
		{ "2X XP 30 MIN", Spin.Count("Boost", "XP") }, { "$5,000", Spin.Count("Cash", 5000) },
		{ "$2,500", Spin.Count("Cash", 2500) }, { "$1,000", Spin.Count("Cash", 1000) },
	}
	for i, row in ipairs(rows) do
		local y = 0.17 + (i - 1) * 0.09
		label(bg, "Prize" .. i, row[1], OSWALD, i == 1 and GOLD or WHITE, UDim2.fromScale(0.05, y), UDim2.fromScale(0.6, 0.075),
			Enum.TextXAlignment.Left)
		label(bg, "Odds" .. i, row[2] .. " in " .. #Spin.Slices, OSWALD_LIGHT, Color3.fromRGB(176, 182, 190),
			UDim2.fromScale(0.65, y), UDim2.fromScale(0.3, 0.075), Enum.TextXAlignment.Right)
	end
	label(bg, "Note", "ONE FREE SPIN A DAY", OSWALD_LIGHT, GOLD, UDim2.fromScale(0.05, 0.9), UDim2.fromScale(0.9, 0.07))
	-- The podium in front, with the SPIN prompt.
	local podium = part(model, "Podium", Vector3.new(3.2, 3.4, 2.4), base * CFrame.new(0, 1.7, -9), STAGE)
	part(model, "PodiumTop", Vector3.new(3.4, 0.3, 2.6), base * CFrame.new(0, 3.5, -9), GOLD, { Material = Enum.Material.Neon })
	local att = Instance.new("Attachment")
	att.Name = "PromptAt"
	att.Position = Vector3.new(0, 2.2, 0)
	att.Parent = podium
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SpinPrompt"
	prompt.ActionText = "SPIN"
	prompt.ObjectText = W.Name
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = att
	prompt.Triggered:Connect(function(player)
		SpinService.SpinAt(player)
	end)
	wheel.podium = podium

	model:SetAttribute("Angle", wheel.angle)
	model:SetAttribute("Busy", false)
	model.Parent = Workspace
	wheel.model = model
	-- A heads-up if something already stands where the stage goes (the lot was clear on Nov 6).
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { model }
	local blocking = Workspace:GetPartBoundsInBox(base * CFrame.new(0, 6, -1), Vector3.new(d + 8, 10, 16), overlap)
	if #blocking > 0 then
		warn("[SpinService] the Lucky Wheel's lot isn't clear: " .. blocking[1]:GetFullName())
	end
end

-- For MapService (the GPS, the minimap): where the wheel is.
SpinService.Place = { Name = W.Name, Kind = W.Kind, Pos = Vector3.new(W.Pos.X, 0, W.Pos.Z) }

function SpinService.Init()
	result = Remotes.Event("SpinResult")
	notify = Remotes.Event("Notify")
	feed = Remotes.Event("Feed")
	Remotes.Event("BoostPaid") -- (EconomyService fires it; made now so clients find it at start-up)
	local ok, err = pcall(build)
	if not ok then
		warn("[SpinService] building the Lucky Wheel: " .. tostring(err))
	end

	DataService.OnLoaded(function(player, data)
		local s = record(data)
		for _, kind in ipairs(BOOST_KINDS) do
			local left = s.boosts[kind]
			if type(left) == "number" and left > 0 then
				player:SetAttribute("Boost" .. kind .. "Until", serverNow() + left)
			end
		end
		if s.pending ~= nil then
			payPending(player, data) -- they left while the wheel turned last time
		end
		publishReady(player, data)
	end)

	task.spawn(function()
		local sinceDayCheck = 0
		while true do
			task.wait(SAVE_BOOSTS_EVERY)
			sinceDayCheck += SAVE_BOOSTS_EVERY
			local dayCheck = sinceDayCheck >= DAY_CHECK_EVERY
			if dayCheck then
				sinceDayCheck = 0
			end
			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.Get(player)
				if data then
					saveBoosts(player, data)
					if dayCheck and player:GetAttribute("SpinReady") ~= true and record(data).pending == nil then
						publishReady(player, data)
					end
				end
			end
		end
	end)
end

return SpinService
