# Northstar — Design and Build Brief

Read this entire file before writing any code. It is the source of truth for what Northstar is, what to build now, and how to work. If anything here conflicts with a request, ask before acting.

---

## 1. What Northstar is

Northstar helps people decide what matters and keeps them moving toward it.

- **Brand promise:** One clear destination. An intelligent path forward.
- **Home tagline:** A brighter tomorrow.
- **One name only:** Northstar. "Clarity" is a moment inside the experience, not a separate product.
- **Built on Claude** (Anthropic) through the API. Northstar has its own identity and voice; the About screen says "Built on Claude by Anthropic."

Northstar is **not** a general chatbot, a productivity app, a therapist substitute, or an engagement machine. It answers first and guides when guidance helps.

---

## 2. The team and roles

| Who | Role |
| --- | --- |
| Roger (Creative Director and Senior Art Director) | Vision, decisions, taste, final design approval, testing on iPhone |
| Claude (Art Director, claude.ai) | Design system, screen designs and specs, design review of every pull request, code review, debugging, planning |
| Cursor | Writes the code, following this brief and the art director's specs |
| Xcode | Builds and runs the app |

**Design decisions flow:** Art Director proposes → Senior Art Director approves → Cursor builds → Art Director reviews → Senior Art Director tests and gives the final yes. Cursor never changes the visual design on its own; if a spec is unclear or doesn't work in code, it asks.

---

## 3. The architecture

| Layer | What it is |
| --- | --- |
| Northstar | What people see: the app |
| Crews | Expert roles with written playbooks. First: the calm crew. Later: the creative crew (art director, director, copywriter, editor), then other professions |
| **The Engine** | Holds the destination, works out the stage, leads the conversation, calls in the crew, manages memory |
| Foundation | Claude, reached only through the backend |

**Rule of thumb:** if a feature works for both a bakery website and a meditation session, it belongs in the Engine. If not, it belongs in a crew playbook.

### Project structure

```
Northstar (Xcode workspace, one GitHub repository)
├── NorthstarEngine   ← Swift Package: destination, memory, stages, prompt building, reply parsing
├── CalmApp           ← first app, imports NorthstarEngine
└── CreatorApp        ← later, same Engine
```

- **Backend:** Supabase. The app talks to a Supabase Edge Function; the function calls the Claude API.
- **Never put the Claude API key in the app or in the repository.** It lives only in Supabase secrets.
- Use Supabase row-level security so each user can only read and write their own rows.
- Target iOS 17+, SwiftUI.

---

## 4. Engine v1 — build only these

1. **Destination:** the goal a person names. The unit of memory.
2. **Memory** (see section 5).
3. **The lead:** one guide speaks. Crew members may add short labeled notes only when useful.
4. **Stage:** Reflection, Perspective, Clarity, Direction or Progress. Worked out fresh each message by Claude. **Never stored.**
5. **"What I heard":** key words from the person's message, returned as pills grouped as What, Feeling, For, Must have, Avoid. The person can remove a pill; removed pills are sent back as corrections.
6. **Show options instead of asking:** when someone has no idea, offer three very different options to react to.
7. **Show, don't tell:** a reply may include a visual (diagram or mockup), rendered safely.
8. **Settings feed the Engine:** answer length, visuals on/off, preferred name, memory on/off.

### Prompt order sent to Claude (built in the Edge Function or Engine)

1. The Northstar Constitution (section 7)
2. The crew playbook (calm crew first)
3. Rules from settings (`EngineSettings.promptRules`)
4. Relevant memory (active destination, its decisions and next step, stated preferences)
5. The conversation (recent turns only)

### Reply format Claude must return (JSON)

```json
{
  "reply": "string",
  "crew_notes": [{ "role": "string", "note": "string" }],
  "destination": "string or null",
  "stage": "Reflection | Perspective | Clarity | Direction | Progress",
  "stage_reason": "string",
  "heard": [{ "group": "what | feeling | for | must | avoid", "text": "string" }],
  "proposed_saves": [{ "kind": "destination | decision | next_step | taste | open_question", "text": "string", "reason": "string", "replaces": "string or null" }],
  "visual": { "kind": "html | svg", "title": "string", "code": "string" },
  "directions": [{ "name": "string", "keywords": ["string"], "palette": ["#hex"], "type_sample": "string" }]
}
```

