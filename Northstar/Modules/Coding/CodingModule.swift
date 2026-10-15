import Foundation

// 💻 Coding module
//
// What it adds when switched on (Settings → Modules → Coding):
// • A patient senior engineer in the brain: plain words first, short sentences, then code.
//   Knows SwiftUI / Swift 6, Supabase and Deno edge functions, web, SQL and Power Apps (Power Fx).
// • Code cards: every piece of code in its own card with the language, a monospace box,
//   one plain line on what it does and a Copy button (Modules/Coding/CodeCardsView).
//   Code never goes inside the chat text.
// • Debugging help: the likely cause in one line, the fix, and how to check it worked.
// • Projects remembered as subjects (e.g. "Northstar app" → next: add the Day theme).
//
// The expert rules live in the brain (supabase/functions/northstar-chat, MODULES.coding) and are
// only sent for people who switched this module on. Off for everyone by default.

nonisolated enum CodingModule {
    static let module = AppModule.coding
}
