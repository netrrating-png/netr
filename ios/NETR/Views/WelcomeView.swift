import SwiftUI
import AuthenticationServices
import CryptoKit
import Auth

struct WelcomeView: View {
    @Environment(SupabaseManager.self) private var supabase
    let onContinue: () -> Void
    var onGoogleSignedInAsNewUser: (() -> Void)? = nil
    var onGoogleSignedInAsExistingUser: (() -> Void)? = nil

    @State private var showSignIn: Bool = false
    @State private var showEmailSignUp: Bool = false
    @State private var errorMessage: String?
    @State private var isCheckingExisting: Bool = false
    @State private var currentNonce: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LoopingVideoView(fileName: "netr_vid", fileExtension: "mp4")
                .ignoresSafeArea()
                .allowsHitTesting(false)

            LinearGradient(
                colors: [Color.black.opacity(0.3), Color.black.opacity(0.0), Color.black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image("NETRLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 50)
                        .clipShape(.rect(cornerRadius: 10))
                        .shadow(color: NETRTheme.neonGreen.opacity(0.6), radius: 10)

                    Text("RUN. RATE. REP. NETR.")
                        .font(.system(.title3, design: .default, weight: .black).width(.compressed))
                        .tracking(2)
                        .foregroundStyle(NETRTheme.neonGreen)
                        .shadow(color: NETRTheme.neonGreen.opacity(0.9), radius: 8)
                        .shadow(color: NETRTheme.neonGreen.opacity(0.5), radius: 20)
                        .shadow(color: NETRTheme.neonGreen.opacity(0.3), radius: 40)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                VStack(spacing: 12) {
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(NETRTheme.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    // Apple sign-in — FIRST and most prominent (guideline 4.8)
                    SignInWithAppleButton(.signUp) { request in
                        let nonce = randomNonceString()
                        currentNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = sha256(nonce)
                    } onCompletion: { result in
                        handleAppleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .clipShape(.rect(cornerRadius: 14))

                    // Google sign-in
                    GoogleSignInButtonView {
                        Task {
                            do {
                                try await supabase.signInWithGoogle()
                                // Wait up to 3s for loadProfile to finish
                                for _ in 0..<6 {
                                    if supabase.currentProfile != nil { break }
                                    try? await Task.sleep(for: .milliseconds(500))
                                }
                                if supabase.currentProfile == nil {
                                    // New Google user with no profile yet — go through setup
                                    onGoogleSignedInAsNewUser?()
                                } else {
                                    // Returning Google user with profile — go straight in
                                    onGoogleSignedInAsExistingUser?()
                                }
                            } catch is CancellationError {
                                // User dismissed — no error to show
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }

                    // Email sign-up
                    Button {
                        showEmailSignUp = true
                    } label: {
                        Text("SIGN UP WITH EMAIL")
                            .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                            .tracking(1.5)
                            .foregroundStyle(NETRTheme.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(PressButtonStyle())

                    Button {
                        showSignIn = true
                    } label: {
                        HStack(spacing: 0) {
                            Text("Already have an account? ")
                                .foregroundStyle(NETRTheme.subtext)
                            Text("Sign In")
                                .foregroundStyle(NETRTheme.neonGreen)
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showEmailSignUp) {
            EmailSignUpView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: showEmailSignUp) { _, isShowing in
            if !isShowing && !supabase.pendingEmail.isEmpty {
                trySignInExistingUser()
            }
        }
        .overlay {
            if isCheckingExisting {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(NETRTheme.neonGreen)
                            .scaleEffect(1.3)
                        Text("Checking account...")
                            .font(.caption)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
            }
        }
    }

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    private func trySignInExistingUser() {
        isCheckingExisting = true
        Task {
            do {
                try await supabase.signInWithEmail(
                    email: supabase.pendingEmail,
                    password: supabase.pendingPassword
                )

                // Poll briefly for profile
                for _ in 0..<6 {
                    if supabase.currentProfile != nil { break }
                    try? await Task.sleep(for: .milliseconds(300))
                }

                // Sign-in succeeded — this is a returning user
                if supabase.currentProfile != nil {
                    hasCompletedOnboarding = true
                } else {
                    onContinue()
                }
            } catch let authError as AuthError {
                print("[NETR] Existing user check failed (auth): \(authError.localizedDescription)")
                onContinue()
            } catch let urlError as URLError {
                errorMessage = "Network error. Check your connection and try again."
                print("[NETR] Existing user check network error: \(urlError)")
            } catch {
                print("[NETR] Existing user check failed: \(error)")
                onContinue()
            }
            isCheckingExisting = false
        }
    }

    // MARK: - Apple Sign-In

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let idTokenData = credential.identityToken,
                let idToken = String(data: idTokenData, encoding: .utf8)
            else { return }

            var appleFullName: String?
            if let nameComponents = credential.fullName {
                let first = nameComponents.givenName ?? ""
                let last = nameComponents.familyName ?? ""
                let name = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { appleFullName = name }
            }

            Task {
                do {
                    try await supabase.signInWithApple(idToken: idToken, nonce: currentNonce, fullName: appleFullName)

                    for _ in 0..<6 {
                        if supabase.currentProfile != nil { break }
                        try? await Task.sleep(for: .milliseconds(500))
                    }

                    if supabase.currentProfile == nil {
                        onGoogleSignedInAsNewUser?()
                    } else {
                        onGoogleSignedInAsExistingUser?()
                    }
                } catch {
                    if (error as? ASAuthorizationError)?.code == .canceled { return }
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = "Apple sign in failed. Try again."
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { byte in charset[Int(byte) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Google Sign-In Button

struct GoogleSignInButtonView: View {
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                GoogleGIcon()
                    .frame(width: 22, height: 22)
                Text("Sign in with Google")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.white)
            .clipShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(PressButtonStyle())
    }
}

// MARK: - Google "G" Icon
// Paths derived from the official Google G mark SVG (24×24 viewBox).
// Four filled shapes — NOT arc strokes — scaled to fit the view.

private struct GoogleGIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let scale = min(size.width, size.height) / 24.0
            // Apply scale so we can work in 24×24 coordinate space
            ctx.concatenate(CGAffineTransform(scaleX: scale, y: scale))

            // ── Blue: top-right arc + horizontal bar ─────────────────────────
            var blue = Path()
            blue.move(to:    CGPoint(x: 22.56, y: 12.25))
            blue.addCurve(to: CGPoint(x: 22.36, y: 10),
                          control1: CGPoint(x: 22.56, y: 11.47),
                          control2: CGPoint(x: 22.49, y: 10.72))
            blue.addLine(to: CGPoint(x: 12, y: 10))
            blue.addLine(to: CGPoint(x: 12, y: 14.26))
            blue.addLine(to: CGPoint(x: 17.92, y: 14.26))
            blue.addCurve(to: CGPoint(x: 15.71, y: 17.57),
                          control1: CGPoint(x: 17.66, y: 15.63),
                          control2: CGPoint(x: 16.88, y: 16.79))
            blue.addLine(to: CGPoint(x: 15.71, y: 20.34))
            blue.addLine(to: CGPoint(x: 19.28, y: 20.34))
            blue.addCurve(to: CGPoint(x: 22.56, y: 12.25),
                          control1: CGPoint(x: 21.36, y: 18.42),
                          control2: CGPoint(x: 22.56, y: 15.60))
            blue.closeSubpath()
            ctx.fill(blue, with: .color(Color(red: 0.259, green: 0.522, blue: 0.957)))

            // ── Green: bottom arc ─────────────────────────────────────────────
            var green = Path()
            green.move(to:    CGPoint(x: 12, y: 23))
            green.addCurve(to: CGPoint(x: 19.28, y: 20.34),
                           control1: CGPoint(x: 14.97, y: 23),
                           control2: CGPoint(x: 17.46, y: 22.02))
            green.addLine(to: CGPoint(x: 15.71, y: 17.57))
            green.addCurve(to: CGPoint(x: 12, y: 18.63),
                           control1: CGPoint(x: 14.73, y: 18.23),
                           control2: CGPoint(x: 13.48, y: 18.63))
            green.addCurve(to: CGPoint(x: 5.84, y: 14.09),
                           control1: CGPoint(x: 9.14, y: 18.63),
                           control2: CGPoint(x: 6.71, y: 16.70))
            green.addLine(to: CGPoint(x: 2.18, y: 14.09))
            green.addLine(to: CGPoint(x: 2.18, y: 16.93))
            green.addCurve(to: CGPoint(x: 12, y: 23),
                           control1: CGPoint(x: 3.99, y: 20.53),
                           control2: CGPoint(x: 7.70, y: 23))
            green.closeSubpath()
            ctx.fill(green, with: .color(Color(red: 0.204, green: 0.659, blue: 0.325)))

            // ── Yellow: left arc ──────────────────────────────────────────────
            var yellow = Path()
            yellow.move(to:    CGPoint(x: 5.84, y: 14.09))
            yellow.addCurve(to: CGPoint(x: 5.49, y: 12),
                            control1: CGPoint(x: 5.62, y: 13.43),
                            control2: CGPoint(x: 5.49, y: 12.73))
            yellow.addCurve(to: CGPoint(x: 5.84, y: 9.91),
                            control1: CGPoint(x: 5.49, y: 11.27),
                            control2: CGPoint(x: 5.62, y: 10.57))
            yellow.addLine(to: CGPoint(x: 5.84, y: 7.07))
            yellow.addLine(to: CGPoint(x: 2.18, y: 7.07))
            yellow.addCurve(to: CGPoint(x: 1, y: 12),
                            control1: CGPoint(x: 1.43, y: 8.55),
                            control2: CGPoint(x: 1, y: 10.22))
            yellow.addCurve(to: CGPoint(x: 2.18, y: 16.93),
                            control1: CGPoint(x: 1, y: 13.78),
                            control2: CGPoint(x: 1.43, y: 15.45))
            yellow.addLine(to: CGPoint(x: 5.03, y: 14.71))
            yellow.addLine(to: CGPoint(x: 5.84, y: 14.09))
            yellow.closeSubpath()
            ctx.fill(yellow, with: .color(Color(red: 0.984, green: 0.737, blue: 0.020)))

            // ── Red: top-left arc ─────────────────────────────────────────────
            var red = Path()
            red.move(to:    CGPoint(x: 12, y: 5.38))
            red.addCurve(to: CGPoint(x: 16.21, y: 7.02),
                         control1: CGPoint(x: 13.62, y: 5.38),
                         control2: CGPoint(x: 15.06, y: 5.94))
            red.addLine(to: CGPoint(x: 19.36, y: 3.87))
            red.addCurve(to: CGPoint(x: 12, y: 1),
                         control1: CGPoint(x: 17.45, y: 2.09),
                         control2: CGPoint(x: 14.97, y: 1))
            red.addCurve(to: CGPoint(x: 2.18, y: 7.07),
                         control1: CGPoint(x: 7.70, y: 1),
                         control2: CGPoint(x: 3.99, y: 3.47))
            red.addLine(to: CGPoint(x: 5.84, y: 9.91))
            red.addCurve(to: CGPoint(x: 12, y: 5.38),
                         control1: CGPoint(x: 6.71, y: 7.31),
                         control2: CGPoint(x: 9.14, y: 5.38))
            red.closeSubpath()
            ctx.fill(red, with: .color(Color(red: 0.918, green: 0.263, blue: 0.208)))
        }
    }
}
