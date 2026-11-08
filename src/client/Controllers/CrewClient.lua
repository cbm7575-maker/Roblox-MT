-- CrewClient (ModuleScript, StarterPlayerScripts.Controllers.CrewClient)
-- Crew invites, crewmate name tags and the friend-bonus toast, in the flat "street" look (Theme). The
-- phone's CREW app sends invites; the minimap draws crewmates (MinimapClient).
--   * Invite (CrewInvite from CrewService, which sends it at any time): frame "CrewInvite" in ScreenGui
--     "Crew", a flat dark card in the upper middle: centred on the Stamp zone, between the left column
--     and the Status column, always UNDER the Banner zone (the mission timer and QUIT, the escape
--     countdown and the prison timer live there; it never covers them) and above the Subtitle zone
--     (phones: the Action zone), so never over the car cluster or GET IN either. A thin brand-pink
--     accent, a small gold CREW INVITE tag, "<name> wants you in their crew", JOIN ("Accept", the
--     primary button) and NO THANKS ("Decline"). PC: two rows, the buttons under the words. Phones: one
--     60 px row (it fits between the Banner and Action zones on a 375 px-tall phone), the words on the
--     left, Theme.Touch-tall buttons on the right; where the band between the columns is too narrow
--     (667 px-wide phones) it keeps to the right and covers the minimap's right part.
--     It goes after 60 s, steps aside while a HUDController stamp shows (same spot) and on the title
--     screen, and is re-placed when the screen size or input type changes. OfferClient's pass card
--     waits while it's up.
--   * Name tags over crewmates' heads (BillboardGui "CrewTag", through walls, local only): the name in
--     small white Body text with a soft shadow and a thin pink bar under it (crew = the brand accent).
--     Hidden on the first-join title screen (local attribute TitleScreen, set by TeamUI).
--   * The crew job (remote "CrewJob" from CrewService, MissionService and BigScoreService): a gold CREW UP!
--     stamp when you form or join a crew (NEW CREW JOB over it, the job and how to unlock it under it), a
--     BIG SCORE UNLOCKED stamp once every crew prep is done, and toasts for the rest (your saved crew is
--     back, a prep done, preps reset after a score, a crewmate left, the crew broke up, and why a prep or
--     the Big Score can't start: JOB_TOASTS).
--   * The invite card says when joining means leaving the crew you're in (Switch).
--   * The heist plan (frame "HeistPlan"): while you're in a crew whose heist isn't paused (CrewService's
--     CrewPreps / CrewPaused), in free roam, not wanted and not busy (a mission or prep, the Big Score, a
--     race, a job shift), the crew heist's steps are on screen: the preps, then THE BIG SCORE itself, done
--     ones ticked, the next one boxed in gold. START plays the next step (RequestCrew "Prep", or
--     RequestBigScore "Start" once every prep is done); PAUSE HEIST puts the crew's heist on hold
--     (RequestCrew "Pause": it leaves every crewmate's screen, progress kept) until RESUME HEIST in the
--     phone's CREW app. PC: a panel at the left edge, half way down (the Big Score's own checklist uses
--     that spot during the job, when this one is hidden), stepping aside while a toast or Coast Feed post
--     reaches over it. Phones: one 60 px row in the invite card's band ("THE BIG SCORE 1/4", "Next: ...",
--     START, PAUSE HEIST). Either steps aside for a stamp, the crew invite, a ride card, a pass offer
--     and the open phone.
--   * The crew tip (for players with no crew). It uses the invite card's spot and its frame name
--     "CrewInvite", with attribute Kind = "Tip", so every HUD piece that keeps clear of the invite keeps
--     clear of it too.
--     - What it says: "MAKE WAY MORE MONEY". A crew earns The Big Score's $48,000+ each, and anyone in this
--       server can be a crewmate.
--     - Buttons: FIND A CREW opens PHONE > CREW (PLAYERS HERE has an INVITE button by every name); LATER.
--     - When it comes up (Util/CrewTip): a few minutes into the session, after a solo payout of $1,000 or
--       more, and when The Big Score refuses for want of a crew. At most a few times a session, and only in
--       free roam, past the tutorial, not busy, with another free-roam player in the server.
--     - It goes after TIP_FOR seconds, when you join a crew, or when an invite arrives (the invite takes
--       the spot).
--   * Crew calls (CrewService: PHONE > CREW > INVITE EVERYONE HERE). Remote CrewCall: a chat line for everyone,
--     "[CREW CALL] <name> wants to start a heist!", and for a free-roam player with no crew (Eligible) a card in
--     the invite card's spot (Kind = "Call", attribute From = the caller's UserId): CREW CALL, "<name> wants to
--     start a heist!", I'M IN (RequestCrew "CallJoin", their UserId) and NO THANKS. It never replaces a crew
--     invite that's waiting. CrewCallClosed { FromUserId } takes that caller's card away (their crew is full, the
--     call ran out or they left). The caller hears who answered (CrewJob "CallJoined" { Name }).
--   * Meeting up (CrewService: joining from a card or a crew call brings you to the one who asked): remote
--     CrewMeet { Name } fades the screen to black with "MEETING <NAME>" while you're moved, { Done } fades it
--     back (never left black past MEET_SAFETY s). The toasts that go with it (MeetLater, MeetRide, MeetHere,
--     MetUp) and the hands-on prep steps' (Grabbed, Dropped, Stashed, PairWait, ...) are namedToast's.
--   * Prep things in the world (CrewTasks' prompts, attribute CrewId): only your own crew's show on this device.
--   CrewClient.Crewmates() -> the other players in your crew

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local Theme = require(ReplicatedStorage.Shared.Util.Theme)
local Heists = require(ReplicatedStorage.Shared.Config.Heists)
local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local CrewTip = require(ReplicatedStorage.Shared.Util.CrewTip)
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local NotifyController = require(script.Parent:WaitForChild("NotifyController"))

local player = Players.LocalPlayer

local CrewClient = {}

local C = Theme.Color

local CARD_W = 320 -- PC: two rows
local CARD_W_TOUCH, MIN_W_TOUCH = 380, 330 -- phones: one row (it narrows to MIN_W_TOUCH before covering the minimap)
-- Per card kind: the phone button widths (yes, no) and the PC card's lines of words.
local CARD_KINDS = {
	Invite = { yes = 64, no = 92, lines = 2 }, -- JOIN, NO THANKS
	Tip = { yes = 104, no = 72, lines = 3 }, -- FIND A CREW, LATER
	Call = { yes = 72, no = 92, lines = 2 }, -- I'M IN, NO THANKS
}
local TIP_FOR = 20 -- seconds before the crew tip goes
local TIP_CHECK_EVERY = 1 -- seconds between checks for whether the crew tip is due
local GAP = 8 -- pixels kept from the zones beside the card
local GAP_Y = 4 -- ...and above / below it
local EDGE = 12
local INVITE_FOR = 60 -- seconds before an unanswered invite goes
local TAGS_EVERY = 1 -- seconds between name tag checks
local CHECK_EVERY = 0.2 -- seconds between checks for a stamp over the card

local gui, card
local cardKind = "Invite" -- what the card is: "Invite" or "Tip" (CARD_KINDS)
local cardWords -- { pc = words, touch = words } on the card (fitCard picks one for the screen)
local tags = {} -- [player] = BillboardGui
local tip = CrewTip.new(os.clock()) -- when the crew tip may come up (Util/CrewTip)

local JOB_NAME = (Missions.CrewJob and Missions.CrewJob.Name) or "The Big Score"

-- The heist plan's sizes (pixels) and what it shows.
local PLAN = {
	PREPS = (Missions.CrewJob and Missions.CrewJob.Preps) or {},
	X = 20, -- PC: from the left edge
	W = 260, -- PC panel width
	PAD = 10,
	HEAD_H = 22,
	SUB_H = 16,
	ROW_H = 22,
	BUTTON_H = 30,
	TOUCH_W = 420, -- phones: one row, narrowing to TOUCH_MIN_W before it covers the minimap
	TOUCH_MIN_W = 330,
	START_W = 70,
	PAUSE_W = 96,
	PAUSE_HIDE = 4, -- seconds the plan stays hidden after PAUSE HEIST while the server answers
	-- Card stacks that can reach the PC panel (paths under PlayerGui): every card showing counts.
	CARD_STACKS = { { "Toasts", "Holder" }, { "CoastFeed", "Holder" } },
}
-- What a full van pays each member: a crew of 2, and the most (a full crew of 4): bigger crews earn more.
PLAN.CUT = Heists.BigScoreCut(2)
PLAN.CUT_MAX = Heists.BigScoreCut((Heists.BigScore and Heists.BigScore.CrewMax) or 4)
PLAN.CUT_SHORT = "$" .. math.floor(PLAN.CUT / 1000) .. "K+ each"
local plan = {} -- frame, title, sub, rows = { { row, ring, tick, dot, label } }, start, pause, touch, pausedAt

-- CrewJob "Toast" keys in words (%d %d = Done, Total) and the toast's style.
local JOB_TOASTS = {
	NoCrew = { "Crew up first: give someone a ride, or invite them from PHONE > CREW.", "crew" },
	AllDone = { "Every crew prep is done: start The Big Score from PHONE > CREW.", "crew" },
	PrepDone = { "Your crew already did that prep.", "info" },
	PrepRunning = { "Your crew is already on a prep.", "info" },
	CivOnly = { "Crew preps are for free-roam players.", "info" },
	WantedStart = { "Lose the cops first, then start the prep.", "warning" },
	Busy = { "Finish what you're doing first.", "info" },
	NeedMate = { "A crew prep needs a crewmate here and free to do it with you.", "warning" },
	Together = { "Stick together: it counts once your crew is there with you.", "crew" },
	Wanted = { "Lose the cops: it doesn't count while you're wanted.", "warning" },
	NeedPreps = { "Do your crew preps first: %d of %d done (PHONE > CREW).", "warning" },
	PairSync = { "Too far apart in time: hold both at once, one of you on each.", "warning" },
	PairTwo = { "It takes two: your crewmate holds the other one at the same time.", "warning" },
	NothingToStash = { "You're not carrying anything: grab it first, or your crewmate puts theirs in.", "info" },
	NotYourJob = { "That's another crew's job.", "info" },
}

-- The hands-on crew steps and the meet-up (MissionService / CrewService toasts with names in them): the words,
-- the colour and the style, or nil for a key that isn't one of these.
local function namedToast(info)
	local key = info.Key
	local me = info.Name ~= nil and info.Name == player.DisplayName
	local who = tostring(info.Name or "Your crewmate")
	local item = tostring(info.Item or "it")
	local done, total = tonumber(info.Done) or 0, tonumber(info.Total) or 0
	local count = total > 1 and string.format(" (%d/%d)", done, total) or ""
	if key == "Grabbed" then
		return (me and ("Got the " .. item .. "!") or (who .. " grabbed the " .. item .. "!")) .. count, C.Gold, "crew"
	elseif key == "Dropped" then
		return (me and "You" or who) .. " dropped the " .. item .. ": grab it again (gold marker).", nil, "warning"
	elseif key == "Stashed" then
		return (me and "In it goes!" or (who .. " put it in!")) .. count, C.Cash, "crew"
	elseif key == "PairWait" then
		local action, other = string.upper(tostring(info.Action or "")), string.upper(tostring(info.Other or ""))
		return me and ("Now your crewmate holds " .. other .. ", quick!")
			or (who .. " did " .. action .. ": you hold " .. other .. " now, quick!"), C.Gold, "crew"
	elseif key == "MeetLater" then
		return "You're in " .. who .. "'s crew! Meet up: their pink tag is on your minimap.", C.Gold, "crew"
	elseif key == "MeetRide" then
		return "You're riding with " .. who .. ": your crew job starts now!", C.Gold, "crew"
	elseif key == "MeetHere" then
		return "You're with " .. who .. ": get in a car together!", C.Gold, "crew"
	elseif key == "MetUp" then
		return who .. (info.Ride and " is in your car: drive, the crew job is on your GPS!" or " is here with you!"), C.Gold, "crew"
	end
	return nil
end

-- The meet-up's fade (CrewService: the joiner is brought to the crewmate who asked): black for a moment with
-- "MEETING <NAME>", then back. Never left black (MEET_SAFETY).
local MEET_SAFETY = 3
local meet = {} -- gui, curtain, label, token
local function meetFade(info)
	if type(info) ~= "table" then
		return
	end
	if not meet.gui then
		local sg = Instance.new("ScreenGui")
		sg.Name = "CrewMeet"
		sg.ResetOnSpawn = false
		sg.IgnoreGuiInset = true
		sg.DisplayOrder = 60
		sg.Parent = player:WaitForChild("PlayerGui")
		local curtain = Instance.new("Frame")
		curtain.Name = "Curtain"
		curtain.Size = UDim2.fromScale(1, 1)
		curtain.BackgroundColor3 = Color3.new(0, 0, 0)
		curtain.BackgroundTransparency = 1
		curtain.BorderSizePixel = 0
		curtain.Visible = false
		curtain.Parent = sg
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		Theme.Text(label, 28, "Display")
		label.TextColor3 = C.Gold
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.new(1, -40, 0, 40)
		label.TextTransparency = 1
		label.Parent = curtain
		meet.gui, meet.curtain, meet.label = sg, curtain, label
	end
	meet.token = (meet.token or 0) + 1
	local token = meet.token
	local TweenService = game:GetService("TweenService")
	local function fade(black, seconds)
		meet.curtain.Visible = true
		TweenService:Create(meet.curtain, TweenInfo.new(seconds), { BackgroundTransparency = black and 0 or 1 }):Play()
		TweenService:Create(meet.label, TweenInfo.new(seconds), { TextTransparency = black and 0 or 1 }):Play()
		if not black then
			task.delay(seconds, function()
				if meet.token == token then
					meet.curtain.Visible = false
				end
			end)
		end
	end
	if info.Done then
		fade(false, 0.5)
		return
	end
	meet.label.Text = "MEETING " .. string.upper(tostring(info.Name or "YOUR CREW"))
	fade(true, 0.3)
	task.delay(MEET_SAFETY, function()
		if meet.token == token then
			fade(false, 0.5)
		end
	end)
end

-- Other crews' prompts on their prep things (CrewTasks: attribute CrewId) don't show here; ours do.
local function gateTaskPrompt(pr)
	if pr:IsA("ProximityPrompt") and pr.Name == "CrewTaskPrompt" then
		local mine = player:GetAttribute("Crew")
		local want = mine ~= nil and pr:GetAttribute("CrewId") == mine
		if pr.Enabled ~= want then
			pr.Enabled = want
		end
	end
end

local function watchTaskPrompts()
	local function hook(folder)
		for _, d in ipairs(folder:GetDescendants()) do
			gateTaskPrompt(d)
		end
		folder.DescendantAdded:Connect(gateTaskPrompt)
	end
	local Workspace = game:GetService("Workspace")
	local existing = Workspace:FindFirstChild("CrewTasks")
	if existing then
		hook(existing)
	end
	Workspace.ChildAdded:Connect(function(c)
		if c.Name == "CrewTasks" and c:IsA("Folder") then
			hook(c)
		end
	end)
	player:GetAttributeChangedSignal("Crew"):Connect(function()
		local folder = Workspace:FindFirstChild("CrewTasks")
		for _, d in ipairs(folder and folder:GetDescendants() or {}) do
			gateTaskPrompt(d)
		end
	end)
end

function CrewClient.Crewmates()
	local list = {}
	local crew = player:GetAttribute("Crew")
	if not crew then
		return list
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p:GetAttribute("Crew") == crew then
			table.insert(list, p)
		end
	end
	return list
end

local function tagFor(p)
	local head = p.Character and p.Character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local tag = tags[p]
	if tag and tag.Parent == head then
		return tag
	end
	if tag then
		tag:Destroy()
	end
	tag = Instance.new("BillboardGui")
	tag.Name = "CrewTag"
	tag.Size = UDim2.fromOffset(160, 24)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 1500
	tag.LightInfluence = 0
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	Theme.Text(name, 14, "Body")
	name.Size = UDim2.new(1, 0, 0, 18)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = p.DisplayName
	name.Parent = tag
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, 20)
	bar.Size = UDim2.fromOffset(24, 2)
	bar.BackgroundColor3 = C.Brand
	bar.BorderSizePixel = 0
	bar.Parent = tag
	tag.Adornee = head
	tag.Parent = head -- a local instance: only this player sees it
	tags[p] = tag
	return tag
