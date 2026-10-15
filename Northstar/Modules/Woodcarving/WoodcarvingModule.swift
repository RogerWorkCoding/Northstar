import Foundation

// 🪵 Wood carving module
//
// What it adds when switched on (Settings → Modules → Wood carving):
// • A carving teacher in the brain: tools to buy first, easy woods, cut names (push, paring, stop, chip),
//   steps in order, sharpening and stropping, food-safe finishes, and safety every time.
// • Lesson videos: real YouTube tutorials, played inside Northstar (Modules/Shared/LessonVideosCard).
// • Projects remembered as subjects (e.g. "First spoon" → next: hollow the bowl).
//
// The expert rules live in the brain (supabase/functions/northstar-chat, MODULES.woodcarving) and are
// only sent for people who switched this module on. Off for everyone by default.

nonisolated enum WoodcarvingModule {
    static let module = AppModule.woodcarving
}
