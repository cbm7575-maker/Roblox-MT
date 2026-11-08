-- CrewTasks (ModuleScript, ServerScriptService.Services.CrewTasks)
-- What the crew preps' hands-on steps put in the world (Config.Missions: Pickup, Deliver, Pair). MissionService
-- runs the steps and makes one run per prep (owner, Nov 7 2026: "have there be a part that they hold and grab").
-- Not a started service (no Init): MissionService requires it when a prep starts.
--   CrewTasks.Run(crewId, onAct) -> run: one prep's things, in Workspace.CrewTasks.Run<n>.
--     onAct(player, "Grab" | "Stash" | "Pair", index) once a prompt's hold really ran its length (timed here,
--     PromptButtonHoldBegan -> Triggered, as BigScoreService does) by someone alive, up (not knocked down or
--     tasered), on foot (else Notify "GetOutFirst", shared 3 s limit with VehicleService) and within reach.
--     MissionService decides whether it counts (on this prep, not wanted, the crew together).
--   run:Spot(pos, within)          a clear spot on the ground within `within` studs of pos (street level, no
--                                  water, nothing solid in a 3 x 4.5 x 3 box over it), or nil
--   run:Item(i, look, name, pos)   thing i on the ground at pos with its Grab prompt and a gold ring under it
--                                  (every prompt here floats PROMPT_UP studs over the ground: mid-screen)
--   run:Carry(i, player, slot)     thing i in the player's right hand (slot 1) or on their back (slot 2+),
--                                  welded and massless (it rides along in cars); gone with the character
--   run:Stand(pos, action, look)   the Deliver step's stand ("Crate" or "Desk") with its `action` prompt
--   run:Stash(i, n)                thing i into the stand, the n-th one in (it stays there, no prompt)
--   run:PairSpot(k, pos, action, look, seconds)  one of a Pair step's two spots: a prompt held `seconds`, a
--                                  gold ring to stand on and a lamp (red; run:PairLight(k, true) turns it green)
--   run:ClearPair(), run:ClearStand(), run:Clear() (everything, carried things too)
-- Looks: Case (drill bits), Motor, Battery, Keycard (on a little post), Bag (a duffel), Lookout (binoculars on a
-- post), FuseBox, Plate (a fake licence plate on a stand), Toolbox; stands Crate and Desk. Everything is
-- anchored on the ground and never solid (cars and people pass through), and every prompt has the attribute
-- CrewId: CrewClient hides other crews' prompts on each device (they'd only hear "NotYourJob" from the server).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)

local CrewTasks = {}

local K = {
	GRAB_HOLD = 0.8, -- seconds to grab a thing
	STASH_HOLD = 1, -- seconds to put things in a stand
	REACH = 10, -- the prompts' reach
	REACH_SLACK = 6, -- studs past it the holder may stand (lag)
	HOLD_SLACK = 0.4, -- a hold may reach us this much short of its length (network jitter)
	HOLD_KEEP = 3, -- seconds past its length a finished hold still counts
	RAY_FROM = 8, -- studs over a spot that Spot's ground ray starts from (under any roof)
	PROMPT_UP = 4, -- studs over the ground a thing's or a stand's prompt floats (mid-screen, not under the HUD)
	-- Colours
	GOLD = Color3.fromRGB(255, 196, 60),
	DARK = Color3.fromRGB(32, 32, 36),
	STEEL = Color3.fromRGB(128, 134, 144),
	YELLOW = Color3.fromRGB(255, 204, 40),
	RED = Color3.fromRGB(226, 52, 52),
	GREEN = Color3.fromRGB(70, 230, 120),
	WOOD = Color3.fromRGB(152, 108, 66),
	WOOD_DARK = Color3.fromRGB(104, 72, 44),
	WHITE = Color3.fromRGB(240, 240, 236),
	BLUE = Color3.fromRGB(60, 150, 255),
}

local runN = 0

