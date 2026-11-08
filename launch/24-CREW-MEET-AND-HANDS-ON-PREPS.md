# 24. Crew meet-up and hands-on heist preps (Nov 7-8, 2026)

**Status:** **LIVE as v18** (published Nov 8 2026, 21:37:05 UTC, on top of v17). No server restart: running
servers keep v17 until they empty, and new servers get v18.

## What the owner asked for

> "If someone accepts the heist that you put out for them, have it where they both spawn in, like respawn together,
> and they have a car that they get in together and go do things together of where to go. And have it be more like
> tasks based, not just drive here... there's no parts to grab. I mean, have there be a part that they hold and
> grab or things like that. Could you make that better and push the live when you're done?"

## How it works

### Meeting up (CrewService)

- **When:** you join a crew from an invite card (PHONE > CREW > INVITE, a ride's CREW UP?, a friend's Roblox invite)
  or from a crew call's **I'M IN**. A saved crew coming back next session doesn't count.
- **The move:** the screen fades to black with "MEETING <NAME>", and you're brought to the player who asked (the
  host).
- **The car:**
  - If the host's own car is out within 60 studs, the crew uses it.
  - If the host is on foot with no car nearby, one of theirs appears on the road beside them, with the host at the
    wheel. It's their last car if they still own it, otherwise the starter.
  - You're put by its passenger door and seated.
  - If there's no free seat (a 3rd or 4th member), you stand beside the host.
- **Toasts:**
  - You: "You're riding with NAME: your crew job starts now!"
  - The host: "NAME is in your car: drive, the crew job is on your GPS!"
- **Already together:** if you were already riding in the host's car (ride, then CREW UP?), nobody moves.
- **When there's no meet-up:** if either of you is wanted, a cop or prisoner, inside a home, on a tour, in a
  penthouse room, or busy (a mission, race, job shift or the Big Score), or the host is in a boat, nobody moves.
  You get "You're in NAME's crew! Meet up: their pink tag is on your minimap."
- **Auto-start:** 5 seconds after a meet-up, the crew's next prep starts by itself (Gear Up first), so the GPS has
  somewhere to go at once. It doesn't start if a prep is already running, the heist is paused, or either player is
  busy. QUIT still works.

### Hands-on preps (MissionService + the new CrewTasks)

The three Big Score preps are now jobs with things to grab, carry and put down, not just markers.

| Prep | Steps |
|---|---|
| **Gear Up** | Grab the drill parts at 3 stops: a **drill bits case** at Coast Arms, a **drill motor** at the Chop Shop, a **power pack** at Spray & Go. Then **stash them in the crate** at the Hideout. |
| **Case the Joint** | At the Ironclad depot gate, **one keeps watch, one plants the bug** (two spots, both held at once). Then **swipe the guard's keycard** at the Gold Reserve gate, and **copy it at the desk** in the Hideout. |
| **Getaway Run** | At Spray & Go, **one holds the fake plate, one screws it on**. Then **grab the getaway bag** outside the Gold Reserve gate, and **race it to the Hideout crate** before the clock runs out (the old timed getaway). |

- **Grabbing:**
  - Hold **E** (or tap the prompt on phones) for 0.8 s on the thing, which sits on a gold ring.
  - It counts once 2 of the crew are within the step's radius. Alone: "Stick together: ...".
  - While wanted: "Lose the cops: ...".
- **Carrying:**
  - The first thing goes in your right hand, the rest on your back. Things stay with you in cars.
  - The step line says "1/3 · you carry 1".
  - If you die or respawn while carrying, it drops where you fell, and anyone in the crew grabs it again.
- **Two-person spots:**
  - Two prompts a few studs apart, each held for 3 s, by two different crew members within 8 s of each other.
  - The crew hears "NAME did KEEP WATCH: you hold PLANT BUG now, quick!".
  - "It takes two" if one player tries both; "Too far apart in time" when the first hold runs out.
- **Putting things down:** a carrier holds the crate's or desk's prompt for 1 s. Everything they carry goes in
  ("In it goes! (2/3)"). The prep passes when the last one is in.
- **Other crews:** another crew's prompts don't show on your screen.
- **Unchanged:** pay ($1,500 + 120 XP each per prep), timers, PAUSE HEIST, the heist plan, the Big Score lock and
  reset, and solo phone missions.
- **Analytics:** `CrewMeetUp` (1 = seated together, 0 = on foot); the existing `CrewPrep_*` events.

## Files

- `src/server/Services/CrewTasks.lua` (new): the things in the world (models, rings, prompts, the hand and back
  welds, the crate and desk, the pair spots with lamps) and the timed prompt holds.
- `MissionService`: the step kinds Pickup / Deliver / Pair, carrying and dropping, `MissionService.CrewAct`, the
  items, stand and spots in the "Mission" attribute. A prep leaving the game now clears its things at once.
