# 26 · Login streak calendar ("come back tomorrow")

Built Nov 9 2026 after the post-ads analytics read. Not live yet: it goes live only on the owner's say-so.

## Why

The first ad campaign (Nov 3-7) brought 1,322 players at 4.8 cents each. Almost none came back:

| | Theft Miami Coast | Action-game median |
|---|---|---|
| Day 1 retention | 0.9-3.9% | about 8% |
| Day 7 retention | 0 | about 1.1% |

About 65% of new players were gone within 5 minutes.

The game already had a login streak paying $1,000 × the day, up to $7,000, with a paint at day 7, plus a daily spin and daily challenges. But a new player only saw the streak as a short stamp when they joined, in the middle of the tutorial. Nothing showed what tomorrow would bring.

## What changed

- **A 7-day calendar card** (DailyClient). It shows the week: done days ticked, today in gold, and TOMORROW outlined in pink, each with its cash and extra. Under that, the line "Come back tomorrow for +$X · unlocks in 5h 12m".
  - **Returning players** see it when the day's reward is paid.
  - **A brand-new player's first day** gets only a short toast while the tutorial runs. The card ("COME BACK TOMORROW", with day 2's reward) comes once the tutorial is done, or after 4 minutes of play. It never shows while the player is wanted or over another stamp.
  - A tap closes it; otherwise it goes after 9 s.
  - PHONE > SPIN now has a LOGIN STREAK row (today's day, tomorrow's reward, a countdown) and a SEE THE WEEK button.
- **Extras on days 2-7** (Config.Daily). The cash is unchanged.

  | Day | Reward |
  |---|---|
  | 1 | $1,000 |
  | 2 | $2,000 + 2X CASH 15 min |
  | 3 | $3,000 + a bonus spin |
  | 4 | $4,000 + 2X XP 30 min |
  | 5 | $5,000 + a bonus spin |
  | 6 | $6,000 + 2X CASH 30 min |
  | 7 | $7,000 + a bonus spin + Streak Sunset paint (first time) |
  | 8+ | the week repeats; cash stays $7,000 |

  - The boosts are the Lucky Wheel's own (they count down on play time only).
  - Bonus spins are kept in the save and used after the day's free spin (SpinService: `data.spin.bonus`, attribute `SpinBonus`).
- **A fairer day rule:** a streak now survives one missed UTC day (`Daily.Grace = 1`). The day line is midnight UTC, which is evening in the Americas, so a player who came back "the next evening" could skip a whole UTC day and lose the streak.
- **Midnight while playing:** a player still in the game when the UTC day turns gets the new day's reward within 30 s, without rejoining.
- **Analytics** (custom events):
  - `Streak_Day`: value = the streak day.
  - `Streak_Broke`: value = the streak that ended.
  - `Streak_BoostCash` / `Streak_BoostXP`: value = minutes.
  - `Spin_Bonus`: a bonus spin used.
  - The cash is still the `daily:day1-7` economy event.

Nothing here is sold for Robux. The streak and the spins are free for everyone, so Roblox's paid random item rules don't apply.

## Files

- New: `src/shared/Config/Daily.lua`, `src/client/Controllers/DailyClient.lua`, `tools/logic-tests/daily.sh`.
- Changed:
  - `src/server/Services/DailyService.lua` (rewritten on the same save fields: `data.daily.last` and `streak`, plus `n` and `best`).
  - `src/server/Services/SpinService.lua` (bonus spins; `GrantBoost` / `AddBonusSpins`).
  - `src/client/Controllers/SpinClient.lua` ("you have a bonus spin left" after a spin).
  - `src/client/Controllers/PhoneUI.lua` (the SPIN page).
  - `src/client/Controllers/ShopClient.lua` (its old streak stamp moved to DailyClient).
  - `src/client/ClientMain.client.lua` (starts DailyClient).

## Tests

- **Offline:** `tools/logic-tests/daily.sh` passes 61 checks covering:
  - the day rules and grace, and the rewards and their words;
  - day 1, then day 2 with the 2X CASH boost;
  - a same-day rejoin paying nothing;
  - the streak ending, with Broke and best;
  - bonus spins (daily first, then the bonus, then refused; and kept to the next day);
  - the day 7 paint and week 2;
  - midnight while online;
  - nothing paid behind the title screen.

  Every other suite still passes: businesses 568, coastguard 74, crew 181, crewtip 30, datastore 26, policeheli 67, robberbots 93, rookierob 49, shop 13, spin 74. Every changed file compiles with no new lint.
- **Studio: PASS, Nov 9 2026 ~10:20 AM MST.** Play Solo in a scratch copy of NeonCoast.rbxl with the full working tree synced and two self-driving test scripts (`DailyTest` / `DailyTestClient`, scratch place only, never in the repo). There were no script errors.

  | Step | Result |
  |---|---|
  | Day 1 | Paid $1,000 with `First = true`. Only a toast while the tutorial ran; the "COME BACK TOMORROW" card came once the tutorial was done ([first-day card](26-first-day-card.jpg)). |
  | Day 2 | $2,000 + 2X CASH (899 s left). |
  | Day 3 | $3,000 + 1 bonus spin. At the wheel, spin 1 used the daily spin (bonus left 1), spin 2 used the bonus (SpinReady false), and spin 3 was refused. |
  | Day 7 | $7,000, bonus spin, paint unlocked. Tomorrow reads $7,000. |
  | PHONE > SPIN | "LOGIN STREAK · DAY 7", tomorrow's reward, NEXT REWARD IN 6h 33m, SEE THE WEEK, and "YOUR SPIN IS READY · 1 BONUS" ([phone page](26-phone-spin-page.jpg)). |
  | SEE THE WEEK | Opens the card. |
  | Phone layout (PreviewTouch) | The day 4 card fits ([phone layout](26-day4-card-phone-layout.jpg)). |

## What to watch after it's live

- Day 1 retention (Creator Hub > Retention, cohorts) against the Nov 4-7 cohorts (0.9-3.9%).
- `Streak_Day` counts by value: how many players reach days 2, 3 and 7.
- Whether the 2X CASH and bonus-spin extras move the economy (the `spinboost:*` and `spin:*` economy events).
