import SwiftUI
import UIKit

struct CameraView: UIViewControllerRepresentable {

    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(
        context: Context
    ) -> UIImagePickerController {

        let camera = UIImagePickerController()
        camera.delegate = context.coordinator
        camera.allowsEditing = false

        if UIImagePickerController
            .isSourceTypeAvailable(.camera) {

            camera.sourceType = .camera
            camera.cameraCaptureMode = .photo
        }

        return camera
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {
    }

    final class Coordinator:
        NSObject,
        UINavigationControllerDelegate,
        UIImagePickerControllerDelegate {

        let parent: CameraView

        init(parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info:
                [UIImagePickerController.InfoKey: Any]
        ) {
            parent.selectedImage =
                info[.originalImage] as? UIImage

            parent.dismiss()
        }

        func imagePickerControllerDidCancel(
            _ picker: UIImagePickerController
        ) {
            parent.dismiss()
        }
    }
}
