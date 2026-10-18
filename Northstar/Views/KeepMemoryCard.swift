import SwiftUI
import AuthenticationServices

// ✦ "Keep your memory safe": asked once, at the right moment (after the 3rd thing Northstar keeps),
// never on the welcome screen. "Not now" closes it for good; Sign in with Apple stays in Settings.

enum KeepMemoryNudge {
    static let countKey = "ns.keptCount"
    static let askedKey = "ns.keepSafeAsked"
    static let after = 3

    /// Call when a save or subject was kept. True when the card should show now (once ever).
    @MainActor
    static func noteKept() -> Bool {
        let d = UserDefaults.standard
        let count = d.integer(forKey: countKey) + 1
        d.set(count, forKey: countKey)
        guard count >= after, !d.bool(forKey: askedKey), !AppleAccount.shared.isSignedInWithApple else { return false }
        d.set(true, forKey: askedKey)
        return true
    }
}

struct KeepMemoryCard: View {
    var onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var account = AppleAccount.shared
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle").foregroundStyle(NorthstarChatStyle.starGold)
                Text("Keep your memory safe").font(.headline)
            }
            .foregroundStyle(NorthstarChatStyle.text)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(NorthstarChatStyle.savedGreen)
            } else {
                Text("Northstar now knows a few things about you. Sign in with Apple so they're not lost if you change phones.")
                    .font(.subheadline)
                    .foregroundStyle(NorthstarChatStyle.soft)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        account.prepare(request)
                    } onCompletion: { result in
                        Task {
                            do {
                                try await account.finish(result)
                                message = "Signed in. Your memory is safe if you change phones."
                                try? await Task.sleep(for: .seconds(3))
                                onClose()
                            } catch {
                                if (error as? ASAuthorizationError)?.code == .canceled { return }
                                message = "Couldn't sign in. You can try any time in Settings."
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 46)
                    .clipShape(Capsule())

                    Button("Not now", action: onClose)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(NorthstarChatStyle.linkBlue)
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
        .padding(.horizontal, 20)
    }
}
