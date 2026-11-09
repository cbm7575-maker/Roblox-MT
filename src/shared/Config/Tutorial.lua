-- Tutorial (ModuleScript, ReplicatedStorage.Shared.Config.Tutorial)
-- The first-session guide, in order: action first (car, rob, bank), the phone last (it opens on GARAGE).
-- Text is what the "NEXT" pill says; Show is where its SHOW ME button points ("OpenHeist" = the nearest
-- heist that's open right now, "Garage" = open the phone on GARAGE, otherwise a place name from
-- MapService). ShowMaxTier (with "OpenHeist"): prefer heists up to this tier; if none is open, the
-- nearest one without a prep job. ServerOnly steps can only be completed by the server.
-- Saves count finished steps (TutorialService), so changing this order needs a step in its migrate().
-- After the last step, new players carry on with the goal chain in Config.Journey.

local Tutorial = {}

Tutorial.Bonus = 500

Tutorial.Steps = {
	{ Id = "car", Text = "Get in your car: walk up to it and press F or E (or tap GET IN)" },
	-- A 1-star store first (Glow Mart, Fuel Stop, ATM), not a 2-star jewellery job.
	{ Id = "rob", Text = "Rob a store with an OPEN sign: hold the ROB button", Show = "OpenHeist", ShowMaxTier = 1 },
	{ Id = "bank", Text = "Lose the cops, then bank your bag at the Hideout", Show = "Hideout", ServerOnly = true },
	{ Id = "phone", Text = "Open your PHONE (tap it or press P): your cars live in GARAGE", Show = "Garage" },
}

-- Rookie chase (owner, Nov 6 2026: "make the cop slower for the first rob, since people don't understand
-- and it's hard for them"). New players left after ~6 minutes, and the tutorial's "lose the cops" step
-- is the first hard thing they meet. Until a citizen has banked a first bag (the "bank" step), and while
-- they're at MaxStars or fewer, the AI police go easy on them:
-- (Everyone else's numbers, by stars, are Config.Wanted; a rookie gets the easier of the two on each line.)
--   SpeedScale   patrol cars drive at most this share of the rookie's car speed (everyone else: 0.8 at 1
--                star, 0.88 at 2)
--   HeadStart    at least this many seconds before the first patrol comes (everyone else: 20 s at 1 star,
--                14 s at 2). Not longer than 20: the heat is added when the robbery ends and the unseen clock
--                starts then, so a longer head start than EscapeAfter would mean no police car ever shows up.
--                A slow car you can outrun is the point, not no chase at all.
--   HollowAfter  seconds unseen before the stars go hollow (everyone else: 5 at 1 star, 6 at 2)
--   EscapeAfter  seconds unseen before the heat is gone (everyone else: 30 at 1 star, 40 at 2)
--   NoTaser      officers on foot don't taser them (they still cuff someone who stands still)
-- A rookie arrested before banking stays a rookie, so the next try is just as gentle.
Tutorial.Rookie = { MaxStars = 2, SpeedScale = 0.7, HeadStart = 20, HollowAfter = 5, EscapeAfter = 30, NoTaser = true }

-- Rookie robbery (Nov 8 2026, after the first ads: of the new players who got into a car, 2 in 3 left
-- before robbing anything). Stores take turns being open (Heists.OpenCount types at a time, 4-6 minutes
-- each, then 2-2.5 minutes shut after every robbery), so a newcomer could be routed across town or reach a
-- store that had just shut. Until a citizen has banked a first bag, and while their bag is empty, every
-- site up to MaxTier (Glow Mart, Fuel Stop, the ATMs) is open for them alone, with a Hold of at most this
-- many seconds. Nothing changes for anyone else: a shut store stays shut for them, and a rookie's robbery
-- of a shut store doesn't start its cooldown. HeistService checks it, HeistClient shows it (OPEN sign,
-- prompt, hold) and TutorialClient routes to the nearest one.
Tutorial.RookieRob = { MaxTier = 1, Hold = 5 }

local BANK_STEP = 0
for i, step in ipairs(Tutorial.Steps) do
	if step.Id == "bank" then
		BANK_STEP = i
	end
end

-- True for a citizen who hasn't banked a first bag yet and isn't past Rookie.MaxStars. Reads the
-- TutorialStep attribute (TutorialService): a player whose save hasn't loaded yet is not a rookie.
function Tutorial.IsRookie(player)
	local step = player:GetAttribute("TutorialStep")
	if type(step) ~= "number" or step >= BANK_STEP then
		return false
	end
	if player:GetAttribute("Side") ~= "Civilian" then
		return false
	end
	return (player:GetAttribute("Heat") or 0) <= Tutorial.Rookie.MaxStars
end

-- True when this player may rob a site of this tier as a rookie (Tutorial.RookieRob): a citizen who
-- hasn't banked a first bag and has nothing in their bag. Leave tier out to ask about the player alone.
-- An arrest empties the bag, so a rookie caught before banking gets the same easy store again.
function Tutorial.CanRookieRob(player, tier)
	if tier ~= nil and tier > Tutorial.RookieRob.MaxTier then
		return false
	end
	local step = player:GetAttribute("TutorialStep")
	if type(step) ~= "number" or step >= BANK_STEP then
		return false
	end
	if player:GetAttribute("Side") ~= "Civilian" then
		return false
	end
	return (player:GetAttribute("Carried") or 0) <= 0
end

return Tutorial