------------------------------------------------------------------ building bits

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A carried thing's own shape: a model whose PrimaryPart "Handle" sits at `cf` (its bottom on the ground when
-- cf is a ground spot raised by half its height). Extra pieces are welded to the handle.
local LOOKS = {}

local function welded(handle, p)
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = p
	w.Parent = p
	return p
end

function LOOKS.Case(m, cf)
	local h = part(m, "Handle", Vector3.new(2.2, 0.9, 1.5), cf, K.DARK, Enum.Material.SmoothPlastic)
	welded(h, part(m, "Stripe", Vector3.new(2.24, 0.14, 1.54), cf, K.YELLOW))
	welded(h, part(m, "Grip", Vector3.new(0.8, 0.22, 0.22), cf * CFrame.new(0, 0.56, 0), K.STEEL, Enum.Material.Metal))
	return h
end

function LOOKS.Motor(m, cf)
	local h = part(m, "Handle", Vector3.new(2, 1.4, 1.4), cf, K.STEEL, Enum.Material.Metal, Enum.PartType.Cylinder)
	welded(h, part(m, "CapA", Vector3.new(0.2, 1.5, 1.5), cf * CFrame.new(1, 0, 0), K.DARK, Enum.Material.Metal, Enum.PartType.Cylinder))
	welded(h, part(m, "CapB", Vector3.new(0.2, 1.5, 1.5), cf * CFrame.new(-1, 0, 0), K.DARK, Enum.Material.Metal, Enum.PartType.Cylinder))
	welded(h, part(m, "Band", Vector3.new(0.3, 1.44, 1.44), cf, K.RED, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder))
	return h
end

function LOOKS.Battery(m, cf)
	local h = part(m, "Handle", Vector3.new(1.6, 1.1, 1), cf, K.YELLOW)
	welded(h, part(m, "Plus", Vector3.new(0.26, 0.26, 0.26), cf * CFrame.new(-0.45, 0.66, 0), K.RED, Enum.Material.Metal))
	welded(h, part(m, "Minus", Vector3.new(0.26, 0.26, 0.26), cf * CFrame.new(0.45, 0.66, 0), K.DARK, Enum.Material.Metal))
	welded(h, part(m, "Label", Vector3.new(1.62, 0.4, 1.02), cf, K.DARK))
	return h
end

function LOOKS.Keycard(m, cf)
	local h = part(m, "Handle", Vector3.new(1.2, 0.1, 0.8), cf, K.WHITE)
	welded(h, part(m, "Chip", Vector3.new(1.22, 0.12, 0.24), cf * CFrame.new(0, 0, 0.18), K.BLUE, Enum.Material.Neon))
	return h
end

function LOOKS.Bag(m, cf)
	local h = part(m, "Handle", Vector3.new(2.4, 1.1, 1.1), cf, K.DARK, Enum.Material.Fabric)
	welded(h, part(m, "StrapA", Vector3.new(0.18, 1.14, 1.14), cf * CFrame.new(-0.6, 0, 0), K.RED, Enum.Material.Fabric))
	welded(h, part(m, "StrapB", Vector3.new(0.18, 1.14, 1.14), cf * CFrame.new(0.6, 0, 0), K.RED, Enum.Material.Fabric))
	welded(h, part(m, "Grip", Vector3.new(1, 0.2, 0.2), cf * CFrame.new(0, 0.62, 0), K.DARK, Enum.Material.Fabric))
	return h
end

-- A gold ring on the ground: "the thing is here" from afar (and where to stand on a pair spot).
local function ring(parent, ground, size)
	local r = part(parent, "Ring", Vector3.new(0.12, size, size), CFrame.new(ground + Vector3.new(0, 0.08, 0))
		* CFrame.Angles(0, 0, math.rad(90)), K.GOLD, Enum.Material.Neon, Enum.PartType.Cylinder)
	r.Transparency = 0.45
	return r
end

