# Subject cards (memory step 4): plan, not built yet

**Status:** design only. The database change below is a **draft** and does not run until Roger says OK.

## The idea (Roger, Oct 13)

Memory should be **one card per subject** that grows, not one card per sentence.

```
BEFORE (today)                         AFTER
──────────────────────                 ──────────────────────────────
I want a logo for my bakery            🎯 Sunrise Loaf bakery
I want a logo for my bakery               Open in May
Logo style: Warm Morning                  Logo: Warm Morning
I need a website for my bakery            Website: ready in April
                                          Next: pick the name font
                                          Updated Oct 13
```

## How it works

```
1. NEW SUBJECT     "Sunrise Loaf bakery — keep this?"   [Keep] [Not now]   ← asked once
2. DECISION        card updates          ✓ Updated · Undo
3. NEXT STEP       card updates          ✓ Updated · Undo
4. COME BACK       "Welcome back. Sunrise Loaf: next is the name font."
5. DONE            "Mark this done?" → moves to Finished
```

- **Notes stay** as the "memory dump". Each note points to its subject, so Search can show the subject.
- **Saves** (the cards we have today) turn into subject updates. No more one-card-per-sentence.
- **Never saved:** feelings, health, money (same rules as now).
- **A choice belongs to what it names.** "Logo: Warm Morning" sits on the card, but it is never applied to the website without asking.

## Where you see it

```
Search Memory
┌──────────────────────────────────────┐
│ 🔍 Type a word or a sentence…        │
└──────────────────────────────────────┘
SUBJECTS
┌──────────────────────────────────────┐
│ 🎯 Sunrise Loaf bakery             › │  ← tap: goal, decisions, next step, Edit, Done
├──────────────────────────────────────┤
│ 🎯 Northstar launch                › │
└──────────────────────────────────────┘
RECENT
( Bakery website ready in April )  ( Dell work laptop… )
```

## Brain changes

- The brain gets the person's active subjects (title + next step) instead of loose saves.
- New reply field `subject`: either `{ match: <id>, update: { decision | next_step | goal } }` or
  `{ new: { title, goal } }`. Validated on the server like everything else.
- A new subject always needs **Keep**. Updates to a kept subject apply right away, with **Undo**.
- The note for each message gets the subject id.

## One open question for Roger

After you tap **Keep** once, should updates to that subject:

- **A.** happen on their own, with an Undo line (fewer taps), or
- **B.** ask each time (more control)?

My recommendation is **A**: it matches "ask once, then the card grows", and Undo is always there.

## Database (draft — not run)

See `supabase/migrations/DRAFT_subjects.sql.txt`. It adds one table and one column. Nothing existing is changed or deleted.
