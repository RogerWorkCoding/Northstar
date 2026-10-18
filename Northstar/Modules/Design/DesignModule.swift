import Foundation

// 🎨 Design module
//
// What it adds when switched on (Settings → Modules → Design):
// • A creative director in the brain: names what works, then the one or two changes that matter most,
//   with the why, so people build their own eye. Short sentences, one idea per line.
// • Critiques of shared images and mockups in a clear order: the screen's one job, hierarchy,
//   readability and contrast, spacing, type, color, touch and accessibility, then the next change.
// • Colors with exact #RRGGBB values and roles, contrast checks, and real typefaces with a size scale.
// • AI image and video prompts (Firefly, Gemini, Grok, Veo…) in copy cards with the "AI prompt" label
//   (shared with the Coding module's cards: Modules/Coding/CodeCardsView). Prompts never go in the chat text.
// • Export sizes for app icons, App Store screenshots and social formats.
//
// The expert rules live in the brain (supabase/functions/northstar-chat, MODULES.design) and are
// only sent for people who switched this module on. Off for everyone by default.
// Each module can later be sold on its own (In-App Purchase per module).

nonisolated enum DesignModule {
    static let module = AppModule.design
}
