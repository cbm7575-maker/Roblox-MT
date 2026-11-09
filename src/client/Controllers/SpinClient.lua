-- SpinClient (ModuleScript, StarterPlayerScripts.Controllers.SpinClient)
-- The Lucky Wheel as this player sees it (Config.Spin; SpinService builds the stand and runs the spins), the
-- spinner's prize stamp, the "your spin is ready" reminder, and the 2X boost pills.
--   * The wheel's face: Workspace.LuckyWheel.Face is a blank see-through part; this draws the 18 slices on it
--     (a SurfaceGui in PlayerGui, adorned to it: same slices, colours and words on every device). A slice is
--     drawn as K.LINES thin spokes of its colour (a frame can't be a wedge): each is a full-diameter bar
--     turned about the centre, with its lower half see-through (UIGradient). Every slice is the same size,
--     so what the wheel shows is the odds: 1 in 18 each. The pointer is drawn over the top of the rim.
--   * Turning it: the model's attributes SpinStart (server time), SpinFrom, SpinTo, SpinSeconds say how a spin
--     goes, and every client eases the slices from SpinFrom to SpinTo over the same seconds (Config.Spin.
--     AngleAt), so everyone in the plaza sees the same spin. At rest it stands at Angle. While it turns it
--     ticks past each slice (a 3D click at the wheel) and the rim's bulbs chase round.
--   * The prompt (SpinPrompt on the podium) says what pressing it would do: SPIN while this player's daily
--     spin is ready, WAIT while someone else spins, USED TODAY otherwise (the server says why in a toast).
--   * The spinner (SpinResult): when the wheel stops, a stamp with the prize (kicker LUCKY WHEEL) and a sound.
--   * Reminder: once a spin is ready (player attribute SpinReady), the tutorial is done and nothing's
--     chasing them, one toast tells them to spin the Lucky Wheel downtown (PHONE > SPIN sets the GPS).
--     Again whenever a new day's spin comes while they play.
--   * Boost pills: "2X CASH 29:41" / "2X XP 12:03" in CombatClient's Pills row (under the cash, next to
--     SAFE ZONE), while the player attributes BoostCashUntil / BoostXPUntil (server time) are ahead.
--     A boost that runs out says so in a toast. Server BoostPaid (amount): the 2X CASH extra on a payout;
--     shown as a toast, added up so a run of small payouts makes one toast (K.PAID_GAP).
-- API: SpinClient.Status() -> { Ready = bool, NextIn = seconds or nil, Cash = boost seconds left, XP = ... },
--   SpinClient.WheelPos() -> Vector3, SpinClient.RouteToWheel() (sets the GPS to the Lucky Wheel).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Spin = require(ReplicatedStorage.Shared.Config.Spin)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local Theme = require(ReplicatedStorage.Shared.Util.Theme)
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local NotifyController = require(script.Parent:WaitForChild("NotifyController"))

local player = Players.LocalPlayer
local C = Theme.Color

local SpinClient = {}

local K = {
	LINES = 8, -- spokes per slice
	CANVAS = 1000, -- the face's SurfaceGui, pixels square
	TICK_GAP = 0.07, -- seconds: the fewest between two tick sounds
	TICK_RANGE = 140, -- studs: ticks are heard this close to the wheel
	BULB_STEP = 0.09, -- seconds per step of the bulbs' chase while it turns
	PAID_GAP = 20, -- seconds the 2X CASH payout toasts are added up for
}

-- Slice colours by prize (text is white, dark on the gold car slice).
local INK = Color3.fromRGB(20, 12, 40)
local BULB_ON, BULB_OFF = Color3.fromRGB(255, 236, 170), Color3.fromRGB(110, 90, 60)
local function sliceColor(slice)
	if slice.Kind == "Car" then
		return C.Gold
	elseif slice.Kind == "Gun" then
		return Color3.fromRGB(206, 92, 48)
	elseif slice.Kind == "Boost" then
		return slice.Boost == "Cash" and C.Brand or Color3.fromRGB(122, 92, 222)
	end
	local shades = { [1000] = Color3.fromRGB(32, 88, 56), [2500] = Color3.fromRGB(44, 118, 72),
		[5000] = Color3.fromRGB(58, 148, 86), [10000] = Color3.fromRGB(92, 186, 98) }
	return shades[slice.Cash] or Color3.fromRGB(44, 118, 72)
end

