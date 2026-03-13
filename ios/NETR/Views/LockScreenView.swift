import SwiftUI

struct LockScreenView: View {

    @Environment(BiometricAuthManager.self) private var biometrics
    @Environment(SupabaseManager.self) private var supabase

    @State private var isAuthenticating: Bool = false
    @State private var pulseAnimation: Bool = false

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            Canvas { context, size in
                let spacing: CGFloat = 40
                var path = Path()
                stride(from: 0, through: size.width, by: spacing).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: 0, through: size.height, by: spacing).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(NETRTheme.neonGreen.opacity(0.04)), lineWidth: 1)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image("NETRLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .clipShape(.rect(cornerRadius: 14))
                        .shadow(color: NETRTheme.neonGreen.opacity(0.4), radius: 20)

                    Text("NETR")
                        .font(.system(size: 42, weight: .black, design: .default).width(.compressed))
                        .foregroundStyle(NETRTheme.text)
                        .tracking(4)
                }

                Spacer()

                VStack(spacing: 20) {
                    if let error = biometrics.authError,
                       let description = error.errorDescription {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundStyle(NETRTheme.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .transition(.opacity)
                    }

                    Button {
                        Task { await attemptBiometricAuth() }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(
                                    NETRTheme.neonGreen.opacity(pulseAnimation ? 0 : 0.3),
                                    lineWidth: 2
                                )
                                .frame(width: pulseAnimation ? 100 : 80, height: pulseAnimation ? 100 : 80)
                                .animation(
                                    .easeInOut(duration: 1.5).repeatForever(autoreverses: false),
                                    value: pulseAnimation
                                )

                            Circle()
                                .fill(NETRTheme.card)
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Circle()
                                        .stroke(NETRTheme.neonGreen.opacity(0.4), lineWidth: 1.5)
                                )

                            if isAuthenticating {
                                ProgressView()
                                    .tint(NETRTheme.neonGreen)
                                    .scaleEffect(1.2)
                            } else {
                                Image(systemName: biometrics.biometricType.iconName)
                                    .font(.system(size: 32, weight: .light))
                                    .foregroundStyle(NETRTheme.neonGreen)
                            }
                        }
                    }
                    .disabled(isAuthenticating)

                    Text(isAuthenticating
                         ? "Authenticating..."
                         : "Tap to unlock with \(biometrics.biometricType.displayName)"
                    )
                    .font(.system(size: 15))
                    .foregroundStyle(NETRTheme.subtext)

                    Button {
                        try? supabase.signOut()
                    } label: {
                        Text("Sign in with a different account")
                            .font(.system(size: 13))
                            .foregroundStyle(NETRTheme.muted)
                            .underline()
                    }
                    .padding(.top, 8)
                }
                .padding(.bottom, 64)
            }
        }
        .onAppear {
            pulseAnimation = true
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                await attemptBiometricAuth()
            }
        }
    }

    private func attemptBiometricAuth() async {
        isAuthenticating = true
        let success = await biometrics.authenticate(reason: "Unlock NETR")
        isAuthenticating = false
        if !success && biometrics.authError == .lockout {
            _ = await biometrics.authenticateWithPasscode(reason: "Unlock NETR")
        }
    }
}
