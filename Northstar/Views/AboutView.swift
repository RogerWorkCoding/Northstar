import SwiftUI

// ✦ About Northstar (star menu): what Northstar is, its promises, privacy in short, and the version.
// Plain words, short lines. Follows Day / Night.

struct AboutView: View {
    @AppStorage(SettingsKeys.welcomed) private var welcomed = true
    /// Northstar Labs only: filled in when this account is an admin.
    @State private var insights: InsightsReport?
    /// Set these when they exist; the rows only show once they're filled in.
    private let privacyURL: URL? = URL(string: "https://mynorthstarlabs.com/privacy.html")
    private let contactEmail: String? = "rogwar51@gmail.com"   // switch to hello@mynorthstarlabs.com when it is set up

    private var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(v) (\(b))"
    }

    private let promises: [(String, String)] = [
        ("location.north", "Your direction is yours. Northstar helps you get where you choose."),
        ("text.bubble", "Answer first. Simple questions get simple answers."),
        ("brain", "It remembers only what you tell it or confirm."),
        ("hand.thumbsup", "Honest and kind, never flattering."),
        ("clock", "Your time matters. No streaks, no guilt, no tricks."),
        ("person.2", "It points you to real people when you need a doctor, lawyer or counselor."),
    ]

    private let privacy: [String] = [
        "Northstar keeps only what you tell it or confirm. You can see, change or delete all of it.",
        "It never saves your feelings or health unless you ask.",
        "No ads. Your information is never sold.",
        "Turn memory off, or delete your account, any time in Settings.",
    ]

    var body: some View {
        ZStack {
            NorthstarChatStyle.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(NorthstarChatStyle.starGold)
                            .accessibilityHidden(true)
                        Text("Northstar")
                            .font(.system(size: 30, weight: .light))
                            .tracking(5)
                            .foregroundStyle(NorthstarChatStyle.text)
                            .accessibilityAddTraits(.isHeader)
                        Text("One clear destination. An intelligent path forward.")
                            .font(.subheadline)
                            .foregroundStyle(NorthstarChatStyle.soft)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                    section("What Northstar is") {
                        Text("A calm place to think things through. Tell it what you want, and it helps you decide what matters and take the next small step. It can look things up, plan, design, make short videos and more.")
                            .font(.body)
                            .foregroundStyle(NorthstarChatStyle.text)
                            .northstarReadingStyle()
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    section("Our promises") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(promises, id: \.1) { icon, text in
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: icon)
                                        .foregroundStyle(NorthstarChatStyle.linkBlue)
                                        .frame(width: 24)
                                        .accessibilityHidden(true)
                                    Text(text)
                                        .foregroundStyle(NorthstarChatStyle.text)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    section("Your privacy, in short") {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(privacy, id: \.self) { line in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(NorthstarChatStyle.savedGreen)
                                        .padding(.top, 3)
                                        .accessibilityHidden(true)
                                    Text(line)
                                        .foregroundStyle(NorthstarChatStyle.text)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            if let privacyURL {
                                Link(destination: privacyURL) {
                                    Label("Read the full privacy page", systemImage: "arrow.up.right")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(NorthstarChatStyle.linkBlue)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }

                    if let contactEmail, let mail = URL(string: "mailto:\(contactEmail)") {
                        section("Contact") {
                            Link(destination: mail) {
                                Label(contactEmail, systemImage: "envelope")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(NorthstarChatStyle.linkBlue)
                            }
                        }
                    }

                    if let insights {
                        NavigationLink {
                            InsightsView(report: insights)
                        } label: {
                            Label("Insights (Northstar Labs)", systemImage: "chart.bar")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(NorthstarChatStyle.linkBlue)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }

                    Button {
                        welcomed = false   // the welcome opens over the app
                    } label: {
                        Label("Show the welcome again", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NorthstarChatStyle.linkBlue)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }

                    VStack(spacing: 4) {
                        Text(version)
                        Text("Made by Northstar Labs")
                    }
                    .font(.footnote)
                    .foregroundStyle(NorthstarChatStyle.label)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .task { insights = await InsightsService.load(days: 7) }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(NorthstarChatStyle.label)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(NorthstarChatStyle.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(NorthstarChatStyle.stroke, lineWidth: 1))
    }
}

#Preview {
    NavigationStack { AboutView() }
}
