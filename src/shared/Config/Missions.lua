-- Missions (ModuleScript, ReplicatedStorage.Shared.Config.Missions)
-- Phone missions (PRD Phase 6): short GPS-guided jobs started from the phone's JOBS app.
-- Each mission is a list of steps done in order, all within TimeLimit seconds.
--   { Kind = "Goto", Pos, Radius, Text }            reach the spot (on foot or driving)
--   { Kind = "Hold", Pos, Radius, Seconds, Text }   stay there (stopped) for a few seconds ("snap a photo")
--   { Kind = "Collect", Points = { ... }, Radius, Text }   touch every point, any order
-- Rewards are paid once per mission per day at full rate, then at RepeatShare (so they can't be farmed).
-- Crew preps (Missions.CrewPreps, below) are missions too, played by a whole crew at once.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Heists = require(script.Parent.Heists)

local Missions = {}

Missions.RepeatShare = 0.25
Missions.Cooldown = 20 -- seconds between missions

Missions.List = {
	{
		Id = "PizzaRush",
		Name = "Pizza Rush",
		Blurb = "Grab a pizza at Taco Wave and get it to Palm Hills while it's hot.",
		TimeLimit = 120,
		Cash = 600,
		XP = 60,
		Steps = {
			{ Kind = "Goto", Pos = Vector3.new(1116, 0, 260), Radius = 30, Text = "Pick up the pizza at Taco Wave" },
			{ Kind = "Goto", Pos = Vector3.new(-125, 0, -1177), Radius = 35, Text = "Deliver it to the Palm Hills Swim Club" },
		},
	},
	{
		Id = "PhotoOp",
		Name = "Photo Op",
		Blurb = "A travel blog wants three shots: the Sky Wheel, the lighthouse and the Solana Heights arch.",
		TimeLimit = 300,
		Cash = 800,
		XP = 80,
		Steps = {
			{ Kind = "Hold", Pos = Vector3.new(1650, 0, -400), Radius = 60, Seconds = 2, Text = "Stop near the Solana Sky Wheel for a photo" },
			{ Kind = "Hold", Pos = Vector3.new(2340, 0, -1300), Radius = 60, Seconds = 2, Text = "Stop by the lighthouse on Lighthouse Key" },
			{ Kind = "Hold", Pos = Vector3.new(0, 0, -200), Radius = 45, Seconds = 2, Text = "Snap the Solana Heights arch downtown" },
		},
	},
	{
		Id = "BeachCleanup",
		Name = "Beach Cleanup",
		Blurb = "Litter on Flamingo Beach! Grab all 6 pieces before the tide comes in.",
		TimeLimit = 150,
		Cash = 500,
		XP = 60,
		Steps = {
			{ Kind = "Collect", Radius = 10, Text = "Collect the litter on Flamingo Beach", Points = {
				Vector3.new(1220, 0, -1300), Vector3.new(1380, 0, -1100), Vector3.new(1260, 0, -820),
				Vector3.new(1400, 0, -560), Vector3.new(1240, 0, -200), Vector3.new(1360, 0, 120),
			} },
		},
	},
	{
		Id = "LostFlamingo",
		Name = "Lost Flamingo",
		Blurb = "Someone's lawn flamingo ran away. Find it in the Palm Hills park and bring it to Flo.",
		TimeLimit = 180,
		Cash = 700,
		XP = 70,
		Steps = {
			{ Kind = "Goto", Pos = Vector3.new(-125, 0, -1450), Radius = 30, Text = "Find the lost flamingo in Palm Hills Park" },
			{ Kind = "Goto", Pos = Vector3.new(1180, 0, -900), Radius = 40, Text = "Bring it home to Flo the Flamingo statue" },
		},
	},
	{
		Id = "IslandHop",
		Name = "Island Hop",
		Blurb = "Take a jet ski out to the yacht, round the Key, and back to the pier.",
		TimeLimit = 240,
		Cash = 900,
		XP = 90,
		NeedsBoat = true,
		Steps = {
			{ Kind = "Goto", Pos = Vector3.new(1760, 0, 1250), Radius = 45, Text = "Cruise past the Sea Dream yacht" },
			{ Kind = "Goto", Pos = Vector3.new(2500, 0, -1300), Radius = 60, Text = "Round the tip of Lighthouse Key" },
			{ Kind = "Goto", Pos = Vector3.new(1600, 0, -520), Radius = 45, Text = "Back to the beach pier" },
		},
	},
}

-- Crew preps: the crew job that unlocks The Big Score (CrewService keeps which ones a crew has done, in its
-- save; MissionService.StartCrew runs them). A crew of 2+ plays each one together: everyone on it shares
-- the steps, and a goal only counts once Together crew members are at it at the same time (one car, or a
-- convoy). Started from the phone's CREW app (or the START card when a crew forms), never from JOBS: they
-- are not in Missions.List. Each member is paid Cash and XP (no daily cut: each prep is done once per
-- score; a passed Big Score clears them for the next one).
-- Extra step fields:
--   Place = "Hideout" (Goto / Hold) or Places = { names } (Collect): a spot from MapService's "Places"
--     list instead of a fixed one; Pos / Points hold a stand-in until Missions.Resolve swaps the real
--     spots in.
--   WithinSpeed, WithinSlack: the step must be done within (straight-line studs from the last goal /
--     WithinSpeed + WithinSlack) seconds of it starting (the mission's clock jumps down to that), else
--     the prep fails with TooSlow.
-- Hands-on steps (owner, Nov 7 2026: "more like tasks based, not just drive here... have there be a part that
-- they hold and grab"). Crew preps only; CrewTasks builds the things in the world, MissionService runs them:
--   { Kind = "Pickup", Items = { { Name, Look } ... }, Points / Places, Radius, Text }
--     a thing to grab at each point (Look: CrewTasks' models). A crew member holds its GRAB prompt once
--     Together of the crew are within Radius of it, and carries it (in the hand, more on the back) until it's
--     stashed. Done when every one is carried. A carrier who dies drops it where they fell: grab it again.
--   { Kind = "Deliver", Place / Pos, Radius, Action, Look, Text }
--     a stand there (Look "Crate" or "Desk") with an Action prompt: a carrier holds it to put in what they
--     carry (Together of the crew there). Done when everything the prep's Pickup steps handed out is in.
--   { Kind = "Pair", Place / Pos, Radius, Seconds, Spots = { { Action, Look, Offset }, { ... } }, Text }
--     two prompts a few studs apart (Offset from Pos), each held Seconds: two different crew members must
--     finish them within CrewJob.PairSync seconds of each other ("one keeps watch, one plants the bug").
local BS = Heists.BigScore
Missions.CrewJob = {
	Name = "The Big Score",
	Together = 2, -- crew members who must be at a goal at once (Studio, crew of one: 1)
	Preps = { "PrepGear", "PrepCase", "PrepGetaway" }, -- the order the phone lists them in (any order works)
	Reach = 12, -- studs from a thing to grab, a stand or a pair spot that its prompt counts from (server check)
	PairSync = 8, -- seconds: a Pair step's two holds must finish this close together (6 was tight in the Studio test)
	-- Meeting up (CrewService): a player who joins from an invite card or a crew call is brought to the one who
	-- asked, the two get in one car, and AutoPrep seconds later the crew's next prep starts by itself.
	MeetUp = { Range = 60, AutoPrep = 5, Fade = 0.45 },
}
Missions.CrewPreps = {
	{
		Id = "PrepGear",
		Crew = true,
		Name = "Gear Up",
		Blurb = "Grab the drill parts at Coast Arms, the Chop Shop and Spray & Go, then stash them in the Hideout crate.",
		TimeLimit = 600,
		Cash = 1500,
		XP = 120,
		Steps = {
			{ Kind = "Pickup", Radius = 40, Text = "Grab the drill parts: 3 stops",
				Places = { "Coast Arms", "Chop Shop", "Spray & Go" },
				Points = { Vector3.new(1116, 0, 260), Vector3.new(-200, 0, 1862), Vector3.new(0, 0, -200) },
				Items = { { Name = "Drill bits", Look = "Case" }, { Name = "Drill motor", Look = "Motor" },
					{ Name = "Power pack", Look = "Battery" } } },
			{ Kind = "Deliver", Place = "Hideout", Pos = BS.VanSpot, Radius = 40, Action = "Stash parts", Look = "Crate",
				Text = "Stash the parts in the crate at the Hideout" },
		},
	},
	{
		Id = "PrepCase",
		Crew = true,
		Name = "Case the Joint",
		Blurb = "Bug the Ironclad depot (one keeps watch, one plants it), swipe a guard's keycard at the Gold Reserve, then copy it at the Hideout.",
		TimeLimit = 540,
		Cash = 1500,
		XP = 120,
		Steps = {
			-- (the depot's gate is on its south side, about 70 studs from where the van parks)
			{ Kind = "Pair", Pos = BS.VanSpot + Vector3.new(0, 0, 76), Radius = 45, Seconds = 3,
				Text = "Bug the depot: one keeps watch, one plants the bug",
				Spots = { { Action = "Keep watch", Look = "Lookout", Offset = Vector3.new(-7, 0, 0) },
					{ Action = "Plant bug", Look = "FuseBox", Offset = Vector3.new(7, 0, 0) } } },
			{ Kind = "Pickup", Radius = 45, Text = "Swipe the guard's keycard at the Gold Reserve gate",
				Points = { BS.Street }, Items = { { Name = "Keycard", Look = "Keycard" } } },
			{ Kind = "Deliver", Place = "Hideout", Pos = BS.VanSpot, Radius = 40, Action = "Copy keycard", Look = "Desk",
				Text = "Copy the keycard at the Hideout" },
		},
	},
	{
		Id = "PrepGetaway",
		Crew = true,
		Name = "Getaway Run",
		Blurb = "Fit fake plates at Spray & Go (one holds, one screws), grab the getaway bag outside the Gold Reserve, then race it to the Hideout.",
		TimeLimit = 600,
		Cash = 1500,
		XP = 120,
		Steps = {
			{ Kind = "Pair", Place = "Spray & Go", Pos = Vector3.new(0, 0, -200), Radius = 45, Seconds = 3,
				Text = "Fake plates: one holds the plate, one screws it on",
				Spots = { { Action = "Hold plate", Look = "Plate", Offset = Vector3.new(-5, 0, 0) },
					{ Action = "Screw it on", Look = "Toolbox", Offset = Vector3.new(5, 0, 0) } } },
			{ Kind = "Pickup", Radius = 45, Text = "Grab the getaway bag outside the Gold Reserve gate",
				Points = { BS.Street }, Items = { { Name = "Getaway bag", Look = "Bag" } } },
			{ Kind = "Deliver", Place = "Hideout", Pos = BS.VanSpot, Radius = 40, Action = "Stash bag", Look = "Crate",
				Text = "Race the bag to the Hideout before the cops show!",
				WithinSpeed = 40, WithinSlack = 40, TooSlow = "Too slow: the cops would've caught you" },
		},
	},
}

Missions.ById = {}
for _, m in ipairs(Missions.List) do
	Missions.ById[m.Id] = m
end
for _, m in ipairs(Missions.CrewPreps) do
	Missions.ById[m.Id] = m
end

-- Swap a mission's Place / Places names for the spots in MapService's "Places" list (ReplicatedStorage
-- attribute: JSON { n = name, x, z, ... }, the first entry of each name). The server and every device read
-- the same list, so they agree on the spots. Until the list is there it changes nothing (the stand-ins
-- stay) and tries again next time; once it has worked it's a no-op. Returns the mission.
function Missions.Resolve(m)
	if type(m) ~= "table" or m.Resolved then
		return m
	end
	local raw = ReplicatedStorage:GetAttribute("Places")
	if type(raw) ~= "string" then
		return m
	end
	local ok, list = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(list) ~= "table" then
		return m
	end
	local spots = {}
	for _, p in ipairs(list) do
		if type(p) == "table" and type(p.n) == "string" and spots[p.n] == nil and tonumber(p.x) and tonumber(p.z) then
			spots[p.n] = Vector3.new(tonumber(p.x), 0, tonumber(p.z))
		end
	end
	for _, step in ipairs(m.Steps) do
		if step.Place and spots[step.Place] then
			step.Pos = spots[step.Place]
		end
		for i, name in ipairs(step.Places or {}) do
			if spots[name] and step.Points then
				step.Points[i] = spots[name]
			end
		end
	end
	m.Resolved = true
	return m
end

return Missions
