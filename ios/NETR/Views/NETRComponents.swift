import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - QR Code (CoreImage — free, offline, no library)

struct QRCodeView: View {
    let content: String
    let size: CGFloat

    var body: some View {
        if let img = generateQR(from: content) {
            Image(uiImage: img)
                .interpolation(.none)   // keep pixels crisp — no blur
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .padding(12)
                .background(Color.white, in: .rect(cornerRadius: 12))
        }
    }

    private func generateQR(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        // Scale up to avoid blurriness
        let scale = size / output.extent.width * UIScreen.main.scale
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct NETRTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                LucideIcon(icon)
                    .foregroundStyle(NETRTheme.subtext)
                    .frame(width: 20)
            }
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .foregroundStyle(NETRTheme.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
        }
        .padding(14)
        .background(NETRTheme.card, in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    text.isEmpty ? NETRTheme.border : NETRTheme.neonGreen.opacity(0.5),
                    lineWidth: 1
                )
        )
    }
}

struct NETRSecureField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    @State private var isVisible: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                LucideIcon(icon)
                    .foregroundStyle(NETRTheme.subtext)
                    .frame(width: 20)
            }
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .foregroundStyle(NETRTheme.text)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .submitLabel(.done)

            Button {
                isVisible.toggle()
            } label: {
                LucideIcon(isVisible ? "eye-off" : "eye", size: 14)
                    .foregroundStyle(NETRTheme.subtext)
            }
        }
        .padding(14)
        .background(NETRTheme.card, in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    text.isEmpty ? NETRTheme.border : NETRTheme.neonGreen.opacity(0.5),
                    lineWidth: 1
                )
        )
    }
}

struct PlayerAvatar: View {
    let player: Player
    let size: CGFloat

    var ringColor: Color {
        player.isProspect ? NETRTheme.purple : (player.isProvisional ? NETRTheme.subtext : NETRRating.color(for: player.rating))
    }

    var body: some View {
        ZStack {
            if let imageData = player.profileImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Text(player.avatar)
                    .font(.system(size: size * 0.32, weight: .bold))
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: size, height: size)
                    .background(NETRTheme.card, in: Circle())
            }
        }
        .overlay(
            Circle()
                .stroke(ringColor, style: StrokeStyle(
                    lineWidth: 2.5,
                    dash: player.isProvisional && !player.isProspect ? [4, 3] : []
                ))
        )
    }
}

struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
