-- MissionClient (ModuleScript, StarterPlayerScripts.Controllers.MissionClient)
-- Phone missions on screen, in the flat "street" look (Theme zones; re-placed when the screen size or
-- input type changes). Started from the phone's JOBS app (RequestMission "Start"); the server runs
-- everything, this only draws the "Mission" attribute it sets.
--   * Banner zone (top centre, under the goal strip): frame "Banner", a slim flat dark strip with a small
--     gold MISSION tag and the mission's name (phones: the name alone, in gold Display, so it fits the
--     narrow banner), the time left in Display (red for the last 15 s), and a QUIT button (Theme.Touch
--     tall on touch screens). It steps aside while a HUDController stamp draws over it (on phones the
--     Stamp zone reaches into the Banner zone, e.g. MISSION FAILED) and while the mission intro is up,
--     then comes back.
--   * Subtitle zone (bottom centre): frame "Step", the current step in white words straight on the
--     screen with a soft shadow, and the count of a "collect" step in gold ("3/6"). It steps aside while
--     ImpactClient's KNOCKED DOWN caption uses the same zone (ScreenGui "ImpactFx", frame "KnockedDown")
--     and while the mission intro is up.
--   * In the world (local parts under the camera): each target gets a slim gold light column with a
--     gold chevron and its distance (GPSClient.FormatDistance) floating over it, and the GPS is routed
--     to the current target (the nearest one left, for a "collect" step).
--   * The mission intro as it starts (HUDController.Intro): letterbox bars, the mission's name large in
--     the script face, the first step under it (a white HUDController.Stamp instead, should Intro be
--     missing). While it is up (HUDController.IntroUp) the banner and the step line make way: the bars
--     cover the top and the bottom, and the intro says the step itself.
--   * Cinematic stamps (HUDController.Stamp): MISSION PASSED in gold with the reward line
--     ("+$500   +50 XP") and the Passed sting, MISSION FAILED in red with the reason (a crew prep, the
--     crew job's shared mission from CrewService: PREP DONE / PREP FAILED under a small CREW JOB, and
--     CREW PREP instead of MISSION on the PC banner's tag; its Place / Places spots come from
--     Missions.Resolve, as on the server); and
--     CROWD FAVOURITE in gold for the car meet's best ride (CarMeetResult).
--   * A crew prep's hands-on steps (Pickup, Deliver, Pair: MissionService puts items / stand / spots in the
--     "Mission" JSON): a marker on every thing lying on the ground (to grab, or dropped on the way), on the
--     Deliver stand and on the Pair spots not done yet; the GPS goes to the nearest thing on the ground, else
--     the stand or the spots. The step line counts them ("1/3") and says what you carry ("you carry 2").
-- Hidden on the first-join title screen (local attribute TitleScreen, set by TeamUI).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local Theme = require(ReplicatedStorage.Shared.Util.Theme)
local GPSClient = require(script.Parent:WaitForChild("GPSClient"))
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local NotifyController = require(script.Parent:WaitForChild("NotifyController"))

local player = Players.LocalPlayer

local MissionClient = {}

local C = Theme.Color

local HURRY = 15 -- seconds left when the timer turns red
local QUIT_W = 64
local TIMER_W, TIMER_W_TOUCH = 64, 46 -- room for "4:59" in Display (22 px on a PC, 20 on phones)
local COLUMN_H = 60 -- studs: the light column over a target
local MARK_EVERY = 0.25 -- seconds between distance updates on the markers

local gui, banner, titleLabel, timerLabel, quit, step, stepLabel
local markers = {} -- { part, distance label, pos }
local state -- decoded "Mission" attribute
local lastTarget
local lastTimer, lastStep -- what the labels say now (only rewritten when it changes)
local markAccum = 0

local function colorText(color, text)
	return string.format('<font color="#%s">%s</font>', color:ToHex(), text)
end

-- Plain words from the config: keep "&", "<" and ">" from being read as rich text.
local function escape(s)
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function clearMarkers()
	for _, m in ipairs(markers) do
		m.part:Destroy()
	end
	table.clear(markers)
end

-- One stroke of the chevron (two make a "V").
local function stroke(parent, x, angle)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.new(0.5, x, 0, 9)
	f.Size = UDim2.fromOffset(13, 3)
	f.Rotation = angle
	f.BackgroundColor3 = C.Gold
	f.BorderSizePixel = 0
	f.Parent = parent
	Theme.Corners(f, 1)
end

