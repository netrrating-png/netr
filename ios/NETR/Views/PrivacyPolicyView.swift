import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Last updated: March 2026")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                        .padding(.top, 8)

                    section("1. Information We Collect") {
                        "We collect information you provide directly, including: your name, email address, username, date of birth, profile photo, city, and basketball position. We also collect peer ratings you give and receive, your NETR score, game session data, court check-ins, posts, comments, and direct messages. When you use location features, we collect your device's location data to show nearby courts and games."
                    }

                    section("2. How We Use Your Information") {
                        "We use your information to: (a) provide, maintain, and improve the NETR App; (b) calculate and display your NETR score based on peer ratings; (c) show you relevant basketball courts, games, and players near you; (d) facilitate social features including posts, comments, follows, and direct messages; (e) send you notifications about ratings, game invitations, and other activity; (f) analyze usage patterns to improve the App; (g) enforce our Terms of Service and protect user safety."
                    }

                    section("3. Information Sharing") {
                        "We do not sell your personal information to third parties. We may share your information with: (a) other NETR users as part of the App's social features (your profile, posts, ratings, and NETR score are visible to other users unless your profile is set to private); (b) service providers who assist in operating the App, including Supabase for backend infrastructure and data storage; (c) law enforcement if required by law or to protect the safety of our users; (d) in connection with a merger, acquisition, or sale of assets."
                    }

                    section("4. Data Storage & Security") {
                        "Your data is stored securely using Supabase, a cloud-based backend platform. We implement industry-standard security measures to protect your information, including encryption in transit and at rest. However, no method of electronic storage is 100% secure, and we cannot guarantee absolute security. Profile photos are stored in secure cloud storage buckets with access controls."
                    }

                    section("5. Data Retention") {
                        "We retain your personal information for as long as your account is active or as needed to provide you services. If you delete your account, we will delete your personal data within 30 days, except where retention is required by law or for legitimate business purposes. Aggregated, anonymized data that cannot identify you may be retained indefinitely for analytics purposes."
                    }

                    section("6. Your Rights") {
                        "You have the right to: (a) access and receive a copy of your personal data; (b) correct inaccurate personal data; (c) request deletion of your personal data; (d) restrict or object to processing of your data; (e) data portability; (f) withdraw consent at any time. To exercise these rights, contact us at netr@netrapp.com. California residents have additional rights under the CCPA, including the right to know what personal information is collected and the right to opt out of the sale of personal information."
                    }

                    section("7. Push Notifications") {
                        "With your permission, we send push notifications for activity such as new ratings, game invitations, follows, likes, comments, mentions, and nearby games. You can manage notification preferences within the App's settings or through your device's notification settings. Disabling push notifications will not affect the core functionality of the App."
                    }

                    section("8. Location Data") {
                        "NETR uses location data to show nearby basketball courts, active games, and players in your area. Location data is collected only when you grant permission through your device settings. You can revoke location permissions at any time through your device settings. We do not continuously track your location in the background unless you have enabled location-based game notifications."
                    }

                    section("9. Children's Privacy") {
                        "NETR is not intended for children under the age of 13. We do not knowingly collect personal information from children under 13. If we become aware that we have collected personal information from a child under 13, we will take steps to delete that information. If you believe we have collected information from a child under 13, please contact us at netr@netrapp.com."
                    }

                    section("10. Changes to This Policy") {
                        "We may update this Privacy Policy from time to time. We will notify you of material changes through the App or via email. Your continued use of the App after changes are posted constitutes your acceptance of the updated Privacy Policy. We encourage you to review this policy periodically."
                    }

                    section("11. Contact Us") {
                        "If you have questions about this Privacy Policy or our data practices, please contact us at netr@netrapp.com."
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Privacy Policy")
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

    private func section(_ title: String, content: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(NETRTheme.neonGreen)
            Text(content())
                .font(.caption)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
