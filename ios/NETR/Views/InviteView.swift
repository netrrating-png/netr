import SwiftUI
import Contacts
import ContactsUI

// MARK: — Model

private struct ContactEntry: Identifiable {
    let id: String
    let name: String
    let phone: String
}

// MARK: — View

struct InviteView: View {
    @Environment(\.dismiss) private var dismiss

    private let appStoreURL = "https://apps.apple.com/app/netr/id6745817342"

    @State private var contacts: [ContactEntry] = []
    @State private var searchText = ""
    @State private var accessDenied = false
    @State private var copiedPhone: String? = nil

    private var filtered: [ContactEntry] {
        searchText.isEmpty ? contacts : contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.phone.contains(searchText)
        }
    }

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("INVITE FRIENDS")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(1.4)
                            .foregroundStyle(NETRTheme.neonGreen)
                        Text("Bring Your Crew.")
                            .font(.custom("BarlowCondensed-Black", size: 32))
                            .foregroundStyle(NETRTheme.text)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NETRTheme.subtext)
                            .padding(10)
                            .background(NETRTheme.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(NETRTheme.muted, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                // Copy link banner
                copyLinkBanner
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                if accessDenied {
                    deniedView
                } else {
                    // Search
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(NETRTheme.subtext)
                            .font(.system(size: 14))
                        TextField("Search contacts…", text: $searchText)
                            .font(.system(size: 14))
                            .foregroundStyle(NETRTheme.text)
                            .tint(NETRTheme.neonGreen)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(NETRTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.muted, lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)

                    if contacts.isEmpty {
                        loadingOrEmpty
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 6) {
                                ForEach(filtered) { contact in
                                    ContactRow(
                                        contact: contact,
                                        appStoreURL: appStoreURL,
                                        isCopied: copiedPhone == contact.phone,
                                        onCopied: { copiedPhone = contact.phone }
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
        }
        .onAppear(perform: loadContacts)
    }

    // MARK: — Sub-views

    private var copyLinkBanner: some View {
        Button(action: copyLink) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(NETRTheme.neonGreen.opacity(0.15))
                        .frame(width: 40, height: 40)
                    LucideIcon("share-2", size: 18)
                        .foregroundStyle(NETRTheme.neonGreen)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Share Invite Link")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(NETRTheme.text)
                    Text("Copy link to send via any app")
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext)
                }
                Spacer()
                Text(copiedPhone == "link" ? "Copied!" : "Copy")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(NETRTheme.neonGreen)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(NETRTheme.neonGreen.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1))
            }
            .padding(14)
            .background(NETRTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NETRTheme.neonGreen.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Spacer()
            LucideIcon("contact", size: 40)
                .foregroundStyle(NETRTheme.subtext)
            Text("Contacts Access Needed")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(NETRTheme.text)
            Text("Enable contacts in Settings to invite friends directly.")
                .font(.system(size: 13))
                .foregroundStyle(NETRTheme.subtext)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(NETRTheme.neonGreen)
            Spacer()
        }
    }

    private var loadingOrEmpty: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .tint(NETRTheme.neonGreen)
            Text("Loading contacts…")
                .font(.system(size: 13))
                .foregroundStyle(NETRTheme.subtext)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: — Helpers

    private func copyLink() {
        let message = "Join me on NETR — the app for tracking your basketball rating. Download it here: \(appStoreURL)"
        UIPasteboard.general.string = message
        withAnimation { copiedPhone = "link" }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { if copiedPhone == "link" { copiedPhone = nil } }
        }
    }

    private func loadContacts() {
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async {
                guard granted else { accessDenied = true; return }
                let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
                let request = CNContactFetchRequest(keysToFetch: keys)
                var result: [ContactEntry] = []
                try? store.enumerateContacts(with: request) { contact, _ in
                    guard let phone = contact.phoneNumbers.first?.value.stringValue else { return }
                    let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty else { return }
                    result.append(ContactEntry(id: contact.identifier, name: name, phone: phone))
                }
                contacts = result.sorted { $0.name < $1.name }
            }
        }
    }
}

// MARK: — Contact Row

private struct ContactRow: View {
    let contact: ContactEntry
    let appStoreURL: String
    let isCopied: Bool
    let onCopied: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar initials
            ZStack {
                Circle()
                    .fill(NETRTheme.surface)
                Circle()
                    .stroke(NETRTheme.muted, lineWidth: 1)
                Text(initials)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(NETRTheme.subtext)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NETRTheme.text)
                Text(contact.phone)
                    .font(.system(size: 12))
                    .foregroundStyle(NETRTheme.subtext)
            }

            Spacer()

            Button(action: copyInvite) {
                Text(isCopied ? "Copied!" : "Invite")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isCopied ? NETRTheme.subtext : NETRTheme.neonGreen)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        isCopied
                        ? NETRTheme.muted.opacity(0.4)
                        : NETRTheme.neonGreen.opacity(0.12)
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(
                            isCopied ? Color.clear : NETRTheme.neonGreen.opacity(0.3),
                            lineWidth: 1
                        )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(NETRTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.muted, lineWidth: 1))
    }

    private var initials: String {
        contact.name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined()
    }

    private func copyInvite() {
        let message = "Hey \(contact.name.split(separator: " ").first.map(String.init) ?? contact.name)! Join me on NETR — the app where we track our basketball rating. Download it here: \(appStoreURL)"
        UIPasteboard.general.string = message
        onCopied()
    }
}
