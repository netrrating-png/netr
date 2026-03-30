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

                    Button {
                        Task {
                            do {
                                try await supabase.signInWithGoogle()
                            } catch is CancellationError {
                                // User dismissed the Google sign-in sheet — no error to show
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                        }
                    } label: {
                        HStack(spacing: 12) {
                            GoogleLogo(size: 22)
                            Text("Continue with Google")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color(red: 31/255, green: 31/255, blue: 31/255))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.white, in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(white: 0.82), lineWidth: 1))
                        .shadow(color: .black.opacity(0.10), radius: 6, y: 2)
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

// MARK: - Google G logo (four-colour arc, matches brand guidelines)

struct GoogleLogo: View {
    var size: CGFloat = 24

    // Official Google brand colours
    private static let blue   = Color(red: 66/255,  green: 133/255, blue: 244/255)
    private static let red    = Color(red: 234/255, green:  67/255, blue:  53/255)
    private static let yellow = Color(red: 251/255, green: 188/255, blue:   5/255)
    private static let green  = Color(red:  52/255, green: 168/255, blue:  83/255)

    var body: some View {
        Canvas { ctx, sz in
            let cx     = sz.width  / 2
            let cy     = sz.height / 2
            let r      = sz.width  * 0.435
            let stroke = sz.width  * 0.195
            let mid    = CGPoint(x: cx, y: cy)

            // Helper: draw a single coloured arc segment
            func arc(_ start: Double, _ end: Double, _ color: Color) {
                var p = Path()
                p.addArc(center: mid, radius: r,
                         startAngle: .degrees(start),
                         endAngle:   .degrees(end),
                         clockwise: false)
                ctx.stroke(p, with: .color(color), lineWidth: stroke)
            }

            // Arc colour distribution (clockwise angles, 0° = 3 o'clock):
            //  Blue   : top-left + left + most of bottom (~100° → 315°)
            //  Red    : bottom-left (~315° → 355°)  ← small slice
            //  Yellow : bottom-right (~355° → 460°/100°) — crosses 0°
            //  Green  : right side  (0° → 100°) — where the crossbar sits
            arc(100, 315, Self.blue)
            arc(315, 355, Self.red)
            arc(355, 460, Self.yellow)   // 460° = 100° after wrapping
            arc(  0, 100, Self.green)

            // Horizontal crossbar (Google "G" right arm) in blue
            let barY      = cy + sz.height * 0.006
            let barLeft   = cx + r * 0.04
            let barRight  = cx + r + stroke * 0.5
            let barHeight = stroke
            let bar = CGRect(x: barLeft,
                             y: barY - barHeight / 2,
                             width: barRight - barLeft,
                             height: barHeight)
            ctx.fill(Path(roundedRect: bar, cornerRadius: barHeight / 2),
                     with: .color(Self.blue))
        }
        .frame(width: size, height: size)
    }
}
