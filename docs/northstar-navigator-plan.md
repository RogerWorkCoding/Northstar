# Northstar Navigator: a module that does things on your Mac

Name: **Northstar Navigator** (chosen by Roger, Oct 19, 2026). The Mac program it installs is the
"Navigator" app.
Decided with Roger, Oct 19, 2026: build it as a **module** (off by default, switched on in
Settings → Modules), and start **early**, for Roger first.

## Why

Northstar helps people decide and move forward. Navigator lets it also **do the work**: find and
tidy files, make lists and summaries, and prepare emails and events for the person to send. That opened
doors for Roger, and the goal is to give the same thing to people who aren't technical, in Northstar's
calm, plain-words, step-by-step way.

## How it works

```
📱 Northstar on iPhone: "Put this week's receipts in my Taxes folder"
        ▼  task goes through the Northstar brain (Supabase), which already exists
🖥 Navigator on the Mac: a small Mac program, always on
   ├─ 1st choice: Apple's own app links (Files, Mail, Calendar, Reminders)  fast, reliable
   └─ later: clicks and typing on screen ("computer use")
        ▼
📱 Back on the phone: "Okay to move these 6 files? [Yes] [No]", then "Done ✓"
```

- The iPhone is the remote control. Apple doesn't let iPhone apps control other apps; Mac programs can,
  with the person's permission (Screen Recording + Accessibility, turned on once in Mac Settings).
- Navigator uses Anthropic's developer tools (the Claude API, its agent tools and computer use).
- It's downloaded from mynorthstarlabs.com, not the App Store. Apple's free safety check
  (Developer ID signing + notarization) is still required, and the existing Apple Developer membership covers it.

## What Navigator does in v1 (decided Oct 19, 2026)

**No coding at launch.** No code, no Terminal or commands, no Xcode, GitHub or databases. Coding is the
riskiest thing an AI can do on a computer (one command can wipe a folder, code folders hide keys, and most
people can't read a code change to approve it). It can come back later as an advanced option, once
Navigator has a track record. Roger keeps using Claude for his own coding.

**The v1 rule:** Navigator prepares, you send. It drafts emails and events; the person taps Send or Add.

| Area | What Navigator can do |
|---|---|
| Files and folders | Find things ("Where's my car insurance PDF?"); sort Downloads into folders; rename in bulk (receipts by date and store); move (this week's receipts into Taxes); find duplicates and old files and move them to Northstar Trash after an OK |
| Documents | Summarize ("What does this lease say about pets?"); make lists (every receipt in Taxes with dates and amounts); fill in a document from notes as a new copy; turn notes into a clean document or PDF |
| Email | Write an email or reply in Mail, ready to read and send; find emails; summarize a long thread; save attachments into the right folder |
| Calendar and reminders | Draft events ("Add dentist Tuesday at 3", shown first, the person taps Add); set reminders; find open time |
| Images | Sort images into folders by project; rename AI images with clear names; make a contact sheet PDF of a folder |
| Bigger tasks | Combinations of the above: "Get my taxes ready", "Clean up my Desktop", "Prepare for my meeting" |

**Not in v1:** code, commands, sending, deleting for good, passwords, payments, buying.

## The module switch

- **Settings → Modules → Northstar Navigator**: off by default, like Good Listener.
- The first time it's switched on: a safety notice ("I Understand"), then a link to download the Navigator Mac app.
- Off = Northstar never sends it a task. Navigator can also be paused from its menu bar icon.

## Safety (built in, not just a disclaimer)

| Rule | What it means |
|---|---|
| Asks first | Sending, deleting, buying, posting, installing: always a Yes/No on the phone |
| Never passwords or payments | The person signs in and pays themselves, every time |
| Only chosen folders | The person picks the folders it can use; nothing else |
| A log, and undo | Every step is written down; reversible steps can be undone |
| Stop button | One tap on the phone or Mac stops everything at once |
| No hidden orders | Text on websites, emails and files is information, never instructions |
| Crisis rules first | Same as all of Northstar |

Safety notice draft (first time it's switched on):
> Northstar can act on your Mac when you ask. It always asks before sending, deleting or buying, and it
> never handles passwords or payments. Review what it does: you're in charge, and you can stop it anytime.

## Steps

| Step | Who | What it can do | Effort |
|---|---|---|---|
| 0 | Roger + Claude | Design: the screens on the phone, the Navigator menu bar icon, the approval card | Small |
| 1 | Roger only | The v1 list above: files, documents, email and event drafts, reminders, images | Medium |
| 2 | 3–5 testers | Same, with trusted friends; watch where they get confused | Medium |
| 3 | Everyone | v1 as a paid module in Pro, with pricing that covers the cost of use | Medium |
| 4 | Later | Sending with Face ID, browser tasks, then computer use in other programs | Bigger |
| 5 | Later still | Coding, as an advanced option, after a long safe track record | Bigger |

## Costs to keep in mind

- Each task uses the Claude API. File and document work is cheap; clicking on screen costs more
  (every step is a screenshot the brain reads). Track the cost per task from step 1 so pricing is real.

## Open questions

- Mac only at first. Windows later?
- Which three v1 tasks come first for Roger (decides where step 1 starts).

## Trust and audit

The full trust, audit and approval model is in [navigator-trust-model.md](navigator-trust-model.md). It overrides anything simpler in this plan.
