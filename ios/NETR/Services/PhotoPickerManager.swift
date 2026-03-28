import SwiftUI
import AVFoundation
import UIKit

/// Reusable image picker that presents camera or photo library via UIImagePickerController.
/// Uses a completion handler pattern to avoid NSObject + @Published conflicts.
///
/// Usage in views:
///   @State private var showPhotoActionSheet = false
///   @State private var avatarImage: UIImage?
///   let photoPicker = PhotoPickerManager()
///
///   .confirmationDialog(...) { Button("Take") { photoPicker.showCamera { img in avatarImage = img } } }
final class PhotoPickerManager: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    private var onImageSelected: ((UIImage) -> Void)?

    var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    /// Show the camera. Checks permission first.
    /// - Parameters:
    ///   - completion: Called on the main thread with the selected/captured image.
    ///   - onPermissionDenied: Called if camera permission is denied.
    func showCamera(completion: @escaping (UIImage) -> Void, onPermissionDenied: (() -> Void)? = nil) {
        guard isCameraAvailable else { return }

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.onImageSelected = completion
                    self?.presentPicker(sourceType: .camera)
                } else {
                    onPermissionDenied?()
                }
            }
        }
    }

    /// Show the photo library picker.
    func showLibrary(completion: @escaping (UIImage) -> Void) {
        onImageSelected = completion
        presentPicker(sourceType: .photoLibrary)
    }

    /// Open the system Settings app (for granting camera permission).
    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Private

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
        let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
        picker.dismiss(animated: true) { [weak self] in
            if let image {
                self?.onImageSelected?(image)
            }
            self?.onImageSelected = nil
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [weak self] in
            self?.onImageSelected = nil
        }
    }
}