-- A prompt's parent, PROMPT_UP studs over the ground at `ground` (an attachment on `part`): on the ground the
-- bubble showed at the bottom of the screen, under the step line and the minimap.
local function raised(part, ground)
	local a = Instance.new("Attachment")
	a.Name = "PromptAt"
	a.Parent = part
	a.WorldPosition = ground + Vector3.new(0, K.PROMPT_UP, 0)
	return a
end

local function prompt(parent, action, object, hold, crewId)
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "CrewTaskPrompt"
	pr.ActionText = action
	pr.ObjectText = object or ""
	pr.HoldDuration = hold
	pr.MaxActivationDistance = K.REACH
	pr.RequiresLineOfSight = false
	pr:SetAttribute("CrewId", crewId)
	pr.Parent = parent
	return pr
end

-- A spot's lamp on a short post: red, green while its hold counts.
local function lamp(parent, base)
	part(parent, "LampPost", Vector3.new(0.25, 3.2, 0.25), CFrame.new(base + Vector3.new(0, 1.6, 0)), K.DARK, Enum.Material.Metal)
	local l = part(parent, "Lamp", Vector3.new(0.6, 0.6, 0.6), CFrame.new(base + Vector3.new(0, 3.4, 0)), K.RED, Enum.Material.Neon,
		Enum.PartType.Ball)
	return l
end

-- The pair spots' looks: the piece the prompt sits on (base = the ground spot).
local SPOT_LOOKS = {}

function SPOT_LOOKS.Lookout(m, base)
	part(m, "Post", Vector3.new(0.3, 3.4, 0.3), CFrame.new(base + Vector3.new(0, 1.7, 0)), K.DARK, Enum.Material.Metal)
	return part(m, "Binoculars", Vector3.new(0.9, 0.42, 0.7), CFrame.new(base + Vector3.new(0, 3.6, 0)), K.DARK, Enum.Material.Metal)
end

function SPOT_LOOKS.FuseBox(m, base)
	part(m, "Post", Vector3.new(0.4, 3, 0.4), CFrame.new(base + Vector3.new(0, 1.5, 0)), K.STEEL, Enum.Material.Metal)
	local box = part(m, "Box", Vector3.new(1.8, 2, 0.8), CFrame.new(base + Vector3.new(0, 3.6, 0)), K.STEEL, Enum.Material.Metal)
	part(m, "Warning", Vector3.new(0.7, 0.7, 0.82), CFrame.new(base + Vector3.new(0, 3.9, 0)), K.YELLOW)
	return box
end

function SPOT_LOOKS.Plate(m, base)
	part(m, "Stand", Vector3.new(0.3, 2.4, 0.3), CFrame.new(base + Vector3.new(0, 1.2, 0)), K.DARK, Enum.Material.Metal)
	local plate = part(m, "Plate", Vector3.new(2.2, 1.1, 0.12), CFrame.new(base + Vector3.new(0, 2.9, 0)), K.WHITE)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(220, 110)
	gui.LightInfluence = 0
	gui.Parent = plate
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(30, 60, 140)
	t.Text = "SUN 4EVR"
	t.Parent = gui
	local back = gui:Clone()
	back.Face = Enum.NormalId.Back
	back.Parent = plate
	return plate
end

function SPOT_LOOKS.Toolbox(m, base)
	local box = part(m, "Toolbox", Vector3.new(1.8, 1, 0.9), CFrame.new(base + Vector3.new(0, 0.5, 0)), K.RED, Enum.Material.Metal)
	part(m, "Grip", Vector3.new(1, 0.2, 0.2), CFrame.new(base + Vector3.new(0, 1.15, 0)), K.DARK, Enum.Material.Metal)
	part(m, "Wrench", Vector3.new(1.3, 0.12, 0.25), CFrame.new(base + Vector3.new(0, 1.06, 0.3)), K.STEEL, Enum.Material.Metal)
	return box
end

-- The stands: the piece the prompt sits on, and where the n-th thing put in goes.
local STANDS = {}