-- A target in the world: a slim, see-through gold column, and over it (on top of everything, so it reads
-- through buildings) a small gold chevron with the distance under it.
local function marker(pos)
	local column = Instance.new("Part")
	column.Name = "MissionMarker"
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.CastShadow = false
	column.Size = Vector3.new(0.6, COLUMN_H, 0.6)
	column.Material = Enum.Material.Neon
	column.Color = C.Gold
	column.Transparency = 0.6
	column.Position = Vector3.new(pos.X, COLUMN_H / 2, pos.Z)
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(80, 36)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 8 - COLUMN_H / 2, 0) -- 8 studs up, not halfway up the column
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	tag.Parent = column
	stroke(tag, -4, 40)
	stroke(tag, 4, -40)
	local distance = Instance.new("TextLabel")
	distance.Name = "Distance"
	Theme.Text(distance, 13, "Body")
	distance.AnchorPoint = Vector2.new(0.5, 0)
	distance.Position = UDim2.new(0.5, 0, 0, 16)
	distance.Size = UDim2.new(1, 0, 0, 16)
	distance.Text = ""
	distance.Parent = tag
	column.Parent = Workspace.CurrentCamera
	table.insert(markers, { part = column, label = distance, pos = pos })
end

local function updateMarkers()
	for _, m in ipairs(markers) do
		local d = GPSClient.Distance(m.pos)
		m.label.Text = d and GPSClient.FormatDistance(d) or ""
	end
end

-- Words in the condensed Display face, inside rich text.
local function displayText(color, text)
	return string.format('<font face="Oswald" weight="bold" size="%d" color="#%s">%s</font>', titleLabel.TextSize + 2,
		color:ToHex(), text)
end

-- The banner's words: a small gold Display tag, then the mission's name. Phones: the name alone, in gold
-- Display (a 667 px-wide phone leaves the title about 120 px, enough for "LOST FLAMINGO", not the tag too).
local function drawTitle()
	local m = state and Missions.ById[state.id]
	if not m then
		return
	end
	local name = escape(string.upper(m.Name))
	if Theme.IsTouch() then
		titleLabel.Text = displayText(C.Gold, name)
	else
		titleLabel.Text = displayText(C.Gold, m.Crew and "CREW PREP" or "MISSION") .. "   " .. name
	end
end

local function hidePieces()
	banner.Visible = false
	step.Visible = false
end

-- ImpactClient's KNOCKED DOWN caption: it shares the Subtitle zone with the step for ~2.5 s.
local function knockCaptionUp()
	local playerGui = player:FindFirstChild("PlayerGui")
	local fx = playerGui and playerGui:FindFirstChild("ImpactFx")
	local caption = fx and fx:FindFirstChild("KnockedDown")
	return caption ~= nil and caption:IsA("GuiObject") and caption.Visible
end

-- Would a stamp starting at y = stampTop (zone coordinates: y = 0 at the very top) draw over the banner?
-- AbsolutePosition starts under the top bar whatever IgnoreGuiInset says: measure from our gui's corner.
local function stampOverBanner()
	local stampTop = HUDController.StampTop and HUDController.StampTop()
	if stampTop == nil then
		return false
	end
	return stampTop < banner.AbsolutePosition.Y - gui.AbsolutePosition.Y + banner.AbsoluteSize.Y
end

-- HUDController's mission intro is on screen (its letterbox bars and the words over the bottom one).
local function introUp()
	return HUDController.IntroUp ~= nil and HUDController.IntroUp() == true
end

-- Show or step aside, every frame (each label is only written when it changes).
local function showPieces()
	local on = player:GetAttribute("TitleScreen") ~= true and not introUp()
	local bannerOn = on and not stampOverBanner()
	local stepOn = on and not knockCaptionUp()
	if banner.Visible ~= bannerOn then
		banner.Visible = bannerOn
	end
	if step.Visible ~= stepOn then
		step.Visible = stepOn
	end
end

