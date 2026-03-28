import SwiftUI
import AVFoundation

/// Reusable coordinator for presenting camera or photo library.
/// Usage: Add @StateObject var photoPicker = PhotoPickerManager() to your view,
/// then call photoPicker.showActionSheet = true and handle the result via photoPicker.selectedImage.
class PhotoPickerManager: NSObject, ObservableObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @Published var selectedImage: UIImage? = nil
    @Published var showActionSheet: Bool = false
    @Published var showCameraPermissionAlert: Bool = false

    var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func showCamera() {
        guard isCameraAvailable else { return }

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.presentPicker(sourceType: .camera)
                } else {
                    self?.showCameraPermissionAlert = true
                }
            }
        }
    }

    func showLibrary() {
        presentPicker(sourceType: .photoLibrary)
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func presentPicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = self
        picker.allowsEditing = true

        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }

        var presented = root
        while let next = presented.presentedViewController {
            presented = next
        }
        presented.present(picker, animated: true)
    }

    // MARK: - UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let edited = info[.editedImage] as? UIImage {
            selectedImage = edited
        } else if let original = info[.originalImage] as? UIImage {
            selectedImage = original
        }
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

/// SwiftUI modifier that adds photo source action sheet + camera permission alert.
struct PhotoPickerModifier: ViewModifier {
    @ObservedObject var manager: PhotoPickerManager

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Choose Photo", isPresented: $manager.showActionSheet, titleVisibility: .hidden) {
                if manager.isCameraAvailable {
                    Button("Take a Photo") { manager.showCamera() }
                }
                Button("Choose from Library") { manager.showLibrary() }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Camera Access Required", isPresented: $manager.showCameraPermissionAlert) {
                Button("Open Settings") { manager.openSettings() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Camera access is needed to take a profile photo. Enable it in Settings.")
            }
    }
}

extension View {
    func photoPickerSheet(manager: PhotoPickerManager) -> some View {
        modifier(PhotoPickerModifier(manager: manager))
    }
}
