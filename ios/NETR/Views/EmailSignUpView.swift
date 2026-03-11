import SwiftUI

struct EmailSignUpView: View {
    @Environment(SupabaseManager.self) private var supabase
    @Environment(\.dismiss) private var dismiss

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                NETRTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 6) {
                            Text("CREATE ACCOUNT")
                                .font(NETRTheme.headingFont)
                                .foregroundStyle(NETRTheme.text)
                            Text("Set up your email and password")
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
                                placeholder: "Email address",
                                text: $email,
                                icon: "envelope.fill",
                                keyboardType: .emailAddress
                            )
                            NETRSecureField(
                                placeholder: "Password (min 6 characters)",
                                text: $password,
                                icon: "lock.fill"
                            )
                            NETRSecureField(
                                placeholder: "Confirm password",
                                text: $confirmPassword,
                                icon: "lock.fill"
                            )
                        }
                        .padding(.horizontal, 24)

                        if !confirmPassword.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                                Text(passwordsMatch ? "Passwords match" : "Passwords don't match")
                                    .font(.system(size: 13))
                            }
                            .foregroundStyle(passwordsMatch ? NETRTheme.neonGreen : NETRTheme.red)
                        }

                        Button {
                            continueToOnboarding()
                        } label: {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(NETRTheme.background)
                                } else {
                                    Text("CONTINUE")
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
                            .shadow(
                                color: isFormValid ? NETRTheme.neonGreen.opacity(0.4) : .clear,
                                radius: 12
                            )
                        }
                        .disabled(!isFormValid || isLoading)
                        .padding(.horizontal, 24)
                        .buttonStyle(PressButtonStyle())

                        Text("By continuing you agree to NETR's Terms of Service and Privacy Policy.")
                            .font(.system(size: 11))
                            .foregroundStyle(NETRTheme.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 32)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
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

    private var passwordsMatch: Bool { password == confirmPassword }

    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 6 && passwordsMatch
    }

    private func continueToOnboarding() {
        supabase.pendingEmail = email
        supabase.pendingPassword = password
        dismiss()
    }
}
