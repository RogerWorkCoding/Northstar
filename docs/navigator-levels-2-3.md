# Navigator Levels 2 and 3

Roger, Oct 19, 2026. Builds on step 1 (docs/navigator-step1.md) and the trust model
(docs/navigator-trust-model.md). Still the v1 rule: **Navigator prepares, you send.** No coding.

## What it can do now

| Level | Ask, for example | What happens | Your OK |
|---|---|---|---|
| 1 Find | "Find my car insurance PDF" | Your Mac searches Desktop, Documents, Downloads | not needed (looks only) |
| 2 Read | "What does my lease say about pets?" | Mac finds the best few files → **you pick one** → Mac reads it → the brain answers from it | **Read it** |
| 3 Email | "Email my insurance card to Sam" | Brain writes the draft, Mac finds the file → **you check the draft and attachment** → Mail opens on the Mac | **Put it in Mail** (you press Send) |
| 3 Event / reminder | "Remind me to renew my registration Friday" | Brain writes it → **you check it** → added on the iPhone (or Mac) | **Add to Calendar / Reminders** |
| — | anything else (send, delete, move, buy, code) | Navigator says kindly it can't do that yet | — |

## The flow

```
 ask ─▶ plan (brain, right away) ─▶ Mac searches ─▶ NEEDS YOUR OK ─▶ Mac finishes ─▶ done
                                                    (pick the file,
                                                     check the draft)
```

Task states: `queued → running → needs_ok → approved → running → done` (or `stopped` / `failed`).
Event and reminder drafts go straight to `needs_ok`; the iPhone adds them with EventKit.

## Safety

- **Nothing is read or drafted before your OK.** The Mac remembers exactly which files it showed you
  (by task), so "read #2" is the file you saw.
- **The file's text is used once and not kept.** The brain answers from it and stores only the answer;
  the record says `kept_file_text: false`.
- **File text is data, not instructions.** The brain is told to ignore anything in a file that tries to
  give it orders.
- **Never sends.** Email drafts open in Mail; you press Send. Events and reminders are added only when
  you tap Add.
- **Stop** works at every stage, including while waiting for your OK.
- **Every step is in the record** (iPhone, brain and Mac), chained so changes show.

## Stop rule for later levels (organizing: move and rename)

When Navigator starts changing files (Level 4), Stop follows this rule (Roger, Oct 19):

1. Stop waits for the current step to finish; a file is never cut off halfway.
2. Every step can be undone; Navigator remembers where each file came from.
3. After Stop: "Stopped after 4 of 6. Here's what I did." with **Undo all** (the big, default button),
   **Keep what's done**, and **Finish the rest**. Closing without choosing leaves it safely stopped.
4. Risky steps (sending) are single steps after your approval: sent or not, never half sent.

## Going live

1. Run `supabase/migrations/20261022_navigator_levels.sql` in the Supabase SQL editor.
2. Deploy `northstar-navigator`.
Both need Roger's "make it live".

## Allow once, Decline, and Always allow (Roger, Oct 19)

- Every OK card says **Allow once** or **Decline**, with a hidden **"Why is Navigator asking?"** reason.
- **Always allow** switches (like modules), all **off** at first: read a file, open email drafts,
  add events, add reminders. On = Navigator goes ahead with the best match and still records it
  ("Went ahead (Always allow is on)"). Turning a switch on or off is itself recorded.
  Stored in `navigator_permissions` (migration 20261023). Sending, deleting and moving always need you.
- **Permissions history**: every Allow, Always allowed and Decline, with its reason on tap.
- **Every stop says why**: you pressed Stop, you chose Decline, Stop on the Mac, or what went wrong.
