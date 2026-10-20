import Foundation

// 🧩 Modules: add-ons a person switches on in Settings → Modules.
// Each module adds an expert to the brain (its rules live in the brain and only load for people who
// turned it on). Off for everyone by default. New module = add a case here + its rules in the brain.

nonisolated enum AppModule: String, CaseIterable, Identifiable, Sendable {
    case woodcarving
    case coding
    case design
    case listener

    var id: String { rawValue }

    var title: String {
        switch self {
        case .woodcarving: return "Wood carving"
        case .coding: return "Coding"
        case .design: return "Design"
        case .listener: return "Good Listener"
        }
    }

    var icon: String {
        switch self {
        case .woodcarving: return "hammer"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .design: return "paintpalette"
        case .listener: return "heart.text.square"
        }
    }

    var blurb: String {
        switch self {
        case .woodcarving: return "Tools, wood, cuts, sharpening and safety, with video lessons."
        case .coding: return "A patient senior engineer: plain-words explanations, code you can copy, help with errors."
        case .design: return "A creative director: honest feedback on your designs, colors and type, and AI image prompts you can copy."
        case .listener: return "Someone to listen while you put your thoughts into words, with a private journal on this phone."
        }
    }

    /// Which modules are on (saved on this phone).
    static var enabled: [AppModule] {
        let saved = UserDefaults.standard.string(forKey: SettingsKeys.modules) ?? ""
        return saved.split(separator: ",").compactMap { AppModule(rawValue: String($0)) }
    }

    /// Good Listener shows its safety notice once, before it's first switched on.
    static let listenerNoticeKey = "ns.listenerNoticeSeen"

    static func isOn(_ module: AppModule) -> Bool { enabled.contains(module) }

    static func set(_ module: AppModule, on: Bool) { setKey(module.rawValue, on: on) }

    /// Raw keys too, so switches that aren't brain experts (like "navigator") are kept when others change.
    static func isKeyOn(_ key: String) -> Bool {
        (UserDefaults.standard.string(forKey: SettingsKeys.modules) ?? "").split(separator: ",").contains { $0 == key }
    }

    static func setKey(_ key: String, on: Bool) {
        let saved = UserDefaults.standard.string(forKey: SettingsKeys.modules) ?? ""
        var list = saved.split(separator: ",").map(String.init).filter { !$0.isEmpty && $0 != key }
        if on { list.append(key) }
        UserDefaults.standard.set(list.joined(separator: ","), forKey: SettingsKeys.modules)
    }

    /// Northstar Navigator's switch (owner preview for now; the brain decides who may use it).
    static let navigatorKey = "navigator"
    /// The owner's Navigator switch starts on once, so the compass doesn't vanish when this switch arrives.
    static let navigatorDefaultKey = "ns.navigatorDefaultApplied"
}
