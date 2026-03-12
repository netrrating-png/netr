import SwiftUI
import AuthenticationServices
import CryptoKit

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

                    Button {
                        Task {
                            do {
                                try await supabase.signInWithGoogle()
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack(spacing: 10) {
                            LucideIcon("globe", size: 20)
                                .foregroundStyle(.white)
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(NETRTheme.text)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(NETRTheme.card, in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(PressButtonStyle())

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
            } catch {
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
            else { return }
            Task {
                do {
                    try await supabase.signInWithApple(idToken: idToken, nonce: currentNonce)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        case .failure(let error):
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
