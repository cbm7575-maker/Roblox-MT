-- FeedController (ModuleScript, StarterPlayerScripts.Controllers.FeedController)
-- The Coast Feed: short, auto-written posts about what's happening in this server, shown like phone
-- notifications ("street" look, Shared.Util.Theme): a small flat dark card with a round avatar (its thin
-- ring says what the post is about: red = an alarm, blue = police, gold = heists and the bank, orange =
-- trouble, purple = Florida moments, pink = the feed's own gossip), the bold handle ("@CoastFeed", or
-- "DISPATCH" in red for police alerts), a dim "now", and the post in one or two lines.
-- The server sends event keys + data (never player-typed text), this file turns them into words.
--   PC / gamepad: the HUD's Feed zone, top-left under Roblox's top bar; newest on top, max 3, never
--     lower than SPLIT of the screen height (NotifyController's toasts come up to there from the bottom).
--     Roblox's chat window opens in that same corner and draws over every game gui, so while chat is on
--     the column starts under the chat window; when that leaves less than MIN_ROOM, posts join the
--     toast stack instead, as on phones.
--   Phone: the Feed zone shares the toast stack, so posts go into NotifyController's stack (Stack). They
--     are "low" cards there: the player's own toasts always win the room (a post that can't fit is
--     dropped from the screen, never from History).
--   Each post slides in and fades after ~5 s. The column is re-placed when the screen size, the input
--   type or the chat window changes.
-- Cards never take touches (Active = false). The feed's ScreenGui draws UNDER the other HUD guis
-- (DisplayOrder -1), so a card can never hide a stamp, a banner or a button; it only ever sits behind
-- them. Its frame "Holder" is the PC column, sized to its cards (empty and 0 tall on phones).
-- FeedController.History keeps the last 30 posts for the phone's Feed app.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Heists = require(ReplicatedStorage.Shared.Config.Heists)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local Theme = require(ReplicatedStorage.Shared.Util.Theme)
local NotifyController = require(script.Parent:WaitForChild("NotifyController"))

local player = Players.LocalPlayer

local FeedController = {}

local C = Theme.Color
local GAP = 6 -- pixels between cards
local MAX_CARDS = 3
local LIFETIME = 5
local CARD_ALPHA = 0.25
local SLIDE = 18 -- pixels a card slides in from (and half that on its way out)
local SPLIT = 0.42 -- PC: the column reaches no lower than this share of the screen (the toasts' limit)
local MIN_ROOM = 120 -- PC: less room than this under the chat window, and posts join the toast stack
local CHAT_GAP = 8 -- pixels between the chat window and the column
local IN = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local OUT = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

FeedController.History = {} -- newest last, for the phone Feed app

local gui, holder
local cards = {} -- oldest first: { slot, fade = { [instance] = { prop = hidden value } } }
local room = 200 -- pixels the PC column may fill
local shareStack = false -- posts go into NotifyController's toast stack (phones; PC with no room under chat)
local order = 0

local function display(typeId)
	local def = Heists.Types[typeId]
	return def and def.Display or tostring(typeId)
end

-- The CoastFeed ScreenGui's own size (the box its zone is laid out in), else the camera's view.
local function screenSize()
	local size = gui and gui.AbsoluteSize
	if size and size.X > 0 and size.Y > 0 then
		return size
	end
	local cam = Workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(844, 390)
end

-- 13 px on a 390-tall phone, 15 px on a 1080p monitor.
local function textSize()
	return math.clamp(math.floor(screenSize().Y * 0.032), 13, 15)
end

-- Roblox's chat window (TextChatService), when it's on and reaches over the column's x range x0..x1:
-- the y of its bottom edge in our gui's pixels, else nil. Measured from our gui's corner, because
-- AbsolutePosition starts under the top bar whatever a ScreenGui's IgnoreGuiInset says.
local function chatBottom(x0, x1)
	if not gui or TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return nil
	end
	local okCore, coreOn = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat)
	local cfg = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if (okCore and not coreOn) or not cfg or not cfg.Enabled then
		return nil
	end
	local ok, pos, size = pcall(function()
		return cfg.AbsolutePosition, cfg.AbsoluteSize
	end)
	if not ok or typeof(pos) ~= "Vector2" or typeof(size) ~= "Vector2" or size.X <= 0 or size.Y <= 0 then
		return nil
	end
	local origin = gui.AbsolutePosition
	local left = pos.X - origin.X
	if left >= x1 or left + size.X <= x0 then
		return nil -- moved somewhere else: not in the column's way
	end
	return pos.Y - origin.Y + size.Y
