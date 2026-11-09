-- HeistClient (ModuleScript, StarterPlayerScripts.Controllers.HeistClient)
-- Client side of heists, in the flat "street" look (Shared.Util.Theme):
--   * Rob prompts show only for robbers, and only while the site is Robbable (local-only toggle of
--     Enabled; the server re-checks everything when a robbery finishes). A prompt that streams in right
--     next to you is switched at once, not on the next pass (the server leaves it on for everybody).
--     A Rob prompt you are holding when its store leaves the rotation stays up until that hold ends
--     (stores shut for new holds only; the server pays a hold that began while the store was open).
--   * Sitting in a car (any seat) you can't rob: PromptGate hides the Rob and prep prompts the moment you
--     sit and brings them back when you stand up. It does that with MaxActivationDistance and this file
--     only ever sets Enabled, text and hold time, so the two never undo each other (nothing here looks at
--     the seat). InteractClient's "Get out to rob" hint asks HeistClient.NearestRob for the nearest spot
--     you could use on foot right now.
--   * Site signs (the server's BillboardGui over each pad, restyled on this device the first time it is
--     seen): the name in white Display, the state after it in the colour that means it, and a thin rule
--     in that colour under the words. "GLOW MART  OPEN" (green: cash to take), "GLOW MART  CLOSED 2:10"
--     (all dim; the same seated or on foot: the store is open, you just have to get out), and for cops
--     "GLOW MART  ALARM" blinking red while the alarm runs.
--   * Rank-locked heists (MinRank, e.g. the Coastal Bank at free-roam rank 3) say so up front for
--     players below it: the sign reads "COASTAL BANK / RANK 3 NEEDED (you're 1)" in purple, the prompts
--     read "Rank 3 needed" (a tap asks the server, which explains), and the first time you walk up to
--     one a stamp (the place over RANK 3 NEEDED) + toast tell you how to rank up.
--   * Prep panels (fuse box, yacht panel) with a live prep read "Done (1:05 left)" for the crew that
--     did it and "Taken (free in 0:32)" for everyone else while it's protected (PrepLockUntil); a tap
--     asks the server, which explains. Otherwise they show the server's own text and hold time.
--   * Heists with a prep step (Config.Heists Prep: the Coastal Bank's fuse box on its east wall, the Sea
--     Dream's alarm panel on the boarding deck) say so BEFORE anyone tries the vault. Until the prep is
--     this player's or their crew's and its window is open (PrepBy / PrepUntil: the server's own test,
--     HeistService prepIsMine), the Rob prompt is locked on this device: it reads "Cut the power first"
--     over "Fuse box: east wall" (K.PREP_WORDS) and has no hold, so E can't be held on it (a tap asks the
--     server, which says NeedPrep_<type>). The sign adds the step in gold under OPEN ("CUT THE POWER
--     FIRST"), or how long your window has left in green ("POWER OUT 1:05"); a gold marker ("CUT THE
--     POWER" over a chevron) floats over the panel for anyone within K.MARK_RANGE studs of it, drawn on
--     top of everything (the fuse box is round the outside of the bank); and the first walk-up to the
--     place says it in a toast. A prep done or redone, or a crew joined or left, re-labels it at once
--     (attribute signals); the pass catches a window running out. A hold already running is never
--     locked under your thumb: the server pays a hold that began inside the window.
--   * Holding a Rob prompt (ScreenGui "HeistUI", frame "Rob", in the Subtitle zone, or standing on top
--     of whatever else is using that zone): the place's name, the take so far counting up in green
--     ("$420 ...": the store's base payout times how far the hold has got; the real figure, with night /
--     crew / VIP bonuses and a big heist's crew split, comes with the result stamp) and a slim white bar
--     that thumps like a heartbeat, faster as the hold nears its end. The camera eases in up to 1.4 studs
--     while you hold and back out when you let go (moved after Roblox's camera each frame, so nothing
--     else's FOV or camera offset is touched). A prep panel's hold gets the same bar with a percentage
--     instead of cash.
--   * The alarm trips (the site's AlarmUntil starts, 10 s after the robbery): two quick red pulses round
--     the edge of the screen (frame "Alarm") for the robber and for anyone within 150 studs of the site.
--   * Result stamp (HUDController.Stamp, gold): "GLOW MART  ·  IN YOUR BAG" over ROBBERY COMPLETE (HEIST
--     COMPLETE for a big heist, CAR DELIVERED for a hot car), the reward line "+$1,200   +40 XP", then
--     "Lose the cops, then bank it at the Hideout (GPS set)" under it and the GPS pointed at the Hideout
--     through ObjectiveClient. A finished prep: STEP 1 DONE, green.
--   * Crew cuts (big heists only, HeistService): a robber who split the take (result Crew > 1) reads
--     "Split with 2 crewmates." before the next step. A crewmate who helped gets YOUR CUT (result Cut)
--     over the same place line, with the cash but no XP (the server gives the heist XP to the robber).
--   * Bag full: a toast with the cash left behind, and the Big Duffel offer is queued (OfferClient
--     shows it later, once the player isn't wanted or speeding).
--   * Big heists (Coastal Bank / Sea Dream, yours or your crew's: attribute BigHeists) say what they
--     count toward: "Big heist 1/3 toward the Riptide R", or which heist-locked ride just unlocked.
--   * Store clerks (HeistService; Heists.Types[...].Clerk): with a gun aimed at a clerk (CombatClient.Aiming)
--     within K.CLERK_REACH studs, the server is asked to start the robbery (RequestStoreRob, at most once a
--     second); its StoreRob "Start" runs the same bar as a hold, counting the take up for the fill time,
--     "Done" / "Fail" end it. While a clerk stands there, a player who owns a gun doesn't see the till's
--     Rob prompt (they're told once, near the store, to point the gun at the clerk); without a gun it
--     shows as before. The clerk's pose (model attribute Pose: HandsUp, Cower) is played here with
--     PoseClient, on every device.
--   * Rookie robbery (Config.Tutorial.RookieRob): until this player has banked a first bag, and while the
--     bag is empty, every tier-1 site is open for them alone: its sign reads OPEN, its Rob prompt shows
--     (and the clerk can be held up), with the shorter rookie hold. The server checks the same rule.
--   * Club Nova's drill (Drill): its Rob prompt reads "Set the drill", then "Drilling 0:18" (locked) for
--     whoever set it and "Drill running" for everyone else, then "Grab the cash" for the driller.
--   HeistClient.NearestRob(pos, range)  studs from pos to the nearest Rob point or prep panel within
--                                       range that this player could use on foot right now, or nil
-- Constants are fields of K and the HUD pieces fields of ui (a script's top level holds 200 locals at most).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Heists = require(ReplicatedStorage.Shared.Config.Heists)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Vehicles = require(ReplicatedStorage.Shared.Config.Vehicles)
local Tutorial = require(ReplicatedStorage.Shared.Config.Tutorial)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local Theme = require(ReplicatedStorage.Shared.Util.Theme)
local HUDController = require(script.Parent:WaitForChild("HUDController"))
local NotifyController = require(script.Parent:WaitForChild("NotifyController"))

local player = Players.LocalPlayer

local HeistClient = {}

local C = Theme.Color
local K = {}
K.EXPLAIN_RANGE = 90 -- studs from a locked site's pad before we explain the lock
K.PASS_EVERY = 0.33 -- seconds between passes over every site
K.PROMPT_NAMES = { "RobPrompt", "PrepPrompt" }
-- Signs: colour by meaning (as rich-text hex). Green = cash to take, dim = shut, purple = "not yet,
-- rank up first" (DealerClient's heist locks use the same), red = the alarm.
K.HEX_OPEN, K.HEX_SHUT, K.HEX_LOCKED = C.Cash:ToHex(), C.Dim:ToHex(), C.Purple:ToHex()
K.HEX_ALARM, K.HEX_TEXT = C.Danger:ToHex(), C.Text:ToHex()
K.SIGN_BIG = UDim2.fromOffset(300, 64) -- a two-line sign (rank lock, prep step) gets a bigger board
K.SIGN_RULE = 64 -- pixels: the thin rule under a sign's words
-- The rob bar
K.ROB_W, K.ROB_W_TOUCH = 360, 300 -- its width (never wider than the Subtitle zone)
K.ROB_H = 36 -- name and take (26 px) over the bar
K.BAR_H = 5 -- the bar at rest...
K.BEAT_SWELL = 3 -- ...and how many pixels thicker it gets on a heartbeat
K.BEAT_SLOW, K.BEAT_FAST = 1.1, 2.1 -- heartbeats a second as the hold starts / as it ends
K.TAKE_STEP = 20 -- the take counts up in steps of this many dollars
K.REPLACE_EVERY = 0.25 -- seconds between looks at what else is using the Subtitle zone
-- Pieces of other controllers that use the Subtitle zone now and then (paths under PlayerGui, the way
-- NotifyController lists them): the bar stands on top of one that is showing there.
K.SUBTITLE_PIECES = { { "Tutorial", "Next" }, { "Mission", "Step" }, { "ImpactFx", "KnockedDown" } }
-- The camera's slow push-in while you hold
K.PUSH = 1.4 -- studs closer by the end of the hold
K.PUSH_KEEP = 5 -- never when that would bring the camera closer to you than this (and at most half the spare room)
K.PUSH_SPEED = 5 -- per second: how fast it follows (and eases back when you let go)
K.STEP_NAME = "NC_HeistRob" -- our render step, bound only while a hold runs or the camera eases back
-- The alarm flash
K.ALARM_RANGE = 150 -- studs from the site's pad: bystanders this close see it too
K.ALARM_FRESH = 3 -- seconds: only an alarm that started this recently flashes (not one already ringing as the site streams in)
K.FLASH_SECONDS = 1 -- two pulses in this long
K.FLASH_ALPHA = 0.5 -- how solid the red gets at the very edge
K.FLASH_EDGE = 0.16 -- how far in it reaches: this share of the screen's shorter side (40-130 px)
-- Store clerks
K.CLERK_REACH = 22 -- studs: a gun aimed at a clerk this close starts the robbery (the server allows 24)
K.CLERK_CONE = 0.94 -- cosine: how close to the gun's line the clerk must be
K.CLERK_ASK_GAP = 1 -- seconds between two asks
K.HINT_RANGE = 40 -- studs from a clerk: a gun owner is told how to rob that store (once each)
-- Prep steps, by heist type: the locked Rob prompt's words (Lock over Where), the panel's marker (Mark)
-- and the sign's word while your crew's window runs (Done). A type missing here gets words made from its
-- Config.Heists Prep (prepWords).
K.PREP_WORDS = {
	CoastalBank = { Lock = "Cut the power first", Where = "Fuse box: east wall", Mark = "CUT THE POWER", Done = "POWER OUT" },
	SeaDream = { Lock = "Disable the alarm first", Where = "Alarm panel: boarding deck", Mark = "DISABLE THE ALARM",
		Done = "ALARM OFF" },
}
K.HEX_PREP = C.Gold:ToHex() -- the sign's "do this first" line (gold: the step toward the reward)
K.PREP_ATTRS = { "PrepBy", "PrepUntil", "PrepLockUntil", "Robbable" } -- site attributes that re-label at once
K.MARK_RANGE = 220 -- studs from the panel: its marker shows this close (all round the bank, the whole yacht)
K.MARK_UP = 4.5 -- studs over the panel's middle (the panel is 4 tall)
K.MARK_SIZE = UDim2.fromOffset(190, 40) -- the words, and the chevron under them

-- The HUD pieces (build sets them once): gui, rob (the frame), robName, robTake, robNameShadow,
-- robTakeShadow, robBar, robFill, alarm (the frame), alarmEdges = { { frame, across } x 4 }
local ui = {}
local rob = {
	active = false, -- a Rob / prep hold is running
	prompt = nil, -- the prompt being held
	began = 0, -- os.clock() the hold began
	hold = 1, -- its length in seconds
	take = nil, -- dollars the place pays at least (nil for a prep step: no cash there)
	p = 0, -- how far the hold has got (0-1)
	shown = nil, -- the number the take label shows now
	phase = 0, -- where the heartbeat is in its cycle (0-1)
	push = 0, -- studs the camera is pushed in right now
	bound = false, -- our render step is hooked up
	token = 0, -- bumps whenever the bar is shown or sent away (a stale "hide it now" does nothing)
	fades = {}, -- the bar's running fade tweens
	placedAt = 0, -- os.clock() the bar was last placed
	flashToken = 0, -- bumps with every alarm flash (a newer one takes over)
}

local siteFolder = nil -- Workspace.Heists (set in Init)
-- Where this player could start a robbery on foot right now: the parents of the Rob / prep prompts that
-- are showing unlocked. Each pass fills the spare list and then swaps the two (no new tables), so
-- NearestRob always reads a finished one.
local robSpots, robCount = {}, 0
local fillSpots, fillCount = {}, 0

local promptDefaults = setmetatable({}, { __mode = "k" }) -- [prompt] = the server's text and hold time
local explained = {} -- [heist type] = true once this player has been told how to unlock it
local alarmSeen = {} -- [site] = the AlarmUntil we have already looked at
local lastBigHeists -- the BigHeists count we last saw (nil until the save has loaded)
local clerkPoses = setmetatable({}, { __mode = "k" }) -- [clerk model] = { name, handle } of the pose we show
local clerkHinted = {} -- [site] = true once a gun owner was told how to rob it
local lastClerkAsk = 0
local lazy = {} -- [controller name] = its module (false if missing)
local prepMarks = {} -- [site] = { part, gui }: the gold marker over that site's prep panel, on this device
local prepTold = {} -- [heist type] = true once this player has been told its prep comes first

local function now()
	return Workspace:GetServerTimeNow()
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- Plain words inside rich text: keep "&", "<" and ">" from being read as tags ("Sparkle & Co.").
local function escape(s)
	return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function tint(hex, text)
	return string.format('<font color="#%s">%s</font>', hex, text)
end

-- The free-roam rank this site needs, if the local player doesn't have it yet (else nil).
local function rankLock(site)
	if player:GetAttribute("Side") ~= "Civilian" then
		return nil
	end
	local def = Heists.Types[site:GetAttribute("HeistId")]
	local need = site:GetAttribute("MinRank") or (def and def.MinRank)
	local rank = player:GetAttribute("CivRank") or 1
	if type(need) == "number" and rank < need then
		return need, rank
	end
	return nil
end

-- Is this site's prep ours: done by us or our crew, its window still open at server time t? The
-- server's own test (HeistService prepIsMine), from the attributes it replicates.
local function prepIsMine(site, t)
	local by = site:GetAttribute("PrepBy")
	local mine = by ~= nil and (by == player:GetAttribute("Crew") or by == "u" .. player.UserId)
	return mine and (site:GetAttribute("PrepUntil") or 0) >= t
end

-- The words for a heist type's prep step (K.PREP_WORDS, or made from its Config.Heists Prep once).
local function prepWords(typeId, def)
	local w = K.PREP_WORDS[typeId]
	if not w then
		local prep = def.Prep
		w = { Lock = tostring(prep.Action) .. " first", Where = tostring(prep.Object), Mark = string.upper(tostring(prep.Action)),
			Done = "STEP 1 DONE" }
		K.PREP_WORDS[typeId] = w
	end
	return w
end

-- The prep panel's lock text while a prep is live, or nil when anyone may do it now.
local function prepLabel(site)
	local t = now()
	local untilAt = site:GetAttribute("PrepUntil") or 0
	if untilAt <= t then
		return nil
	end
	if prepIsMine(site, t) then
		return "Done (" .. clock(untilAt - t) .. " left)"
	end
	local lockUntil = site:GetAttribute("PrepLockUntil") or 0
	if lockUntil > t then
		return "Taken (free in " .. clock(lockUntil - t) .. ")"
	end
	return nil
end

-- Locked (text given, e.g. "Rank 3 needed"): no hold, and a tap asks the server, which explains
-- (BankNeedsRank, PrepTaken, NeedPrep_...). Unlocked (nil): back to the server's own text and hold
-- time. With `hold` as well: that text with that hold (an unlocked stage of its own: the drill's "Grab
-- the cash"). With `object`: the small line over the words too (a prep lock's "Fuse box: east wall");
-- without it, the server's own (the place's name).
local function labelPrompt(prompt, text, hold, object)
	local d = promptDefaults[prompt]
	if not d then
		d = { ActionText = prompt.ActionText, HoldDuration = prompt.HoldDuration, ObjectText = prompt.ObjectText }
		promptDefaults[prompt] = d
	end
	local action = text or d.ActionText
	hold = hold or (text and 0 or d.HoldDuration)
	object = object or d.ObjectText
	if prompt.ActionText ~= action then
		prompt.ActionText = action
	end
	if prompt.ObjectText ~= object then
		prompt.ObjectText = object
	end
	if prompt.HoldDuration ~= hold then
		prompt.HoldDuration = hold
	end
end

------------------------------------------------------------------ site signs

-- The server builds each sign as one scaled label with a hard outline. The first time this device
-- sees it: the Display face, white, a soft shadow instead of the outline, room for a thin rule under
-- the words, and its normal size kept on the board itself (the locked sign is bigger). Returns the rule.
local function styleSign(gui, label)
	local rule = gui:FindFirstChild("Rule")
	-- A site that streamed out and back in can come back with the label's own properties reset to the
	-- server's while our Rule is still there: the sign then showed its colour tags as text ("<font
	-- color=...>ATM CLOSED</font>", seen in play on Nov 3). So the label is restyled whenever it lost them.
	if rule and label.RichText then
		return rule
	end
	if gui:GetAttribute("NormalSize") == nil then
		gui:SetAttribute("NormalSize", gui.Size)
	end
	label.FontFace = Theme.Font.Display
	label.RichText = true
	label.TextColor3 = C.Text
	label.TextStrokeTransparency = 1
	Theme.Shadow(label, 2)
	label.Size = UDim2.new(1, 0, 1, -6)
	if rule then
		return rule
	end
	rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.AnchorPoint = Vector2.new(0.5, 1)
	rule.Position = UDim2.new(0.5, 0, 1, -1)
	rule.Size = UDim2.fromOffset(K.SIGN_RULE, 2)
	rule.BackgroundColor3 = C.Text
	rule.BorderSizePixel = 0
	rule.Parent = gui
	return rule
end

-- A two-line sign (a rank lock, or a prep step under OPEN) gets a bigger board.
local function sizeSign(gui, big)
	local normal = gui:GetAttribute("NormalSize")
	local want = big and K.SIGN_BIG or normal
	if typeof(want) == "UDim2" and gui.Size ~= want then
		gui.Size = want
	end
end

-- First time near a locked heist: say what it needs and how to get there.
local function explainLock(site, need, rank)
	local typeId = site:GetAttribute("HeistId")
	if explained[typeId] then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local pad = site.PrimaryPart
	if not root or not pad or (root.Position - pad.Position).Magnitude > K.EXPLAIN_RANGE then
		return
	end
	explained[typeId] = true
	local name = site:GetAttribute("Display") or site.Name
	HUDController.Stamp("RANK " .. need .. " NEEDED", "Unlocks at free-roam rank " .. need .. " (you're rank " .. rank .. ")",
		C.Purple, string.upper(name))
	NotifyController.Show("Earn XP by robbing stores, racing, stunts, taxi/courier jobs and missions. Check PHONE > GOALS.",
		C.Gold, "info")
end

-- First walk-up to an open heist whose prep we haven't done: say what comes first and where, before
-- anyone tries the vault (the server's own NeedPrep words, which a tap on the locked prompt also brings).
local function explainPrep(site, typeId)
	if prepTold[typeId] then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local pad = site.PrimaryPart
	if not root or not pad or (root.Position - pad.Position).Magnitude > K.EXPLAIN_RANGE then
		return
	end
	prepTold[typeId] = true
	local text = NotifyController.Messages and NotifyController.Messages["NeedPrep_" .. typeId]
	if text then
		NotifyController.Show(text, nil, "info")
	end
end

-- The prep panel's marker: a small invisible anchor at the panel's Config spot under the camera (the
-- panel itself may not have streamed in yet), holding a board drawn on top of everything, so it reads
-- through the bank's walls from the vault: the step in gold Display over a gold chevron pointing down.
local function buildMark(def, w)
	local anchor = Instance.new("Part")
	anchor.Name = "PrepMark"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(def.Prep.Pos + Vector3.new(0, K.MARK_UP, 0))
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = K.MARK_SIZE
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	tag.Enabled = false
	tag.Parent = anchor
	local words = Instance.new("TextLabel")
	words.Name = "Words"
	words.Size = UDim2.new(1, 0, 0, 22)
	Theme.Text(words, 17, "Display")
	words.TextColor3 = C.Gold
	words.Text = w.Mark
	words.Parent = tag
	for _, s in ipairs({ { -4, 40 }, { 4, -40 } }) do -- (MissionClient's target chevron: two strokes, a "V")
		local stroke = Instance.new("Frame")
		stroke.AnchorPoint = Vector2.new(0.5, 0.5)
		stroke.Position = UDim2.new(0.5, s[1], 0, 31)
		stroke.Size = UDim2.fromOffset(13, 3)
		stroke.Rotation = s[2]
		stroke.BackgroundColor3 = C.Gold
		stroke.BorderSizePixel = 0
		Theme.Corners(stroke, 1)
		stroke.Parent = tag
	end
	anchor.Parent = Workspace.CurrentCamera
	return { part = anchor, gui = tag }
end

-- Show this site's prep marker (on: the step is ours to do and the place is open) while we're within
-- K.MARK_RANGE studs of the panel; built the first time it's needed (again if the camera was replaced).
local function markPrep(site, def, w, on)
	local mark = prepMarks[site]
	if on then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		on = root ~= nil and (root.Position - def.Prep.Pos).Magnitude <= K.MARK_RANGE
			and player:GetAttribute("TitleScreen") ~= true
	end
	if not on then
		if mark and mark.gui.Enabled then
			mark.gui.Enabled = false
		end
		return
	end
	if not mark or not mark.part.Parent then
		mark = buildMark(def, w)
		prepMarks[site] = mark
	end
	if not mark.gui.Enabled then
		mark.gui.Enabled = true
	end
end

------------------------------------------------------------------ the alarm flash

-- Two quick red pulses round the edge of the screen (the second softer). Labels and frames only: it
-- never takes a touch. A newer flash takes over from one still running.
local function flashAlarm()
	if not ui.alarm or player:GetAttribute("TitleScreen") == true then
		return
	end
	rob.flashToken += 1
	local token = rob.flashToken
	local view = ui.gui.AbsoluteSize
	local edge = math.clamp(math.floor(math.min(view.X, view.Y) * K.FLASH_EDGE), 40, 130)
	for _, e in ipairs(ui.alarmEdges) do
		e.frame.Size = e.across and UDim2.new(1, 0, 0, edge) or UDim2.new(0, edge, 1, 0)
		e.frame.BackgroundTransparency = 1
	end
	ui.alarm.Visible = true
	task.spawn(function()
		local t0 = os.clock()
		while rob.flashToken == token do
			local x = (os.clock() - t0) / K.FLASH_SECONDS
			if x >= 1 then
				break
			end
			local strength = math.abs(math.sin(x * math.pi * 2)) * (x < 0.5 and 1 or 0.65)
			local alpha = 1 - K.FLASH_ALPHA * strength
			for _, e in ipairs(ui.alarmEdges) do
				e.frame.BackgroundTransparency = alpha
			end
			RunService.RenderStepped:Wait()
		end
		if rob.flashToken == token then
			ui.alarm.Visible = false
		end
	end)
end

-- Has this site's alarm just gone off? Each alarm (each new AlarmUntil) is looked at once.
local function watchAlarm(site, t)
	local untilAt = site:GetAttribute("AlarmUntil") or 0
	if untilAt <= t or alarmSeen[site] == untilAt then
		return
	end
	alarmSeen[site] = untilAt
	if untilAt - t < Heists.AlarmSeconds - K.ALARM_FRESH then
		return -- it has been ringing for a while (we just arrived, or the site just streamed in)
	end
	-- The robber wherever they have got to, and anyone standing at the scene.
	if site:GetAttribute("LastRobbedBy") ~= player.UserId then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local pad = site.PrimaryPart
		if not root or not pad or (root.Position - pad.Position).Magnitude > K.ALARM_RANGE then
			return
		end
	end
	flashAlarm()
end

------------------------------------------------------------------ every site, three times a second

-- collect: this is the regular pass, so note the site's usable spots for NearestRob.
-- Does this player own a gun (CombatClient's weapons)? (Store clerks: then the till's prompt is hidden.)
local function other(name)
	local m = lazy[name]
	if m == nil then
		local ok, res = pcall(require, script.Parent:FindFirstChild(name))
		m = (ok and type(res) == "table") and res or false
		lazy[name] = m
	end
	return m or nil
end

local function ownsGun()
	local combat = other("CombatClient")
	local ok, list = pcall(function()
		return combat.Weapons()
	end)
	for _, w in ipairs(ok and type(list) == "table" and list or {}) do
		if w.Class ~= nil then
			return true
		end
	end
	return false
end

-- Club Nova's drill stage for this player: the Rob prompt's text and hold (nil: the server's own).
local function drillLabel(site, def)
	local by, doneAt = site:GetAttribute("DrillBy"), site:GetAttribute("DrillDoneAt")
	if by == nil or not doneAt then
		return nil
	end
	if by ~= player.UserId then
		return "Drill running", 0
	end
	local t = now()
	if t >= doneAt then
		return "Grab the cash", def.Drill.Grab
	end
	return "Drilling " .. clock(doneAt - t), 0
end

local function updateSite(site, collect)
	local typeId = site:GetAttribute("HeistId")
	local def = Heists.Types[typeId]
	-- A rookie's first robbery: every tier-1 site is open for them alone (Tutorial.RookieRob).
	local rookie = def ~= nil and not def.Drill and Tutorial.CanRookieRob(player, def.Tier)
	local robbable = site:GetAttribute("Robbable") == true or rookie
	local civilian = player:GetAttribute("Side") == "Civilian"
	local need, rank = rankLock(site)
	local t = now()
	-- A prep step (fuse box, alarm panel) that we or our crew still have to do before the vault works.
	-- (Under a rank lock that one says it all: the rank comes first, on the server too.)
	local prepW = def and def.Prep and prepWords(typeId, def) or nil
	local prepLocked = prepW ~= nil and civilian and need == nil and not prepIsMine(site, t)
	for _, name in ipairs(K.PROMPT_NAMES) do
		local prompt = site:FindFirstChild(name, true)
		if prompt then
			local text = need and ("Rank " .. need .. " needed") or (name == "PrepPrompt" and prepLabel(site)) or nil
			local object -- a lock's small line over the words: where the prep step is
			-- The vault waits for the prep: the step to do, where it is, and no hold. Never under our own
			-- thumb, though: a hold begun inside the window is paid (the server checks the prep when the
			-- hold begins), so the window running out mid-hold must not take that hold away.
			if not text and name == "RobPrompt" and prepLocked and not (rob.active and rob.prompt == prompt) then
				text, object = prepW.Lock, prepW.Where
			end
			local stageHold -- an unlocked stage with its own text (the drill's "Grab the cash")
			if not text and name == "RobPrompt" and def and def.Drill then
				text, stageHold = drillLabel(site, def)
				stageHold = (stageHold ~= nil and stageHold > 0) and stageHold or nil
			elseif not text and name == "RobPrompt" and rookie then
				stageHold = math.min(def.Hold, Tutorial.RookieRob.Hold) -- (the server allows the same)
			end
			labelPrompt(prompt, text, stageHold, object)
			-- A locked prompt shows even while the site is closed, so walking up to it tells you why.
			-- Only Enabled is switched here, and never for the seat: PromptGate keeps both prompts out of
			-- sight while we sit (through MaxActivationDistance), so the two can't flicker against each other.
			local show = civilian and (robbable or need ~= nil or stageHold ~= nil)
			-- A clerk store with its clerk standing: a gun owner robs it at gunpoint, not at the till.
			if show and name == "RobPrompt" and def and def.Clerk and site:GetAttribute("ClerkUp") == true and ownsGun() then
				show = false
			end
			-- The store left the rotation while we were holding its Rob prompt: it shuts for new holds
			-- only, so ours stays up until the hold ends (switching it off here made the bar vanish with
			-- nothing paid; the server pays a hold that began while the place was open). Not for a hold
			-- under a second old (the server may have shut before it saw that one begin), and not when
			-- somebody else emptied the place first (its ReopenAt is running: nothing left to take).
			local held = not show and civilian and name == "RobPrompt" and rob.active and rob.prompt == prompt
				and os.clock() - rob.began >= 1 and now() >= (site:GetAttribute("ReopenAt") or 0)
			if prompt.Enabled ~= (show or held) then
				prompt.Enabled = show or held
			end
			-- Showing and not locked: a spot we could use on foot right now.
			if collect and show and (text == nil or stageHold ~= nil) and prompt.Parent then
				fillCount += 1
				fillSpots[fillCount] = prompt.Parent
			end
		end
	end
	if need then
		explainLock(site, need, rank)
	end
	-- The panel's marker and the first walk-up's heads-up, only while the place is open (a shut bank
	-- has nothing to prepare for).
	if prepW then
		local on = prepLocked and robbable
		markPrep(site, def, prepW, on)
		if on then
			explainPrep(site, typeId)
		end
	end
	watchAlarm(site, t)
	local pad = site.PrimaryPart
	local gui = pad and pad:FindFirstChildOfClass("BillboardGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	if not label then
		return
	end
	local rule = styleSign(gui, label)
	local name = escape(string.upper(site:GetAttribute("Display") or site.Name))
	local alarm = t < (site:GetAttribute("AlarmUntil") or 0)
	local words, color
	local twoLines = need ~= nil
	if alarm and player:GetAttribute("Side") == "Cop" then
		local lit = math.floor(t * 3) % 2 == 0 -- (blinks from one pass to the next)
		color = lit and C.Danger or C.Text
		words = name .. "  " .. tint(lit and K.HEX_ALARM or K.HEX_TEXT, "ALARM")
	elseif need then
		color = C.Purple
		words = name .. "\n" .. tint(K.HEX_LOCKED, "RANK " .. need .. " NEEDED (you're " .. rank .. ")")
	elseif robbable then
		color = C.Cash
		words = name .. "  " .. tint(K.HEX_OPEN, "OPEN")
		-- A prep step first: which one, under OPEN (gold), so nobody finds out at the vault. Once ours is
		-- live: how long the window has left (green: go).
		if prepLocked then
			color = C.Gold
			words = words .. "\n" .. tint(K.HEX_PREP, string.upper(prepW.Lock))
			twoLines = true
		elseif prepW and civilian then
			words = words .. "\n" .. tint(K.HEX_OPEN, prepW.Done .. " " .. clock((site:GetAttribute("PrepUntil") or 0) - t))
			twoLines = true
		end
	elseif site:GetAttribute("TypeOpen") then
		color = C.Dim
		words = tint(K.HEX_SHUT, name .. "  CLOSED " .. clock((site:GetAttribute("ReopenAt") or 0) - t))
	else
		color = C.Dim
		words = tint(K.HEX_SHUT, name .. "  CLOSED")
	end
	if label.Text ~= words then
		label.Text = words
	end
	if rule.BackgroundColor3 ~= color then
		rule.BackgroundColor3 = color
	end
	sizeSign(gui, twoLines)
end

------------------------------------------------------------------ holding a Rob prompt

local startRob -- (below)

-- Put the bar in the Subtitle zone, sitting on its bottom edge; if another piece is using the zone (the
-- tutorial's help line, a mission step, KNOCKED DOWN) the bar stands on top of that piece instead.
local function placeRob()
	local view = ui.gui.AbsoluteSize
	if view.X <= 0 or view.Y <= 0 then
		return
	end
	local touch = Theme.IsTouch()
	local z = Theme.Zone("Subtitle", touch)
	local zw = z.Size.X.Scale * view.X + z.Size.X.Offset
	local zh = z.Size.Y.Scale * view.Y + z.Size.Y.Offset
	local zx = z.Pos.X.Scale * view.X + z.Pos.X.Offset - z.Anchor.X * zw
	local zy = z.Pos.Y.Scale * view.Y + z.Pos.Y.Offset - z.Anchor.Y * zh
	local bottom = zy + zh
	local playerGui = player:FindFirstChild("PlayerGui")
	for _, path in ipairs(K.SUBTITLE_PIECES) do
		local sg = playerGui and playerGui:FindFirstChild(path[1])
		local obj = sg and sg:FindFirstChild(path[2])
		if obj and obj:IsA("GuiObject") and obj.Visible and sg:IsA("ScreenGui") and sg.Enabled then
			-- (measured from that gui's own corner: AbsolutePosition starts under the top bar. The
			-- tutorial's frame is also its goal strip at the top of the screen: only one down here counts.)
			local top = obj.AbsolutePosition.Y - sg.AbsolutePosition.Y
			if top < zy + zh and top + obj.AbsoluteSize.Y > zy - K.ROB_H then
				bottom = math.min(bottom, top - 6)
			end
		end
	end
	ui.rob.Position = UDim2.fromOffset(math.floor(zx + zw / 2), math.floor(bottom))
	ui.rob.Size = UDim2.fromOffset(math.floor(math.min(zw, touch and K.ROB_W_TOUCH or K.ROB_W)), K.ROB_H)
	rob.placedAt = os.clock()
end

-- Fade the bar in (shown) or out, after `pause` seconds. A new fade takes over from one still running.
local function fadeRob(shown, seconds, pause)
	for _, t in ipairs(rob.fades) do
		t:Cancel()
	end
	table.clear(rob.fades)
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, pause or 0)
	local function go(inst, prop, value)
		local t = TweenService:Create(inst, info, { [prop] = value })
		table.insert(rob.fades, t)
		t:Play()
	end
	local text, shadow = shown and 0 or 1, shown and 0.45 or 1
	go(ui.robName, "TextTransparency", text)
	go(ui.robTake, "TextTransparency", text)
	go(ui.robNameShadow, "Transparency", shadow)
	go(ui.robTakeShadow, "Transparency", shadow)
	go(ui.robBar, "BackgroundTransparency", shown and 0.35 or 1)
	go(ui.robFill, "BackgroundTransparency", text)
end

-- The hold is over. done = it ran its full length (the server pays, or says why not): the bar fills
-- and stays a moment, the result stamp is on its way. Let go early: it just fades.
local function endRob(done)
	if not rob.active then
		return
	end
	rob.active = false
	rob.prompt = nil
	rob.token += 1
	local token = rob.token
	ui.robBar.Size = UDim2.new(1, 0, 0, K.BAR_H)
	if done then
		ui.robFill.Size = UDim2.fromScale(1, 1)
		ui.robTake.Text = rob.take and HUDController.Money(rob.take) or "100%"
	end
	local pause, seconds = done and 0.3 or 0, done and 0.45 or 0.25
	fadeRob(false, seconds, pause)
	task.delay(pause + seconds + 0.05, function()
		if rob.token == token then
			ui.rob.Visible = false
		end
	end)
end

-- Every frame while a hold runs, and after it until the camera is back where it belongs. Bound right
-- after Roblox's camera, so the push below is added to wherever that put the camera this frame.
local function robStep(dt)
	local t = os.clock()
	if rob.active then
		local prompt = rob.prompt
		local p = math.clamp((t - rob.began) / rob.hold, 0, 1)
		rob.p = p
		-- (A gunpoint robbery has no prompt: the server's "Done" or "Fail" ends it, or its time runs out.)
		if (prompt and (not prompt.Parent or not prompt.Enabled)) or t - rob.began > rob.hold + (prompt and 1 or 3) then
			-- The prompt went away under the thumb (the store shut, we were moved), or its end never
			-- reached us: no bar may be left hanging.
			endRob(prompt ~= nil and p >= 1) -- (a gunpoint bar the server never answered paid nothing)
		else
			ui.robFill.Size = UDim2.fromScale(p, 1)
			-- The heartbeat: a strong thump and a softer one after it, faster as the end nears.
			rob.phase = (rob.phase + dt * (K.BEAT_SLOW + (K.BEAT_FAST - K.BEAT_SLOW) * p)) % 1
			local x = rob.phase
			local beat = math.exp(-((x - 0.1) / 0.055) ^ 2) + 0.55 * math.exp(-((x - 0.32) / 0.07) ^ 2)
			ui.robBar.Size = UDim2.new(1, 0, 0, K.BAR_H + K.BEAT_SWELL * beat)
			-- The take so far (a prep step has no cash: how far it has got).
			local shown = rob.take and math.floor(rob.take * p / K.TAKE_STEP) * K.TAKE_STEP or math.floor(p * 100)
			if shown ~= rob.shown then
				rob.shown = shown
				ui.robTake.Text = rob.take and (HUDController.Money(shown) .. " ...") or (shown .. "%")
			end
			if t - rob.placedAt >= K.REPLACE_EVERY then
				placeRob() -- (the tutorial's help line may have come or gone)
			end
		end
	end
	-- The camera creeps in while you hold (most of it early on) and eases back out afterwards.
	local want = rob.active and K.PUSH * (1 - (1 - rob.p) ^ 2) or 0
	rob.push += (want - rob.push) * math.min(1, dt * K.PUSH_SPEED)
	local cam = Workspace.CurrentCamera
	if cam and rob.push > 0.005 and cam.CameraType == Enum.CameraType.Custom then
		local cf = cam.CFrame
		local spare = (cam.Focus.Position - cf.Position).Magnitude - K.PUSH_KEEP -- (first person: none)
		local d = math.min(rob.push, spare * 0.5)
		if d > 0.005 then
			cam.CFrame = cf + cf.LookVector * d
		end
	end
	if not rob.active and rob.push <= 0.005 then
		rob.push = 0
		rob.bound = false
		RunService:UnbindFromRenderStep(K.STEP_NAME)
	end
end

-- A Rob or prep hold has begun on this device (prompt), or a clerk is filling the bag at gunpoint
-- (prompt nil, seconds: the fill time).
startRob = function(prompt, site, seconds)
	local def = Heists.Types[site:GetAttribute("HeistId")]
	local prep = prompt ~= nil and prompt.Name == "PrepPrompt"
	-- (setting Club Nova's drill pays nothing yet: a percentage, like a prep step)
	local drillSet = prompt ~= nil and def ~= nil and def.Drill ~= nil and prompt.ActionText ~= "Grab the cash"
	rob.token += 1
	rob.active = true
	rob.prompt = prompt
	rob.began = os.clock()
	rob.hold = math.max(prompt and prompt.HoldDuration or seconds or 1, 0.1)
	rob.take = (not prep and not drillSet and def and def.Payout and def.Payout[1]) or nil
	rob.p, rob.phase, rob.shown = 0, 0, nil
	local name
	if prep then
		name = (def and def.Prep and def.Prep.Object) or prompt.ObjectText
	elseif drillSet then
		name = "SETTING THE DRILL"
	else
		name = site:GetAttribute("Display") or site.Name
	end
	ui.robName.Text = string.upper(tostring(name))
	ui.robTake.Text = ""
	ui.robTake.TextColor3 = rob.take and C.Cash or C.Text
	ui.robFill.Size = UDim2.fromScale(0, 1)
	placeRob()
	ui.rob.Visible = true
	fadeRob(true, 0.2)
	if not rob.bound then
		rob.bound = true
		RunService:BindToRenderStep(K.STEP_NAME, Enum.RenderPriority.Camera.Value + 2, robStep)
	end
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HeistUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- the zone map's coordinates (y = 0 is the very top of the screen)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	ui.gui = gui

	-- The rob bar: [GLOW MART ............ $420 ...] over a slim bar. Built hidden (fadeRob brings it in).
	local frame = Instance.new("Frame")
	frame.Name = "Rob"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Size = UDim2.fromOffset(K.ROB_W, K.ROB_H)
	frame.BackgroundTransparency = 1
	frame.Active = false
	frame.Visible = false
	frame.Parent = gui
	ui.rob = frame
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.AnchorPoint = Vector2.new(0, 1)
	name.Position = UDim2.new(0, 0, 1, -(K.BAR_H + 5))
	name.Size = UDim2.new(0.6, 0, 0, 18)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = ""
	Theme.Text(name, 13, "Bold")
	name.TextColor3 = C.Dim
	name.TextTransparency = 1
	name.Parent = frame
	ui.robName = name
	ui.robNameShadow = Theme.Shadow(name)
	ui.robNameShadow.Transparency = 1
	local take = Instance.new("TextLabel")
	take.Name = "Take"
	take.AnchorPoint = Vector2.new(1, 1)
	take.Position = UDim2.new(1, 0, 1, -(K.BAR_H + 3))
	take.Size = UDim2.new(0.6, 0, 0, 26)
	take.TextXAlignment = Enum.TextXAlignment.Right
	take.Text = ""
	Theme.Text(take, 22, "Display")
	take.TextTransparency = 1
	take.Parent = frame
	ui.robTake = take
	ui.robTakeShadow = Theme.Shadow(take)
	ui.robTakeShadow.Transparency = 1
	ui.robBar, ui.robFill = Theme.Bar(frame, C.Text)
	ui.robBar.AnchorPoint = Vector2.new(0.5, 1)
	ui.robBar.Position = UDim2.fromScale(0.5, 1)
	ui.robBar.Size = UDim2.new(1, 0, 0, K.BAR_H)
	ui.robBar.BackgroundTransparency = 1
	ui.robFill.Size = UDim2.fromScale(0, 1)
	ui.robFill.BackgroundTransparency = 1

	-- The alarm flash: four red edges, each fading out toward the middle of the screen.
	local alarm = Instance.new("Frame")
	alarm.Name = "Alarm"
	alarm.Size = UDim2.fromScale(1, 1)
	alarm.BackgroundTransparency = 1
	alarm.Active = false
	alarm.Visible = false
	alarm.Parent = gui
	ui.alarm = alarm
	ui.alarmEdges = {}
	-- name, anchor (also where it sits), runs across the screen?, gradient turn, solid end last?
	local edges = {
		{ "Top", 0.5, 0, true, 90, false }, { "Bottom", 0.5, 1, true, 90, true },
		{ "Left", 0, 0.5, false, 0, false }, { "Right", 1, 0.5, false, 0, true },
	}
	for i, e in ipairs(edges) do
		local f = Instance.new("Frame")
		f.Name = e[1]
		f.AnchorPoint = Vector2.new(e[2], e[3])
		f.Position = UDim2.fromScale(e[2], e[3])
		f.BackgroundColor3 = C.Danger
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.Active = false
		local fall = Instance.new("UIGradient")
		fall.Rotation = e[5]
		fall.Transparency = e[6] and NumberSequence.new(1, 0) or NumberSequence.new(0, 1)
		fall.Parent = f
		f.Parent = alarm
		ui.alarmEdges[i] = { frame = f, across = e[4] }
	end
end

------------------------------------------------------------------ results

-- Point the GPS at the Hideout through ObjectiveClient (it clears the route once you've banked).
local function routeToHideout()
	local module = script.Parent:FindFirstChild("ObjectiveClient")
	if not module then
		return false
	end
	local ok, Objective = pcall(require, module)
	if not ok or type(Objective) ~= "table" or not Objective.RouteTo then
		return false
	end
	local routed
	ok, routed = pcall(Objective.RouteTo, "Hideout")
	return ok and routed == true
end

-- A big heist (ours or our crew's) just counted: say which heist-locked ride it unlocked, or how far
-- along the next one is. The first value (the save loading) is only remembered.
local function onBigHeists()
	local n = player:GetAttribute("BigHeists")
	local before = lastBigHeists
	lastBigHeists = n
	if type(n) ~= "number" or type(before) ~= "number" or n <= before then
		return
	end
	local unlocked, nextDef
	for _, def in ipairs(Vehicles.List) do
		local need = def.UnlockHeists
		if need and not def.Hidden then
			if need > before and need <= n and not unlocked then
				unlocked = def
			elseif need > n and (not nextDef or need < nextDef.UnlockHeists) then
				nextDef = def
			end
		end
	end
	if unlocked then
		NotifyController.Show("Big heist! The " .. (unlocked.DisplayName or unlocked.Id) .. " is unlocked: buy it at "
			.. (unlocked.Boat and "Marina Boat Sales." or "AutoNeon Motors."), C.Gold, "success")
	elseif nextDef then
		NotifyController.Show("Big heist " .. n .. "/" .. nextDef.UnlockHeists .. " toward the "
			.. (nextDef.DisplayName or nextDef.Id) .. " (" .. (nextDef.Boat and "Marina Boat Sales" or "AutoNeon Motors") .. ").",
			C.Gold, "info")
	end
end

-- The Big Duffel offer (OfferClient waits for a calm moment before it shows it).
local function offerBiggerBag(leftBehind)
	local module = script.Parent:FindFirstChild("OfferClient")
	if module then
		pcall(function()
			require(module).Queue("BagFull", { LeftBehind = leftBehind })
		end)
	end
end

-- A robbery (or a delivered hot car) paid into the bag: the stamp says what to do next, and the GPS
-- is routed there.
local function onResult(result)
	if type(result) ~= "table" then
		return
	end
	local payout = tonumber(result.Payout) or 0
	local wanted = result.Wanted
	if wanted == nil then
		wanted = (player:GetAttribute("Heat") or 0) > 0
	end
	local gps = routeToHideout() and " (GPS set)" or ""
	local nextStep = wanted and ("Lose the cops, then bank it at the Hideout" .. gps)
		or ("Bank it at the Hideout" .. gps)
	if payout > 0 then
		local def = Heists.Types[result.Type]
		local boost = result.Type == "CarBoost"
		local from = def and string.upper(def.Display) or (boost and "HOT CAR" or nil)
		local kicker = from and (from .. "  ·  IN YOUR BAG") or "IN YOUR BAG"
		if result.Cut == true then
			-- A crewmate robbed it and we helped: our share of the pot, no XP (ProgressService gives the
			-- heist XP to the robber alone).
			HUDController.Stamp("YOUR CUT", nextStep, C.Gold, kicker, { Cash = payout, XP = nil })
		else
			-- The headline, the place and the bag on top, then the cash and XP (ProgressService: Heist XP x
			-- the tier, CarBoost XP for a hot car) and what to do next (after who it was split with, if anyone).
			local title = boost and "CAR DELIVERED" or (def and def.Tier >= Heists.BigTier and "HEIST COMPLETE")
				or "ROBBERY COMPLETE"
			local xp = boost and Progression.XP.CarBoost or (def and Progression.XP.Heist * math.max(def.Tier, 1)) or nil
			local helpers = math.floor(tonumber(result.Crew) or 1) - 1
			local sub = nextStep
			if helpers > 0 then
				sub = "Split with " .. helpers .. (helpers == 1 and " crewmate. " or " crewmates. ") .. nextStep
			end
			HUDController.Stamp(title, sub, C.Gold, kicker, { Cash = payout, XP = xp })
		end
	end
	if result.BagFull then
		local left = math.max(0, math.floor(tonumber(result.LeftBehind) or 0)) -- hot cars don't send it
		NotifyController.Show("Bag full!" .. (left > 0 and (" " .. HUDController.Money(left) .. " left behind.") or "")
			.. " Bank your cash at the Hideout before you rob again.", C.Danger, "warning")
		offerBiggerBag(left)
	end
end

-- The heist site a prompt (or anything else) belongs to: its ancestor directly under Workspace.Heists.
local function siteOf(inst)
	local site = inst
	while site and site.Parent ~= siteFolder do
		site = site.Parent
	end
	if site and site:GetAttribute("HeistId") then
		return site
	end
	return nil
end

-- Studs from `pos` to the nearest spot within `range` where this player could start a robbery on foot
-- right now (a Rob point or prep panel whose prompt is showing unlocked), or nil. Seated players are
-- told to get out there (InteractClient, 25 studs: from the street that's mostly an ATM kiosk, since
-- store tills sit 22+ studs behind their shop fronts); the list is at most one pass old.
function HeistClient.NearestRob(pos, range)
	local best
	for i = 1, robCount do
		local spot = robSpots[i]
		if spot and spot.Parent then
			local at = spot:IsA("Attachment") and spot.WorldPosition or (spot:IsA("BasePart") and spot.Position)
			if at then
				local d = (at - pos).Magnitude
				if d <= range and (not best or d < best) then
					best = d
				end
			end
		end
	end
	return best
end

function HeistClient.Init()
	local heists = Workspace:WaitForChild("Heists")
	siteFolder = heists
	build()
	task.spawn(function()
		while true do
			fillCount = 0
			for _, site in ipairs(heists:GetChildren()) do
				if site:GetAttribute("HeistId") then
					local ok, err = pcall(updateSite, site, true)
					if not ok then
						warn("[HeistClient] " .. tostring(err))
					end
				end
			end
			for i = #fillSpots, fillCount + 1, -1 do
				fillSpots[i] = nil -- left over from a longer list two passes ago
			end
			robSpots, fillSpots = fillSpots, robSpots
			robCount = fillCount
			-- A site that's gone (streamed out) takes its prep marker with it: the pass no longer visits it.
			for site, mark in pairs(prepMarks) do
				if site.Parent ~= heists then
					mark.part:Destroy()
					prepMarks[site] = nil
				end
			end
			task.wait(K.PASS_EVERY)
		end
	end)
	-- A prep done, redone or wiped by a robbery (the server's attributes), or our crew changing, locks or
	-- unlocks that vault at once instead of on the next pass: the Rob prompt is there the moment the fuse
	-- box is cut. (A window running out changes no attribute: the pass sees that one.)
	local watched = setmetatable({}, { __mode = "k" })
	local function watchSite(site)
		local def = Heists.Types[site:GetAttribute("HeistId")]
		if watched[site] or not (def and def.Prep) then
			return
		end
		watched[site] = true
		for _, attr in ipairs(K.PREP_ATTRS) do
			site:GetAttributeChangedSignal(attr):Connect(function()
				pcall(updateSite, site, false)
			end)
		end
	end
	for _, site in ipairs(heists:GetChildren()) do
		watchSite(site)
	end
	heists.ChildAdded:Connect(watchSite)
	player:GetAttributeChangedSignal("Crew"):Connect(function()
		for _, site in ipairs(heists:GetChildren()) do
			local def = Heists.Types[site:GetAttribute("HeistId")]
			if def and def.Prep then
				pcall(updateSite, site, false)
			end
		end
	end)
	-- A Rob / prep prompt streaming in is switched right away: the server leaves it on for everybody, so
	-- until the next pass it could show to a cop, or at a closed store, for a moment.
	heists.DescendantAdded:Connect(function(inst)
		if inst:IsA("ProximityPrompt") and (inst.Name == "RobPrompt" or inst.Name == "PrepPrompt") then
			local site = siteOf(inst)
			if site then
				pcall(updateSite, site, false)
			end
		end
	end)
	-- The hold itself (E, gamepad X or a thumb on the prompt): the bar, the take and the camera.
	-- A locked prompt has no hold (a tap asks the server why), so it never starts one.
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		if (prompt.Name == "RobPrompt" or prompt.Name == "PrepPrompt") and prompt.HoldDuration > 0 then
			local site = siteOf(prompt)
			if site then
				startRob(prompt, site)
			end
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		if prompt == rob.prompt then
			endRob(true)
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		if prompt == rob.prompt then
			endRob(os.clock() - rob.began >= rob.hold - 0.1)
		end
	end)
	Remotes.OnClient("HeistPrep", function(info)
		HUDController.Stamp(type(info) == "table" and info.Title or "STEP 1 DONE", type(info) == "table" and info.Text or nil, C.Cash)
	end)
	-- A clerk at gunpoint (HeistService): the bar while they fill the bag, and why it stopped.
	Remotes.OnClient("StoreRob", function(kind, site, a)
		if typeof(site) ~= "Instance" then
			return
		end
		if kind == "Start" and not rob.active then
			startRob(nil, site, tonumber(a) or 6)
		elseif kind == "Done" and rob.active and rob.prompt == nil then
			endRob(true)
		elseif kind == "Fail" then
			if rob.active and rob.prompt == nil then
				endRob(false)
			end
			local text = type(a) == "string" and NotifyController.Messages[a]
			if text then
				NotifyController.Show(text, nil, "warning")
			end
		end
	end)
	-- Clerks: their poses on this device, a gun aimed at one asks for the robbery, and gun owners near a
	-- clerk store are told how it's done.
	task.spawn(function()
		local npcs = Workspace:WaitForChild("NPCs", 30)
		while npcs do
			task.wait(0.25)
			local ok, err = pcall(function()
				local combat = other("CombatClient")
				local aiming, from, look, gunAt = false, nil, nil, nil
				if combat and type(combat.Aiming) == "function" then
					aiming, from, look, gunAt = combat.Aiming()
				end
				local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				for _, m in ipairs(npcs:GetChildren()) do
					local siteName = m:GetAttribute("Site")
					if siteName then
						-- The pose (PoseClient, if it's there).
						local want = m:GetAttribute("Pose")
						local shown = clerkPoses[m]
						if (shown and shown.name or nil) ~= want then
							if shown and shown.handle then
								pcall(function()
									shown.handle:Stop()
								end)
							end
							local handle
							local pose = want and other("PoseClient")
							if pose then
								pcall(function()
									handle = pose.Play(m, want)
								end)
							end
							clerkPoses[m] = want and { name = want, handle = handle } or nil
						end
						local site = siteFolder:FindFirstChild(siteName)
						local head = m:FindFirstChild("Head")
						local siteDef = site and Heists.Types[site:GetAttribute("HeistId")]
						local open = site and (site:GetAttribute("Robbable") == true
							or (siteDef ~= nil and Tutorial.CanRookieRob(player, siteDef.Tier))) -- (a rookie's store)
						if open and head and m:GetAttribute("NPCKind") == "Clerk"
							and player:GetAttribute("Side") == "Civilian" then
							-- (the angle from the crosshair's line, the distance from the gun)
							local to = head.Position - (from or head.Position)
							local reach = (head.Position - (gunAt or head.Position)).Magnitude
							if aiming and not rob.active and reach <= K.CLERK_REACH and to.Magnitude > 1
								and to.Unit:Dot(look) > K.CLERK_CONE and os.clock() - lastClerkAsk >= K.CLERK_ASK_GAP then
								lastClerkAsk = os.clock()
								Remotes.Event("RequestStoreRob"):FireServer(site)
							end
							if not clerkHinted[site] and myRoot and (myRoot.Position - head.Position).Magnitude <= K.HINT_RANGE and ownsGun() then
								clerkHinted[site] = true
								NotifyController.Show(NotifyController.Messages.StoreRobHint, nil, "info")
							end
						end
					end
				end
			end)
			if not ok then
				warn("[HeistClient] clerks: " .. tostring(err))
			end
		end
	end)
	Remotes.OnClient("HeistResult", onResult)
	lastBigHeists = player:GetAttribute("BigHeists")
	player:GetAttributeChangedSignal("BigHeists"):Connect(onBigHeists)
end

return HeistClient