local ui = {}
local S = {
	world = nil, -- { model, face, gui, rotor, bulbs = { parts }, prompt }
	lastTick = nil, lastSound = 0, bulbStep = 0, bulbAt = 0, turning = false,
	reminded = false, -- the "your spin is ready" toast has shown for this ready spell
	paid = 0, paidAt = nil, -- 2X CASH extras waiting for their toast
	boostWasOn = { Cash = false, XP = false },
}

local function serverNow()
	return Workspace:GetServerTimeNow()
end

local function money(n)
	return HUDController.Money(n)
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function untilText(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h, m = seconds // 3600, (seconds % 3600) // 60
	if h > 0 then
		return h .. "h " .. m .. "m"
	end
	return math.max(m, 1) .. "m"
end

local function sound(name, volume, where)
	local ok, SoundClient = pcall(require, script.Parent:FindFirstChild("SoundClient"))
	if ok and type(SoundClient) == "table" and type(SoundClient.Play) == "function" then
		pcall(SoundClient.Play, name, where, volume)
	end
end

function SpinClient.Status()
	local nextAt = player:GetAttribute("SpinNextAt")
	local function left(kind)
		local t = player:GetAttribute("Boost" .. kind .. "Until")
		return type(t) == "number" and math.max(0, t - serverNow()) or 0
	end
	return {
		Ready = player:GetAttribute("SpinReady") == true,
		NextIn = type(nextAt) == "number" and math.max(0, nextAt - serverNow()) or nil,
		Cash = left("Cash"),
		XP = left("XP"),
	}
end

------------------------------------------------------------------ the wheel

-- A label: Display font, white, scaled to its box (capped), with a dark edge.
local function text(parent, name, kind, maxSize)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	Theme.Text(l, nil, kind or "Display")
	l.TextScaled = true
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = maxSize or 24
	cap.MinTextSize = 8
	cap.Parent = l
	l.Parent = parent
	return l
end

-- A bar from the centre of `parent` out to its edge, turned `angle` degrees clockwise from straight up:
-- a full-diameter bar about the centre whose lower half is see-through.
local function spoke(parent, name, angle, width, color, alpha, z)
	local bar = Instance.new("Frame")
	bar.Name = name
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.5)
	bar.Size = UDim2.new(0, width, 1, 0)
	bar.Rotation = angle
	bar.BackgroundColor3 = color
	bar.BackgroundTransparency = 0
	bar.BorderSizePixel = 0
	bar.ZIndex = z or 1
	local g = Instance.new("UIGradient")
	g.Rotation = 90 -- top to bottom
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, alpha or 0),
		NumberSequenceKeypoint.new(0.5, alpha or 0),
		NumberSequenceKeypoint.new(0.501, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = bar
	bar.Parent = parent
	return bar
end

local function buildWheel(holder, d)
	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromOffset(d, d)
	disc.BackgroundColor3 = C.Panel
	disc.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = disc
	local rim = Instance.new("UIStroke")
	rim.Color = C.Gold
	rim.Thickness = math.max(4, math.floor(d * 0.018))
	rim.Parent = disc
	disc.Parent = holder

	-- The part that turns.
	local rotor = Instance.new("Frame")
	rotor.Name = "Rotor"
	rotor.AnchorPoint = Vector2.new(0.5, 0.5)
	rotor.Position = UDim2.fromScale(0.5, 0.5)
	rotor.Size = UDim2.new(1, -4, 1, -4)
	rotor.BackgroundTransparency = 1
	rotor.Rotation = 0
	rotor.Parent = disc
	ui.rotor = rotor

	local n = #Spin.Slices
	local step = 360 / n
	local spokeWidth = math.ceil(d * 0.028)
	for i, slice in ipairs(Spin.Slices) do
		local mid = (i - 1) * step
		local color = sliceColor(slice)
		for j = 0, K.LINES - 1 do
			spoke(rotor, "Fill" .. i .. "_" .. j, mid - step / 2 + (j + 0.5) * step / K.LINES, spokeWidth, color, 0, 1)
		end
		-- Its words, along the radius from the rim inward (a holder the size of the disc, turned to the
		-- slice, keeps the label's centre on the slice's middle line).
		local turn = Instance.new("Frame")
		turn.Name = "Words" .. i
		turn.Size = UDim2.fromScale(1, 1)
		turn.BackgroundTransparency = 1
		turn.Rotation = mid
		turn.ZIndex = 3
		turn.Parent = rotor
		local main = Spin.Label(slice)
		local l = text(turn, "Label", "Display", math.floor(d * 0.05))
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5 - 0.325) -- (its middle 0.65 of the way out; it runs 0.39 to 0.92)
		l.Size = UDim2.fromOffset(math.floor(d * 0.265), math.floor(d * 0.068))
		l.Rotation = 90
		l.ZIndex = 3
		l.Text = main
		if slice.Kind == "Car" then
			l.TextColor3 = INK
			l:FindFirstChild("Shadow").Transparency = 1
		end
	end
	-- Thin dark lines between the slices.
	for i = 1, n do
		spoke(rotor, "Line" .. i, (i - 1) * step - step / 2, math.max(2, math.floor(d * 0.006)), INK, 0.1, 2)
	end

	-- The hub.
	local hub = Instance.new("Frame")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromScale(0.2, 0.2)
	hub.BackgroundColor3 = C.Panel
	hub.BorderSizePixel = 0
	hub.ZIndex = 5
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(0.5, 0)
	hc.Parent = hub
	local hs = Instance.new("UIStroke")
	hs.Color = C.Gold
	hs.Thickness = math.max(2, math.floor(d * 0.01))
	hs.Parent = hub
	hub.Parent = disc
	local star = text(hub, "Star", "Bold", math.floor(d * 0.09))
	star.Size = UDim2.fromScale(0.8, 0.8)
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Position = UDim2.fromScale(0.5, 0.5)
	star.Text = "★"
	star.TextColor3 = C.Gold
	star.ZIndex = 6

	-- The pointer, over the rim at the top: white with a thick dark edge, so it shows on every slice (a gold
	-- one vanished on the gold car slice in the Studio test).
	local size = math.floor(d * 0.17)
	local pointer = text(holder, "Pointer", "Bold", size)
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Position = UDim2.new(0.5, 0, 0.5, -math.floor(d / 2) + math.floor(d * 0.01))
	pointer.Size = UDim2.fromOffset(size, size)
	pointer.Text = "▼"
	pointer.TextColor3 = C.Text
	pointer.ZIndex = 8
	local ps = pointer:FindFirstChild("Shadow")
	ps.Color = INK
	ps.Thickness = 3
	ps.Transparency = 0
	return rotor
