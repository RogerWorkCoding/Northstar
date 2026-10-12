import SwiftUI

/// Which screen is currently mounted. Intentionally not a NavigationStack push —
/// a push would let the user swipe back to the arrival screen after sending their
/// first message, and would risk ContentView's .task re-firing on re-push. A plain
/// switch mounts ContentView exactly once and keeps its identity stable thereafter.
enum NorthstarRootDestination {
    case arrival
    case chat
}

/// What ContentView should do, exactly once, right after it mounts as a result of
/// the Arrival handoff. Represented as one enum (per the approved plan) rather than
/// several loosely related Booleans, so "what to do" and "what text, if any" can
/// never disagree with each other.
enum NorthstarPendingAction: Equatable {
    case sendPrompt(String)
    case openStarMenu
    case beginVoice
}

/// Coordinates the one-time handoff from the Arrival (Vision) screen into the real
/// chat experience. Intentionally minimal: two @State values are the entire root —
/// no view model, no environment object, no change to how ContentView owns its own
/// chat state. ContentView's existing send pipeline, star menu, and microphone
/// logic are reused as-is; this view only decides *when* to show which screen and
/// *what* ContentView should do once it appears.
struct NorthstarRootView: View {
    @State private var destination: NorthstarRootDestination = .arrival
    @State private var pendingAction: NorthstarPendingAction?

    var body: some View {
        switch destination {
        case .arrival:
            NorthstarVisionScreen(
                onSubmitPrompt: { text in
                    arrive(with: .sendPrompt(text))
                },
                onSelectStar: {
                    // Wired in a later integration step; the button exists now so
                    // the composer's full control set (star/text/mic/send) is in
                    // place, but selecting it does nothing yet.
                },
                onSelectMicrophone: {
                    // Wired in a later integration step; see onSelectStar above.
                }
            )
        case .chat:
            ContentView(pendingAction: $pendingAction)
        }
    }

    private func arrive(with action: NorthstarPendingAction) {
        pendingAction = action
        destination = .chat
    }
}

#Preview {
    NorthstarRootView()
}
