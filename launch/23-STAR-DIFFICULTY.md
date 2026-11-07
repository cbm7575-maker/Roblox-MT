# 23. Star difficulty: easy 1-2 stars, real chases from 3 (Nov 7, 2026)

**Status:** **LIVE as v17** (published Nov 7 2026, 18:58:55 UTC, from the live place opened at v16). No
server restart: servers already running stay on v16 until they empty. Committed together with this note, so
git HEAD = live v17.

## Why

The owner, after testing: "The cops actually are very annoying with the 1-star. You need to make sure it's
easier to get away with 1-star. And probably 2 stars. And once you get to 3 stars, it should be probably as
hard as it actually is... make sure that all the stars make sense on how difficult it is."

What made 1 star annoying (before v17):

- The patrol car always drove to where you **really** were, even after it lost sight of you (hollow stars).
  Hiding never worked: it came straight to your hiding spot.
- It drove at 95% of your car's top speed, so you barely pulled away.
- You had to stay unseen for 40 s (1★) or 50 s (2★), with that car homing in the whole time.
- Officers on foot tasered you at 1 star, then cuffed you for a store till.

## The ladder now (all in one table: `src/shared/Config/Wanted.lua`)

| Stars | Typical crime | Head start | Hollow after | Gone after (unseen) | Patrol speed | Cars | Officers/car | Lost you → | Taser |
|---|---|---|---|---|---|---|---|---|---|
| 1★ | store till, ATM, carjack, race | 20 s | **5 s** (was 8) | **30 s** (was 40) | **80%** (was 95) | 1 | 1 | **searches where it last saw you** | **no** |
| 2★ | Sparkle & Co., Club Nova, breakout | 14 s | **6 s** (was 8) | **40 s** (was 50) | **88%** (was 95) | 1 | 1 | **searches where it last saw you** | yes |
| 3★ | bank, yacht | 8 s | 8 s | 60 s | 95% | 3 | 2 | still knows where you are | yes |
| 4★ | stacked crimes | 4 s | 8 s | 70 s | 95% | 4 | 2 | still knows (+ pistols out) | yes |
| 5★ | stacked crimes | 4 s | 8 s | 80 s | 95% | 5 + helicopter | 2 | still knows | yes |

3-5 stars are exactly as before. Rookies (no bag banked yet) get the easier of these numbers and their own
(70% speed, 5 s / 30 s, no taser), as before.

**How the 1-2 star search works** (AIPoliceService):
- The first car is still sent to where you are (the 911 call said where), so a petty crime still gets a chase.
- Once a cop has seen you and then lost you (hollow stars), the car drives to **LastSeen**, then on to road
  crossings within 220 studs of it, at 70% of its chase speed. It doesn't head for you through walls.
- No new car is sent while it searches, and its officers stay in the car (any who were out go back).
- Seen again → the chase is back on. A new crime reported while searching moves the search to the new spot.
- Coast Guard boats do the same on the water (open water within 150 studs of LastSeen).
- Player cops: the shorter 1-2 star timers apply to them too (30 s / 40 s unseen instead of 40 / 50).

## Files (the v17 publish set)

| Script | What changed |
|---|---|
| `ReplicatedStorage.Shared.Config.Wanted` | **new**: the star table |
| `ServerScriptService.Services.HeatService` | hollow / escape timers from the table |
| `ServerScriptService.Services.AIPoliceService` | cars, officers, head start, speed from the table; the 1-2★ search |
| `ServerScriptService.Services.PoliceOfficerService` | no taser at 1★; officers stay in / go back while the car searches |
| `StarterPlayer.StarterPlayerScripts.Controllers.ObjectiveClient` | the STAY HIDDEN fallback countdown uses the table |
| `ReplicatedStorage.Shared.Config.Tutorial` | comments only (rookie vs everyone else) |

Before the sync, all five existing scripts in live v16 were byte-for-byte the same as git HEAD (ec262ae).
After it, every SyncSha matched the working tree.

## Tests

- `tools/logic-tests/coastguard.sh`: 74 PASS (46 old + 28 new: head start and speed by stars, the 1★ search,
  no second car, officers told to stay in, seen again → chase on, 2★ search follows a new report, 3★ still
  tracks through walls, the Coast Guard search).
- `tools/logic-tests/policeheli.sh`: 67 PASS (new: hollow and escape timers for every star, rookies at 1-2★).
- `robberbots.sh` 93 PASS, `spin.sh` 74 PASS (unchanged).
- **Studio Play Solo on the live place (v16 + these files)**, a self-driving server test, dev account:
  - 1★: patrol ETA 20 s, meter 30 s; the car arrived after 20.9 s and saw us at 238 studs. We moved 815 studs
    away: stars hollow after 5.1 s, then the car searched 60-260 studs from where it last saw us; every
    logged sample had it 550+ studs from us (970 by the end). One car the whole time, top speed 67.
  - 3★: ETA 8 s, meter 60 s, three cars, and they drove straight to where we really were (489 → 85 studs in
    6 s). Same as before.
  - 2★: ETA 14 s, meter 40 s.
  - No script errors. Every chase ended with `HeatService.Clear(p, "role")`: no arrest, no escape stats saved.

## What to watch

Analytics from Nov 8: `ChaseEnd_Escaped_*` vs `ChaseEnd_Arrested_*` by stars (the event value is the star
count). 1-2★ escapes should go up; 3★+ should stay about where they were.
