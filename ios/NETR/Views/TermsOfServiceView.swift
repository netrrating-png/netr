import SwiftUI
import Supabase
import Auth
import PostgREST

struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Last updated: March 2026")
                        .font(.caption)
                        .foregroundStyle(NETRTheme.subtext)
                        .padding(.top, 8)

                    tosSection("1. Acceptance of Terms") {
                        "By accessing or using the NETR mobile application (\"App\"), you agree to be bound by these Terms of Service (\"Terms\"). If you do not agree to these Terms, do not use the App. NETR reserves the right to modify these Terms at any time. Continued use of the App after changes constitutes acceptance of the modified Terms."
                    }

                    tosSection("2. User Accounts") {
                        "You must be at least 13 years of age to create an account. You are responsible for maintaining the confidentiality of your account credentials and for all activities that occur under your account. You agree to provide accurate, current, and complete information during registration and to update such information to keep it accurate. NETR reserves the right to suspend or terminate accounts that violate these Terms."
                    }

                    tosSection("3. User Content") {
                        "You retain ownership of content you post on NETR, including posts, comments, ratings, and profile information. By posting content, you grant NETR a non-exclusive, worldwide, royalty-free license to use, display, reproduce, and distribute your content in connection with operating the App. You are solely responsible for the content you post and represent that you have the right to post it."
                    }

                    tosSection("4. Peer Ratings & NETR Scores") {
                        "NETR allows users to rate other basketball players through peer ratings. Your NETR score is calculated based on peer ratings received during pickup games. You agree that ratings reflect subjective opinions and that NETR does not guarantee the accuracy of any rating. Manipulation of ratings, including creating fake accounts to inflate scores, is strictly prohibited."
                    }

                    tosSection("5. Prohibited Conduct") {
                        "You agree not to: (a) use the App for any illegal purpose; (b) harass, bully, or intimidate other users; (c) post false, misleading, or defamatory content; (d) manipulate ratings or game results; (e) impersonate another person; (f) use automated scripts or bots to interact with the App; (g) attempt to gain unauthorized access to other users' accounts; (h) interfere with the proper functioning of the App; (i) post spam or unsolicited promotional content."
                    }

                    tosSection("6. Basketball Courts & Location Data") {
                        "NETR provides information about basketball courts submitted by users and other sources. NETR does not guarantee the accuracy of court information, including availability, condition, or accessibility. Use of court location features requires your consent to share location data. You assume all risk associated with visiting any court listed on the App."
                    }

                    tosSection("7. Intellectual Property") {
                        "The NETR name, logo, and all related marks, designs, and slogans are trademarks of NETR. The App and its original content, features, and functionality are owned by NETR and are protected by international copyright, trademark, and other intellectual property laws. You may not copy, modify, distribute, or create derivative works based on the App without express written permission."
                    }

                    tosSection("8. Disclaimers") {
                        "THE APP IS PROVIDED \"AS IS\" AND \"AS AVAILABLE\" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED. NETR DOES NOT WARRANT THAT THE APP WILL BE UNINTERRUPTED, ERROR-FREE, OR FREE OF HARMFUL COMPONENTS. NETR DISCLAIMS ALL WARRANTIES, INCLUDING IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT."
                    }

                    tosSection("9. Limitation of Liability") {
                        "TO THE MAXIMUM EXTENT PERMITTED BY LAW, NETR SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES, INCLUDING BUT NOT LIMITED TO LOSS OF PROFITS, DATA, OR USE, ARISING OUT OF OR RELATED TO YOUR USE OF THE APP. NETR'S TOTAL LIABILITY SHALL NOT EXCEED THE AMOUNT YOU PAID TO NETR IN THE TWELVE MONTHS PRECEDING THE CLAIM."
                    }

                    tosSection("10. Governing Law") {
                        "These Terms shall be governed by and construed in accordance with the laws of the State of New York, without regard to its conflict of law provisions. Any legal action or proceeding arising under these Terms shall be brought exclusively in the courts located in New York County, New York."
                    }

                    tosSection("11. Changes to Terms") {
                        "NETR reserves the right to modify these Terms at any time. We will notify users of material changes through the App or via email. Your continued use of the App after such modifications constitutes your acceptance of the updated Terms."
                    }

                    tosSection("12. Contact") {
                        "If you have any questions about these Terms, please contact us at netr@netrapp.com."
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Terms of Service")
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

    private func tosSection(_ title: String, content: () -> String) -> some View {
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
