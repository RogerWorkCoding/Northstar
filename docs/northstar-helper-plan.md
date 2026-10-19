# Northstar Helper: a module that does things on your Mac

Working name: **Northstar Helper** (the name can change).
Decided with Roger, Oct 19, 2026: build it as a **module** (off by default, switched on in
Settings → Modules), and start **early**, for Roger first.

## Why

Northstar helps people decide and move forward. The Helper lets it also **do the work**: organize
files, write and build code, save to GitHub, fill in a web form, click through a program. That opened
doors for Roger, and the goal is to give the same thing to people who aren't technical, in Northstar's
calm, plain-words, step-by-step way.

## How it works

```
📱 Northstar on iPhone: "Add a Share button to the journal screen"
        ▼  task goes through the Northstar brain (Supabase), which already exists
🖥 Northstar Helper on the Mac: a small Mac program, always on
   ├─ 1st choice: APIs (GitHub, Claude)          fast, reliable
   ├─ 2nd choice: commands (Xcode builds, files) fast, reliable
   └─ last resort: clicks and typing on screen ("computer use")
        ▼
📱 Back on the phone: "Done ✓" or "Okay to send this email? [Yes] [No]"
```

- The iPhone is the remote control. Apple doesn't let iPhone apps control other apps; Mac programs can,
  with the person's permission (Screen Recording + Accessibility, turned on once in Mac Settings).
- The Helper uses Anthropic's developer tools (the Claude API, its agent tools and computer use).
- It's downloaded from mynorthstarlabs.com, not the App Store. Apple's free safety check
  (Developer ID signing + notarization) is still required, and the existing Apple Developer membership covers it.

## The module switch

- **Settings → Modules → Northstar Helper**: off by default, like Good Listener.
- The first time it's switched on: a safety notice ("I Understand"), then a link to download the Mac Helper.
- Off = Northstar never sends it a task. The Mac Helper can also be paused from its menu bar icon.

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
| 0 | Roger + Claude | Design: the screens on the phone, the menu bar Helper, the approval card | Small |
| 1 | Roger only | Files and documents; write code, build in Xcode, save to GitHub | Medium |
| 2 | Roger only | Browser tasks (look up, fill in a form, with approval) | Medium |
| 3 | Roger only | Full computer use: click and type in any program | Bigger |
| 4 | 3–5 testers | Same, with trusted friends; watch where they get confused | Medium |
| 5 | Everyone | Paid module, with pricing that covers the cost of use | Medium |

## Costs to keep in mind

- Each task uses the Claude API. Files, code and GitHub work are cheap; clicking on screen costs more
  (every step is a screenshot the brain reads). Track the cost per task from step 1 so pricing is real.

## Open questions

- Final name (Helper? Hands? Do It?).
- Mac only at first. Windows later?
- Which three tasks come first for Roger (decides where step 1 starts).