end

------------------------------------------------------------------ the Lucky Wheel in the city

function SpinClient.WheelPos()
	local w = S.world
	if w and w.model and w.model.Parent then
		return w.model:GetPivot().Position
	end
	return Vector3.new(Spin.Wheel.Pos.X, 0, Spin.Wheel.Pos.Z)
end

function SpinClient.RouteToWheel()
	local ok, GPSClient = pcall(require, script.Parent:FindFirstChild("GPSClient"))
	if ok and type(GPSClient) == "table" and type(GPSClient.SetTarget) == "function" then
		GPSClient.SetTarget(Spin.Wheel.Name, SpinClient.WheelPos())
	end
end

-- Draw the slices on the wheel's blank face.
local function attach(model)
	local face = model:WaitForChild("Face", 10)
	if not face or S.world then
		return
	end
	local g = Instance.new("SurfaceGui")
	g.Name = "LuckyWheelFace"
	g.Adornee = face
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	g.CanvasSize = Vector2.new(K.CANVAS, K.CANVAS)
	g.LightInfluence = 0
	g.MaxDistance = 600
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.ResetOnSpawn = false
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = g
	-- The wheel fills Diameter of the face's width (the rest is room for the pointer over the rim).
	local across = face.Size.X > 0 and (face:GetAttribute("Diameter") or face.Size.X) / face.Size.X or 0.85
	local rotor = buildWheel(holder, math.floor(K.CANVAS * across))
	g.Parent = player:WaitForChild("PlayerGui")
	local bulbs = {}
	local folder = model:FindFirstChild("Bulbs")
	for i = 1, 24 do
		local b = folder and folder:FindFirstChild("Bulb" .. i)
		if b then
			table.insert(bulbs, b)
		end
	end
	local podium = model:FindFirstChild("Podium")
	local prompt = podium and podium:FindFirstChild("SpinPrompt", true)
	S.world = { model = model, face = face, gui = g, rotor = rotor, bulbs = bulbs, prompt = prompt }
	model.AncestryChanged:Connect(function()
		if not model.Parent and S.world and S.world.model == model then
			g:Destroy()
			S.world = nil
		end
	end)
