import SwiftUI

/// Top-right DM entry point. Used on Feed, Courts, Rate, and Daily Game
/// screens now that DMs live outside the tab bar.
///
/// Owns its own presentation of `DMInboxView` as a `fullScreenCover`.
struct DMHeaderButton: View {

    @Bindable var dmViewModel: DMViewModel
    @State private var showInbox: Bool = false

    var body: some View {
        Button {
            showInbox = true
        } label: {
            ZStack(alignment: .topTrailing) {
                LucideIcon("mail", size: 18)
                    .foregroundStyle(NETRTheme.text)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(NETRTheme.border, lineWidth: 1))

                if dmViewModel.totalUnread > 0 {
                    Text(dmViewModel.totalUnread > 9 ? "9+" : "\(dmViewModel.totalUnread)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(NETRTheme.neonGreen, in: Circle())
                        .offset(x: 4, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
        .fullScreenCover(isPresented: $showInbox, onDismiss: {
            Task { await dmViewModel.loadConversations() }
        }) {
            NavigationStack {
                DMInboxView(viewModel: dmViewModel)
            }
            .preferredColorScheme(.dark)
        }
        .task {
            await dmViewModel.loadConversations()
        }
    }
}
