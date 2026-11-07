# 21. Daily spin wheel + easier first chase (Nov 6, 2026)

**Status:** **LIVE as v14** (published Nov 7 2026, 03:13 UTC = Nov 6 evening, on the owner's "Build world wheel, then
push"). No server restart: servers already running stay on v13 until they empty. Not committed to git yet.
**Then v15** (Nov 7, 03:26 UTC): the business session published the Empire businesses on top of v14. It checked
that the Lucky Wheel scripts survived. Since then every live script (except DesignDoc) equals the working tree, so
the five "live ≠ git" shas listed below are history. Live = the uncommitted working tree.

## Why

Analytics (Nov 6, latest day): 243 players, 241 of them new, 5.9-minute sessions, and almost nobody
came back the next day. The ads bring players in cheaply, but the first few minutes don't hold them.
The owner picked two fixes:

1. "Make the cop slower for the first rob, since people don't understand and it's hard for them."
2. "Spin a wheel once a day... cash, double XP, double money, maybe a free gun, maybe a free car.
   The car would be really hard to get... 1 in 18 odds for the car."

## 1. Rookie chase (the first robbery)

A **rookie** is a citizen who hasn't banked a first bag yet (tutorial step "bank" not done), at 1–2 stars.
Until then the AI police go easy:

| | Normal | Rookie |
|---|---|---|
| Patrol car top speed | 95% of your car | **70%** |
| Head start before the first patrol | 20 s (1★), 14 s (2★) | 20 s (same at 1★) |
| Stars go hollow after | 8 s unseen | **5 s** |
| Heat gone after | 40 s unseen (1★) | **30 s** |
| Officers on foot taser you | yes | **no** (they still cuff someone who stands still) |

- Why the head start isn't longer: the heat starts when the robbery ends, so in the first build (35 s head start,
  15 s escape) a rookie who just drove off was clear before any police car came. Found in the Studio test,
  retuned so a slow police car does show up and can be outrun.
- A toast when the chase starts: *"First job: the cops go easy on you. Drive away and get out of sight to lose them!"*
- Getting arrested before banking keeps you a rookie, so the next try is just as gentle. Skipping the tutorial ends it.
- Player cops are not slowed (only the AI).
- Numbers: `Config/Tutorial.lua` → `Tutorial.Rookie`.
- Analytics: chase ends now log `ChaseEnd_<how>_<radar>_AI_Rookie` for rookie chases. Compare escapes vs arrests.

## 2. Daily spin wheel

- **One free spin per UTC day** (same day line as the login streak, which stays as it is). Never sold for Robux.
- **18 slices of the same size.** The server picks 1–18 at random, so every slice is exactly 1 in 18 and what the
  wheel shows is the real odds:

| Prize | Slices | Odds |
|---|---|---|
| **Solana GT** (the $95,000 supercar) | 1 | 1 in 18 |
| $10,000 | 1 | 1 in 18 |
| Free gun (the next one you don't own that your rank allows: Coast 9 → Squall → Gatorbite → Tarpon Carbine at rank 5) | 2 | 2 in 18 |
| 2X CASH for 30 min of play | 2 | 2 in 18 |
| 2X XP for 30 min of play | 3 | 3 in 18 |
| $5,000 | 2 | 2 in 18 |
| $2,500 | 3 | 3 in 18 |
| $1,000 | 4 | 4 in 18 |

- Already own the Solana GT → $25,000 instead. Own every gun your rank allows → $5,000 instead.
- The car is a dealer car, not the Hypercar pass car, so the wheel doesn't undercut the Robux shop.
- **Boosts count play time only** (offline time doesn't use them up), and a second win adds on.
  - 2X CASH doubles money from playing: police pay, arrests, Big Score, missions, races, drifts, stunts,
    car meets, taxi/courier, Empire jobs, and a **bag banked at the Hideout** (heists, carjacks, chop shop, wallets).
  - Never doubled: Robux cash packs, refunds, the daily streak, goal/tutorial rewards, money from other players.
  - 2X XP doubles every XP gain.
- **Where players spin it: the Lucky Wheel, a real wheel in the city** (owner, Nov 6: "an actual wheel that everyone
  will go to and can spin. People can watch them spin"). The first build's pop-up wheel was replaced by it.
  - It stands in the open plaza east of the downtown citizen spawn: stage centre (-49, 24), facing the spawn. The lot
    was mapped clear (x -77 to -21, z -4 to 52) with a probe of the place on Nov 6.
  - It has a stage, an 18-slice wheel 18 studs across with bulbs round the rim, a "LUCKY WHEEL" sign above with a
    status line, a PRIZES board with the odds, and a podium in front with the SPIN prompt (hold E, 0.4 s).
  - One player spins at a time. Everyone around watches the same spin: the server sends the start time and the
    angles, and every client turns the wheel the same way. The wheel ticks past each slice and the bulbs chase.
  - The sign says "NAME IS SPINNING..." and then "NAME WON <PRIZE>!" for 4 s. The car, or $10,000, goes on everyone's
    city feed: "NAME just won a Solana GT on the Lucky Wheel downtown!"
  - The prompt reads SPIN, WAIT (someone else is spinning) or USED TODAY. Refusals are toasts: busy, used, too far,
    still loading.
  - The plaza is a safe zone (12 studs round the stage), so the crowd can't be robbed.
  - The spinner gets a big stamp, "LUCKY WHEEL · YOU WON" over the prize, then a toast with the next free spin time.
- **How players find it:**
  - Once a spin is ready (after the tutorial, not wanted) one toast says to spin the Lucky Wheel downtown.
  - **PHONE > SPIN** shows today's spin or the countdown, the boosts running, the distance, and a **GPS TO THE LUCKY
    WHEEL** button. There's a red dot on the app while a spin is ready.
  - GPS > FUN lists the Lucky Wheel too, and so does the minimap.
- While a boost is on, a pill under the cash says `2X CASH 29:41`, and doubled payouts toast `2X CASH: +$500 bonus`.
- The prize is paid when the wheel stops (about 6.4 s). If you leave mid-spin, it's paid on your next join.
- Analytics: `Spin_Cash`, `Spin_Car`, `Spin_CarOwned`, `Spin_Gun`, `Spin_GunFallback`, `Spin_BoostCash`, `Spin_BoostXP`.
  Economy events: `spin:*` (TimedReward) and `spinboost:*` (the 2X extras).

## Files

New:
- `src/shared/Config/Spin.lua`
- `src/server/Services/SpinService.lua`
- `src/client/Controllers/SpinClient.lua`
- `tools/logic-tests/spin.sh`

Changed:
- `Config/Tutorial.lua` (Rookie), `HeatService`, `AIPoliceService`, `PoliceOfficerService`, `NotifyController`
  (the rookie chase).
- `EconomyService` (2X CASH), `ProgressService` (2X XP), `Telemetry` (`spin` = TimedReward).
- `CombatService.GiveGun`, `GarageService.Give`.
- `PhoneUI` (the SPIN app).
- `Main.server.lua` / `ClientMain.client.lua` (start order).
- `tools/logic-tests/coastguard.sh` and `policeheli.sh` (their stand-in config needed the new Tutorial table).

Also changed for the Lucky Wheel:
- `MapService` (the GPS place).
- `CombatService` (the plaza safe zone) and `Config/Combat` (`WheelMargin`).
- `FeedController` (`WheelWin`).
- `NotifyController` (the wheel's refusals).

## How v14 was published (Nov 6 evening)

- The live place (v13) was opened in its own Studio window (`-task EditPlace`). Every script's SyncSha was read and
  matched to git:
  - Live had none of the Empire scripts.
  - 15 files were older than HEAD (all the unreleased Empire changes).
  - `Main`, `ClientMain` and `PhoneUI` matched no commit: they were copied out of Studio, byte for byte.
- The publish set was 19 files:
  - Files where live = HEAD went in as the working tree.
  - `CombatService` (live = 9f3681e) and `MapService` (live = 76cbf46) got only this feature's diff patched on.
  - `PhoneUI` got only the SPIN hunks on top of the live copy (sha b6a69ed7).
  - `Main` and `ClientMain` got only the SpinService / SpinClient line. The other session's uncommitted Empire
    start-order change was left out.
- That exact tree (live + the 19) was smoke-tested first in a scratch copy: no start-up errors; spins, the gun,
  2X CASH and the rookie chase all worked; the SPIN page rendered.
- After the sync only those 19 scripts differed from v13 (147 → 150 scripts). Then File > Publish: "Publish
  succeeded ... v14".
- **Live script shas that are NOT in git** (start the next publish from these, not from the repo):
  - `Main` fe40582a02ee
  - `ClientMain` 238a331a1486
  - `PhoneUI` 829a4ef8e05b
  - `CombatService` 5f33fc9f44f8
  - `MapService` 7fe219744062
  - The other 14 publish files are the working tree as of the publish.

## Tests done (offline, Nov 6)

- Every changed file compiles (luau-compile); no new lint warnings.
- `tools/logic-tests/spin.sh`: **74 PASS** after the Lucky Wheel (54 before it). It covers:
  - 18 slices, the car 1 in 18, no prize next to itself;
  - paid only when the wheel stops; one spin a day; ready again after midnight;
  - car given, or $25k if already owned;
  - gun order, the rank-5 Rifle, the $5k fallback;
  - 2X CASH doubles a taxi fare and a banked bag, not the streak, a cash pack, or after 30 min;
  - leaving mid-spin pays on the next join;
  - boosts don't tick while offline, and a second win adds on;
  - who counts as a rookie;
  - the Lucky Wheel: one spinner at a time (busy while it turns and while the result shows), too far from the
    podium, the car and $10,000 on the feed (not $1,000, not an owned car), every slice from every start angle
    stops on itself after 5 to 6 turns.
- All the other suites still pass: coastguard 46, policeheli 51, robberbots 93, crew 89, crewtip 30, shop 13,
  datastore 26, businesses 568.

## Studio test of the Lucky Wheel, Nov 6 late evening (scratch copy, Play Solo, then Server + 2 clients)

| Check | Result |
|---|---|
| The wheel stands in the plaza east of the downtown spawn: sign, 18 slices, bulbs, PRIZES board, podium, SAFE ZONE | PASS |
| Holding E at the podium spins it: the sign says "NIGHTSHIFT_DEV IS SPINNING...", the prompt says WAIT | PASS |
| Stops on the slice the server picked; the prize arrives (Coast 9 in the hotbar); the prompt then says USED TODAY | PASS |
| Stamp "LUCKY WHEEL · YOU WON $10,000 · Cash in your account"; the cash goes up when it stops | PASS |
| The city feed: "NightShift_Dev just won $10,000 on the Lucky Wheel downtown!" | PASS |
| **Two players:** Player2, standing in the plaza, watches Player1's spin turn and stop on the same slice | PASS |
| Player2 sees the sign "PLAYER1 WON A SOLANA GT" and the feed post; Player1 gets "YOU WON SOLANA GT" | PASS |
| The feed said "A SOLANA GT" in capitals: fixed to "a Solana GT" | FIXED |
| The live-plus-mine tree (exactly what v14 publishes) in a scratch copy: no errors; spins, gun, 2X CASH, rookie, phone page | PASS |

## Studio test of the first build, Nov 6 evening (scratch copy of NeonCoast.rbxl + all 156 scripts synced, Play Solo)

Screenshots: `21-spin-wheel-pc-car-win.jpg` (PC) and `21-spin-wheel-phone.jpg` (phone layout).

| Check | Result |
|---|---|
| Rookie: toast "First job: the cops go easy..." on getting 1★ at tutorial step 2 | PASS |
| Rookie: "PATROLS ARRIVE IN" countdown from ~20 s; a patrol came | PASS |
| Rookie: patrol speed capped at 70% (82 studs/s toward a player on foot; 95% would be 114) | PASS |
| Rookie: standing still → arrested (expected: gentle, not immune) | PASS |
| Rookie: unseen → heat gone ~30 s after the robbery, escape XP paid | PASS |
| Wheel opens by itself after the tutorial, standing still | PASS |
| Wheel look: 18 slices, readable labels, odds list, SPIN / LATER | PASS |
| SPIN: turns ~5.5 s, stops inside the slice the server picked, result card matches | PASS ($2,500) |
| Prize paid only when the wheel stops (cash $1,000 → $3,500 at the stop) | PASS |
| "Next free spin in 21h 41m"; second spin the same day refused | PASS |
| PHONE > SPIN: new app, red dot only while a spin is ready, page shows used / ready and running boosts | PASS |
| 2X CASH: pill "2X CASH 29:58" under the cash; taxi $300 → +$600; banked $2,000 bag → +$4,000 | PASS |
| 2X CASH does not double: daily-style $1,000, a $5,000 Robux cash pack, the $25,000 car fallback | PASS |
| 2X CASH toast "✓ 2X CASH: +$150 bonus" above the minimap | PASS |
| 2X XP: pill shows; a 100 XP mission paid 200 | PASS |
| Car slice: SOLANA GT added to the garage; again when owned → "$25,000 instead" | PASS |
| Gun slice: Coast 9 given, in the hotbar | PASS |
| Opens by itself again when a new spin is ready (2nd time), not a 3rd time | PASS |
| LATER closes it and it stays closed | PASS |
| Phone layout (PreviewTouch), ~1066×492 and ~670 wide: wheel and column fit, 44 px buttons | PASS |

Fixed during the test:
- The pointer was gold and vanished on the gold car slice → now white with a thick dark edge, bigger.
- On phones the news-feed cards join the toast stack (DisplayOrder 20) and one drew over the wheel → the wheel
  is now DisplayOrder 21, like the wardrobe, and it doesn't open by itself while the wardrobe is open.
- The rookie head start / escape timing (see above).
- Added `SpinService.ForceNext(i)` (Studio only, does nothing live) to test each prize.

Not covered in Studio:
- A real phone.
- A real car chase with a rookie driving (the speed cap was checked on foot).
- The "boost is over" toast after 30 minutes (logic tests cover the timer).

## Studio test checklist (for a re-test)

In a scratch copy (NeonCoast.rbxl is from v8, so sync the whole working tree first).

**PC:**
1. Play. Pick Civilian. Do the tutorial up to the robbery: rob a 1★ store.
   - The toast "First job: the cops go easy..." shows.
   - The police ETA countdown is ~20 s.
   - The patrol car is clearly slower than your car.
   - Out of sight ~30 s → "You lost the cops!".
   - Server log: `ChaseEnd_Escaped_On_AI_Rookie`.
2. Bank at the Hideout, finish the tutorial.
   - After the welcome stamp, stand still for 3 s: the wheel opens by itself.
3. Look at the wheel:
   - 18 coloured slices with readable words;
   - the gold Solana GT slice at the top;
   - the pointer on top;
   - the odds list on the right.
4. SPIN:
   - it ticks, slows, and stops inside one slice;
   - the result card matches the slice;
   - the cash/gun/car/boost actually arrived;
   - "Next free spin in ...".
5. Force a 2X CASH win (server bar: set `data.spin.day = nil`, then `SpinReady = true`, and repeat; or temporarily
   edit `Spin.Slices`).
   - The pill `2X CASH 29:59` shows under the cash.
   - Do a taxi fare: the toast `2X CASH: +$...` shows and the cash goes up twice the fare.
6. LATER closes it. PHONE > SPIN shows "used" with the countdown. Closing and opening the phone keeps the
   red dot only while a spin is ready.

**Phone layout:**
7. `PreviewTouch = true`, a 667×375 window: the wheel and the column both fit; the text is readable; the
   buttons are tappable.

## Things to watch after launch

- **Day 1 retention:** the main number to move (was ~0%).
- **Average session:** it was 5.9 min.
- **`Tutorial_bank` completion** in the onboarding funnel.
- **`ChaseEnd_*_Rookie`:** escaped vs arrested.
- **The Economy dashboard:** `spin` and `spinboost` sources, so the wheel doesn't flood the economy.
