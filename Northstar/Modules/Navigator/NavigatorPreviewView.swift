import SwiftUI

// 🧭 Northstar Navigator: "Coming soon" placeholder.
// Shows the design images of what Navigator will look like (iPhone and Mac). Nothing here works yet:
// there is no switch to turn on until Navigator is built. Plan: docs/northstar-navigator-plan.md.

struct NavigatorPreviewView: View {
    private struct Shot: Identifiable {
        let id: Int
        let caption: String
        var image: String { "NavigatorPreview-\(id)" }
        var isMac: Bool { id >= 5 }
    }

    private let shots: [Shot] = [
        Shot(id: 1, caption: "Turn it on. You'll see how it keeps you safe first."),
        Shot(id: 2, caption: "Ask in Chat. Watch each step, and stop it anytime."),
        Shot(id: 3, caption: "It asks for your OK before it sends, deletes or buys."),
        Shot(id: 4, caption: "See everything it did, with Undo."),
        Shot(id: 5, caption: "On your Mac: a small star in the menu bar shows what it's doing."),
        Shot(id: 6, caption: "On your Mac: pick the folders it may use."),
    ]

    @State private var page = 1
    /// Northstar Labs only: the working step 1 (find files on your Mac), while it's being built.
    @State private var ownerPreview = false

    var body: some View {
        VStack(spacing: 16) {
            if ownerPreview {
                NavigationLink {
                    NavigatorView()
                } label: {
                    Label("Open Navigator (owner preview)", systemImage: "sparkle.magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            Text("Coming soon")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.yellow.opacity(0.25)))
                .accessibilityAddTraits(.isHeader)

            Text("Ask, and Northstar does things on your Mac for you: finds and tidies your files, makes lists and summaries, and writes emails and events for you to send.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            TabView(selection: $page) {
                ForEach(shots) { shot in
                    VStack(spacing: 12) {
                        Image(shot.image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: shot.isMac ? 12 : 24, style: .continuous))
                            .shadow(radius: 8, y: 4)
                            .accessibilityLabel("Design preview \(shot.id) of 6")
                        Text(shot.caption)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .tag(shot.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Text("Design preview. Examples are made up, and nothing here works yet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .task { ownerPreview = await NavigatorService.status()?.allowed == true }
        .navigationTitle("Northstar Navigator")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { NavigatorPreviewView() }
}
