import Foundation

// 🧩 Modules: add-ons a person switches on in Settings → Modules.
// Each module adds an expert to the brain (its rules live in the brain and only load for people who
// turned it on). Off for everyone by default. New module = add a case here + its rules in the brain.

nonisolated enum AppModule: String, CaseIterable, Identifiable, Sendable {
    case woodcarving

    var id: String { rawValue }

    var title: String {
        switch self {
        case .woodcarving: return "Wood carving"
        }
    }

    var icon: String {
        switch self {
        case .woodcarving: return "hammer"
        }
    }

    var blurb: String {
        switch self {
        case .woodcarving: return "Tools, wood, cuts, sharpening and safety, with video lessons."
        }
    }

    /// Which modules are on (saved on this phone).
    static var enabled: [AppModule] {
        let saved = UserDefaults.standard.string(forKey: SettingsKeys.modules) ?? ""
        return saved.split(separator: ",").compactMap { AppModule(rawValue: String($0)) }
    }

    static func isOn(_ module: AppModule) -> Bool { enabled.contains(module) }

    static func set(_ module: AppModule, on: Bool) {
        var list = enabled.filter { $0 != module }
        if on { list.append(module) }
        UserDefaults.standard.set(list.map(\.rawValue).joined(separator: ","), forKey: SettingsKeys.modules)
    }
}
