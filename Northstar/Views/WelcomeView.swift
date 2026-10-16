import SwiftUI
import AuthenticationServices

// ✦ First-run welcome: four short pages on the night sky, shown once.
// 1. What Northstar is. 2. What you can ask. 3. The Concierge (the bell). 4. Your memory is yours (+ optional Sign in with Apple).
// Big text, one idea per page, always skippable. Settings → About can show it again later.

struct WelcomeView: View {
    var onDone: () -> Void

    @State private var page = 0
    private let lastPage = 3
    @State private var account = AppleAccount.shared
    @State private var message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
                HStack {
                    Spacer()
                    // Always takes its space (hidden on the last page) so the star never jumps.
                    Button("Skip") { onDone() }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(minWidth: 44, minHeight: 44)
                        .opacity(page < lastPage ? 1 : 0)
                        .disabled(page >= lastPage)
                        .accessibilityHidden(page >= lastPage)
                }
                .padding(.horizontal, 20)

                NorthstarVisionStarMark(size: 44)
                    .padding(.top, 24)
                    .accessibilityHidden(true)

                TabView(selection: $page) {
                    WelcomeFadePage(
                        title: "Find your direction",
                        first: ["Northstar helps you decide what matters,", "then take the next small step."],
                        second: "Your direction is always yours.",
                        active: page == 0
                    ).tag(0)

                    WelcomeFadePage(
                        title: "Talk or type",
                        first: ["Plan a project. Find a place nearby.", "Sketch a design. Make a short video."],
                        second: "Simple questions get simple answers.",
                        active: page == 1
                    ).tag(1)

                    WelcomeFadePage(
                        title: "\(Image(systemName: "bell")) Your concierge",
                        first: ["Tap the bell for dinner, classes,", "things to do, travel and more, near you."],
                        second: "You choose.\nNorthstar never books or pays without you.",
                        active: page == 2
                    ).tag(2)

                    memoryPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .interactive))

                if page == lastPage {
                    appleSignIn
                        .transition(.opacity)
                }

                Button {
                    if page < lastPage {
                        withAnimation(reduceMotion ? nil : .easeInOut) { page += 1 }
                    } else {
                        onDone()
                    }
                } label: {
                    Text(page < lastPage ? "Continue" : "Start")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.05, green: 0.09, blue: 0.21))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Capsule().fill(Color(red: 0.91, green: 0.93, blue: 1.0)))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
                .frame(maxWidth: 480)
            }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The sky sits BEHIND the layout, so the picture never changes the layout's size.
        .background {
            ZStack {
                NorthstarVisionLandscapeBackground()
                // A soft veil so the words always read clearly over the sky.
                LinearGradient(colors: [Color.black.opacity(0.15), Color.black.opacity(0.55)],
                               startPoint: .top, endPoint: .bottom)
            }
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
        // The welcome always sits on the night sky.
        .environment(\.colorScheme, .dark)
    }

    private func pageView(title: LocalizedStringKey, lines: [String]) -> some View {
        VStack(spacing: 18) {
            Text(title)
                .font(.system(size: 32, weight: .light))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 8) {
                ForEach(lines, id: \.self) { Text($0) }
            }
            .font(.system(size: 19))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.88))
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
        }
        .padding(.top, 40)
        .padding(.horizontal, 28)
        .frame(maxWidth: 520)
    }

    /// Sign in with Apple, at the bottom just above Start (last page only).
    private var appleSignIn: some View {
        VStack(spacing: 8) {
            if account.isSignedInWithApple {
                Label("Signed in with Apple", systemImage: "checkmark.circle.fill")
                    .font(.body.weight(.semibold))
                    .padding(.top, 8)
            } else {
                VStack(spacing: 8) {
                    SignInWithAppleButton(.signIn) { request in
                        account.prepare(request)
                    } onCompletion: { result in
                        Task {
                            do {
                                try await account.finish(result)
                                message = account.cameBack
                                    ? "Welcome back. Your memory and chats are here again."
                                    : "Signed in. Your memory is safe if you change phones."
                            } catch {
                                if (error as? ASAuthorizationError)?.code == .canceled { return }
                                message = "Couldn't sign in. You can try later in Settings."
                            }
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .clipShape(Capsule())   // matches the Start button

                    Text("Optional. Creates your free account, no password.\nKeeps your memory safe if you change phones.")
                        .multilineTextAlignment(.center)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .padding(.top, 8)
            }

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 14)
        .frame(maxWidth: 480)
    }

    private var memoryPage: some View {
        VStack(spacing: 18) {
            Text("Your memory is yours")
                .font(.system(size: 32, weight: .light))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 8) {
                Text("Northstar remembers only what you tell it or confirm.")
                Text("See, change or delete it any time in Settings.")
            }
            .font(.system(size: 19))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.88))
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)
        }
        .padding(.top, 40)
        .padding(.horizontal, 28)
        .frame(maxWidth: 520)
    }
}

/// A welcome page whose words change in place: the first lines fade in, stay long enough to read,
/// fade away, then the last line fades in and stays. It plays when the page is on screen.
private struct WelcomeFadePage: View {
    let title: LocalizedStringKey
    let first: [String]
    let second: String
    let active: Bool

    @State private var firstShown = false
    @State private var secondShown = false
    @State private var played = false

    var body: some View {
        VStack(spacing: 18) {
            Text(title)
                .font(.system(size: 32, weight: .light))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            ZStack(alignment: .top) {
                VStack(spacing: 8) {
                    ForEach(first, id: \.self) { Text($0) }
                }
                .opacity(firstShown ? 1 : 0)
                Text(second)
                    .opacity(secondShown ? 1 : 0)
            }
            .font(.system(size: 19))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.88))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel((first + [second]).joined(separator: " "))
            Spacer(minLength: 0)
        }
        .padding(.top, 40)
        .padding(.horizontal, 28)
        .frame(maxWidth: 520)
        .task(id: active) {
            guard active, !played else { return }
            played = true
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.easeOut(duration: 1.0)) { firstShown = true }
            try? await Task.sleep(for: .milliseconds(3200))   // fade in + time to read
            withAnimation(.easeIn(duration: 0.8)) { firstShown = false }
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeOut(duration: 1.0)) { secondShown = true }
        }
    }
}

#Preview {
    WelcomeView(onDone: {})
}
