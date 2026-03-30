import SwiftUI
import AuthenticationServices
import CryptoKit
import Auth

struct WelcomeView: View {
    @Environment(SupabaseManager.self) private var supabase
    let onContinue: () -> Void

    @State private var showSignIn: Bool = false
    @State private var showEmailSignUp: Bool = false
    @State private var errorMessage: String?
    @State private var currentNonce: String = ""
    @State private var isCheckingExisting: Bool = false

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
                            .shadow(color: NETRTheme.neonGreen.opacity(0.4), radius: 12)
                    }
                    .buttonStyle(PressButtonStyle())

                    GoogleSignInButtonView {
                        Task {
                            do {
                                try await supabase.signInWithGoogle()
                            } catch is CancellationError {
                                // User dismissed — no error to show
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .frame(height: 54)

                    SignInWithAppleButton(.signIn) { request in
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

    private func trySignInExistingUser() {
        isCheckingExisting = true
        Task {
            do {
                try await supabase.signInWithEmail(
                    email: supabase.pendingEmail,
                    password: supabase.pendingPassword
                )
                // Sign-in succeeded — session is set, user proceeds to main app
            } catch let authError as AuthError {
                // Invalid credentials means user doesn't exist yet — continue to onboarding
                print("[NETR] Existing user check failed (auth): \(authError.localizedDescription)")
                onContinue()
            } catch let urlError as URLError {
                // Network error — show message instead of silently continuing
                errorMessage = "Network error. Check your connection and try again."
                print("[NETR] Existing user check network error: \(urlError)")
            } catch {
                // Other errors — continue to onboarding (user likely doesn't exist)
                print("[NETR] Existing user check failed: \(error)")
                onContinue()
            }
            isCheckingExisting = false
        }
    }

    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let idTokenData = credential.identityToken,
                let idToken = String(data: idTokenData, encoding: .utf8)
            else {
                print("[NETR Auth] Apple credential missing identity token")
                return
            }
            print("[NETR Auth] Apple credential received")

            // Apple only sends name on the very first sign-in — capture it now
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
                } catch {
                    print("[NETR Auth] Apple Sign-In error: \(error)")
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            print("[NETR Auth] Apple Sign-In failed: \(error)")
            errorMessage = error.localizedDescription
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

// MARK: - Official Google Sign-In button (GIDSignInButton from GoogleSignIn SDK)

import GoogleSignIn

struct GoogleSignInButtonView: UIViewRepresentable {
    var onTap: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    func makeUIView(context: Context) -> GIDSignInButton {
        let btn = GIDSignInButton()
        btn.style = .wide          // Shows full "Sign in with Google" text + official G logo
        btn.colorScheme = .light   // White button, matches the Sign in with Apple style
        btn.layer.cornerRadius = 14
        btn.layer.masksToBounds = true
        btn.addTarget(context.coordinator,
                      action: #selector(Coordinator.tapped),
                      for: .touchUpInside)
        return btn
    }

    func updateUIView(_ uiView: GIDSignInButton, context: Context) {}

    final class Coordinator: NSObject {
        let onTap: () -> Void
        init(onTap: @escaping () -> Void) { self.onTap = onTap }
        @objc func tapped() { onTap() }
    }
}
