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
    var errorDescription: String? { "Apple didn't send a sign-in token. Please try again." }
}

@MainActor
@Observable
final class AppleAccount {
    static let shared = AppleAccount()

    /// True once this account is linked to an Apple ID.
    private(set) var isSignedInWithApple = false
    private(set) var email: String?

    /// The random value for the current request (Apple gets its hash, Supabase checks it).
    private var rawNonce = ""

    private var auth: AuthClient { SupabaseManager.shared.client.auth }

    private init() {}

    /// Reads who is signed in (call when Settings opens).
    func refresh() async {
        guard let user = try? await auth.user() else {
            isSignedInWithApple = false
            email = nil
            return
        }
        let apple = user.identities?.first { $0.provider == "apple" }
        isSignedInWithApple = apple != nil
        email = isSignedInWithApple ? user.email : nil
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

        do {
            // Keep everything: attach Apple to the account they already have.
            try await auth.linkIdentityWithIdToken(credentials: credentials)
        } catch {
            // This Apple ID already has a Northstar account (new phone, reinstalled app):
            // switch to it, so its memory and chats come back.
            if Self.isAlreadyLinked(error) {
                try await auth.signInWithIdToken(credentials: credentials)
                await SupabaseManager.shared.signInIfNeeded()
            } else {
                throw error
            }
        }
        await refresh()
    }

    /// Signs out and starts a fresh, empty account on this phone.
    /// Their saved memory stays with their Apple ID; signing in again brings it back.
    func signOut() async {
        try? await auth.signOut()
        await SupabaseManager.shared.signInIfNeeded()
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
