import SwiftUI
import AuthenticationServices
import CryptoKit
import Auth

struct SignInView: View {
    @Environment(SupabaseManager.self) private var supabase
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var currentNonce: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 6) {
                            Text("WELCOME BACK")
                                .font(NETRTheme.headingFont)
                                .foregroundStyle(NETRTheme.text)
                            Text("Sign in to your NETR account")
                                .font(.subheadline)
                                .foregroundStyle(NETRTheme.subtext)
                        }
                        .padding(.top, 32)

                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(NETRTheme.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        VStack(spacing: 12) {
                            NETRTextField(
                                placeholder: "Email",
                                text: $email,
                                icon: "envelope.fill",
                                keyboardType: .emailAddress
                            )
                            NETRSecureField(
                                placeholder: "Password",
                                text: $password,
                                icon: "lock.fill"
                            )
                        }
                        .padding(.horizontal, 24)

                        Button {
                            Task { await signIn() }
                        } label: {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(NETRTheme.background)
                                } else {
                                    Text("SIGN IN")
                                        .font(.system(.headline, design: .default, weight: .black).width(.compressed))
                                        .tracking(1.5)
                                        .foregroundStyle(NETRTheme.background)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                isFormValid ? NETRTheme.neonGreen : NETRTheme.muted,
                                in: .rect(cornerRadius: 14)
                            )
                        }
                        .disabled(!isFormValid || isLoading)
                        .padding(.horizontal, 24)
                        .buttonStyle(PressButtonStyle())

                        HStack {
                            Rectangle()
                                .fill(NETRTheme.border)
                                .frame(height: 1)
                            Text("or")
                                .font(.system(size: 13))
                                .foregroundStyle(NETRTheme.subtext)
                                .padding(.horizontal, 12)
                            Rectangle()
                                .fill(NETRTheme.border)
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 24)

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
                        .padding(.horizontal, 24)

                        Spacer(minLength: 32)
                    }
                }
                .dismissKeyboardOnScroll()
            }
            .hideKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 6
    }

    private func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await supabase.signInWithEmail(email: email, password: password)
            dismiss()
        } catch let authError as AuthError {
            errorMessage = authError.localizedDescription
        } catch let urlError as URLError {
            errorMessage = "Network error. Check your connection and try again."
            print("[NETR] Sign-in network error: \(urlError)")
        } catch {
            errorMessage = "Invalid email or password. Try again."
            print("[NETR] Sign-in error: \(error)")
        }
        isLoading = false
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
                    dismiss()
                } catch {
                    print("[NETR Auth] Apple Sign-In error: \(error)")
                    errorMessage = "Apple sign in failed. Try again."
                }
            }
        case .failure(let error):
            print("[NETR Auth] Apple Sign-In failed: \(error)")
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