end

-- Where the wheel stands right now (degrees) and whether it's turning.
local function wheelAngle(model, now)
	local start, from = model:GetAttribute("SpinStart"), model:GetAttribute("SpinFrom")
	local to, secs = model:GetAttribute("SpinTo"), model:GetAttribute("SpinSeconds")
	if type(start) == "number" and type(from) == "number" and type(to) == "number" and type(secs) == "number" then
		local t = now - start
		if t < 0 then
			return from, false
		elseif t < secs then
			return Spin.AngleAt(from, to, secs, t), true
		end
		return to, false
	end
	return model:GetAttribute("Angle") or 0, false
end

local function bulbs(w, turning)
	if turning then
		if os.clock() - S.bulbAt < K.BULB_STEP then
			return
		end
		S.bulbAt = os.clock()
		S.bulbStep += 1
		for i, b in ipairs(w.bulbs) do
			b.Color = (i + S.bulbStep) % 3 == 0 and BULB_ON or BULB_OFF
		end
	elseif S.turning then
		for _, b in ipairs(w.bulbs) do
			b.Color = BULB_ON
		end
	end
end

-- What pressing the prompt would do, for this player.
local function promptText(w)
	if not w.prompt then
		return
	end
	local text
	if w.model:GetAttribute("Busy") == true then
		text = "WAIT"
	elseif player:GetAttribute("SpinReady") == true then
		text = "SPIN"
	else
		text = "USED TODAY"
	end
	if w.prompt.ActionText ~= text then
		w.prompt.ActionText = text
	end
end

