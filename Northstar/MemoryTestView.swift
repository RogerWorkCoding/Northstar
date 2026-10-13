import SwiftUI

struct MemoryTestView: View {

    
    @State private var memoryText = ""
    @State private var category = "Architecture"

    private let memoryService = MemoryService()

    
    var body: some View {

        NavigationStack {

            VStack(spacing: 20) {

                Text("Memory Test")
                    .font(.largeTitle)

                TextField(
                    "Category",
                    text: $category
                )
                .textFieldStyle(.roundedBorder)

                TextEditor(
                    text: $memoryText
                )
                .frame(height: 200)
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 12
                    )
                    .stroke(.gray.opacity(0.3))
                }

                Button("Save Memory") {

                    Task {

                        do {

                            try await memoryService.saveMemory(
                                identityId: SupabaseManager.shared.identityId,
                                projectId: nil,
                                content: memoryText,
                                category: category
                            )

                            print("✅ Memory Saved")

                        } catch {

                            print("❌ Save Failed:", error)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                Spacer()
            }
            .padding()
        }
    }
}

#Preview {
    MemoryTestView()
}
