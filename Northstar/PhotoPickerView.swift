import SwiftUI
import PhotosUI
import UIKit

struct PhotoPickerView: View {

    @Binding var selectedImage: UIImage?

    @Environment(\.dismiss)
    private var dismiss

    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Choose a Photo")
                    .font(.title2)

                PhotosPicker(
                    selection: $photoItem,
                    matching: .images
                ) {
                    Label(
                        "Open Photo Library",
                        systemImage: "photo"
                    )
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: 14
                        )
                    )
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Photos")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: photoItem) {
            Task {
                guard let photoItem else {
                    return
                }

                if let data =
                    try? await photoItem.loadTransferable(
                        type: Data.self
                    ),
                   let image = UIImage(data: data) {

                    await MainActor.run {
                        selectedImage = image
                        dismiss()
                    }
                }
            }
        }
    }
}
