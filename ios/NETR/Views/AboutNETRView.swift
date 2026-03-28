import SwiftUI
import MessageUI

struct AboutNETRView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo & Version
                    VStack(spacing: 12) {
                        Text("NETR")
                            .font(.system(size: 48, weight: .black, design: .default).width(.compressed))
                            .tracking(4)
                            .foregroundStyle(NETRTheme.neonGreen)

                        Text("Version \(appVersion)")
                            .font(.caption)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                    .padding(.top, 40)

                    // Tagline
                    Text("The Court. The Rating. The Rep.")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(NETRTheme.text)
                        .multilineTextAlignment(.center)

                    // Description
                    Text("NETR is the peer-rating platform for pickup basketball players. Built for streetball culture, starting in New York City. Your NETR score is earned on the court — one game at a time.")
                        .font(.subheadline)
                        .foregroundStyle(NETRTheme.subtext)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Built by ballers
                    VStack(spacing: 8) {
                        Rectangle()
                            .fill(NETRTheme.neonGreen.opacity(0.3))
                            .frame(width: 40, height: 2)
                        Text("Built by ballers, for ballers.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(NETRTheme.neonGreen)
                    }

                    // Links
                    VStack(spacing: 12) {
                        aboutLink(icon: "star", title: "Rate the App") {
                            // Open App Store (placeholder URL)
                            if let url = URL(string: "https://apps.apple.com/app/netr") {
                                openURL(url)
                            }
                        }

                        aboutLink(icon: "instagram", title: "Follow Us") {
                            // Placeholder
                        }

                        aboutLink(icon: "mail", title: "Contact Us") {
                            if let url = URL(string: "mailto:netr@netrapp.com") {
                                openURL(url)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)
                }
            }
            .scrollIndicators(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        LucideIcon("x", size: 14)
                            .foregroundStyle(NETRTheme.subtext)
                    }
                }
            }
        }
    }

    private func aboutLink(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                LucideIcon(icon, size: 16)
                    .foregroundStyle(NETRTheme.neonGreen)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NETRTheme.text)
                Spacer()
                LucideIcon("chevron-right", size: 12)
                    .foregroundStyle(NETRTheme.muted)
            }
            .padding(14)
            .background(NETRTheme.card, in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