local function refresh()
	local raw = player:GetAttribute("Mission")
	if not raw then
		state = nil
		hidePieces()
		clearMarkers()
		if lastTarget then
			lastTarget = nil
			GPSClient.Clear()
		end
		return
	end
	local ok, s = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok then
		return
	end
	state = s
	lastTimer, lastStep = nil, nil -- the next Heartbeat rewrites both
	showPieces()
	-- (a crew prep's places: the same spots the server worked out from MapService's list)
	local m = Missions.Resolve(Missions.ById[s.id])
	local current = m and m.Steps[s.step]
	if not current then
		return
	end
	drawTitle()
	clearMarkers()
	local target
	if current.Kind == "Collect" then
		local got = {}
		for _, i in ipairs(s.got or {}) do
			got[i] = true
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local best, bestD
		for i, p in ipairs(current.Points) do
			if not got[i] then
				marker(p)
				local d = root and (p - root.Position).Magnitude or 0
				if not bestD or d < bestD then
					best, bestD = p, d
				end
			end
		end
		target = best
	elseif current.Kind == "Pickup" or current.Kind == "Deliver" or current.Kind == "Pair" then
		-- A crew prep's hands-on step (MissionService): the things on the ground (to grab, or dropped on the
		-- way), the stand to bring them to, or the two spots of a pair job. The GPS goes to the nearest thing
		-- on the ground, else the stand or the spots.
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local best, bestD
		local function consider(x, z, mark)
			local p = Vector3.new(tonumber(x) or 0, 0, tonumber(z) or 0)
			if mark then
				marker(p)
			end
			local d = root and (p - root.Position * Vector3.new(1, 0, 1)).Magnitude or 0
			if not bestD or d < bestD then
				best, bestD = p, d
			end
		end
		for _, it in ipairs(s.items or {}) do
			if it.s == "g" then
				consider(it.x, it.z, true)
			end
		end
		if not best and current.Kind == "Deliver" then
			local stand = s.stand
			consider(stand and stand.x or current.Pos.X, stand and stand.z or current.Pos.Z, true)
		elseif current.Kind == "Deliver" and s.stand then
			marker(Vector3.new(s.stand.x, 0, s.stand.z))
		elseif current.Kind == "Pair" then
			for _, spot in ipairs(s.spots or {}) do
				if not spot.d then
					consider(spot.x, spot.z, true)
				end
			end
			if not best then
				consider(current.Pos.X, current.Pos.Z, true)
			end
		end
		target = best or current.Pos
	else
		target = current.Pos
		marker(current.Pos)
	end
	updateMarkers()
	if target and target ~= lastTarget then
		lastTarget = target
		GPSClient.SetTarget(m.Name, target)
	end
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Mission"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- the zone map's coordinates (y = 0 is the very top of the screen)
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Banner zone: [MISSION  NAME ........ 1:42  QUIT]
	banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.Visible = false
	Theme.Panel(banner)
	banner.Parent = gui

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	Theme.Text(titleLabel, 14, "Bold")
	titleLabel.RichText = true
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	titleLabel.Position = UDim2.fromOffset(12, 0)
	titleLabel.Size = UDim2.new(1, -(12 + 8 + TIMER_W + 8 + QUIT_W + 6), 1, 0)
	titleLabel.Parent = banner

	timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "Timer"
	Theme.Text(timerLabel, 22, "Display")
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right
	timerLabel.AnchorPoint = Vector2.new(1, 0.5)
	timerLabel.Position = UDim2.new(1, -(QUIT_W + 6 + 8), 0.5, 0)
	timerLabel.Size = UDim2.new(0, TIMER_W, 1, 0)
	timerLabel.Text = ""
	timerLabel.Parent = banner

	quit = Instance.new("TextButton")
	quit.Name = "Quit"
	Theme.Button(quit, "Quiet")
	quit.BackgroundColor3 = C.PanelLight
	quit.BackgroundTransparency = 0.15
	quit.TextSize = 13
	quit.Text = "QUIT"
	quit.AnchorPoint = Vector2.new(1, 0.5)
	quit.Position = UDim2.new(1, -6, 0.5, 0)
	quit.Parent = banner
	quit.Activated:Connect(function()
		Remotes.Event("RequestMission"):FireServer("Quit")
	end)

	-- Subtitle zone: the step, white words straight on the screen.
	step = Instance.new("Frame")
	step.Name = "Step"
	step.BackgroundTransparency = 1
	step.Visible = false
	step.Parent = gui
	stepLabel = Instance.new("TextLabel")
	stepLabel.Name = "Text"
	Theme.Text(stepLabel, 16, "Body")
	stepLabel.RichText = true
	stepLabel.TextWrapped = true
	stepLabel.TextTruncate = Enum.TextTruncate.AtEnd
	stepLabel.Size = UDim2.fromScale(1, 1)
	stepLabel.Text = ""
	stepLabel.Parent = step
end