function STANDS.Crate(m, base)
	local body = part(m, "Crate", Vector3.new(4, 2.2, 3), CFrame.new(base + Vector3.new(0, 1.1, 0)), K.WOOD, Enum.Material.WoodPlanks)
	for _, dz in ipairs({ -1.5, 1.5 }) do
		part(m, "Slat", Vector3.new(4.1, 0.3, 0.12), CFrame.new(base + Vector3.new(0, 1.6, dz)), K.WOOD_DARK, Enum.Material.WoodPlanks)
		part(m, "Slat", Vector3.new(4.1, 0.3, 0.12), CFrame.new(base + Vector3.new(0, 0.6, dz)), K.WOOD_DARK, Enum.Material.WoodPlanks)
	end
	return body, function(n)
		return CFrame.new(base + Vector3.new(-1.2 + ((n - 1) % 3) * 1.2, 2.2 + 0.75 + math.floor((n - 1) / 3) * 1.3, 0))
	end
end

function STANDS.Desk(m, base)
	local top = part(m, "Desk", Vector3.new(4, 0.3, 2.4), CFrame.new(base + Vector3.new(0, 2.8, 0)), K.WOOD, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -1.8, 1.8 }) do
		for _, z in ipairs({ -1, 1 }) do
			part(m, "Leg", Vector3.new(0.25, 2.65, 0.25), CFrame.new(base + Vector3.new(x, 1.33, z)), K.WOOD_DARK, Enum.Material.WoodPlanks)
		end
	end
	part(m, "Laptop", Vector3.new(1.4, 0.08, 1), CFrame.new(base + Vector3.new(0.8, 3, 0)), K.DARK, Enum.Material.Metal)
	part(m, "Screen", Vector3.new(1.4, 0.9, 0.06), CFrame.new(base + Vector3.new(0.8, 3.45, -0.5)), K.BLUE, Enum.Material.Neon)
	return top, function(n)
		return CFrame.new(base + Vector3.new(-1 + (n - 1) * 0.5, 3.0, 0.2))
	end
end

local function sizeOf(look)
	local probe = Instance.new("Model")
	local h = (LOOKS[look] or LOOKS.Case)(probe, CFrame.new())
	local y = h.Size.Y
	if look == "Motor" then
		y = 1.5
	end
	probe:Destroy()
	return y
end

------------------------------------------------------------------ a run

local Run = {}
Run.__index = Run

-- Characters and our own things don't count as ground or as being in the way; parked cars are in the way but
-- never ground (no thing on a car roof).
function Run:_params()
	local chars = { self.folder, Workspace.Terrain }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(chars, p.Character)
		end
	end
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = table.clone(chars)
	table.remove(ignore, 2) -- (the ray may land on terrain; water is turned down below)
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if vehicles then
		table.insert(ignore, vehicles)
	end
	ray.FilterDescendantsInstances = ignore
	local box = OverlapParams.new()
	box.FilterType = Enum.RaycastFilterType.Exclude
	box.FilterDescendantsInstances = chars
	box.RespectCanCollide = true
	return ray, box
end

