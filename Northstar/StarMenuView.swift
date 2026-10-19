import SwiftUI

struct StarMenuView: View {

    @Binding var isPresented: Bool

    /// Opens a place from the shared list (ContentView decides how: screen, sheet or action).
    var onOpen: (NorthstarRoute) -> Void = { _ in }

    private static let sections = Array(Set(NorthstarDestinations.all.filter(\.inMenu).map(\.menuSection))).sorted()

    var body: some View {
        ZStack(alignment: .leading) {

            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    closeMenu()
                }

            VStack(
                alignment: .leading,
                spacing: 0
            ) {

                menuHeader

                Divider()
                    .overlay(
                        .white.opacity(0.15)
                    )
                    .padding(.vertical, 14)

                // The rows come from the one shared list (NorthstarDestinations), in its order and groups.
                ForEach(Self.sections, id: \.self) { section in
                    if section != Self.sections.first { sectionDivider }
                    ForEach(NorthstarDestinations.available.filter { $0.inMenu && $0.menuSection == section }) { d in
                        menuButton(title: d.title, systemImage: d.symbol) { onOpen(d.route) }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            .frame(width: 240)
            .frame(maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(
                        .white.opacity(0.12)
                    )
                    .frame(width: 1)
            }
        }
    }

    private var menuHeader: some View {
        HStack {
            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Image(systemName: "sparkle")
                    .font(
                        .system(
                            size: 24,
                            weight: .ultraLight
                        )
                    )
                    .foregroundStyle(.white)

                Text("Northstar")
                    .font(
                        .system(
                            size: 24,
                            weight: .light
                        )
                    )
                    .tracking(2)
                    .foregroundStyle(.white)
            }

            Spacer()
        }
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(
                .white.opacity(0.12)
            )
            .padding(.vertical, 10)
    }

    private func menuButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {

        Button {
            action()
            closeMenu()
        } label: {

            HStack(spacing: 14) {

                Image(systemName: systemImage)
                    .font(
                        .system(
                            size: 17,
                            weight: .light
                        )
                    )
                    .frame(width: 24)

                Text(title)
                    .font(
                        .system(
                            size: 17,
                            weight: .regular
                        )
                    )

                Spacer()
            }
            .foregroundStyle(
                .white.opacity(0.92)
            )
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func closeMenu() {
        withAnimation(
            .easeInOut(duration: 0.25)
        ) {
            isPresented = false
        }
    }
}

#Preview {
    StarMenuView(
        isPresented: .constant(true)
    )
    .background(
        Color(
            red: 0.08,
            green: 0.12,
            blue: 0.25
        )
    )
}
