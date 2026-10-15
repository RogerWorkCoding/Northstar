import Foundation
import AuthenticationServices
import CryptoKit
import Supabase

// Sign in with Apple: keeps a person's memory, subjects and chats safe if they
// delete the app or get a new phone.
//
// Everyone starts signed in quietly (anonymous). Tapping "Sign in with Apple"
// LINKS Apple to that same account, so nothing moves and nothing is lost.
// If this Apple ID already has a Northstar account (new phone, reinstalled app),
// we switch to that account instead, and its memory comes back.

nonisolated enum AppleAccountError: LocalizedError, Sendable {
    case noToken
    case message(String)
    var errorDescription: String? {
        switch self {
        case .noToken: return "Apple didn't send a sign-in token. Please try again."
        case .message(let text): return text
        }
    }
}

nonisolated private struct DeleteAccountRequest: Encodable, Sendable { let action = "delete" }
nonisolated private struct DeleteAccountReply: Decodable, Sendable { let deleted: Bool?; let error: String? }

@MainActor
@Observable
final class AppleAccount {
    static let shared = AppleAccount()

    /// True once this account is linked to an Apple ID.
    private(set) var isSignedInWithApple = false
    private(set) var email: String?
    /// Goes up when the phone switches to a different account, so screens can start fresh.
    private(set) var accountChanges = 0
    /// True when the last sign-in brought back an existing account (new phone, reinstall).
    private(set) var cameBack = false

    /// The random value for the current request (Apple gets its hash, Supabase checks it).
    private var rawNonce = ""

    private var auth: AuthClient { SupabaseManager.shared.client.auth }

    private init() {}

    /// Reads who is signed in (call when Settings opens).
    func refresh() async {
        // Saved on the phone first (works offline), then checked with the server.
        if let local = auth.currentUser { apply(local) }
        if let fresh = try? await auth.user() { apply(fresh) }
    }

    private func apply(_ user: User) {
        let apple = user.identities?.first { $0.provider == "apple" }
        isSignedInWithApple = apple != nil
        let fromApple: String? = {
            if case let .string(value)? = apple?.identityData?["email"] { return value }
            return nil
        }()
        email = isSignedInWithApple ? (user.email ?? fromApple) : nil
    }

    /// Fills in the Apple request: name and email (asked once by Apple), plus the nonce.
    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        rawNonce = Self.randomNonce()
        request.requestedScopes = [.email]
        request.nonce = Self.sha256(rawNonce)
    }

    /// Finishes sign-in with what Apple returned.
    func finish(_ result: Result<ASAuthorization, Error>) async throws {
        let authorization = try result.get()
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else { throw AppleAccountError.noToken }

        let credentials = OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: rawNonce)

        cameBack = false
        if auth.currentSession == nil {
            // No account on this phone yet: just sign in with Apple.
            try await auth.signInWithIdToken(credentials: credentials)
            await SupabaseManager.shared.signInIfNeeded()
            accountChanges += 1
        } else {
            do {
                // Keep everything: attach Apple to the account they already have.
                try await auth.linkIdentityWithIdToken(credentials: credentials)
            } catch {
                // This Apple ID already has a Northstar account (new phone, reinstalled app):
                // switch to it, so its memory and chats come back. Anything made on this phone
                // before signing in stays with the old guest account.
                guard Self.isAlreadyLinked(error) else { throw error }
                try await auth.signInWithIdToken(credentials: credentials)
                await SupabaseManager.shared.signInIfNeeded()
                cameBack = true
                accountChanges += 1
            }
        }
        await refresh()
    }

    /// Signs out and starts a fresh, empty account on this phone.
    /// Their saved memory stays with their Apple ID; signing in again brings it back.
    func signOut() async {
        // This phone only: other phones stay signed in.
        try? await auth.signOut(scope: .local)
        await SupabaseManager.shared.signInIfNeeded()
        accountChanges += 1
        await refresh()
    }

    /// Permanently deletes this account and everything Northstar saved for it (memory, subjects,
    /// notes, chats, videos), then starts this phone fresh. Can't be undone.
    func deleteAccount() async throws {
        let reply: DeleteAccountReply = try await SupabaseManager.shared.client.functions.invoke(
            "northstar-account", options: FunctionInvokeOptions(body: DeleteAccountRequest())
        )
        guard reply.deleted == true else {
            throw AppleAccountError.message(reply.error ?? "Couldn't delete the account.")
        }
        // The copies on this phone too.
        try? FileManager.default.removeItem(at: URL.documentsDirectory.appending(path: "Videos", directoryHint: .isDirectory))
        try? await auth.signOut(scope: .local)
        await SupabaseManager.shared.signInIfNeeded()
        accountChanges += 1
        await refresh()
    }

    // MARK: - Helpers

    nonisolated private static func isAlreadyLinked(_ error: Error) -> Bool {
        if let authError = error as? AuthError, authError.errorCode == .identityAlreadyExists { return true }
        let text = String(describing: error).lowercased()
        return text.contains("identity_already_exists") || text.contains("already linked")
    }

    nonisolated private static func randomNonce(length: Int = 32) -> String {
        let chars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in chars[Int(generator.next() % UInt64(chars.count))] })
    }

    nonisolated private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
