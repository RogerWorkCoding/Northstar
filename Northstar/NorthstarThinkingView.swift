import SwiftUI

struct NorthstarThinkingView: View {

    @State private var animate = false

    let disciplines: [String]

    var body: some View {

        VStack(spacing: 16) {

            Text("Considering the best approach...")
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 10) {

                ForEach(
                    disciplines,
                    id: \.self
                ) { discipline in

                    Text(discipline)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Color.white.opacity(0.12)
                        )
                        .clipShape(
                            Capsule()
                        )
                        .opacity(
                            animate ? 1.0 : 0.4
                        )
                }
            }

            Text("Drawing from relevant expertise...")
                .font(.caption)
                .foregroundStyle(
                    .white.opacity(0.7)
                )
        }
        .padding(18)
        .background(
            Color.white.opacity(0.08)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .onAppear {

            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever()
            ) {
                animate = true
            }
        }
    }
}

#Preview {

    ZStack {

        Color(
            red: 0.08,
            green: 0.12,
            blue: 0.25
        )
        .ignoresSafeArea()

        NorthstarThinkingView(
            disciplines: [
                "Design",
                "Development",
                "Strategy"
            ]
        )
        .padding()
    }
}
