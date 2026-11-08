-- CrewService (ModuleScript, ServerScriptService.Services.CrewService)
-- Crews: up to 4 players who play together (PRD "Crew" phone app + crew bonus). A crew is SAVED: it's
-- still your crew the next time you play, in any server, until you leave it.
--   * Invite from the phone's CREW app; the other player gets an ACCEPT / NO card (60 s to answer). A
--     player already in another crew is told on the card that joining means leaving theirs (Switch).
--   * Ride, then crew up: after someone has ridden in your car for a little while, RideService offers you
--     (the driver) a "CREW UP?" card that sends them this same invite (CrewService.CanCrewUp says when).
--   * Crewmates see each other's name tags through walls and on the minimap (CrewClient).
--   * Crew bonus: +20% heist cash when a crewmate is within 150 studs (HeistService asks CrewBonus).
--   * Friend bonus: +10% heist cash while any Roblox friend is in the server (attribute FriendBonus).
--     Who is friends with whom is asked from Roblox once per pair when the later one joins and a yes is
--     kept for the session (CrewService.AreFriends; FriendsService's co-op bonus uses it too). Every
--     SWEEP seconds the pairs not known to be friends are asked again: that catches a check that failed
--     and players who became friends while playing.
--   * Crewmates and Roblox friends ride in each other's cars (VehicleService's passenger seat asks
--     CrewService.MayRide: same crew, or friends; in Studio the test players count as friends, as they do
--     for FriendsService's co-op bonus). Each player's in-server friends are published as the player
--     attribute "FriendIds" (",id,id,": the UserIds of the Roblox friends in this server, nil for none) so
--     every device can show the Ride bubble and the RIDE button to exactly those players.
--   * CrewService.Invite(from, target) sends the same invite card as the phone's INVITE button
--     (FriendsService uses it when a friend arrives through a Roblox invite).
--   * Crew call (owner, Nov 7 2026: "another button that says invite people from server... it'll pop up in the
--     chat, someone wants to start a crew, start a heist. And anyone can click on I want to start a heist with
--     you"). PHONE > CREW > INVITE EVERYONE HERE ("Call"): every other player in the server gets a chat line,
--     "[CREW CALL] <name> wants to start a heist!", and every free-roam player with no crew also gets a card
--     with I'M IN (CrewClient). The first to tap I'M IN ("CallJoin", the caller's UserId) join the caller's
--     crew (a new one if the caller has none, with its CREW UP! job), up to MAX_CREW; the call ends when the crew
--     is full, after CALL_SECONDS, or when the caller leaves or stops being a citizen. One open call per player
--     and CALL_GAP seconds between calls. Only for citizens (the crew heist is theirs).
--     Caller attribute "CrewCallUntil" (server time) while their call is open: the phone's PLAYERS HERE shows
--     I'M IN by their name. Remotes CrewCall (server -> every other player) { FromUserId, FromName, Eligible,
--     Seconds, Size } and CrewCallClosed (to all) { FromUserId }; the caller gets CrewJob "CallJoined" { Name }
--     for each player who answers. Refusals are Notify keys: CrewCallCivOnly, CrewCallOpen, CrewCallWait,
--     CrewCallNobody (nobody free to join), CrewCallGone (to someone who answered too late), CrewFull.
--     Telemetry: CrewCall (value = players who got the card), CrewCallJoined (value = the crew's size).
-- The crew job (Config.Missions.CrewJob): every crew has one, The Big Score. Its crew preps
-- (Missions.CrewPreps: driving chores the crew does together, run by MissionService.StartCrew) must all be
-- done before BigScoreService lets the crew start the heist (CrewService.HeistUnlocked); a passed Big
-- Score clears them for the next one (CrewService.ScoreDone). Forming a crew hands it the job (CrewJob
-- "New": a stamp on both screens; CrewClient's heist plan then shows the steps with START and PAUSE
-- HEIST). A prep is started from the plan or the phone ("Prep", prepId) by any crew member who is free:
-- every crewmate here who is free comes along, and it needs Missions.CrewJob.Together of them (Studio: 1).
-- One prep at a time per crew. If a member leaves and fewer than two are left, the crew breaks up and the
-- job goes with it.
-- Meeting up (owner, Nov 7 2026: "If someone accepts the heist that you put out for them, have it where they
-- both spawn in... and they have a car that they get in together and go do things together"). Someone who joins
-- from an invite card (the phone's INVITE, a ride's CREW UP?, a friend's Roblox invite) or a crew call's I'M IN
-- is brought to the one who asked (the host); a saved crew coming back next session is not.
--   * Only when both are citizens, alive, not wanted, not inside a home, a tour or a penthouse room, and not on
--     a mission, race, job shift or the Big Score; and the host isn't in a boat. Else the joiner hears where
--     to find the host instead (CrewJob "Toast" MeetLater { Name }).
--   * The car: the host's own land car if it's out within MeetUp.Range of them; else, with the host on foot, a
--     new one of theirs on the road beside them (their last car if they still own it, else the starter;
--     VehicleService.Spawn: no cooldown, not saved as their pick) with the host in the driver's seat.
--   * The joiner: unless they're already in that car (a ride, then CREW UP?), a short fade (remote CrewMeet
--     { Name }, then { Name, Done = true }; none when they were already within MeetUp.Range), then by the car's
--     passenger door and into that seat (VehicleService.TryRide: crewmates ride); no car or no free seat: on
--     foot beside the host. Both hear it (Toast MeetRide / MeetHere to the joiner, MetUp { Name, Ride } to
--     the host). Telemetry CrewMeetUp (1 = seated together, 0 = on foot).
--   * MeetUp.AutoPrep seconds later the crew's next prep starts by itself (the GPS has somewhere to go at
--     once) if one is left, none is running, the heist isn't paused and both are still free for a prep.
-- PAUSE HEIST ("Pause", true) puts the whole crew's heist on hold: the plan leaves every member's screen
-- (saved: it stays paused next time too) and the progress is kept. RESUME HEIST on the phone ("Pause",
-- false), starting a prep, or a new member joining brings it back. The crew hears who did it (CrewJob
-- "Paused" / "Resumed" { Name }).
-- Saving (DataStore "NeonCoast_Crews_v1"; memory only while DataService saves to memory, ReplicatedStorage
-- SavesOff): key "c_<crewId>" = { members = { userIds }, names = { ["<userId>"] = name }, preps =
-- { [prepId] = true }, scores, created, paused }, key "u_<userId>" = the crewId. A player who joins is put back in
-- their saved crew (a pointer to a crew that's gone, or that no longer lists them, is dropped). Every
-- change is made here at once and written behind it, one write at a time per crew (UpdateAsync, so
-- changes from another server's members merge); every REFRESH seconds each crew with members here is read
-- back (another server's joins, leaves and preps; a crew broken up elsewhere is broken up here too).
-- State: player attribute "Crew" = crew id (string) for members in this server, "CrewRoster" = JSON
-- { { i = userId, n = name } } (the whole saved crew, online or not), "CrewPreps" = ",prepId," list of the
-- preps done ("" for none), "CrewPrepRun" = the prep the crew is playing now (nil when none),
-- "CrewPaused" = true while the crew's heist is paused;
-- ReplicatedStorage attribute "Crews" = JSON { [crewId] = { userIds in this server } } so every client can
-- draw tags.
-- Remotes: RequestCrew(action, arg) with action "Invite" (target userId) | "Accept" | "Decline" | "Leave" |
--          "Prep" (prepId, or nil for the next one not done) | "Pause" (true = pause, false = resume);
--          CrewInvite (server -> client) { FromUserId, FromName, Switch }; CrewMeet (server -> the joiner)
--          { Name, Done } (the meet-up's fade);
--          CrewJob (server -> client) kind, info: "New" / "Joined" { Done, Total, Mates }, "Back" { Done,
--          Total, Mates }, "PrepDone" { Name, Done, Total }, "Ready", "Reset", "Broke" { Name }, "Left"
--          { Name }, "Paused" / "Resumed" { Name }, "Toast" { Key, Done, Total } (CrewClient has the words).
-- Studio: CrewService.Debug(player, what): "solo" (a crew of one, to try the preps alone), "preps" (all
-- done), "reset" (none done). Through DebugService: ["call","CrewService","Debug","$me","preps"].

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Missions = require(ReplicatedStorage.Shared.Config.Missions)
local Remotes = require(ReplicatedStorage.Shared.Util.Remotes)
local RateLimit = require(ReplicatedStorage.Shared.Util.RateLimit)
local Telemetry = require(ServerScriptService.Services.Telemetry)

local CrewService = {}

local MAX_CREW = 4
local INVITE_SECONDS = 60
local CALL_SECONDS = 60 -- a crew call stays open this long
local CALL_GAP = 90 -- seconds between two crew calls from the same player
local BONUS_RANGE = 150
local SWEEP = 300 -- seconds between asks about the pairs not known to be friends
local SWEEP_GAP = 0.2 -- seconds between two of those asks (spreads the web calls out)
local REFRESH = 120 -- seconds between reads of each crew's save (changes made in other servers)
CrewService.CrewBonus = 0.2
CrewService.FriendBonus = 0.1

local JOB = Missions.CrewJob
local MEET = JOB.MeetUp or {}

-- [crewId] = { members = { players in this server }, rec = the saved record (see the header), running = prepId }
local crews = {}
local invites = {} -- [targetPlayer] = { from = player, crewId = id or nil, at = os.clock() }
local calls = {} -- [caller] = os.clock() when their open crew call ends
local lastCall = {} -- [caller] = os.clock() of their last crew call (CALL_GAP)
local friendsOf = {} -- [player] = { [userId] = true } for each Roblox friend in this server
local nextId = 0
local notify, inviteEvent, crewJob, callEvent, callClosed, crewMeet

local Store = {
	ds = nil, -- the DataStore, or nil in memory mode
	memory = nil, -- { [key] = JSON } in memory mode
	queues = {}, -- [crewId] = { write, ... } waiting their turn
	changes = {}, -- [crewId] = how many writes this server has asked for (a refresh that saw it change throws its read away)
}

local function svc(name)
	return require(ServerScriptService.Services:FindFirstChild(name))
end

------------------------------------------------------------------ saving

local function crewKey(id)
	return "c_" .. id
end

local function userKey(userId)
	return "u_" .. tostring(userId)
end

-- A DataStore call with two retries. Returns ok, result.
local function dsCall(fn)
	local err
	for i = 1, 3 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		err = result
		if i < 3 then
			task.wait(i)
		end
	end
	warn("[CrewService] save: " .. tostring(err))
	return false, nil
end

local function storeGet(key)
	if Store.memory then
		local raw = Store.memory[key]
		return true, raw and HttpService:JSONDecode(raw) or nil
	end
	return dsCall(function()
		return Store.ds:GetAsync(key)
	end)
end

-- value nil = remove the key.
local function storeSet(key, value)
	if Store.memory then
		Store.memory[key] = value ~= nil and HttpService:JSONEncode(value) or nil
		return true
	end
	return dsCall(function()
		if value == nil then
			Store.ds:RemoveAsync(key)
		else
			Store.ds:SetAsync(key, value)
		end
	end)
end

-- fn(the saved record or nil) -> the new record, or nil to leave it as it is (fn may run more than once).
local function storeUpdate(key, fn)
	if Store.memory then
		local raw = Store.memory[key]
		local new = fn(raw and HttpService:JSONDecode(raw) or nil)
		if new ~= nil then
			Store.memory[key] = HttpService:JSONEncode(new)
		end
		return true
	end
	return dsCall(function()
		return Store.ds:UpdateAsync(key, fn)
	end)
end

-- Run `write` after this crew's earlier writes (one at a time per crew, in order).
local function persist(id, write)
	Store.changes[id] = (Store.changes[id] or 0) + 1
	local q = Store.queues[id]
	if q then
		table.insert(q, write)
		return
	end
	q = { write }
	Store.queues[id] = q
	task.spawn(function()
		while #q > 0 do
			local ok, err = pcall(table.remove(q, 1))
			if not ok then
				warn("[CrewService] save: " .. tostring(err))
			end
		end
		Store.queues[id] = nil
	end)
end

-- Changes to a saved record, as UpdateAsync transforms (nil = no change: the record is gone, or full).
local Ops = {}
function Ops.add(userId, name)
	return function(rec)
		if type(rec) ~= "table" or type(rec.members) ~= "table" then
			return nil
		end
		if not table.find(rec.members, userId) then
			if #rec.members >= MAX_CREW then
				return nil
			end
			table.insert(rec.members, userId)
		end
		rec.names = type(rec.names) == "table" and rec.names or {}
		rec.names[tostring(userId)] = name
		return rec
	end
end
function Ops.remove(userId)
	return function(rec)
		if type(rec) ~= "table" or type(rec.members) ~= "table" then
			return nil
		end
		local i = table.find(rec.members, userId)
		if i then
			table.remove(rec.members, i)
		end
		if type(rec.names) == "table" then
			rec.names[tostring(userId)] = nil
		end
		return rec
	end
end
function Ops.prep(prepId)
	return function(rec)
		if type(rec) ~= "table" then
			return nil
		end
		rec.preps = type(rec.preps) == "table" and rec.preps or {}
		rec.preps[prepId] = true
		return rec
	end
end
function Ops.score()
	return function(rec)
		if type(rec) ~= "table" then
			return nil
		end
		rec.preps = {}
		rec.scores = (tonumber(rec.scores) or 0) + 1
		return rec
	end
end
function Ops.pause(flag)
	return function(rec)
		if type(rec) ~= "table" then
			return nil
		end
		rec.paused = flag or nil
		return rec
	end
end
function Ops.setPreps(preps)
	return function(rec)
		if type(rec) ~= "table" then
			return nil
		end
		rec.preps = preps
		return rec
	end
end

-- A record read from the save, made safe to use (nil if it isn't a crew record).
local function clean(rec)
	if type(rec) ~= "table" or type(rec.members) ~= "table" then
		return nil
	end
	rec.names = type(rec.names) == "table" and rec.names or {}
	rec.preps = type(rec.preps) == "table" and rec.preps or {}
	rec.scores = tonumber(rec.scores) or 0
	rec.paused = rec.paused == true or nil
	return rec
end

------------------------------------------------------------------ what clients see

local function publish()
	local out = {}
	for id, crew in pairs(crews) do
		local ids = {}
		for _, p in ipairs(crew.members) do
			table.insert(ids, p.UserId)
		end
		out[id] = ids
	end
	ReplicatedStorage:SetAttribute("Crews", HttpService:JSONEncode(out))
end

-- Preps done and how many there are.
local function prepCount(crew)
	local done = 0
	for _, prepId in ipairs(JOB.Preps) do
		if crew.rec.preps[prepId] then
			done += 1
		end
	end
	return done, #JOB.Preps
end

-- The names of everyone else in the crew (saved, online or not).
local function mateNames(crew, except)
	local list = {}
	for _, uid in ipairs(crew.rec.members) do
		if not except or uid ~= except.UserId then
			table.insert(list, tostring(crew.rec.names[tostring(uid)] or "?"))
		end
	end
	return list
end

local function jobInfo(crew, forPlayer)
	local done, total = prepCount(crew)
	return { Done = done, Total = total, Mates = mateNames(crew, forPlayer), Job = JOB.Name }
end

-- The crew's saved roster, preps and running prep, on every member here (the phone's CREW app).
local function publishInfo(crew)
	local roster = {}
	for _, uid in ipairs(crew.rec.members) do
		table.insert(roster, { i = uid, n = tostring(crew.rec.names[tostring(uid)] or "?") })
	end
	local preps = {}
	for _, prepId in ipairs(JOB.Preps) do
		if crew.rec.preps[prepId] then
			table.insert(preps, prepId)
		end
	end
	local rosterJson = HttpService:JSONEncode(roster)
	local prepList = #preps > 0 and ("," .. table.concat(preps, ",") .. ",") or ""
	for _, p in ipairs(crew.members) do
		p:SetAttribute("CrewRoster", rosterJson)
		p:SetAttribute("CrewPreps", prepList)
		p:SetAttribute("CrewPrepRun", crew.running)
		p:SetAttribute("CrewPaused", crew.rec.paused == true or nil)
	end
end

local function clearAttributes(player)
	player:SetAttribute("Crew", nil)
	player:SetAttribute("CrewPos", nil)
	player:SetAttribute("CrewRoster", nil)
	player:SetAttribute("CrewPreps", nil)
	player:SetAttribute("CrewPrepRun", nil)
	player:SetAttribute("CrewPaused", nil)
end

local function tell(player, kind, info)
	if player.Parent == Players then
		crewJob:FireClient(player, kind, info or {})
	end
end

local function toast(player, key, extra)
	local info = { Key = key }
	for k, v in pairs(extra or {}) do
		info[k] = v
	end
	tell(player, "Toast", info)
end

------------------------------------------------------------------ crews

function CrewService.CrewOf(player)
	local id = player:GetAttribute("Crew")
	return id and crews[id] or nil
end

function CrewService.SameCrew(a, b)
	local id = a:GetAttribute("Crew")
	return id ~= nil and id == b:GetAttribute("Crew")
end

-- The crew breaks up: everyone here is told, and its save goes (the other members' pointers are dropped
-- when they next join).
local function breakUp(id, crew, byName)
	crews[id] = nil
	for _, p in ipairs(crew.members) do
		clearAttributes(p)
		tell(p, "Broke", { Name = byName })
	end
	persist(id, function()
		storeSet(crewKey(id), nil)
	end)
	publish()
end

-- `player` leaves their crew for good (LEAVE CREW, or joining another one).
local function leave(player)
	local id = player:GetAttribute("Crew")
	local crew = id and crews[id]
	clearAttributes(player)
	if not crew then
		return
	end
	local i = table.find(crew.members, player)
	if i then
		table.remove(crew.members, i)
	end
	local j = table.find(crew.rec.members, player.UserId)
	if j then
		table.remove(crew.rec.members, j)
	end
	crew.rec.names[tostring(player.UserId)] = nil
	local userId = player.UserId
	persist(id, function()
		storeSet(userKey(userId), nil)
	end)
	Telemetry.Custom(player, "CrewLeft", #crew.rec.members)
	if #crew.rec.members <= 1 then
		breakUp(id, crew, player.DisplayName)
		return
	end
	persist(id, function()
		storeUpdate(crewKey(id), Ops.remove(userId))
	end)
	for _, p in ipairs(crew.members) do
		notify:FireClient(p, "CrewLeft")
		tell(p, "Left", { Name = player.DisplayName })
	end
	if #crew.members == 0 then
		crews[id] = nil -- (the rest of the crew isn't in this server: it lives on in the save)
	else
		publishInfo(crew)
	end
	publish()
end

-- `player` goes offline: off the crew in this server, still in it in the save.
local function goOffline(player)
	local id = player:GetAttribute("Crew")
	local crew = id and crews[id]
	if not crew then
		return
	end
	local i = table.find(crew.members, player)
	if i then
		table.remove(crew.members, i)
	end
	if #crew.members == 0 then
		crews[id] = nil
	end
	publish()
end

-- Pause or resume the crew's heist (see the header). `by` is who did it (nil: say nothing).
local function setPaused(id, crew, paused, by)
	if (crew.rec.paused == true) == paused then
		return
	end
	crew.rec.paused = paused or nil
	persist(id, function()
		storeUpdate(crewKey(id), Ops.pause(paused))
	end)
	publishInfo(crew)
	if by then
		for _, p in ipairs(crew.members) do
			tell(p, paused and "Paused" or "Resumed", { Name = by.DisplayName })
		end
	end
end

local function join(player, crewId)
	local crew = crews[crewId]
	if player:GetAttribute("Crew") == crewId then
		return true
	end
	if not crew or #crew.rec.members >= MAX_CREW then
		return false
	end
	if player:GetAttribute("Crew") then
		leave(player)
	end
	table.insert(crew.members, player)
	if not table.find(crew.rec.members, player.UserId) then
		table.insert(crew.rec.members, player.UserId)
	end
	crew.rec.names[tostring(player.UserId)] = player.DisplayName
	player:SetAttribute("Crew", crewId)
	local userId, name = player.UserId, player.DisplayName
	persist(crewId, function()
		storeUpdate(crewKey(crewId), Ops.add(userId, name))
		storeSet(userKey(userId), crewId)
	end)
	for _, p in ipairs(crew.members) do
		notify:FireClient(p, "CrewJoined")
	end
	setPaused(crewId, crew, false, nil) -- (a new member: the plan comes back for everyone)
	publishInfo(crew)
	publish()
	tell(player, "Joined", jobInfo(crew, player))
	Telemetry.Custom(player, "CrewJoined", #crew.rec.members)
	return true
end

local function newId(leader)
	nextId += 1
	return "c" .. tostring(leader.UserId) .. "x" .. os.time() .. "n" .. nextId
end

-- A new saved crew of these players (the first is the one who invited). Returns its id.
local function create(list)
	local id = newId(list[1])
	local rec = { members = {}, names = {}, preps = {}, scores = 0, created = os.time() }
	local crew = { members = {}, rec = rec }
	crews[id] = crew
	for _, p in ipairs(list) do
		if p:GetAttribute("Crew") then
			leave(p)
		end
		table.insert(crew.members, p)
		table.insert(rec.members, p.UserId)
		rec.names[tostring(p.UserId)] = p.DisplayName
		p:SetAttribute("Crew", id)
	end
	local ids = table.clone(rec.members)
	persist(id, function()
		storeSet(crewKey(id), crew.rec)
		for _, uid in ipairs(ids) do
			storeSet(userKey(uid), id)
		end
	end)
	publishInfo(crew)
	publish()
	return id
end

-- A just-formed crew gets its job: the CREW UP! stamp for everyone (then CrewClient's heist plan).
local function handJob(id)
	local crew = crews[id]
	if not crew then
		return
	end
	for _, p in ipairs(crew.members) do
		tell(p, "New", jobInfo(crew, p))
		Telemetry.Custom(p, "CrewFormed", #crew.rec.members)
	end
end

-- A player who joins: back in their saved crew (see the header). Runs in its own thread (it reads the save).
local function loadFor(player)
	local okU, id = storeGet(userKey(player.UserId))
	-- ("" = no crew: what a dropped pointer is set to, see below)
	if not okU or type(id) ~= "string" or id == "" or player.Parent ~= Players then
		return
	end
	local crew = crews[id]
	local rec = crew and crew.rec
	if not rec then
		local okC, saved = storeGet(crewKey(id))
		if not okC then
			return
		end
		rec = clean(saved)
	end
	if player.Parent ~= Players then
		return
	end
	local userId = player.UserId
	local mine = player:GetAttribute("Crew")
	if mine == id then
		return
	end
	crew = crews[id]
	if mine then
		-- They joined another crew here while this was loading: that means leaving this one.
		if rec and table.find(rec.members, userId) then
			if crew then
				local j = table.find(crew.rec.members, userId)
				if j then
					table.remove(crew.rec.members, j)
				end
				crew.rec.names[tostring(userId)] = nil
			end
			persist(id, function()
				storeUpdate(crewKey(id), Ops.remove(userId))
			end)
			if crew and #crew.rec.members <= 1 then
				breakUp(id, crew, player.DisplayName)
			elseif crew then
				publishInfo(crew)
			end
		end
		return
	end
	if not rec or not table.find(rec.members, userId) or #rec.members < 2 then
		-- Gone, or it doesn't list them any more (they left it in another server): drop the old pointer.
		persist(id, function()
			storeUpdate(userKey(userId), function(old)
				return old == id and "" or nil -- (nil leaves a newer pointer alone)
			end)
		end)
		return
	end
	if not crew then
		crew = { members = {}, rec = rec }
		crews[id] = crew
	end
	if not table.find(crew.members, player) then
		table.insert(crew.members, player)
	end
	if crew.rec.names[tostring(userId)] ~= player.DisplayName then
		-- A new display name since last time: the save shows it to crewmates who aren't here too.
		crew.rec.names[tostring(userId)] = player.DisplayName
		local name = player.DisplayName
		persist(id, function()
			storeUpdate(crewKey(id), Ops.add(userId, name))
		end)
	end
	player:SetAttribute("Crew", id)
	publishInfo(crew)
	publish()
	tell(player, "Back", jobInfo(crew, player))
	for _, p in ipairs(crew.members) do
		if p ~= player then
			notify:FireClient(p, "CrewJoined")
		end
	end
end

-- Read a crew's save back (see the header). Skipped while this server still has writes of its own waiting.
local function refresh(id)
	local crew = crews[id]
	if not crew or Store.queues[id] then
		return
	end
	local changes = Store.changes[id]
	local ok, saved = storeGet(crewKey(id))
	-- (a change made here while it read, even one already written, may be missing from what it read)
	if not ok or crews[id] ~= crew or Store.queues[id] or Store.changes[id] ~= changes then
		return
	end
	local rec = clean(saved)
	if not rec then
		-- Broken up in another server (the last but one member left there). Members here together are still a
		-- crew, though: save them as one again (two or more), or break it up here too.
		if #crew.members >= 2 then
			crew.rec.members, crew.rec.names = {}, {}
			for _, p in ipairs(crew.members) do
				table.insert(crew.rec.members, p.UserId)
				crew.rec.names[tostring(p.UserId)] = p.DisplayName
			end
			persist(id, function()
				storeSet(crewKey(id), crew.rec)
			end)
			publishInfo(crew)
		else
			breakUp(id, crew, nil)
		end
		return
	end
	crew.rec = rec
	-- Anyone here the save doesn't list (it filled up from another server first): out of it.
	for i = #crew.members, 1, -1 do
		local p = crew.members[i]
		if not table.find(rec.members, p.UserId) then
			table.remove(crew.members, i)
			clearAttributes(p)
			tell(p, "Broke", nil)
		end
	end
	if #crew.members == 0 then
		crews[id] = nil
	else
		for _, p in ipairs(crew.members) do
			rec.names[tostring(p.UserId)] = p.DisplayName
		end
		publishInfo(crew)
	end
	publish()
end

------------------------------------------------------------------ the crew job

-- Free for a crew prep: here, free roam, not wanted, and not on a mission, race, job shift or the Big Score.
local function freeForPrep(p)
	if p.Parent ~= Players or p:GetAttribute("Side") ~= "Civilian" or (p:GetAttribute("Heat") or 0) > 0 then
		return false
	end
	if p:GetAttribute("Mission") or p:GetAttribute("RacingId") or p:GetAttribute("JobKind") or p:GetAttribute("BigScore") then
		return false
	end
	local ok, MissionService = pcall(svc, "MissionService")
	return not (ok and MissionService.Active(p))
end

local function nextPrep(crew)
	for _, prepId in ipairs(JOB.Preps) do
		if not crew.rec.preps[prepId] then
			return prepId
		end
	end
	return nil
end

local function prepDone(id, prepId, passed)
	local crew = crews[id]
	if crew and crew.running == prepId then
		crew.running = nil
	end
	if not passed then
		if crew then
			publishInfo(crew)
		end
		return
	end
	persist(id, function()
		storeUpdate(crewKey(id), Ops.prep(prepId))
	end)
	if not crew then
		return
	end
	crew.rec.preps[prepId] = true
	publishInfo(crew)
	local done, total = prepCount(crew)
	local m = Missions.ById[prepId]
	for _, p in ipairs(crew.members) do
		tell(p, done >= total and "Ready" or "PrepDone", { Name = m and m.Name or prepId, Done = done, Total = total })
	end
end

-- (see the header) Start crew prep `prepId` (nil: the next one not done) for `player`'s crew. Says why not.
function CrewService.StartPrep(player, prepId)
	local id = player:GetAttribute("Crew")
	local crew = id and crews[id]
	if not crew then
		toast(player, "NoCrew")
		return false
	end
	if prepId == nil then
		prepId = nextPrep(crew)
		if not prepId then
			toast(player, "AllDone")
			return false
		end
	end
	if type(prepId) ~= "string" or not table.find(JOB.Preps, prepId) then
		return false
	end
	if crew.rec.preps[prepId] then
		toast(player, "PrepDone")
		return false
	end
	if crew.running then
		toast(player, "PrepRunning")
		return false
	end
	if player:GetAttribute("Side") ~= "Civilian" then
		toast(player, "CivOnly")
		return false
	end
	if (player:GetAttribute("Heat") or 0) > 0 then
		toast(player, "WantedStart")
		return false
	end
	if not freeForPrep(player) then
		toast(player, "Busy")
		return false
	end
	local list = { player }
	for _, p in ipairs(crew.members) do
		if p ~= player and freeForPrep(p) then
			table.insert(list, p)
		end
	end
	local min = RunService:IsStudio() and 1 or (JOB.Together or 2)
	if #list < min then
		toast(player, "NeedMate")
		return false
	end
	local ok = svc("MissionService").StartCrew(list, prepId, id, function(passed)
		prepDone(id, prepId, passed)
	end)
	if not ok then
		toast(player, "Busy")
		return false
	end
	crew.running = prepId
	setPaused(id, crew, false, nil) -- (starting a prep is getting back on the heist)
	publishInfo(crew)
	return true
end

-- Has `player`'s crew done every prep? (true without a crew: the Big Score's own crew check refuses that,
-- and Studio's solo test needs it.) Also returns done, total.
function CrewService.HeistUnlocked(player)
	local crew = CrewService.CrewOf(player)
	if not crew then
		return true, 0, #JOB.Preps
	end
	local done, total = prepCount(crew)
	return done >= total, done, total
end

-- A Big Score passed: the crews of these players start over on their preps (for the next score).
function CrewService.ScoreDone(players)
	local seen = {}
	for _, p in ipairs(players) do
		local id = p:GetAttribute("Crew")
		local crew = id and crews[id]
		if crew and not seen[id] then
			seen[id] = true
			crew.rec.preps = {}
			crew.rec.scores += 1
			persist(id, function()
				storeUpdate(crewKey(id), Ops.score())
			end)
			publishInfo(crew)
			for _, mate in ipairs(crew.members) do
				tell(mate, "Reset", jobInfo(crew, mate))
			end
		end
	end
end

------------------------------------------------------------------ meeting up (see the header)

-- A living character's humanoid and root part, or nil.
local function bodyOf(p)
	local char = p.Character
	local hum = char and char.FindFirstChildOfClass and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or hum.Health <= 0 or not root then
		return nil
	end
	return hum, root
end

-- Free to be moved to a crewmate: a citizen with a body, not wanted, not indoors, not busy.
local function meetFree(p)
	if p.Parent ~= Players or p:GetAttribute("Side") ~= "Civilian" or (p:GetAttribute("Heat") or 0) > 0 then
		return false
	end
	for _, name in ipairs({ "InHome", "Touring", "InApartment", "Mission", "RacingId", "JobKind", "BigScore" }) do
		if p:GetAttribute(name) then
			return false
		end
	end
	local ok, MissionService = pcall(svc, "MissionService")
	if ok and MissionService.Active(p) then
		return false
	end
	return bodyOf(p) ~= nil
end

-- The host's car for the crew: their last land car if they still own it and may drive it, else the starter.
local function carFor(host, VehicleService)
	local okT, Teams = pcall(require, ReplicatedStorage.Shared.Config.Teams)
	local team = okT and Teams.BySide and Teams.BySide.Civilian
	local id = team and team.Starter or "Palmetto"
	local last = (VehicleService.LastCarFor and VehicleService.LastCarFor(host, "Civilian")) or host:GetAttribute("LastCar")
	local okV, Vehicles = pcall(require, ReplicatedStorage.Shared.Config.Vehicles)
	local def = okV and type(last) == "string" and Vehicles.ById[last] or nil
	if def and not def.Boat and VehicleService.CanDrive("Civilian", last) then
		local okG, owns = pcall(function()
			return svc("GarageService").Owns(host, last)
		end)
		if (okG and owns) or RunService:IsStudio() then
			id = last
		end
	end
	return id
end

-- Out of whatever seat they're in (their own car stays where it is).
local function unseat(hum)
	local seat = hum.SeatPart
	if seat then
		for _, j in ipairs(seat:GetChildren()) do
			if j:IsA("JointInstance") and j.Part1 and j.Part1:IsDescendantOf(hum.Parent) then
				j:Destroy()
			end
		end
	end
	hum.Sit = false
end

-- (see the header) The crew's next prep, by itself, a few seconds after two of them met up.
local function autoPrep(a, b)
	local delay = MEET.AutoPrep
	if not delay then
		return
	end
	task.delay(delay, function()
		local id = a:GetAttribute("Crew")
		local crew = id and crews[id]
		if not crew or b:GetAttribute("Crew") ~= id or crew.running or crew.rec.paused or not nextPrep(crew) then
			return
		end
		if freeForPrep(a) and freeForPrep(b) then
			CrewService.StartPrep(b, nil)
		end
	end)
end

-- (see the header) `joiner` has just joined `host`'s crew: bring them together in one car.
local function meetUp(joiner, host)
	if joiner == host or not CrewService.SameCrew(joiner, host) then
		return
	end
	if not meetFree(joiner) or not meetFree(host) then
		toast(joiner, "MeetLater", { Name = host.DisplayName })
		return
	end
	local VehicleService = svc("VehicleService")
	local hHum, hRoot = bodyOf(host)
	local jHum, jRoot = bodyOf(joiner)
	local range = MEET.Range or 60
	local seat = hHum.SeatPart
	local car = VehicleService.GetCar(host)
	local chassis = car and car.Parent and car.PrimaryPart
	if not chassis or car:GetAttribute("Boat") == true or (chassis.Position - hRoot.Position).Magnitude > range then
		car = nil
	end
	if seat and not (car and seat:IsDescendantOf(car)) then
		-- Riding in someone else's car, or sitting on a boat or a bench: no crew car here.
		local model = seat:FindFirstAncestorOfClass("Model")
		if model and model:GetAttribute("Boat") == true then
			toast(joiner, "MeetLater", { Name = host.DisplayName })
			return
		end
		car = nil
	elseif not car then
		-- On foot with no car of theirs close by: one on the road beside them, the host at the wheel.
		car = VehicleService.Spawn(host, carFor(host, VehicleService), { IgnoreCooldown = true, Auto = true, Sit = true })
	end
	if car and jHum.SeatPart and jHum.SeatPart:IsDescendantOf(car) then
		autoPrep(joiner, host) -- (a ride, then CREW UP?: already in the car together)
		return
	end
	local together = (jRoot.Position - hRoot.Position).Magnitude <= range
	if not together then
		crewMeet:FireClient(joiner, { Name = host.DisplayName })
	end
	task.delay(together and 0.2 or (MEET.Fade or 0.45), function()
		local hum = bodyOf(joiner)
		local _, hostRoot = bodyOf(host)
		if not hum or not hostRoot or host.Parent ~= Players or not CrewService.SameCrew(joiner, host) then
			if joiner.Parent == Players and not together then
				crewMeet:FireClient(joiner, { Name = host.DisplayName, Done = true })
			end
			return
		end
		if hum.SeatPart then
			unseat(hum)
		end
		local seated = false
		local pseat = car and car.Parent and car:FindFirstChild("PassengerSeat")
		if pseat and pseat:IsA("Seat") and not pseat.Occupant then
			local door = car.PrimaryPart and car.PrimaryPart:FindFirstChild("PassengerDoor")
			local at = door and door:IsA("Attachment") and door.WorldCFrame
				or CFrame.lookAt(pseat.Position + pseat.CFrame.RightVector * 4, pseat.Position)
			joiner.Character:PivotTo(at)
			seated = VehicleService.TryRide(joiner, car) == true
		end
		if not seated and not together then
			joiner.Character:PivotTo(hostRoot.CFrame * CFrame.new(4, 0, 2))
		end
		if not together then
			crewMeet:FireClient(joiner, { Name = host.DisplayName, Done = true })
		end
		toast(joiner, seated and "MeetRide" or "MeetHere", { Name = host.DisplayName })
		toast(host, "MetUp", { Name = joiner.DisplayName, Ride = seated })
		Telemetry.Custom(joiner, "CrewMeetUp", seated and 1 or 0)
		autoPrep(joiner, host)
	end)
end

-- Never lets a meet-up stop a join.
local function bringTogether(joiner, host)
	local ok, err = pcall(meetUp, joiner, host)
	if not ok then
		warn("[CrewService] meet-up: " .. tostring(err))
	end
end

------------------------------------------------------------------ invites

-- Heist bonus multiplier for this player right now (crew nearby, friend in server).
function CrewService.BonusFor(player)
	local bonus = 0
	local crew = CrewService.CrewOf(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if crew and root then
		for _, p in ipairs(crew.members) do
			local r = p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - root.Position).Magnitude <= BONUS_RANGE then
				bonus += CrewService.CrewBonus
				break
			end
		end
	end
	if player:GetAttribute("FriendBonus") then
		bonus += CrewService.FriendBonus
	end
	return bonus
end

-- Send `from`'s crew invite card to `target`. Returns true when sent, else false and the Notify key
-- that tells `from` why (nil when there's nothing to say: no such player, or already crewmates).
function CrewService.Invite(from, target)
	if not target or target == from or target.Parent ~= Players or CrewService.SameCrew(from, target) then
		return false, nil
	end
	local crew = CrewService.CrewOf(from)
	if crew and #crew.rec.members >= MAX_CREW then
		return false, "CrewFull"
	end
	local pending = invites[target]
	if pending and os.clock() - pending.at < INVITE_SECONDS then
		return false, "CrewInvitePending"
	end
	invites[target] = { from = from, at = os.clock() }
	inviteEvent:FireClient(target, { FromUserId = from.UserId, FromName = from.DisplayName,
		Switch = target:GetAttribute("Crew") ~= nil })
	return true
end

-- Would a CREW UP? card make sense for this driver and their rider (RideService asks)? Not crewmates
-- already, room in the driver's crew, both free roam or both police, and no crew invite waiting on the rider.
function CrewService.CanCrewUp(owner, rider)
	if owner == rider or owner.Parent ~= Players or rider.Parent ~= Players or CrewService.SameCrew(owner, rider) then
		return false
	end
	local side = owner:GetAttribute("Side")
	if side == "Prisoner" or rider:GetAttribute("Side") ~= side then
		return false
	end
	local crew = CrewService.CrewOf(owner)
	if crew and #crew.rec.members >= MAX_CREW then
		return false
	end
	local pending = invites[rider]
	return not (pending and os.clock() - pending.at < INVITE_SECONDS)
end

------------------------------------------------------------------ crew calls (see the header)

local function callOpen(caller)
	local ends = calls[caller]
	return ends ~= nil and os.clock() < ends and caller.Parent == Players
end

local function closeCall(caller)
	if calls[caller] then
		calls[caller] = nil
		if caller.Parent == Players then
			caller:SetAttribute("CrewCallUntil", nil)
		end
		callEvent = callEvent or Remotes.Event("CrewCall")
		callClosed = callClosed or Remotes.Event("CrewCallClosed")
		callClosed:FireAllClients({ FromUserId = caller.UserId })
	end
end

-- Who a crew call's card goes to: other citizens with no crew.
local function callable(p, caller)
	return p ~= caller and p:GetAttribute("Side") == "Civilian" and p:GetAttribute("Crew") == nil
end

-- Send `player`'s crew call to the server. Returns true when it went out, else false and the Notify key that says why.
function CrewService.Call(player)
	if player:GetAttribute("Side") ~= "Civilian" then
		return false, "CrewCallCivOnly"
	end
	local crew = CrewService.CrewOf(player)
	if crew and #crew.rec.members >= MAX_CREW then
		return false, "CrewFull"
	end
	if callOpen(player) then
		return false, "CrewCallOpen"
	end
	if lastCall[player] and os.clock() - lastCall[player] < CALL_GAP then
		return false, "CrewCallWait"
	end
	local reach = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if callable(p, player) then
			reach += 1
		end
	end
	if reach == 0 then
		return false, "CrewCallNobody"
	end
	lastCall[player] = os.clock()
	calls[player] = os.clock() + CALL_SECONDS
	player:SetAttribute("CrewCallUntil", game:GetService("Workspace"):GetServerTimeNow() + CALL_SECONDS)
	local size = crew and #crew.rec.members or 1
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			callEvent:FireClient(p, { FromUserId = player.UserId, FromName = player.DisplayName,
				Eligible = callable(p, player), Seconds = CALL_SECONDS, Size = size })
		end
	end
	Telemetry.Custom(player, "CrewCall", reach)
	local ends = calls[player]
	task.delay(CALL_SECONDS + 0.5, function()
		if calls[player] == ends then
			closeCall(player)
		end
	end)
	return true
end

-- `player` answers `caller`'s crew call (I'M IN). Returns true when they're now in the caller's crew.
function CrewService.AnswerCall(player, caller)
	if not caller or caller == player then
		return false
	end
	if not callOpen(caller) or caller:GetAttribute("Side") ~= "Civilian" then
		if caller.Parent == Players then
			closeCall(caller)
		end
		notify:FireClient(player, "CrewCallGone")
		return false
	end
	if CrewService.SameCrew(player, caller) then
		return true
	end
	if player:GetAttribute("Side") ~= "Civilian" then
		notify:FireClient(player, "CrewCallCivOnly")
		return false
	end
	local id = caller:GetAttribute("Crew")
	if id and crews[id] then
		if not join(player, id) then
			notify:FireClient(player, "CrewCallGone")
			closeCall(caller)
			return false
		end
	else
		id = create({ caller, player })
		for _, p in ipairs({ caller, player }) do
			notify:FireClient(p, "CrewJoined")
		end
		handJob(id)
	end
	bringTogether(player, caller)
	local crew = crews[id]
	tell(caller, "CallJoined", { Name = player.DisplayName })
	Telemetry.Custom(player, "CrewCallJoined", crew and #crew.rec.members or 2)
	if not crew or #crew.rec.members >= MAX_CREW then
		closeCall(caller)
	end
	return true
end

local function onRequest(player, action, arg)
	if not RateLimit.Allow(player, "Crew", 2, 4) or type(action) ~= "string" then
		return
	end
	if action == "Invite" then
		local target = type(arg) == "number" and Players:GetPlayerByUserId(arg) or nil
		local sent, why = CrewService.Invite(player, target)
		if sent then
			notify:FireClient(player, "CrewInviteSent")
		elseif why then
			notify:FireClient(player, why)
		end
	elseif action == "Accept" or action == "Decline" then
		local pending = invites[player]
		invites[player] = nil
		if not pending or os.clock() - pending.at > INVITE_SECONDS or not pending.from.Parent then
			return
		end
		if action == "Decline" then
			notify:FireClient(pending.from, "CrewDeclined")
			return
		end
		if CrewService.SameCrew(player, pending.from) then
			return -- crossed invites: already together
		end
		local leader = pending.from
		local id = leader:GetAttribute("Crew")
		if id and crews[id] then
			if not join(player, id) then
				notify:FireClient(player, "CrewFull")
				return
			end
			bringTogether(player, leader)
			return
		end
		id = create({ leader, player })
		for _, p in ipairs({ leader, player }) do
			notify:FireClient(p, "CrewJoined")
		end
		handJob(id)
		bringTogether(player, leader)
	elseif action == "Call" then
		local sent, why = CrewService.Call(player)
		notify:FireClient(player, sent and "CrewCallSent" or why)
	elseif action == "CallJoin" then
		if type(arg) == "number" then
			CrewService.AnswerCall(player, Players:GetPlayerByUserId(arg))
		end
	elseif action == "Leave" then
		leave(player)
	elseif action == "Prep" then
		if arg == nil or type(arg) == "string" then
			CrewService.StartPrep(player, arg)
		end
	elseif action == "Pause" then
		local id = player:GetAttribute("Crew")
		local crew = id and crews[id]
		if crew and type(arg) == "boolean" then
			setPaused(id, crew, arg, player)
		elseif not crew then
			toast(player, "NoCrew")
		end
	end
end

-- Studio test hook (see the header).
function CrewService.Debug(player, what)
	if not RunService:IsStudio() then
		return
	end
	local id = player:GetAttribute("Crew")
	if what == "solo" and not id then
		local newCrew = create({ player })
		tell(player, "New", jobInfo(crews[newCrew], player))
		return
	end
	local crew = id and crews[id]
	if not crew then
		return
	end
	if what == "preps" or what == "reset" then
		local preps = {}
		if what == "preps" then
			for _, prepId in ipairs(JOB.Preps) do
				preps[prepId] = true
			end
		end
		crew.rec.preps = preps
		persist(id, function()
			storeUpdate(crewKey(id), Ops.setPreps(preps))
		end)
		publishInfo(crew)
	end
end

-- Are these two players Roblox friends? (From the cache: asked when the later one joined, then by the sweep.)
function CrewService.AreFriends(a, b)
	local set = friendsOf[a]
	return set ~= nil and set[b.UserId] == true
end

-- May `rider` sit in `owner`'s passenger seat? Crewmates and Roblox friends may (VehicleService adds the
-- side, prison and reach rules), and so may anyone the owner has let in this session (RideService: an
-- accepted INVITE or "let in?" card puts the rider on the owner's "RideIds" attribute, ",id,id,").
-- Studio's test players (Player1, Player2: negative UserIds) count as friends, so riding together can
-- be tried there; set the Workspace attribute "RideAsStrangers" = true to treat them as strangers
-- instead (to try the HOP IN / INVITE cards in a two-player test).
function CrewService.MayRide(rider, owner)
	if rider == owner then
		return false
	end
	if CrewService.SameCrew(rider, owner) or CrewService.AreFriends(rider, owner) then
		return true
	end
	local ids = owner:GetAttribute("RideIds")
	if type(ids) == "string" and string.find(ids, "," .. tostring(rider.UserId) .. ",", 1, true) then
		return true
	end
	return RunService:IsStudio() and rider.UserId < 0 and owner.UserId < 0
		and game:GetService("Workspace"):GetAttribute("RideAsStrangers") ~= true
end

-- The player attribute "FriendIds" (see the header): ",id,id," for the friends of this player in this
-- server, or nil.
local function publishFriends(player)
	local set = friendsOf[player]
	local ids = {}
	if set then
		for id in pairs(set) do
			table.insert(ids, tostring(id))
		end
	end
	table.sort(ids)
	player:SetAttribute("FriendIds", #ids > 0 and ("," .. table.concat(ids, ",") .. ",") or nil)
end

-- Ask Roblox whether a and b are friends and remember a yes (both get the friend bonus). It's a web
-- call that can fail: a failed answer counts as not friends until the next sweep asks again.
local function askPair(a, b)
	local ok, isFriend = pcall(a.IsFriendsWith, a, b.UserId)
	-- Either one may have left while Roblox answered.
	if ok and isFriend and a.Parent == Players and b.Parent == Players then
		friendsOf[a] = friendsOf[a] or {}
		friendsOf[b] = friendsOf[b] or {}
		friendsOf[a][b.UserId] = true
		friendsOf[b][a.UserId] = true
		a:SetAttribute("FriendBonus", true)
		b:SetAttribute("FriendBonus", true)
		publishFriends(a)
		publishFriends(b)
	end
end

-- Friend bonus: any Roblox friend in the same server. A newcomer is asked about everyone here.
local function checkFriends(player)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and not CrewService.AreFriends(player, other) then
			askPair(player, other)
		end
	end
end

-- Every pair still not known to be friends, asked once more (far fewer calls than asking every pair
-- whenever someone leaves).
local function sweep()
	local list = Players:GetPlayers()
	for i, a in ipairs(list) do
		for j = i + 1, #list do
			local b = list[j]
			if a.Parent == Players and b.Parent == Players and not CrewService.AreFriends(a, b) then
				askPair(a, b)
				task.wait(SWEEP_GAP)
			end
		end
	end
end

local function recheckFriendBonus()
	for _, p in ipairs(Players:GetPlayers()) do
		local any = false
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= p and CrewService.AreFriends(p, other) then
				any = true
				break
			end
		end
		p:SetAttribute("FriendBonus", any or nil)
	end
end

function CrewService.Init()
	notify = Remotes.Event("Notify")
	inviteEvent = Remotes.Event("CrewInvite")
	crewJob = Remotes.Event("CrewJob")
	callEvent = Remotes.Event("CrewCall")
	callClosed = Remotes.Event("CrewCallClosed")
	crewMeet = Remotes.Event("CrewMeet")
	Remotes.Event("RequestCrew").OnServerEvent:Connect(onRequest)
	-- Crews are saved where players are (DataService has set SavesOff by now: memory in Studio without API
	-- access, so nothing is written there).
	if ReplicatedStorage:GetAttribute("SavesOff") == true then
		Store.memory = {}
	else
		local ok, ds = pcall(function()
			return DataStoreService:GetDataStore("NeonCoast_Crews_v1")
		end)
		if ok and ds then
			Store.ds = ds
		else
			Store.memory = {}
		end
	end
	Players.PlayerAdded:Connect(function(p)
		task.spawn(checkFriends, p)
		task.spawn(loadFor, p)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(checkFriends, p) -- anyone who joined before this service started (Studio)
		task.spawn(loadFor, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		closeCall(p)
		lastCall[p] = nil
		goOffline(p)
		invites[p] = nil
		for target, inv in pairs(invites) do
			if inv.from == p then
				invites[target] = nil
			end
		end
		friendsOf[p] = nil
		for other, set in pairs(friendsOf) do
			if set[p.UserId] then
				set[p.UserId] = nil
				if other.Parent == Players then
					publishFriends(other)
				end
			end
		end
		task.defer(recheckFriendBonus)
	end)
	task.spawn(function()
		while true do
			task.wait(SWEEP)
			local ok, err = pcall(sweep)
			if not ok then
				warn("[CrewService] friend sweep failed: " .. tostring(err))
			end
		end
	end)
	-- Each crew with members here reads its save back now and then (changes made in other servers).
	task.spawn(function()
		while true do
			task.wait(REFRESH)
			local ids = {}
			for id in pairs(crews) do
				table.insert(ids, id)
			end
			for _, id in ipairs(ids) do
				local ok, err = pcall(refresh, id)
				if not ok then
					warn("[CrewService] refresh failed: " .. tostring(err))
				end
				task.wait(0.5)
			end
		end
	end)
	publish()
	-- Crewmates stream out when far away, so publish each crew member's position (player attribute
	-- "CrewPos" = "x,z") for the minimap. Every player's goes out too, as "MapPos" = "x,z" (the same
	-- 1.5 s beat): the minimap and the big map draw other players from it while their character is
	-- streamed out (MinimapClient / MapClient decide who is shown to whom). nil while there's no body.
	task.spawn(function()
		while true do
			task.wait(1.5)
			for _, crew in pairs(crews) do
				for _, p in ipairs(crew.members) do
					local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					p:SetAttribute("CrewPos", root and string.format("%d,%d", root.Position.X, root.Position.Z) or nil)
				end
			end
			for _, p in ipairs(Players:GetPlayers()) do
				local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
				p:SetAttribute("MapPos", root and string.format("%d,%d", root.Position.X, root.Position.Z) or nil)
			end
		end
	end)
end

return CrewService
