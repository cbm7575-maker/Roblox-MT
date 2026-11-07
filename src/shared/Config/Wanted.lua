-- Wanted (ModuleScript, ReplicatedStorage.Shared.Config.Wanted)
-- How hard the police try at each star level, all in one table (owner, Nov 7 2026: "The cops actually are
-- very annoying with the 1-star. You need to make sure it's easier to get away with 1-star. And probably 2
-- stars. And once you get to 3 stars, it should be probably as hard as it actually is").
-- Two tiers:
--   1-2 stars, a small crime (a store till, an ATM, a carjack, a street race; 2 stars: Sparkle & Co., Club
--     Nova, a breakout). One patrol car, and only while no player cop is on duty. It's slower than you, and
--     once it has seen you and then lost you (hollow stars), it no longer knows where you are: it searches
--     around where you were last seen (LastSeen) and no new car is sent (AIPoliceService). A short unseen
--     timer clears the stars. No taser at 1 star. Before Nov 7 the car always drove to where you really
--     were, at 95% of your speed, and you had to stay unseen for 40 s (1 star) or 50 s (2 stars).
--   3-5 stars, a big job (the bank, the yacht, stacked crimes): the same as before Nov 7. A pack of cars
--     that always knows where you are and drives at 95% of your car's top speed, two officers in each, the
--     pistols out from 4 stars (PoliceOfficerService) and the helicopter at 5 (PoliceHeliService).
-- One row per star:
--   HeadStart    seconds after the crime before the first patrol comes (AIPoliceService; the PATROLS ARRIVE
--                IN countdown)
--   HollowAfter  seconds unseen before the stars go hollow (HeatService)
--   EscapeAfter  seconds unseen before the stars are gone (HeatService; the LOSING THEM meter). Keep it
--                well over HeadStart: the unseen clock starts at the crime, so a head start as long as this
--                means no patrol ever shows up.
--   CarSpeed     patrol cars and Coast Guard boats drive at most this share of your car's top speed
--   Cars         patrol cars per wanted player (1-2 stars: only while no player cop is on duty)
--   Officers     officers riding in each car (PoliceOfficerService.Board)
--   Search       true: seen and then lost, the patrols search around LastSeen instead of driving to you
--   Taser        officers on foot may taser someone running from them
-- A rookie (Config.Tutorial.Rookie: no bag banked yet, 1-2 stars) gets the easier of these and the
-- Rookie numbers on each line.

local Wanted = {}

Wanted.Stars = {
	{ HeadStart = 20, HollowAfter = 5, EscapeAfter = 30, CarSpeed = 0.8, Cars = 1, Officers = 1, Search = true, Taser = false },
	{ HeadStart = 14, HollowAfter = 6, EscapeAfter = 40, CarSpeed = 0.88, Cars = 1, Officers = 1, Search = true, Taser = true },
	{ HeadStart = 8, HollowAfter = 8, EscapeAfter = 60, CarSpeed = 0.95, Cars = 3, Officers = 2, Search = false, Taser = true },
	{ HeadStart = 4, HollowAfter = 8, EscapeAfter = 70, CarSpeed = 0.95, Cars = 4, Officers = 2, Search = false, Taser = true },
	{ HeadStart = 4, HollowAfter = 8, EscapeAfter = 80, CarSpeed = 0.95, Cars = 5, Officers = 2, Search = false, Taser = true },
}

-- The row for this many stars (anything under 1 reads as 1, over 5 as 5).
function Wanted.For(heat)
	local n = math.floor(tonumber(heat) or 1)
	if n ~= n then -- (NaN)
		n = 1
	end
	return Wanted.Stars[math.clamp(n, 1, #Wanted.Stars)]
end

return Wanted