- `CrewService`: the meet-up (host's car or a new one, seating, fade, auto-start of the next prep), remote
  `CrewMeet`.
- `Config/Missions`: the three preps rewritten as hands-on steps; `CrewJob.Reach`, `PairSync = 8`, `MeetUp`.
- `CrewClient`: the meet-up fade, the new toasts, hiding other crews' prompts, and closing a crew-call card once
  you're in that caller's crew.
- `MissionClient`: markers and GPS on the things, the crate/desk and the pair spots; counts and "you carry N".
- `tools/logic-tests/crew.sh`: a CrewTasks and VehicleService stand-in; walk-based scenarios rewritten for the new
  steps; 5 new scenarios.

## Tests

- **`tools/logic-tests/crew.sh`: 181 PASS** (113 before). The new checks cover:
  - grabbing: alone, out of reach, twice, while wanted, by a stranger (NotYourJob);
  - carrying: hand, then back; a dead carrier dropping it where they fell; grabbing it again;
  - stashing: alone doesn't count, "nothing to stash", the prep passing on the last one;
  - pair holds: one hold counts, "it takes two", a hold too old clears, both together pass;
  - Case the Joint and the timed Getaway Run end to end; a QUIT or leaving the game clearing the world;
  - meet-up: car for the host, joiner seated, fades, toasts, the auto-started prep; wanted joiners not moved;
    a ride then CREW UP? not moved; the host's nearby car used; a 3rd member standing by the host.
- All other suites still pass: businesses 568, coastguard 74, crewtip 30, datastore 26, policeheli 67,
  robberbots 93, shop 13, spin 74.
- **Studio, Server + 2 clients, scratch copy of the place (the full current tree synced), three runs on Nov 7-8:**

| Check | Result |
|---|---|
| Player1 crew call → Player2 taps **I'M IN** on the card | PASS |
| Player2 faded and was moved from ~1,000 studs away; Player1 at the wheel of a Palmetto, Player2 in its passenger seat | PASS |
| Gear Up started by itself ~5 s later; "GEAR UP" intro; 3 parts placed at Coast Arms, Chop Shop, Spray & Go | PASS |
| Real **E hold** grabbed the drill bits; the case visible in Player2's right hand; "1/3 · you carry 1" | PASS |
| HOP IN with the case: still carried in the passenger seat while the car moved | PASS |
| A second part went on the back (UpperTorso weld) | PASS |
| The Hideout crate; stash 1/3, "You're not carrying anything" on a second try, 3/3 passes the prep (+$1,500) | PASS |
| Case the Joint: real E holds on KEEP WATCH, keycard GRAB and COPY KEYCARD; pair finished with Player2 | PASS |
| Getaway Run: plates pair, bag grab, race clock cut to 1:23, stash → all 3 preps done, "Player2 put it in!" | PASS |
| Heist plan panel showed Gear Up and Case the Joint ticked, Getaway Run next | PASS |
| Script errors in the server and both client logs | none |

Screenshots: `24-meet-up-riding.jpg`, `24-carrying-the-case.jpg`, `24-grab-prompt.jpg`.

**Fixed during the test:**
- **A dropped item went back to its first spot.** The ground check cast down from 40 studs and stopped on the Spray
  & Go booth's roof (y 19). It now casts from 8 studs, and a drop under a roof lands where the player fell.
- **Prompts sat at the bottom of the screen**, under the step line and the minimap. The prompts on things, stands
  and pair spots now float 4 studs over the ground.
- **The pair window was tight.** It went from 6 s to 8 s.
- **A crew-call card stayed up** after joining that crew another way. It now closes.

## Publish (v18)

- The live place (v17, "DataModel Loading ... version=17") was opened in its own window.
- **Before the sync:** the 5 existing target scripts matched git HEAD 6268f16 (SyncSha and byte length).
  CrewTasks wasn't there, and ChangeHistoryService:GetCanUndo() was false (no stray edits).
- **The sync:** only my 6 files were synced, with a DevSync clone on port 35178 (5 UPD + NEW CrewTasks). All 6
  were then checked against the new hashes and sizes.
- **Publish:** File > Publish gave "Publish succeeded for placeId 121416734424826 ... Add publish notes to v18". The
  games API shows `updated` 2026-11-08T21:37:05Z. Servers were not restarted.

## Follow-ups (not done here)

- **BusinessClient warning:** `BusinessClient:694` warns 4 times a second for any passenger
  ("attempt to index boolean with 'GetAttribute'"). `car = seat and seat.Name == "DriverSeat" and seat.Parent` is
  `false` in a passenger seat, and the next line calls `car:GetAttribute`. This was already live before this change;
  the meet-up just seats passengers more often. A one-line fix: `car ~= nil and car ~= false`.
- **Phone layout:** not looked at in Studio this time. The prompts are Roblox's own and tappable, and the step line
  and toasts are the existing ones.
