# Navigator step 1: "Find my files" (look only)

Started Oct 19, 2026. Goal: Roger asks on his iPhone, "Where's my car insurance PDF?", and the Mac finds it.
**Step 1 only looks.** It never moves, changes, sends or deletes anything (Level 1 in the trust model).

## How it works

```
📱 iPhone (Navigator screen, Roger only)
   "Find my car insurance PDF"
        │  northstar-navigator: ask
        ▼
☁️ Northstar brain (Supabase)
   saves the task  ·  records every step (chained record)
        ▲  next (every few seconds)          │  result
        │                                     ▼
🖥 Navigator on the Mac (menu bar star)
   1. picks up the task
   2. asks the brain for a search plan (words, file kinds, how recent)
   3. searches ONLY the folders Roger picked (Spotlight)
   4. skips protected places (Keys, .ssh, Keychains, hidden files)
   5. sends back names, folders, dates and sizes (never file contents)
        ▼
📱 iPhone: the list of files found, plus "What Navigator did"
```

## Parts

| Part | Where | What it does |
|---|---|---|
| Tables | `supabase/migrations/20261021_navigator.sql` | Devices, pairing codes, tasks, and the server record. Only the function can use them. |
| Brain | `supabase/functions/northstar-navigator` | Pairing, tasks, the search plan (Claude), results, the chained record. Owner only (`NS_ADMIN_USERS`). |
| Mac app | `NavigatorMac/` (Swift package) | Menu bar star, folder picker, pairing, Spotlight search, its own local record, Pause and Stop. |
| iPhone | `Northstar/Modules/Navigator/NavigatorView.swift` | Pair a Mac, ask, see results and the record. Shown only to the owner. |

## Linking the Mac (pairing)

The iPhone shows a short code that lasts 10 minutes. Roger types it into the Mac app once. The Mac gets
its own device key (kept in the Mac's Keychain; the brain stores only a fingerprint of it). Roger can
unlink a Mac from the iPhone at any time.

## Tonight, with Roger (about 20 minutes)

1. Say "make it live": the tables are added and the brain part is deployed.
2. In Xcode on the Mac: File › Open › `Developer/Northstar/NavigatorMac/Package.swift`, then Run.
3. Click the star in the menu bar › Choose folders (for example Documents and Downloads).
4. On the iPhone: Settings › Modules › Northstar Navigator (owner preview) › Link a Mac. Type the code on the Mac.
5. Ask: "Find my car insurance PDF". Watch it appear.

## Not in step 1

Moving, renaming, editing, emails, calendar, Undo (nothing to undo yet), Face ID approvals. Those come
with the trust system in step 2.