Validate everything. Never render model output as live code: visuals go in a sandboxed web view with JavaScript disabled.

---

## 5. Memory

- Organized around **destinations (goals)**, not conversations.
- Each destination holds **decisions** (with the reason, in the person's words), **next steps**, and **the work** (briefs, versions, files).
- Across destinations: **stated preferences and taste**, and **open questions**.
- **Progress is not stored.** It comes from steps done and work improving.
- **Stated or confirmed only.** Never store inferred personality, values or mood. Feelings are never saved.
- **Capture automatically, confirm with one tap** (end of session by default; setting can switch to every time).
- A new decision **supersedes** an old one; history stays visible.
- One fact per item, short, tagged with destination, type, date and source chat.
- Check for similar facts before saving; update instead of duplicating.
- Load only what's relevant: always the active destination and preferences; search the rest by meaning (Supabase vector search).
- Use a memory only when it changes the answer.
- People can view, edit, export and delete everything. "Forget this" works. Memory can be turned off.
- Never save passwords, ID numbers or card numbers. Sensitive topics (health, money) only with explicit consent.

**Memory screen:** topic cards (destinations, brand, decisions, preferences) → tap a card to see its facts → swipe to edit or delete. No "continue chat" button there.

### Supabase table (starting point)

`memory_items`: id, user_id, destination_id, kind, text, reason, source_chat_id, supersedes_id, created_at, updated_at, embedding.

---

## 6. Design

### Feel

Calm, premium, night sky. One clear focus per screen. Visuals over text. Plain, short sentences.

### Home screen (approved design)

- **Background:** the existing mountain backdrop asset (`MountainBackdrop`): deep navy night sky, soft layered mountains in the lower half.
- **Soft blue radial glow** behind the star (centered about 36% down the screen, subtle).
- **The four-point star**, centered about 30–36% down, white with a soft blue glow; breathes gently (8-second cycle); still when Reduce Motion is on. **Tapping the star opens the menu.**
- **"Northstar"** below the star: light weight, ~34pt, wide letter spacing.
- **"A BRIGHTER TOMORROW"** below the name: small caps style, at least 12–13pt, tracking ~3, 75% white. Two lines.
- **No other text on the screen.** No corner taglines, no footer line.
- **Glassy navy input bar** near the bottom: rounded capsule, thin light border, soft blue glow, mic on the left, placeholder "Ask Northstar…", round button on the right that shows a voice icon when empty and a send arrow when typing.
- Reference implementation: `NorthstarHomeView.swift`.

### Menu (opens from the star)

New chat · **Destinations** (each shows its next step) · Memory · History · Settings · About Northstar.
Camera and photo library move to a **+** in the message bar.

### Settings (reference: `NorthstarSettings.swift`)

1. Memory and privacy: memory on/off, review memory, confirm saves (end of session / every time), export, delete all (with confirmation).
2. How Northstar talks to you: preferred name, answer length (short/detailed), show visuals.
3. Reading and accessibility: easier-reading font (Atkinson Hyperlegible, extra spacing), read replies aloud, reduce motion.
4. Check-ins: off by default; if on, quiet hours.

### Design rules

- Accessibility first: Dynamic Type, VoiceOver labels, contrast, Reduce Motion. The founder is dyslexic; design for easy reading.
- Small uppercase text never below 11–12pt.
- Color never carries meaning alone; always pair with a label.
- Layout before polish. Real content, never lorem ipsum.

---

## 7. The Northstar Constitution (include in every Engine prompt)

1. **Your direction is yours.** Northstar helps you reach the destinations you choose. It never decides what your life should be.
2. **We answer first.** Simple questions get simple answers. We guide only when it helps.
3. **We remember only what you tell us.** No guessing your personality, values or mood. You can see, change, export or delete anything.
4. **We tell the truth kindly.** Honest feedback over flattery.
5. **Your time matters more than our numbers.** No streaks, no guilt, no tricks to keep you here.
6. **We point you to people.** Northstar is not a therapist, doctor or lawyer. When you need a real person, we say so.
7. **We design for everyone.** Plain words, visuals and accessibility built in.
8. **We earn trust over time.** If these promises change, we say so clearly and first.
9. **We ask before we act.** Anything that changes something important is shown first and confirmed.

---

## 8. The calm app (first product)

The calm app is the Engine's first home: the Engine plus the calm crew.

- **Home:** the approved home screen above.
- **The guide:** "How are you feeling?" conversations powered by the Engine with the calm crew playbook.
- **Practices:** breathing (with the orb), journaling with gentle prompts, quiet listening, guided meditation, teaching.
- **Personalized path:** uses memory to suggest what helped before.
- **Safety:** a calm, kind path to real help (crisis resources) when someone is in distress. Never claim to be therapy. Build this in the first calm quarter, not at the end.
- Existing work to reuse: the lake/orb designs and `LoopingVideoBackground.swift`, `CrystalOrb.swift`, `CalmOrb.swift`.

---

## 9. How we build: quarters

Each quarter is built on its own branch, reviewed by Claude, tested by Roger on his iPhone, then merged. **After every quarter, the app must still build and run.**

### Engine

| Quarter | Build | Done when |
| --- | --- | --- |
| **Q1 Foundation** | Supabase Edge Function calling Claude; NorthstarEngine package with Destination, MemoryItem, Decision, NextStep models | Type a message in the app and Claude replies |
| **Q2 The brain** | Prompt building (constitution, playbook, settings, memory); JSON reply parsing | Replies show stage, "What I heard" pills and save cards |
| **Q3 Memory** | Confirmed saves, loading the active destination, relevance search, edit/delete, Memory screen | Save something, restart the app, start a new chat: it remembers |
| **Q4 Experience** | Chat screen in the Northstar design, home screen, menu, settings wired in | Three test scenarios pass on iPhone (below) |

### Calm app (in parallel, only pieces that don't depend on the Engine until Q4)

| Quarter | Build | Done when |
| --- | --- | --- |
| **C1** | Home screen and orb; calm crew playbook draft; safety path | Home matches the approved design |
| **C2** | Breathing, journaling, quiet listening | Each practice works start to finish |
| **C3** | Guide and personalized path connected to the Engine | It remembers what helped last time |
| **C4** | Polish, settings, safety review, TestFlight | Friends can install and use it |

### Test scenarios (must pass before Engine v1 is done)

1. **Clear goal:** "I want to make a launch video for my design studio." → asks about the destination before making anything; proposes saving the destination; picks up on return with the next step.
2. **Feeling stuck:** "I haven't touched my portfolio in 3 weeks." → offers perspective first; saves no feelings; records the new decision and keeps history.
3. **Quick question:** "How do I export a transparent PNG in Photoshop?" → short direct answer; no guidance; nothing saved.

---

## 10. Working rules for AI helpers

- **One helper per branch at a time.** Never edit a branch another helper is working on.
- **Stay in scope.** Build only the current quarter. No extra features, no new dependencies without asking.
- **Ask before** deleting files, changing the architecture, or anything that can't be undone.
- **Never commit secrets** (API keys, tokens, passwords).
- **Small, clear commits** with plain-English messages.
- **End every session** by updating the "Next step" line in this file or in the pull request.
- **Explain changes in plain words** in each pull request, with a short checklist Roger can test on his iPhone.
- When unsure about design or behavior, ask; don't guess.

---

## 11. Out of scope for now

Image and video generation (providers not yet verified for ownership and commercial rights), the creative crew, computer access, other professions, multiple AI providers, and the public App Store launch.

---

**Next step:** Q1 Foundation and C1 Home screen.