function Run:Spot(pos, within)
	local ray, box = self:_params()
	local tries = { Vector3.new(pos.X, 0, pos.Z) }
	local r = 4
	while r <= (within or 10) do
		for a = 0, 7 do
			local angle = math.rad(a * 45 + r * 7)
			table.insert(tries, Vector3.new(pos.X + math.cos(angle) * r, 0, pos.Z + math.sin(angle) * r))
		end
		r += 4
	end
	for _, c in ipairs(tries) do
		-- (from just over head height: a roof or an awning over the spot, like the Spray & Go booth's at 19
		-- studs, isn't "the ground", and a ray from high up stopped on it)
		local hit = Workspace:Raycast(c + Vector3.new(0, K.RAY_FROM, 0), Vector3.new(0, -2 * K.RAY_FROM, 0), ray)
		if hit and hit.Normal.Y > 0.8 and math.abs(hit.Position.Y) < 4 and hit.Material ~= Enum.Material.Water then
			local inWay = Workspace:GetPartBoundsInBox(CFrame.new(hit.Position + Vector3.new(0, 2.6, 0)), Vector3.new(3, 4.5, 3), box)
			if #inWay == 0 then
				return hit.Position
			end
		end
	end
	return nil
end

-- Times a prompt's hold here, then the body checks; fn(player) when it all holds.
function Run:_wire(pr, hold, fn)
	local began = setmetatable({}, { __mode = "k" })
	local slack = math.min(K.HOLD_SLACK, hold * 0.5)
	pr.PromptButtonHoldBegan:Connect(function(p)
		began[p] = os.clock()
	end)
	pr.PromptButtonHoldEnded:Connect(function(p)
		local b = began[p]
		if b and os.clock() - b < hold - slack then
			began[p] = nil
		end
	end)
	pr.Triggered:Connect(function(p)
		local b = began[p]
		began[p] = nil
		if hold > 0 then
			local held = b and os.clock() - b
			if not held or held < hold - slack or held > hold + K.HOLD_KEEP then
				return
			end
		end
		local char = p.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local at = pr.Parent
		local atPos = at and ((at:IsA("Attachment") and at.WorldPosition) or (at:IsA("BasePart") and at.Position)) or nil
		if not hum or hum.Health <= 0 or not root or not atPos then
			return
		end
		local t = Workspace:GetServerTimeNow()
		if (p:GetAttribute("KnockedUntil") or 0) > t or (p:GetAttribute("StunnedUntil") or 0) > t then
			return
		end
		if hum.SeatPart then
			if RateLimit.Allow(p, "GetOutFirstToast", 1 / 3, 1) then
				Remotes.Event("Notify"):FireClient(p, "GetOutFirst")
			end
			return
		end
		if (root.Position - atPos).Magnitude > K.REACH + K.REACH_SLACK then
			return
		end
		local ok, err = pcall(fn, p)
		if not ok then
			warn("[CrewTasks] " .. tostring(err))
		end
	end)
end

function Run:_gone(i)
	local m = self.models[i]
	self.models[i] = nil
	if m then
		m:Destroy()
	end
end

function Run:Item(i, look, name, pos)
	self:_gone(i)
	self.looks[i] = { look = LOOKS[look] and look or "Case", name = name }
	local m = Instance.new("Model")
	m.Name = "Item" .. i
	local ground = pos
	local h
	if look == "Keycard" then
		-- (a card on the ground is too small to see: it lies on a little post)
		part(m, "Post", Vector3.new(0.8, 2.6, 0.8), CFrame.new(ground + Vector3.new(0, 1.3, 0)), K.STEEL, Enum.Material.Metal)
		h = LOOKS.Keycard(m, CFrame.new(ground + Vector3.new(0, 2.66, 0)))
	else
		h = (LOOKS[look] or LOOKS.Case)(m, CFrame.new(ground + Vector3.new(0, sizeOf(look) / 2 + 0.05, 0))
			* CFrame.Angles(0, math.rad(20 * i), 0))
	end
	m.PrimaryPart = h
	ring(m, ground, 5)
	local pr = prompt(raised(h, ground), "Grab", name, K.GRAB_HOLD, self.crewId)
	self:_wire(pr, K.GRAB_HOLD, function(p)
		self.onAct(p, "Grab", i)
	end)
	m.Parent = self.folder
	self.models[i] = m
end

function Run:Carry(i, player, slot)
	self:_gone(i)
	local def = self.looks[i] or { look = "Case" }
	local char = player.Character
	local hand = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
	local holder = ((slot or 1) <= 1 and hand) or torso or hand
	if not holder then
		return
	end
	local m = Instance.new("Model")
	m.Name = "CrewCarry" .. i
	local h = LOOKS[def.look](m, CFrame.new())
	m.PrimaryPart = h
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
		end
	end
	local weld = Instance.new("Weld")
	weld.Part0 = holder
	weld.Part1 = h
	if holder == hand then
		-- Hanging from the hand like a briefcase, long side forward.
		weld.C0 = CFrame.new(0, -holder.Size.Y / 2 - h.Size.Y / 2 - 0.05, 0) * CFrame.Angles(0, math.rad(90), 0)
	else
		-- On the back, stacked down from the shoulders.
		local n = math.max(0, (slot or 2) - 2)
		weld.C0 = CFrame.new(0, 0.35 - n * (h.Size.Y + 0.15), holder.Size.Z / 2 + h.Size.Z / 2 + 0.05)
	end
	-- (the whole model moves as one before it's welded on: its pieces keep their places on the handle)
	m:PivotTo(holder.CFrame * weld.C0)
	weld.Parent = h
	m.Parent = char
	self.models[i] = m
end

function Run:Stand(pos, action, look)
	self:ClearStand()
	local m = Instance.new("Model")
	m.Name = "Stand"
	local build = STANDS[look] or STANDS.Crate
	local body, slotCF = build(m, pos)
	ring(m, pos, 7)
	self.standSlot = slotCF
	local pr = prompt(raised(body, pos), action, look == "Desk" and "Hideout desk" or "Hideout crate", K.STASH_HOLD, self.crewId)
	self:_wire(pr, K.STASH_HOLD, function(p)
		self.onAct(p, "Stash", 1)
	end)
	m.Parent = self.folder
	self.stand = m
end

function Run:Stash(i, n)
	self:_gone(i)
	local def = self.looks[i] or { look = "Case" }
	if not self.stand or not self.standSlot then
		return
	end
	local m = Instance.new("Model")
	m.Name = "Stashed" .. i
	m.PrimaryPart = LOOKS[def.look](m, self.standSlot(n))
	m.Parent = self.stand
end

function Run:PairSpot(k, pos, action, look, seconds)
	local old = self.spots[k]
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "Spot" .. k
	local body = (SPOT_LOOKS[look] or SPOT_LOOKS.Toolbox)(m, pos)
	ring(m, pos, 6)
	self.lamps[k] = lamp(m, pos + Vector3.new(1.6, 0, 1.6))
	local pr = prompt(raised(body, pos), action, "Both at once", seconds, self.crewId)
	self:_wire(pr, seconds, function(p)
		self.onAct(p, "Pair", k)
	end)
	m.Parent = self.folder
	self.spots[k] = m
end

function Run:PairLight(k, on)
	local l = self.lamps[k]
	if l and l.Parent then
		l.Color = on and K.GREEN or K.RED
	end
end

function Run:ClearPair()
	for k, m in pairs(self.spots) do
		m:Destroy()
		self.spots[k] = nil
	end
	table.clear(self.lamps)
end

function Run:ClearStand()
	if self.stand then
		self.stand:Destroy()
		self.stand = nil
	end
	self.standSlot = nil
end

function Run:Clear()
	for i in pairs(self.models) do
		self:_gone(i)
	end
	self:ClearPair()
	self:ClearStand()
	if self.folder then
		self.folder:Destroy()
	end
end

-- (see the header) A new run's things go in Workspace.CrewTasks.Run<n>.
function CrewTasks.Run(crewId, onAct)
	local root = Workspace:FindFirstChild("CrewTasks")
	if not root then
		root = Instance.new("Folder")
		root.Name = "CrewTasks"
		root.Parent = Workspace
	end
	runN += 1
	local folder = Instance.new("Folder")
	folder.Name = "Run" .. runN
	folder:SetAttribute("CrewId", crewId)
	folder.Parent = root
	return setmetatable({
		crewId = crewId, onAct = onAct, folder = folder,
		models = {}, looks = {}, spots = {}, lamps = {},
	}, Run)
end

return CrewTasks