-- Put both pieces in their zones and size them for this screen (phones: Theme.Touch-tall QUIT, a
-- narrower timer so the name keeps its room).
local function place()
	local touch = Theme.IsTouch()
	Theme.Place(banner, "Banner", touch)
	Theme.Place(step, "Subtitle", touch)
	local timerW = touch and TIMER_W_TOUCH or TIMER_W
	titleLabel.TextSize = touch and 13 or 14
	titleLabel.Size = UDim2.new(1, -(12 + 8 + timerW + 8 + QUIT_W + 6), 1, 0)
	timerLabel.TextSize = touch and 20 or 22
	timerLabel.Size = UDim2.new(0, timerW, 1, 0)
	quit.Size = UDim2.fromOffset(QUIT_W, touch and Theme.Touch or 28)
	stepLabel.TextSize = touch and 14 or 16
	drawTitle() -- the Display words' size follows the title's, and phones drop the MISSION tag
end

-- Every frame: show or step aside, the countdown, and the step with its count (labels only change when
-- the words do).
local function tick(dt)
	if not state then
		return
	end
	showPieces()
	local m = Missions.ById[state.id]
	local current = m and m.Steps[state.step]
	if not current then
		return
	end
	local left = math.max(0, math.ceil(state.deadline - Workspace:GetServerTimeNow()))
	local timer = string.format("%d:%02d", left // 60, left % 60)
	if timer ~= lastTimer then
		lastTimer = timer
		timerLabel.Text = timer
		timerLabel.TextColor3 = left <= HURRY and C.Danger or C.Text
	end
	local words = escape(current.Text)
	if current.Kind == "Collect" then
		words ..= "   " .. colorText(C.Gold, string.format("%d/%d", #(state.got or {}), #current.Points))
	elseif current.Kind == "Pickup" or current.Kind == "Deliver" or current.Kind == "Pair" then
		-- How far along: grabbed (this step's things), in the stand (all of them), or pair spots done; and what
		-- you carry yourself.
		local done, total, mine = 0, 0, 0
		if current.Kind == "Pair" then
			for _, spot in ipairs(state.spots or {}) do
				total += 1
				done += spot.d and 1 or 0
			end
		end
		for _, it in ipairs(state.items or {}) do
			if current.Kind == "Deliver" or it.p == state.step then
				total += 1
				done += ((current.Kind == "Deliver" and it.s == "s") or (current.Kind == "Pickup" and it.s ~= "g")) and 1 or 0
			end
			if it.s == "c" and it.u == player.UserId then
				mine += 1
			end
		end
		if total > 1 then
			words ..= "   " .. colorText(C.Gold, string.format("%d/%d", done, total))
		end
		if mine > 0 then
			words ..= "   " .. colorText(C.Cash, mine > 1 and string.format("you carry %d", mine) or "you carry 1")
		end
	end
	if words ~= lastStep then
		lastStep = words
		stepLabel.Text = words
	end
	markAccum += dt
	if markAccum >= MARK_EVERY then
		markAccum = 0
		updateMarkers()
	end
end

function MissionClient.Init()
	build()
	place()
	refresh()
	player:GetAttributeChangedSignal("Mission"):Connect(refresh)
	player:GetAttributeChangedSignal("TitleScreen"):Connect(function()
		if state then
			showPieces()
		end
	end)
	-- Re-place when the screen changes size or the device's input changes (phone layout or not).
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	UserInputService:GetPropertyChangedSignal("MouseEnabled"):Connect(place)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(place)
	task.spawn(function()
		Remotes.OnClient("CarMeetResult", function(info)
			if info.Favourite then
				HUDController.Stamp("CROWD FAVOURITE", "Best ride at the car meet  +" .. HUDController.Money(info.Bonus), C.Gold)
			end
		end)
		Remotes.OnClient("MissionEvent", function(kind, info)
			if kind == "Started" then
				-- The cinematic intro: the name over the first step (the old white stamp if it's missing).
				if type(HUDController.Intro) == "function" then
					HUDController.Intro(string.upper(info.Name), info.Text)
				else
					HUDController.Stamp(string.upper(info.Name), info.Text, C.Text)
				end
			elseif kind == "Step" then
				NotifyController.Show("Next: " .. info.Text, C.Gold)
			elseif kind == "Done" then
				HUDController.Stamp(info.Crew and "PREP DONE" or "MISSION PASSED", not info.First and "Repeat pay" or nil, C.Gold,
					info.Crew and "CREW JOB" or nil, { Cash = info.Cash, XP = info.XP })
			elseif kind == "Failed" then
				HUDController.Stamp(info.Crew and "PREP FAILED" or "MISSION FAILED", info.Reason, C.Danger)
			end
		end)
	end)
	RunService.Heartbeat:Connect(tick)
end

return MissionClient
