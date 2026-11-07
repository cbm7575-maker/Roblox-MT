# 22. Crew call: INVITE EVERYONE HERE (Nov 6, 2026)

**Status:** **LIVE as v16** (published Nov 7 2026, 04:36 UTC, on top of v15). The owner asked for no server restart
("don't make everyone leave the game"): running servers keep v15 until they empty, and new servers get v16.

## What the owner asked for

> "When you want to find a crew in the game... could there be another button that says invite people from server...
> then it'll pop up in the chat, someone wants to start a crew, start a heist. And anyone can click on I want to
> start a heist with you."

## How it works

- **The button:** PHONE > CREW has **INVITE EVERYONE HERE** under INVITE FRIENDS. It's for free-roam players; it
  reads CREW CALL SENT while your call is open.
- **The chat line:** everyone else in the server sees, in Roblox's chat, *"[CREW CALL] NAME wants to start a heist!
  Tap I'M IN to join their crew."* If the caller already has a crew, it reads "NAME's crew (2/4)".
- **The card:** every free-roam player with no crew also gets a card in the crew-invite spot: CREW CALL,
  "NAME wants to start a heist! Join their crew: The Big Score pays $48,000+ each.", with **I'M IN** and **NO
  THANKS**. It never replaces a crew invite that's waiting.
- **Joining:**
  - I'M IN puts you in the caller's crew. If the caller had no crew, it becomes a new crew with the CREW UP! job.
  - The first answers win, up to 4 in the crew.
  - The caller gets *"NAME answered your crew call and joined your crew!"*.
- **Joining later from the phone:** while the call is open, PHONE > CREW > PLAYERS HERE shows **I'M IN** next to
  the caller's name ("Wants to start a heist!").
- **Limits:**
  - A call is open for 60 s, or until the crew is full; then every card goes away.
  - One open call per player, and 90 s between calls (no chat spam).
  - Cops can't call.
  - "Nobody here is free to join" when there's nobody to send it to.
- **Analytics:** `CrewCall` (value = players who got the card) and `CrewCallJoined` (value = the crew's size).

## Files

- `CrewService`: `CrewService.Call`, `CrewService.AnswerCall`, and the request actions "Call" / "CallJoin".
- `CrewClient`: the chat line, the card, closing it, and the "answered" toast.
- `NotifyController`: the six refusal and confirmation toasts.
- `PhoneUI`: the button, and I'M IN in PLAYERS HERE.
- `tools/logic-tests/crew.sh`: three new scenarios.

## Tests

- `tools/logic-tests/crew.sh`: **113 PASS** (89 before). The new checks cover:
  - who gets the card (not cops, not players in a crew, not the caller);
  - the first answer forming the crew and the job;
  - the caller hearing who answered;
  - joining up to 4, a full crew closing the call, and a fifth answer being too late;
  - cops refused, one open call at a time, the call running out after 60 s, the 90 s wait;
  - leaving the server closing the call, and "nobody free" refusing without sending.
- All the other suites still pass: spin 74, coastguard 46, policeheli 51, robberbots 93, crewtip 30, shop 13,
  datastore 26, businesses 568.
- **Studio, Server + 2 clients (scratch copy, Nov 6):**

| Check | Result |
|---|---|
| Player1: PHONE > CREW shows INVITE EVERYONE HERE | PASS |
| Tapping it: the phone closes, "Crew call sent! ..." | PASS |
| Player2: the CREW CALL card with I'M IN / NO THANKS, and the chat badge | PASS |
| Player2's chat: "[CREW CALL] Player1 wants to start a heist! Tap I'M IN to join their crew." | PASS |
| Player2 taps I'M IN: both in one crew (server attribute), crew name tags, "Crew updated!" | PASS |
| Player1: "Player2 answered your crew call and joined your crew!" | PASS |
| The call closed by itself after 60 s | PASS |

  Screenshots: `22-crew-call-card.jpg` and `22-crew-call-chat.jpg`.

## Publish (v16)

- The live place (v15) was opened in its own window. All 156 live scripts matched git HEAD 5de195a.
- Only the 4 changed files were synced. After the sync only those 4 differed (158 scripts with DevSync and
  DesignDoc).
- File > Publish: "Publish succeeded ... v16". No restart.
