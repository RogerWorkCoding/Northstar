import SwiftUI

// 🧭 The one list of places in Northstar. The ✦ menu and Discovery's background bubbles both read it,
// so they can never drift apart. Each entry maps to a real screen or action in ContentView (see `go(_:)`).
// Order = the menu's order; `priority` = which bubbles Discovery keeps if the screen is small (1 = most important).

enum NorthstarRoute: String, CaseIterable, Hashable, Sendable {
    case newChat, camera, photoLibrary
    case projects, videos, voices
    case memory, documents, history
    case concierge
    case settings, about, feedback
}

struct NorthstarDestinationInfo: Identifiable, Hashable {
    var id: NorthstarRoute { route }
    let route: NorthstarRoute
    let title: String
    let symbol: String
    /// 1 = most important (kept first when Discovery is short on room).
    let priority: Int
    /// What opening it does, for VoiceOver.
    let hint: String
    /// Which group of the ✦ menu it sits in (dividers between groups).
    let menuSection: Int
    /// Shown as a row in the ✦ menu (Concierge and History have their own buttons elsewhere).
    let inMenu: Bool
}

enum NorthstarDestinations {
    static let all: [NorthstarDestinationInfo] = [
        .init(route: .newChat, title: "New Chat", symbol: "square.and.pencil", priority: 6,
              hint: "Starts a new chat", menuSection: 0, inMenu: true),
        .init(route: .camera, title: "Camera", symbol: "camera", priority: 8,
              hint: "Opens the camera to ask about a photo", menuSection: 0, inMenu: true),
        .init(route: .photoLibrary, title: "Photo Library", symbol: "photo.on.rectangle", priority: 9,
              hint: "Picks a photo to ask about", menuSection: 0, inMenu: true),
        .init(route: .projects, title: "Projects", symbol: "folder", priority: 1,
              hint: "Opens your projects", menuSection: 1, inMenu: true),
        .init(route: .videos, title: "Videos", symbol: "play.rectangle.on.rectangle", priority: 10,
              hint: "Opens your saved and made videos", menuSection: 1, inMenu: true),
        .init(route: .voices, title: "Voices", symbol: "waveform", priority: 7,
              hint: "Opens voice settings", menuSection: 1, inMenu: true),
        // Short-term memory: the recent conversations themselves.
        .init(route: .history, title: "Recent Chats", symbol: "clock.arrow.circlepath", priority: 2,
              hint: "Opens your recent chats", menuSection: 2, inMenu: true),
        // Long-term memory: everything Northstar keeps from your chats, searchable.
        .init(route: .memory, title: "Search Memory", symbol: "brain.head.profile", priority: 3,
              hint: "Searches everything you've said", menuSection: 2, inMenu: true),
        .init(route: .documents, title: "Documents", symbol: "doc", priority: 4,
              hint: "Opens your documents", menuSection: 2, inMenu: true),
        .init(route: .concierge, title: "Concierge", symbol: "bell", priority: 4,
              hint: "Opens the Concierge", menuSection: 2, inMenu: false),
        .init(route: .settings, title: "Settings", symbol: "gearshape", priority: 5,
              hint: "Opens Settings", menuSection: 3, inMenu: true),
        .init(route: .about, title: "About Northstar", symbol: "info.circle", priority: 12,
              hint: "Opens About Northstar", menuSection: 3, inMenu: true),
        .init(route: .feedback, title: "Send Feedback", symbol: "bubble.left.and.text.bubble.right", priority: 13,
              hint: "Opens anonymous feedback", menuSection: 3, inMenu: true),
    ]

    static func info(_ route: NorthstarRoute) -> NorthstarDestinationInfo {
        all.first { $0.route == route }!
    }

    /// Sent to the brain so Discovery can suggest opening a real place (never one that doesn't exist).
    static var forBrain: [[String: String]] {
        all.map { ["id": $0.route.rawValue, "title": $0.title] }
    }
}
