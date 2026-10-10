import SwiftUI

/// Layout constants pulled out of NorthstarResponseContainer because static stored
/// properties aren't supported on a generic type.
private enum NorthstarResponseContainerMetrics {
    static let rowHorizontalPadding: CGFloat = 20
    static let contentHorizontalPadding: CGFloat = 18
}

/// The reusable Northstar pill shell. Preserves ChatBubbleView's original
/// RoundedRectangle(cornerRadius: 24, style: .continuous) fill and spacer-based
/// left/right stagger alignment exactly; only width and border/shadow emphasis
/// change with density, so every density still reads as the same pill family.
struct NorthstarResponseContainer<Content: View>: View {
    let isUser: Bool
    let density: NorthstarResponseDensity
    @ViewBuilder var content: () -> Content

    @State private var rowWidth: CGFloat = 0

    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: oppositeSpacerMinLength)
            }

            content()
                .padding(.horizontal, NorthstarResponseContainerMetrics.contentHorizontalPadding)
                .padding(.vertical, 14)
                .frame(maxWidth: maxContentWidth, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(NorthstarResponseTheme.pillFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(NorthstarResponseTheme.pillBorder, lineWidth: borderLineWidth)
                )
                .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: 6)

            if !isUser {
                Spacer(minLength: oppositeSpacerMinLength)
            }
        }
        .padding(.horizontal, NorthstarResponseContainerMetrics.rowHorizontalPadding)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { newWidth in
            rowWidth = newWidth
        }
    }

    /// Keeps the original 60pt conversational reserve for compact pills, but relaxes it as
    /// density increases so standard/expanded pills can actually reach their target width
    /// while still leaving a visible gap on the staggered side.
    private var oppositeSpacerMinLength: CGFloat {
        switch density {
        case .compact: return 60
        case .standard: return 32
        case .expanded: return 16
        }
    }

    /// Safe margins: the full row width minus this view's own horizontal padding and the
    /// opposite-side spacer's minimum, so an expanded pill never crowds the staggered side.
    private var maxContentWidth: CGFloat? {
        guard rowWidth > 0 else { return nil }
        let available = rowWidth - (NorthstarResponseContainerMetrics.rowHorizontalPadding * 2) - oppositeSpacerMinLength
        guard available > 0 else { return nil }

        switch density {
        case .compact:
            return nil
        case .standard:
            return available * 0.82
        case .expanded:
            return available * 0.92
        }
    }

    private var borderLineWidth: CGFloat {
        density == .compact ? 0 : 1
    }

    private var shadowRadius: CGFloat {
        density == .expanded ? 14 : 0
    }

    private var shadowColor: Color {
        density == .expanded ? NorthstarResponseTheme.pillShadow : .clear
    }
}

#Preview {
    VStack(spacing: 20) {
        NorthstarResponseContainer(isUser: false, density: .compact) {
            Text("Sure, I can help with that.")
                .foregroundStyle(.white)
        }
        NorthstarResponseContainer(isUser: false, density: .standard) {
            Text("A standard-density response with a bit more room to breathe.")
                .foregroundStyle(.white)
        }
        NorthstarResponseContainer(isUser: false, density: .expanded) {
            Text("An expanded response that uses nearly all of the available width while keeping safe margins on both sides.")
                .foregroundStyle(.white)
        }
        NorthstarResponseContainer(isUser: true, density: .compact) {
            Text("Got it, thanks!")
                .foregroundStyle(.white)
        }
    }
    .padding()
    .background(Color(red: 0.08, green: 0.12, blue: 0.25))
}