end

-- Fade helpers (as NotifyController's): `fade` maps an instance to its hidden values; cards are built
-- in their shown state.
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

-- The PC column in the Feed zone (pushed under the chat window while chat is on), how far down it may
-- reach, and whether posts go into the toast stack instead.
local function layout()
	if not holder then
		return
	end
	local touch = Theme.IsTouch()
	local z = Theme.Place(holder, "Feed", touch) -- (keeps the holder's own height: it fits its cards)
	local size = screenSize()
	local top = z.Pos.Y.Scale * size.Y + z.Pos.Y.Offset
	if not touch then
		local x0 = z.Pos.X.Scale * size.X + z.Pos.X.Offset
		local chat = chatBottom(x0, x0 + z.Size.X.Offset)
		if chat then
			top = math.max(top, math.ceil(chat) + CHAT_GAP)
			holder.Position = UDim2.new(z.Pos.X.Scale, z.Pos.X.Offset, 0, top)
		end
	end
	room = math.floor(size.Y * SPLIT - top)
	shareStack = touch or room < MIN_ROOM
	room = math.max(room, 60)
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "CoastFeed"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- zone coordinates: y = 0 is the very top of the screen
	-- Under every other HUD gui (they're all 0 or more): stamps, banners and buttons draw on top of
	-- the cards, never the other way round. The phone (5) covers it too.
	gui.DisplayOrder = -1
	gui.Parent = player:WaitForChild("PlayerGui")
	holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.Size = UDim2.fromOffset(320, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y -- as tall as its cards (0 when there are none)
	holder.BackgroundTransparency = 1
	holder.Active = false
	holder.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, GAP)
	list.Parent = holder
	layout()
end

local function removeCard(c)
	local i = table.find(cards, c)
	if i then
		table.remove(cards, i)
	end
	c.slot:Destroy()
end

-- Drop the oldest cards while the column would run past its limit. Always keeps the newest.
local function trim()
	local total = 0
	for i, c in ipairs(cards) do
		total += c.slot.AbsoluteSize.Y + (i > 1 and GAP or 0)
	end
	while #cards > 1 and total > room do
		local oldest = cards[1]
		total -= oldest.slot.AbsoluteSize.Y + GAP
		removeCard(oldest)
	end
end

-- One notification card, built in its shown state: slot (for a list) > Card > avatar, handle, "now",
-- the words. Returns the slot and its fade map (NotifyController.Stack takes the same pair).
local function buildCard(header, body, accent, alert)
	local ts = textSize()
	local av = ts + 12 -- avatar: 25 px on a phone, 27 on a monitor
	local left = 8 + av + 9
	local isDispatch = header == "DISPATCH"

	local slot = Instance.new("Frame")
	slot.Name = "Post"
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
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = card

	-- The avatar: a dark disc with a thin ring in the post's colour and the account's mark.
	local avatar = Instance.new("Frame")
	avatar.Name = "Avatar"
	avatar.Position = UDim2.fromOffset(8, 8)
	avatar.Size = UDim2.fromOffset(av, av)
	avatar.BackgroundColor3 = C.PanelLight
	avatar.BorderSizePixel = 0
	avatar.Active = false
	avatar.Parent = card
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = avatar
	local ring = Instance.new("UIStroke")
	ring.Color = accent
	ring.Thickness = 1.5
	ring.Parent = avatar
	local mark = Instance.new("TextLabel")
	mark.Name = "Mark"
	mark.Size = UDim2.fromScale(1, 1)
	Theme.Text(mark, math.floor(av * 0.55), isDispatch and "Bold" or "Display")
	mark.Text = isDispatch and "★" or "C"
	mark.Active = false
	mark.Parent = avatar

	local handle = Instance.new("TextLabel")
	handle.Name = "Handle"
	handle.Position = UDim2.fromOffset(left, 7)
	handle.Size = UDim2.new(1, -(left + 44), 0, ts + 2)
	Theme.Text(handle, ts, "Bold")
	if alert then
		handle.TextColor3 = C.Danger
	end
	handle.TextXAlignment = Enum.TextXAlignment.Left
	handle.TextTruncate = Enum.TextTruncate.AtEnd
	handle.Text = header
	handle.Active = false
	handle.Parent = card

	local when = Instance.new("TextLabel")
	when.Name = "Time"
	when.AnchorPoint = Vector2.new(1, 0)
	when.Position = UDim2.new(1, -10, 0, 7)
	when.Size = UDim2.fromOffset(34, ts + 2)
	Theme.Text(when, 13, "Body")
	when.TextColor3 = C.Dim
	when.TextXAlignment = Enum.TextXAlignment.Right
	when.Text = "now"
	when.Active = false
	when.Parent = card

	-- The post: one or two lines (cut with "..." past that), starting with a capital.
	local words = Instance.new("TextLabel")
	words.Name = "Text"
	words.Position = UDim2.fromOffset(left, 7 + ts + 4)
	words.Size = UDim2.new(1, -(left + 10), 0, 0)
	words.AutomaticSize = Enum.AutomaticSize.Y
	Theme.Text(words, ts, "Body")
	words.TextWrapped = true
	words.TextTruncate = Enum.TextTruncate.AtEnd
	words.TextXAlignment = Enum.TextXAlignment.Left
	words.TextYAlignment = Enum.TextYAlignment.Top
	words.Text = string.upper(string.sub(body, 1, 1)) .. string.sub(body, 2)
	words.Active = false
	words.Parent = card
	local lines = Instance.new("UISizeConstraint")
	lines.MaxSize = Vector2.new(4000, ts * 2 + 4)
	lines.Parent = words

	local fade = {
		[card] = { BackgroundTransparency = 1 },
		[avatar] = { BackgroundTransparency = 1 },
		[ring] = { Transparency = 1 },
	}
	for _, l in ipairs({ mark, handle, when, words }) do
		fade[l] = { TextTransparency = 1 }
		local shadow = l:FindFirstChild("Shadow")
		if shadow then
			fade[shadow] = { Transparency = 1 }
		end
	end
	return slot, fade
end

-- PC: into our own column in the Feed zone, newest on top.
local function pushOwn(slot, fade)
	if not gui then
		build()
	end
	layout()
	while #cards >= MAX_CARDS do
		removeCard(cards[1])
	end
	order -= 1
	slot.LayoutOrder = order
	local c = { slot = slot, fade = fade }
	table.insert(cards, c)
	fadeIn(fade, IN)
	local card = slot:FindFirstChild("Card")
	local rest = card.Position
	card.Position = rest + UDim2.fromOffset(-SLIDE, 0)
	TweenService:Create(card, IN, { Position = rest }):Play()
	slot.Parent = holder
	-- Wrapped heights are only known after a frame, then make sure the column still fits.
	task.defer(function()
		task.wait()
		if slot.Parent then
			trim()
		end
	end)
	task.delay(LIFETIME, function()
		if not slot.Parent then
			return -- already pushed out by newer posts
		end
		fadeOut(fade, OUT)
		TweenService:Create(card, OUT, { Position = rest + UDim2.fromOffset(-SLIDE / 2, 0) }):Play()
		task.wait(0.45)
		if slot.Parent then
			removeCard(c)
		end
	end)
end

-- header: "@CoastFeed" or "DISPATCH". color: what the post is about (a Theme colour). alert = a police
-- alert (red ring and red handle).
local function post(header, body, color, alert)
	local text = header .. ": " .. body
	table.insert(FeedController.History, { Text = text, Header = header, Body = body, Alert = alert == true, Time = os.time() })
	if #FeedController.History > 30 then
		table.remove(FeedController.History, 1)
	end
	local slot, fade = buildCard(header, body, alert and C.Danger or (color or C.Brand), alert == true)
	if not gui then
		build()
	end
	layout() -- (the chat window may have opened or moved since the last post)
	if shareStack then
		-- Phones (the Feed zone shares the toast stack), or a PC whose chat window leaves no room: a low
		-- card there, so the player's own toasts keep their place.
		NotifyController.Stack(slot, fade, LIFETIME, true)
	else
		pushOwn(slot, fade)
	end
end

-- A text field from the server data, or a stand-in if it's missing.
local function textOr(v, default)
	return type(v) == "string" and v or default
end

-- "$96,000" (HUDController's money format, kept here so the feed needs nothing else).
local function money(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return "$" .. out
end

local HANDLERS = {
	HeistOpen = function(d)
		if player:GetAttribute("Side") == "Civilian" then
			post("@CoastFeed", display(d.Type) .. " just opened for business...", C.Gold)
		end
	end,
	HeistAlarm = function(d)
		if player:GetAttribute("Side") == "Cop" then
			post("DISPATCH", "alarm at " .. display(d.Type) .. "! Respond now.", C.Danger, true)
		else
			post("@CoastFeed", "alarms ringing at " .. display(d.Type) .. "!", C.Danger, true)
		end
	end,
	BankSoon = function()
		post("@CoastFeed", "the Coastal Bank vault unlocks in 60 seconds...", C.Gold)
	end,
	BankOpen = function()
		post("@CoastFeed", "the Coastal Bank vault is OPEN. Crews, go!", C.Gold)
	end,
	Arrest = function(d)
		post("@CoastFeed", textOr(d.Name, "Someone") .. " was just cuffed by " .. textOr(d.Cop, "the police") .. ".", C.Police)
	end,
	Escaped = function(d)
		post("@CoastFeed", textOr(d.Name, "Someone") .. " gave the cops the slip!", C.Brand)
	end,
	-- A big win on the Lucky Wheel downtown (SpinService: the car, or $10,000+).
	WheelWin = function(d)
		post("@CoastFeed", textOr(d.Name, "Someone") .. " just won " .. textOr(d.Prize, "big") .. " on the Lucky Wheel downtown!", C.Gold)
	end,
	-- A robber bot (RobberBotService) broke into a parked car; its alarm is ringing there.
	BotCarjack = function()
		if player:GetAttribute("Side") == "Cop" then
			post("DISPATCH", "car theft reported, alarm ringing! Respond now.", C.Danger, true)
		end
	end,
	TrackerPing = function(d)
		if player:GetAttribute("Side") == "Cop" then
			post("DISPATCH", "stolen " .. textOr(d.Model, "car") .. " tracker is pinging. Check your map!", C.Danger, true)
		end
	end,
	CarDelivered = function(d)
		post("@CoastFeed", "somebody's " .. textOr(d.Model, "car") .. " just vanished at the Docks...", C.Orange)
	end,
	Breakout = function(d)
		post("@CoastFeed", "BREAKOUT at Saltmarsh Prison! " .. textOr(d.Name, "Someone") .. " is on the run.", C.Orange)
	end,
	-- The Big Score (BigScoreService): a crew heist on the Solana Gold Reserve. d.Crew is the crew's names.
	BigScoreStarted = function(d)
		local crew = textOr(d.Crew, "")
		post("@CoastFeed", "word on the street: a crew is planning The Big Score" .. (crew ~= "" and (" (" .. crew .. ")") or "") .. "...",
			C.Gold)
	end,
	BigScoreAlarm = function()
		if player:GetAttribute("Side") == "Cop" then
			post("DISPATCH", "vault alarm at the Solana Gold Reserve, Palm Hills! All units respond.", C.Danger, true)
		else
			post("@CoastFeed", "alarms ringing at the Solana Gold Reserve! Somebody's drilling the vault...", C.Danger, true)
		end
	end,
	BigScoreDone = function(d)
		post("@CoastFeed", textOr(d.Crew, "A crew") .. " pulled off The Big Score: " .. money(d.Total) .. " in gold!", C.Gold)
	end,
	-- Florida moments (EventService)
	Event = function(d)
		if type(d.Text) == "string" then
			post("@CoastFeed", d.Text, C.Purple)
		end
	end,
	EventDone = function(d)
		if type(d.Text) == "string" then
			post("@CoastFeed", textOr(d.Name, "Someone") .. " " .. d.Text .. "!", C.Purple)
		end
	end,
}

function FeedController.Init()
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
	-- ...and when Roblox's chat window opens, moves or resizes (it may cover the column).
	local chatCfg = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if chatCfg then
		for _, prop in ipairs({ "Enabled", "AbsoluteSize", "AbsolutePosition" }) do
			pcall(function()
				chatCfg:GetPropertyChangedSignal(prop):Connect(relayout)
			end)
		end
	end

	Remotes.OnClient("Feed", function(kind, data)
		local h = HANDLERS[kind]
		if h then
			h(type(data) == "table" and data or {})
		end
	end)
end

return FeedController