end

local function refreshTags()
	local title = player:GetAttribute("TitleScreen") == true
	local mates = {}
	for _, p in ipairs(CrewClient.Crewmates()) do
		mates[p] = true
		local tag = tagFor(p)
		if tag then
			tag.Enabled = not title
		end
	end
	for p, tag in pairs(tags) do
		if not mates[p] then
			tag:Destroy()
			tags[p] = nil
		end
	end
end

-- A zone's box on this screen: x, y, width, height (pixels).
local function zoneBox(name, touch, screen)
	local z = Theme.Zone(name, touch)
	local w = z.Size.X.Scale * screen.X + z.Size.X.Offset
	local h = z.Size.Y.Scale * screen.Y + z.Size.Y.Offset
	return z.Pos.X.Scale * screen.X + z.Pos.X.Offset - z.Anchor.X * w, z.Pos.Y.Scale * screen.Y + z.Pos.Y.Offset - z.Anchor.Y * h, w, h
end

-- Size and place the card for this screen (see the header; OfferClient's card uses the same band).
local function fitCard()
	if not card then
		return
	end
	local screen = gui.AbsoluteSize
	if screen.X < 1 then
		return
	end
	local touch = Theme.IsTouch()
	local kind = CARD_KINDS[cardKind] or CARD_KINDS.Invite
	local pad = touch and 8 or 10
	local buttonH = touch and Theme.Touch or 32
	local wordsH = 18 * kind.lines -- PC: the words' height (two lines for an invite, three for the tip)
	local h = touch and (pad + buttonH + pad) or (pad + 18 + wordsH + 6 + buttonH + pad) -- 60 on phones; 112 / 130 on a PC
	-- Across: right of the left column (feed; minimap on phones), left of the Status column.
	local lx, _, lw = zoneBox(touch and "Minimap" or "Feed", touch, screen)
	local left = lx + lw + GAP
	local right = zoneBox("Status", touch, screen) - GAP
	local least = touch and MIN_W_TOUCH or CARD_W
	local band = right - left
	if band < least then
		left = EDGE -- too tight (small phones): cover the minimap rather than squash the words
	end
	local w = math.min(touch and CARD_W_TOUCH or CARD_W, math.max(least, band), screen.X - 2 * EDGE)
	local x = math.clamp(screen.X / 2, left + w / 2, math.max(left + w / 2, right - w / 2))
	-- Down: centred on the Stamp zone, but under the Banner zone (which sits under the Goal zone) and
	-- above the Subtitle zone (phones: the Action zone).
	local _, sy, _, sh = zoneBox("Stamp", touch, screen)
	local _, by, _, bh = zoneBox("Banner", touch, screen)
	local _, ly = zoneBox(touch and "Action" or "Subtitle", touch, screen)
	local minTop = by + bh + GAP_Y
	local y = math.clamp(sy + sh / 2 - h / 2, minTop, math.max(minTop, ly - GAP_Y - h))
	card.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
	card.Size = UDim2.fromOffset(w, h)
	local tagLabel, line = card:FindFirstChild("Tag"), card:FindFirstChild("Line")
	local accept, decline = card:FindFirstChild("Accept"), card:FindFirstChild("Decline")
	if cardWords then
		line.Text = touch and cardWords.touch or cardWords.pc
	end
	-- Phones: the words shrink a little where the card is narrow (330 px on a 667 px-wide phone) rather
	-- than being cut off; never past 9 or over 13.
	line.TextScaled = touch
	local fit = line:FindFirstChildOfClass("UITextSizeConstraint")
	if touch and not fit then
		fit = Instance.new("UITextSizeConstraint")
		fit.MinTextSize = 9
		fit.MaxTextSize = 13
		fit.Parent = line
	end
	if touch then
		-- One row: [CREW INVITE / <name> wants you in their crew] .... [JOIN] [NO THANKS]
		local reserved = 14 + 10 + kind.yes + 6 + kind.no + 8 -- the words' left inset, a gap, the two buttons
		tagLabel.TextSize = 13
		tagLabel.Position = UDim2.fromOffset(14, 6)
		tagLabel.Size = UDim2.new(1, -reserved, 0, 14)
		line.TextSize = 13
		line.Position = UDim2.fromOffset(14, 22)
		line.Size = UDim2.new(1, -reserved, 0, 32) -- two lines
		decline.AnchorPoint = Vector2.new(1, 0.5)
		decline.Position = UDim2.new(1, -8, 0.5, 0)
		decline.Size = UDim2.fromOffset(kind.no, buttonH)
		accept.AnchorPoint = Vector2.new(1, 0.5)
		accept.Position = UDim2.new(1, -(8 + kind.no + 6), 0.5, 0)
		accept.Size = UDim2.fromOffset(kind.yes, buttonH)
	else
		-- Two rows: the tag and the words, then the two buttons side by side.
		tagLabel.TextSize = 14
		tagLabel.Position = UDim2.fromOffset(16, pad)
		tagLabel.Size = UDim2.new(1, -32, 0, 16)
		line.TextSize = 15
		line.Position = UDim2.fromOffset(16, pad + 18)
		line.Size = UDim2.new(1, -32, 0, wordsH)
		for _, b in ipairs({ accept, decline }) do
			b.AnchorPoint = Vector2.new(0, 1)
			b.Size = UDim2.new(0.5, -(16 + 4), 0, buttonH)
			b.Position = UDim2.new(b == accept and 0 or 0.5, b == accept and 16 or 4, 1, -pad)
		end
	end
end

-- The card shows unless a stamp uses its spot or the title screen is up (it keeps its 60 s meanwhile).
local function cardWanted()
	local stamped = HUDController.StampTop ~= nil and HUDController.StampTop() ~= nil
	return not stamped and player:GetAttribute("TitleScreen") ~= true
end

local function button(parent, name, text, kind, onClick)
	local b = Instance.new("TextButton")
	b.Name = name
	Theme.Button(b, kind)
	if kind == "Quiet" then
		b.BackgroundColor3 = C.PanelLight
		b.BackgroundTransparency = 0.15
	end
	b.TextSize = 14
	b.Text = text
	b.Parent = parent
	b.Activated:Connect(onClick)
	return b
end

-- Put up the card (see the header), in place of any card already up. o = { kind = "Invite" | "Tip",
-- tag, tagColor, words = { pc, touch }, yes, no (button words), onYes, onNo, seconds (before it goes) }.
local function openCard(o)
	if card then
		card:Destroy()
	end
	cardKind, cardWords = o.kind, o.words
	card = Instance.new("Frame")
	card.Name = "CrewInvite" -- (the crew tip too: the HUD pieces that keep clear of this spot look for this name)
	card:SetAttribute("Kind", o.kind)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Active = true -- taps on the card don't reach the world behind it
	Theme.Panel(card, 0.2)
	card.Parent = gui
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Position = UDim2.fromOffset(0, 8)
	accent.Size = UDim2.new(0, 2, 1, -16)
	accent.BackgroundColor3 = C.Brand
	accent.BorderSizePixel = 0
	accent.Parent = card
	local tag = Instance.new("TextLabel")
	tag.Name = "Tag"
	Theme.Text(tag, 14, "Display")
	tag.TextColor3 = o.tagColor or C.Gold
	tag.TextXAlignment = Enum.TextXAlignment.Left
	tag.Size = UDim2.new(1, -32, 0, 16)
	tag.Text = o.tag
	tag.Parent = card
	local line = Instance.new("TextLabel")
	line.Name = "Line"
	Theme.Text(line, 15, "Body")
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top -- right under the tag, however many lines
	line.TextWrapped = true
	line.TextTruncate = Enum.TextTruncate.AtEnd
	line.Size = UDim2.new(1, -32, 0, 36)
	line.Text = o.words.pc
	line.Parent = card
	local mine = card
	local function close()
		if card == mine then
			card:Destroy()
			card = nil
		end
	end
	button(card, "Accept", o.yes, "Primary", function()
		close()
		o.onYes()
	end)
	button(card, "Decline", o.no, "Quiet", function()
		close()
		o.onNo()
	end)
	fitCard()
	card.Visible = cardWanted()
	task.delay(o.seconds, close)
end

local function showInvite(info)
	if type(info) ~= "table" then
		return
	end
	local words = tostring(info.FromName) .. " wants you in their crew" .. (info.Switch and " (you'd leave yours)" or "")
	openCard({
		kind = "Invite", tag = "CREW INVITE", words = { pc = words, touch = words },
		yes = "JOIN", no = "NO THANKS", seconds = INVITE_FOR,
		onYes = function()
			Remotes.Event("RequestCrew"):FireServer("Accept")
		end,
		onNo = function()
			Remotes.Event("RequestCrew"):FireServer("Decline")
		end,
	})
end

------------------------------------------------------------------ crew calls (see the header)

-- A line in Roblox's chat window, from the game (rich text; names escaped).
local function escapeRich(text)
	return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end
local function chatLine(text)
	pcall(function()
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage(text)
		end
	end)
end

local function showCall(info)
	if type(info) ~= "table" or type(info.FromUserId) ~= "number" then
		return
	end
	local name = tostring(info.FromName or "Someone")
	local size = tonumber(info.Size) or 1
	local whose = size > 1 and (name .. "'s crew (" .. size .. "/4)") or name
	chatLine('<font color="#F0C850"><b>[CREW CALL]</b></font> ' .. escapeRich(whose) .. " wants to start a heist!"
		.. (info.Eligible and " Tap I'M IN to join their crew." or ""))
	if not info.Eligible or (card and cardKind == "Invite") then
		return -- (a crew invite that's waiting keeps its card)
	end
	openCard({
		kind = "Call", tag = "CREW CALL", tagColor = C.Gold,
		words = {
			pc = whose .. " wants to start a heist! Join their crew: " .. JOB_NAME .. " pays " .. HUDController.Money(PLAN.CUT) .. "+ each.",
			touch = whose .. " wants to start a heist: join their crew!",
		},
		yes = "I'M IN", no = "NO THANKS", seconds = math.clamp(tonumber(info.Seconds) or 60, 5, 120),
		onYes = function()
			Remotes.Event("RequestCrew"):FireServer("CallJoin", info.FromUserId)
		end,
		onNo = function() end,
	})
	if card then
		card:SetAttribute("From", info.FromUserId)
	end
end

local function closeCallCard(info)
	if card and cardKind == "Call" and type(info) == "table" and card:GetAttribute("From") == info.FromUserId then
		card:Destroy()
		card = nil
	end
end

------------------------------------------------------------------ the heist plan

-- The crew heist's steps (the preps, then the Big Score itself) as of the attributes CrewService sets:
-- a list of { id, name, done, running, finale }, the index of the next step, and how many preps are done.
local function planSteps()
	local list = player:GetAttribute("CrewPreps")
	local running = player:GetAttribute("CrewPrepRun")
	local steps, nextIndex, done = {}, nil, 0
	for i, id in ipairs(PLAN.PREPS) do
		local m = Missions.ById[id]
		local isDone = type(list) == "string" and string.find(list, "," .. id .. ",", 1, true) ~= nil
		steps[i] = { id = id, name = m and m.Name or id, done = isDone, running = running == id }
		if isDone then
			done += 1
		elseif not nextIndex then
			nextIndex = i
		end
	end
	table.insert(steps, { id = "BigScore", name = JOB_NAME, finale = true, done = false })
	return steps, nextIndex or #steps, done
end

local function planText(parent, name, size, kind)
	local l = Instance.new("TextLabel")
	l.Name = name
	Theme.Text(l, size, kind)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.RichText = true
	l.Parent = parent
	return l
end

local function planStroke(parent, x, y, length, angle)
	local f = Instance.new("Frame")
	f.Name = "Stroke"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(length, 2)
	f.Rotation = angle
	f.BackgroundColor3 = C.Cash
	f.BorderSizePixel = 0
	f.Parent = parent
end

-- "$96,000"
local function cash(n)
	local digits = tostring(math.floor(n))
	local out = string.reverse((string.gsub(string.reverse(digits), "(%d%d%d)", "%1,")))
	if string.sub(out, 1, 1) == "," then
		out = string.sub(out, 2)
	end
	return "$" .. out
end

-- START: the next prep for the crew, or the Big Score itself once they're all done (the servers check it
-- all again and say why not). PAUSE HEIST: the crew's heist goes on hold (the plan hides at once).
local function planStart()
	local steps, n = planSteps()
	local step = steps[n]
	if step.running then
		return
	end
	if step.finale then
		Remotes.Event("RequestBigScore"):FireServer("Start")
	else
		Remotes.Event("RequestCrew"):FireServer("Prep", step.id)
	end
end

local function planPause()
	plan.pausedAt = os.clock()
	plan.frame.Visible = false
	Remotes.Event("RequestCrew"):FireServer("Pause", true)
end

local function buildPlan()
	local f = Instance.new("Frame")
	f.Name = "HeistPlan"
	f.Active = true -- taps on it don't reach the world behind it
	f.Visible = false
	Theme.Panel(f, 0.2)
	f.Parent = gui
	plan.frame = f
	local accent = Instance.new("Frame")
	accent.Name = "Accent"
	accent.Position = UDim2.fromOffset(0, 8)
	accent.Size = UDim2.new(0, 2, 1, -16)
	accent.BackgroundColor3 = C.Gold
	accent.BorderSizePixel = 0
	accent.Parent = f
	plan.title = planText(f, "Title", 16, "Display")
	plan.sub = planText(f, "Sub", 12, "Body")
	plan.sub.TextColor3 = C.Dim
	plan.rows = {}
	for i = 1, #PLAN.PREPS + 1 do
		local row = Instance.new("Frame")
		row.Name = "Step" .. i
		row.BackgroundTransparency = 1
		row.Parent = f
		-- The box: a thin ring; a green tick once the step is done, a small gold square in it for the next one.
		local box = Instance.new("Frame")
		box.Name = "Box"
		box.AnchorPoint = Vector2.new(0, 0.5)
		box.Position = UDim2.fromScale(0, 0.5)
		box.Size = UDim2.fromOffset(14, 14)
		box.BackgroundTransparency = 1
		box.BorderSizePixel = 0
		box.Parent = row
		Theme.Corners(box, 3)
		local ring = Instance.new("UIStroke")
		ring.Thickness = 1.5
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Color = C.Dim
		ring.Parent = box
		local tick = Instance.new("Frame")
		tick.Name = "Tick"
		tick.BackgroundTransparency = 1
		tick.Size = UDim2.fromScale(1, 1)
		tick.Visible = false
		tick.Parent = box
		planStroke(tick, 4, 9, 5.5, 45) -- (the fonts have no tick glyph: two strokes)
		planStroke(tick, 8.5, 7, 10.5, -49)
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.Size = UDim2.fromOffset(6, 6)
		dot.BackgroundColor3 = C.Gold
		dot.BorderSizePixel = 0
		dot.Visible = false
		dot.Parent = box
		local label = planText(row, "Text", 13, "Body")
		label.Position = UDim2.fromOffset(22, 0)
		label.Size = UDim2.new(1, -22, 1, 0)
		plan.rows[i] = { row = row, ring = ring, tick = tick, dot = dot, label = label }
	end
	plan.start = button(f, "Start", "START", "Primary", planStart)
	plan.pause = button(f, "Pause", "PAUSE HEIST", "Quiet", planPause)
end

-- The words and boxes for the steps as they stand (only when something changed).
local function drawPlan()
	if not plan.frame then
		return
	end
	local steps, n, done = planSteps()
	local nextStep = steps[n]
	local total = #steps
	local rankNeed = (Heists.BigScore and Heists.BigScore.MinRank) or 3
	local lowRank = (player:GetAttribute("CivRank") or 1) < rankNeed
	if plan.touch then
		local size = plan.title.TextSize + 2
		plan.title.Text = string.format('<font face="Oswald" weight="bold" size="%d" color="#%s">%s</font>  %s', size,
			C.Gold:ToHex(), string.upper(JOB_NAME), done .. "/" .. total)
		local words = nextStep.running and ("Crew on it: " .. nextStep.name)
			or nextStep.finale and ("Ready: hit the Gold Reserve" .. (lowRank and (" at rank " .. rankNeed) or "!"))
			or ("Next: " .. nextStep.name)
		plan.sub.Text = words .. "  ·  " .. PLAN.CUT_SHORT
	else
		plan.title.Text = string.upper(JOB_NAME)
		plan.title.TextColor3 = C.Gold
		plan.sub.Text = "The Gold Reserve: " .. cash(PLAN.CUT) .. "-" .. cash(PLAN.CUT_MAX) .. " each"
		for i, step in ipairs(steps) do
			local r = plan.rows[i]
			local here = i == n
			r.tick.Visible = step.done
			r.dot.Visible = here
			r.ring.Color = here and C.Gold or (step.done and C.Cash or C.Dim)
			r.ring.Transparency = here and 0 or 0.45
			local words = step.name
			if step.running then
				words ..= "  (your crew is on it)"
			elseif step.finale and not here then
				words ..= "  (after the preps)"
			elseif step.finale and lowRank then
				words ..= "  (rank " .. rankNeed .. ")"
			end
			r.label.Text = words
			r.label.FontFace = here and Theme.Font.Bold or Theme.Font.Body
			r.label.TextColor3 = here and C.Text or C.Dim
			r.label.TextTransparency = step.done and 0.35 or 0
		end
	end
	plan.start.Text = nextStep.running and "ON IT" or (nextStep.finale and not plan.touch and "START HEIST" or "START")
	plan.start.AutoButtonColor = not nextStep.running
	plan.start.BackgroundTransparency = nextStep.running and 0.5 or 0
end

-- Size and place the plan for this screen (see the header).
local function placePlan()
	local f = plan.frame
	local screen = gui.AbsoluteSize
	if not f or screen.X < 1 then
		return
	end
	local touch = Theme.IsTouch()
	plan.touch = touch
	local pad = PLAN.PAD
	if touch then
		-- One row in the invite card's band: [THE BIG SCORE 1/4 / Next: Gear Up ...] [START] [PAUSE HEIST]
		local buttonH = Theme.Touch
		local h = 8 + buttonH + 8
		local lx, _, lw = zoneBox("Minimap", true, screen)
		local left = lx + lw + GAP
		local right = zoneBox("Status", true, screen) - GAP
		if right - left < PLAN.TOUCH_MIN_W then
			left = EDGE
		end
		local w = math.min(PLAN.TOUCH_W, math.max(PLAN.TOUCH_MIN_W, right - left), screen.X - 2 * EDGE)
		local x = math.clamp(screen.X / 2, left + w / 2, math.max(left + w / 2, right - w / 2))
		local _, sy, _, sh = zoneBox("Stamp", true, screen)
		local _, by, _, bh = zoneBox("Banner", true, screen)
		local _, ly = zoneBox("Action", true, screen)
		local minTop = by + bh + GAP_Y
		local y = math.clamp(sy + sh / 2 - h / 2, minTop, math.max(minTop, ly - GAP_Y - h))
		f.AnchorPoint = Vector2.new(0.5, 0)
		f.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
		f.Size = UDim2.fromOffset(w, h)
		local reserved = 14 + 10 + PLAN.START_W + 6 + PLAN.PAUSE_W + 8
		plan.title.TextSize = 13
		plan.title.Position = UDim2.fromOffset(14, 8)
		plan.title.Size = UDim2.new(1, -reserved, 0, 18)
		plan.sub.TextSize = 12
		plan.sub.Position = UDim2.fromOffset(14, 30)
		plan.sub.Size = UDim2.new(1, -reserved, 0, 16)
		for _, r in ipairs(plan.rows) do
			r.row.Visible = false
		end
		plan.pause.AnchorPoint = Vector2.new(1, 0.5)
		plan.pause.Position = UDim2.new(1, -8, 0.5, 0)
		plan.pause.Size = UDim2.fromOffset(PLAN.PAUSE_W, buttonH)
		plan.start.AnchorPoint = Vector2.new(1, 0.5)
		plan.start.Position = UDim2.new(1, -(8 + PLAN.PAUSE_W + 6), 0.5, 0)
		plan.start.Size = UDim2.fromOffset(PLAN.START_W, buttonH)
	else
		-- A panel at the left edge, half way down (where the Big Score's own checklist goes during the job).
		local rowsH = #plan.rows * PLAN.ROW_H
		local h = pad + PLAN.HEAD_H + PLAN.SUB_H + 6 + rowsH + 8 + PLAN.BUTTON_H + pad
		f.AnchorPoint = Vector2.new(0, 0.5)
		f.Position = UDim2.new(0, PLAN.X, 0.5, 0)
		f.Size = UDim2.fromOffset(PLAN.W, h)
		plan.title.TextSize = 16
		plan.title.Position = UDim2.fromOffset(14, pad)
		plan.title.Size = UDim2.new(1, -28, 0, PLAN.HEAD_H)
		plan.sub.TextSize = 12
		plan.sub.Position = UDim2.fromOffset(14, pad + PLAN.HEAD_H)
		plan.sub.Size = UDim2.new(1, -28, 0, PLAN.SUB_H)
		for i, r in ipairs(plan.rows) do
			r.row.Visible = true
			r.row.Position = UDim2.fromOffset(14, pad + PLAN.HEAD_H + PLAN.SUB_H + 6 + (i - 1) * PLAN.ROW_H)
			r.row.Size = UDim2.new(1, -28, 0, PLAN.ROW_H)
		end
		for _, b in ipairs({ plan.start, plan.pause }) do
			b.AnchorPoint = Vector2.new(0, 1)
			b.Size = UDim2.new(0.5, -(14 + 3), 0, PLAN.BUTTON_H)
			b.Position = UDim2.new(b == plan.start and 0 or 0.5, b == plan.start and 14 or 3, 1, -pad)
		end
		plan.pause.Text = "PAUSE HEIST"
	end
	drawPlan()
end

-- In free roam, on the HUD (not the title screen), not wanted, and not busy with a mission (a prep
-- included), the Big Score, a race or a job shift.
local function freeRoamIdle()
	if player:GetAttribute("Side") ~= "Civilian" or player:GetAttribute("TitleScreen") == true
		or (player:GetAttribute("Heat") or 0) > 0 then
		return false
	end
	return not (player:GetAttribute("Mission") or player:GetAttribute("BigScore") or player:GetAttribute("RacingId")
		or player:GetAttribute("JobKind"))
end

-- Should the plan be up? A crew with its heist not paused, and the player free (freeRoamIdle).
local function planWanted()
	if type(player:GetAttribute("CrewPreps")) ~= "string" or player:GetAttribute("CrewPaused") == true then
		return false
	end
	if os.clock() - (plan.pausedAt or -math.huge) < PLAN.PAUSE_HIDE then
		return false -- (PAUSE was pressed: hidden until the server's answer lands)
	end
	return freeRoamIdle()
end

local function uiPart(guiName, childName)
	local pg = player:FindFirstChild("PlayerGui")
	local sg = pg and pg:FindFirstChild(guiName)
	return sg and sg:FindFirstChild(childName)
end

local function phoneModule()
	local ok, PhoneUI = pcall(require, script.Parent:FindFirstChild("PhoneUI"))
	return ok and type(PhoneUI) == "table" and PhoneUI or nil
end

-- Is a ride card, a pass offer or the phone up? (They share the card's band, or cover it.)
local function bandTaken()
	local ride = uiPart("RideInvite", "RideCard")
	if ride and ride:IsA("GuiObject") and ride.Visible then
		return true
	end
	local offer = uiPart("Offer", "Card")
	if offer and offer:IsA("GuiObject") and offer.Visible then
		return true
	end
	local PhoneUI = phoneModule()
	return PhoneUI ~= nil and type(PhoneUI.IsOpen) == "function" and PhoneUI.IsOpen() == true
end

-- Is something else using the plan's spot right now? A stamp over it, the crew card, a ride card, a pass
-- offer, the phone, or (PC) a toast or Coast Feed post reaching over it.
local function planCovered()
	local f = plan.frame
	if card or bandTaken() then
		return true
	end
	local origin = gui.AbsolutePosition
	local top = f.AbsolutePosition.Y - origin.Y
	local bottom = top + f.AbsoluteSize.Y
	local stampTop, stampBottom
	if HUDController.StampTop then
		stampTop, stampBottom = HUDController.StampTop()
	end
	if stampTop ~= nil and stampTop < bottom and (stampBottom == nil or stampBottom > top) then
		return true
	end
	if plan.touch then
		return false
	end
	local right = f.AbsolutePosition.X - origin.X + f.AbsoluteSize.X
	local playerGui = player:FindFirstChild("PlayerGui")
	for _, path in ipairs(PLAN.CARD_STACKS) do
		local sg = playerGui and playerGui:FindFirstChild(path[1])
		local holder = sg and sg:FindFirstChild(path[2])
		if holder and sg:IsA("ScreenGui") and sg.Enabled then
			for _, c in ipairs(holder:GetChildren()) do
				if c:IsA("GuiObject") and c.Visible then
					local y = c.AbsolutePosition.Y - sg.AbsolutePosition.Y
					local x = c.AbsolutePosition.X - sg.AbsolutePosition.X
					if y < bottom and y + c.AbsoluteSize.Y > top and x < right then
						return true
					end
				end
			end
		end
	end
	return false
end

local function planTick()
	if not plan.frame then
		return
	end
	local want = planWanted() and not planCovered()
	if plan.frame.Visible ~= want then
		plan.frame.Visible = want
	end
end

------------------------------------------------------------------ the crew tip

-- Is someone else in this server to team up with? Another player in free roam.
local function someoneToTeamWith()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p:GetAttribute("Side") == "Civilian" then
			return true
		end
	end
	return false
end

-- Could the crew tip come up right now? (see the header)
local function tipReady()
	if card or player:GetAttribute("Crew") ~= nil or not freeRoamIdle() then
		return false
	end
	local step = player:GetAttribute("TutorialStep")
	if type(step) ~= "number" or step < #Tutorial.Steps then
		return false
	end
	if not cardWanted() or bandTaken() then
		return false
	end
	return someoneToTeamWith()
end

local function showTip(why)
	CrewTip.Shown(tip, why, os.clock())
	openCard({
		kind = "Tip", tag = "WAY MORE MONEY", tagColor = C.Cash,
		words = {
			pc = "Crews unlock " .. JOB_NAME .. ": " .. cash(PLAN.CUT) .. "+ each. You can team up with anyone in this server!",
			touch = "Crews earn " .. PLAN.CUT_SHORT .. ". Team up with anyone here!",
		},
		yes = "FIND A CREW", no = "LATER", seconds = TIP_FOR,
		onYes = function()
			local PhoneUI = phoneModule()
			if PhoneUI and type(PhoneUI.Open) == "function" then
				PhoneUI.Open("Crew") -- (PLAYERS HERE: an INVITE button by every name)
			end
		end,
		onNo = function()
			CrewTip.Later(tip, os.clock())
		end,
	})
end

-- The crew job's moments (see the header).
local function onJob(kind, info)
	info = type(info) == "table" and info or {}
	local done, total = tonumber(info.Done) or 0, tonumber(info.Total) or 3
	if kind == "New" or kind == "Joined" then
		HUDController.Stamp("CREW UP!", JOB_NAME .. ": rob the Gold Reserve for " .. cash(PLAN.CUT)
			.. "+ each (more with a bigger crew)", C.Gold,
			"NEW CREW HEIST")
	elseif kind == "Back" then
		local mates = type(info.Mates) == "table" and table.concat(info.Mates, ", ") or ""
		NotifyController.Show((mates ~= "" and ("Your crew: " .. mates .. ". ") or "")
			.. (done >= total and (JOB_NAME .. " is unlocked!") or ("Crew preps " .. done .. "/" .. total .. " (PHONE > CREW).")),
			nil, "crew")
	elseif kind == "PrepDone" then
		NotifyController.Show("Crew prep done: " .. tostring(info.Name or "") .. " (" .. done .. "/" .. total
			.. "). Next one: PHONE > CREW.", C.Cash, "crew")
	elseif kind == "Ready" then
		HUDController.Stamp("BIG SCORE UNLOCKED", "Every crew prep is done. Start it: PHONE > CREW", C.Gold, "CREW JOB")
	elseif kind == "Reset" then
		NotifyController.Show("New score, new preps: do them again to unlock the next Big Score.", nil, "crew")
	elseif kind == "Broke" then
		NotifyController.Show((info.Name and (tostring(info.Name) .. " left: ") or "")
			.. "your crew broke up, and its Big Score job with it.", nil, "warning")
	elseif kind == "Left" then
		NotifyController.Show(tostring(info.Name or "Someone") .. " left your crew.", nil, "crew")
	elseif kind == "CallJoined" then
		NotifyController.Show(tostring(info.Name or "Someone") .. " answered your crew call and joined your crew!", C.Gold, "crew")
	elseif kind == "Paused" then
		local me = info.Name == player.DisplayName
		NotifyController.Show((me and "Heist paused." or (tostring(info.Name) .. " paused the heist."))
			.. " Your progress is saved: find it again in PHONE > CREW.", nil, "crew")
	elseif kind == "Resumed" then
		NotifyController.Show(tostring(info.Name or "Your crew") .. " is back on the heist: the plan is on your screen.", C.Gold,
			"crew")
	elseif kind == "Toast" then
		local said, color, style = namedToast(info)
		if said then
			NotifyController.Show(said, color, style)
			return
		end
		local t = JOB_TOASTS[info.Key]
		if t then
			local text = t[1]
			if string.find(text, "%d", 1, true) then
				text = string.format(text, done, total)
			end
			NotifyController.Show(text, nil, t[2])
		end
	end
end

function CrewClient.Init()
	gui = Instance.new("ScreenGui")
	gui.Name = "Crew"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- the zone map's coordinates (y = 0 is the very top of the screen)
	gui.DisplayOrder = 8
	gui.Parent = player:WaitForChild("PlayerGui")
	-- Re-place the card when the screen changes size or the device's input changes.
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitCard)
	UserInputService:GetPropertyChangedSignal("MouseEnabled"):Connect(fitCard)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(fitCard)
	-- The heist plan: built once, placed for the screen, redrawn when the crew's progress changes.
	buildPlan()
	placePlan()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placePlan)
	UserInputService:GetPropertyChangedSignal("MouseEnabled"):Connect(placePlan)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(placePlan)
	player:GetAttributeChangedSignal("PreviewTouch"):Connect(placePlan) -- (Studio's phone preview)
	for _, name in ipairs({ "CrewPreps", "CrewPrepRun", "CivRank" }) do
		player:GetAttributeChangedSignal(name):Connect(drawPlan)
	end
	player:GetAttributeChangedSignal("CrewPaused"):Connect(function()
		if player:GetAttribute("CrewPaused") ~= true then
			plan.pausedAt = nil -- (resumed: show it again at once)
		end
	end)
	task.spawn(function()
		Remotes.OnClient("CrewInvite", showInvite)
	end)
	Remotes.OnClient("CrewCall", showCall)
	Remotes.OnClient("CrewCallClosed", closeCallCard)
	Remotes.OnClient("CrewJob", onJob)
	task.spawn(function()
		Remotes.OnClient("CrewMeet", meetFade)
	end)
	watchTaskPrompts()
	player:GetAttributeChangedSignal("FriendBonus"):Connect(function()
		if player:GetAttribute("FriendBonus") then
			NotifyController.Show("A friend is in this server: +10% heist cash!", C.Cash)
		end
	end)
	player:GetAttributeChangedSignal("TitleScreen"):Connect(refreshTags)
	-- The crew tip's moments (Util/CrewTip): a payout, The Big Score refusing for want of a crew. Joining a
	-- crew takes the tip away.
	local lastCash = player:GetAttribute("Cash")
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		local value = player:GetAttribute("Cash")
		if type(value) == "number" and type(lastCash) == "number" and value > lastCash and player:GetAttribute("Crew") == nil then
			CrewTip.Payout(tip, value - lastCash, os.clock())
		end
		lastCash = value
	end)
	Remotes.OnClient("Notify", function(key)
		if key == "BigScoreNeedCrew" and player:GetAttribute("Crew") == nil then
			CrewTip.NeedCrew(tip, os.clock())
		end
	end)
	player:GetAttributeChangedSignal("Crew"):Connect(function()
		local mine = player:GetAttribute("Crew")
		if mine ~= nil and card and cardKind == "Tip" then
			card:Destroy()
			card = nil
		end
		-- In the caller's crew already (by an invite, or the server's answer): their call card has done its job.
		-- (a moment later: the caller's own Crew attribute may land after ours)
		task.delay(0.5, function()
			local now = player:GetAttribute("Crew")
			if now ~= nil and card and cardKind == "Call" then
				local from = Players:GetPlayerByUserId(tonumber(card:GetAttribute("From")) or 0)
				if from and from:GetAttribute("Crew") == now then
					card:Destroy()
					card = nil
				end
			end
		end)
	end)
	local lastTags, lastCheck, lastTip = 0, 0, 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastCheck >= CHECK_EVERY then
			lastCheck = now
			-- A big stamp uses the card's spot: step aside until it's gone (the card keeps its 60 s).
			if card then
				local want = cardWanted()
				if card.Visible ~= want then
					card.Visible = want
				end
			end
			planTick()
		end
		if now - lastTip >= TIP_CHECK_EVERY then
			lastTip = now
			local why = CrewTip.Due(tip, now, tipReady())
			if why then
				showTip(why)
			end
		end
		if now - lastTags > TAGS_EVERY then
			lastTags = now
			refreshTags()
		end
	end)
end

return CrewClient