local function step()
	local w = S.world
	if not w then
		return
	end
	local angle, turning = wheelAngle(w.model, serverNow())
	w.rotor.Rotation = angle % 360
	-- A tick each time a slice line passes the pointer (heard near the wheel only).
	local slice = math.floor((angle + 180 / #Spin.Slices) / (360 / #Spin.Slices))
	if turning and S.lastTick ~= nil and slice ~= S.lastTick and os.clock() - S.lastSound >= K.TICK_GAP then
		local cam = Workspace.CurrentCamera
		if cam and (cam.CFrame.Position - w.face.Position).Magnitude < K.TICK_RANGE then
			S.lastSound = os.clock()
			sound("Click", 0.7, w.face)
		end
	end
	S.lastTick = slice
	bulbs(w, turning)
	S.turning = turning
end

------------------------------------------------------------------ the spinner's prize

-- What a plan (SpinResult.Plan) says on the stamp: title, line under it.
local function describe(plan)
	if plan.Kind == "Cash" then
		return money(plan.Cash), "Cash in your account"
	elseif plan.Kind == "Car" then
		local name = string.upper(tostring(plan.CarName or plan.Car))
		if plan.Owned then
			return name, "You own one already: +" .. money(plan.Cash or Spin.CarFallback) .. " instead"
		end
		return name, "The 1 in 18! It's in your GARAGE"
	elseif plan.Kind == "Gun" then
		if plan.Owned then
			return "FREE GUN", "You have every gun your rank allows: +" .. money(plan.Cash or Spin.GunFallback)
		end
		return string.upper(tostring(plan.GunName or plan.Gun)), "A free gun, yours for good"
	elseif plan.Kind == "Boost" then
		return "2X " .. string.upper(tostring(plan.Boost)), (plan.Boost == "Cash" and "Double money" or "Double XP")
			.. " for " .. tostring(plan.Minutes) .. " minutes of play"
	end
	return "PRIZE", ""
end
SpinClient.Describe = describe

local function onResult(r)
	if type(r) ~= "table" or type(r.Plan) ~= "table" then
		return
	end
	local wait = (tonumber(r.StopAt) or serverNow()) - serverNow()
	if wait > 0 then
		task.wait(math.min(wait, 15))
	end
	local title, sub = describe(r.Plan)
	HUDController.Stamp(title, sub, C.Gold, "LUCKY WHEEL · YOU WON")
	local big = r.Plan.Kind == "Car" and not r.Plan.Owned
	sound(big and "Passed" or "CashIn", 1)
	local bonus = tonumber(r.Bonus) or 0
	if bonus > 0 then
		task.delay(4, function()
			NotifyController.Show(bonus == 1 and "You have a bonus spin left (login streak): spin again!"
				or ("You have " .. bonus .. " bonus spins left (login streak): spin again!"), C.Gold, "success")
		end)
	elseif r.NextAt then
		task.delay(4, function()
			NotifyController.Show("Next free spin in " .. untilText(r.NextAt - serverNow()) .. ".", C.Gold, "info")
		end)
	end
end

------------------------------------------------------------------ the reminder

local function remindStep()
	if player:GetAttribute("SpinReady") ~= true then
		S.reminded = false -- (the next ready spell reminds again)
		return
	end
	if S.reminded or player:GetAttribute("TitleScreen") == true then
		return
	end
	local stepDone = player:GetAttribute("TutorialStep")
	if type(stepDone) ~= "number" or stepDone < #Tutorial.Steps or (player:GetAttribute("Heat") or 0) > 0 then
		return
	end
	if HUDController.StampTop and HUDController.StampTop() ~= nil then
		return -- (after the welcome stamp or a rank-up, not over it)
	end
	S.reminded = true
	NotifyController.Show("Your free daily spin is ready! Spin the Lucky Wheel downtown. PHONE > SPIN sets your GPS.", C.Gold, "success")
end

------------------------------------------------------------------ boost pills

local function uiPart(guiName, childName)
	local pg = player:FindFirstChild("PlayerGui")
	local screenGui = pg and pg:FindFirstChild(guiName)
	return screenGui and screenGui:FindFirstChild(childName)
end

local function boostPills()
	local pills = uiPart("CombatHUD", "Pills")
	if not pills then
		return nil
	end
	local function pill(kind, color, order)
		local name = "Boost" .. kind
		local l = pills:FindFirstChild(name)
		if l then
			return l
		end
		l = Instance.new("TextLabel")
		l.Name = name
		Theme.Text(l, 12, "Bold")
		l.LayoutOrder = order
		l.Size = UDim2.fromScale(0, 1)
		l.AutomaticSize = Enum.AutomaticSize.X
		l.TextColor3 = color
		l.Visible = false
		Theme.Panel(l)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 9), UDim.new(0, 9)
		pad.Parent = l
		l.Parent = pills
		return l
	end
	return { Cash = pill("Cash", C.Cash, 5), XP = pill("XP", C.Purple, 6) }
end

local function boostStep()
	local st = SpinClient.Status()
	local pills = boostPills()
	for _, kind in ipairs({ "Cash", "XP" }) do
		local left = st[kind]
		local on = left > 0
		if pills then
			pills[kind].Visible = on
			if on then
				pills[kind].Text = "2X " .. string.upper(kind) .. "  " .. clock(left)
			end
		end
		if S.boostWasOn[kind] and not on then
			NotifyController.Show("Your 2X " .. string.upper(kind) .. " is over. Spin again tomorrow for another prize!", C.Gold, "info")
		end
		S.boostWasOn[kind] = on
	end
	-- 2X CASH extras, added up into one toast.
	if S.paid > 0 and S.paidAt and os.clock() - S.paidAt >= 1.5 then
		NotifyController.Show("2X CASH: +" .. money(S.paid) .. " bonus", C.Cash, "success")
		S.paid, S.paidAt = 0, nil
		S.quietUntil = os.clock() + K.PAID_GAP
	end
end

------------------------------------------------------------------ start

function SpinClient.Init()
	Remotes.OnClient("SpinResult", function(r)
		task.spawn(onResult, r)
	end)
	Remotes.OnClient("BoostPaid", function(amount)
		if type(amount) ~= "number" or amount <= 0 then
			return
		end
		S.paid += amount
		-- (The toast waits out PAID_GAP after the last one, so a run of payouts makes one toast.)
		local at = os.clock()
		if S.quietUntil and at < S.quietUntil then
			at = S.quietUntil
		end
		S.paidAt = S.paidAt or at
	end)
	-- The wheel (Persistent: every player gets it, however far away).
	task.spawn(function()
		local model = Workspace:WaitForChild("LuckyWheel", 60)
		if model then
			attach(model)
		end
		Workspace.ChildAdded:Connect(function(child)
			if child.Name == "LuckyWheel" and child:IsA("Model") then
				attach(child)
			end
		end)
	end)
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(step)
		if not ok and not S.stepWarned then
			S.stepWarned = true
			warn("[SpinClient] wheel: " .. tostring(err))
		end
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 then
			return
		end
		acc = 0
		boostStep()
		remindStep()
		if S.world then
			promptText(S.world)
		end
	end)
end

return SpinClient
