import SwiftUI
import Supabase
import Auth
import PostgREST

/// Reusable searchable sheet for selecting a court to tag in posts or DMs.
struct CourtTagPickerView: View {
    @Binding var selectedCourt: FeedCourtSearchResult?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var results: [FeedCourtSearchResult] = []
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>?

    private let client = SupabaseManager.shared.client

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    LucideIcon("search", size: 14)
                        .foregroundStyle(NETRTheme.subtext)
                    TextField("Search for a court by name", text: $searchText)
                        .font(.system(size: 14))
                        .foregroundStyle(NETRTheme.text)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                }
                .padding(12)
                .background(NETRTheme.card, in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(NETRTheme.border, lineWidth: 1))
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .onChange(of: searchText) { _, newValue in
                    performSearch(query: newValue)
                }

                if isSearching {
                    HStack {
                        ProgressView()
                            .tint(NETRTheme.neonGreen)
                            .scaleEffect(0.8)
                        Text("Searching...")
                            .font(.system(size: 13))
                            .foregroundStyle(NETRTheme.subtext)
                        Spacer()
                    }
                    .padding(16)
                } else if results.isEmpty && searchText.count >= 1 {
                    VStack(spacing: 12) {
                        Spacer()
                        LucideIcon("map-pin-off", size: 28)
                            .foregroundStyle(NETRTheme.muted)
                        Text("No courts found — try a different name")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else if searchText.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        LucideIcon("map-pin", size: 28)
                            .foregroundStyle(NETRTheme.muted)
                        Text("Search for a court by name")
                            .font(.subheadline)
                            .foregroundStyle(NETRTheme.subtext)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { court in
                                Button {
                                    selectedCourt = court
                                    dismiss()
                                } label: {
                                    courtRow(court)
                                }
                                .buttonStyle(.plain)

                                if court.id != results.last?.id {
                                    Divider().background(NETRTheme.border)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .scrollIndicators(.hidden)
                    .dismissKeyboardOnScroll()
                }
            }
            .background(Color.black)
            .navigationTitle("Tag a Court")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(NETRTheme.subtext)
                }
            }
        }
    }

    private func courtRow(_ court: FeedCourtSearchResult) -> some View {
        HStack(spacing: 12) {
            LucideIcon("map-pin", size: 16)
                .foregroundStyle(NETRTheme.neonGreen)
                .frame(width: 36, height: 36)
                .background(NETRTheme.neonGreen.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(court.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NETRTheme.text)
                    .lineLimit(1)
                if !court.locationLabel.isEmpty {
                    Text(court.locationLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.subtext)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func performSearch(query: String) {
        searchTask?.cancel()

        guard query.count >= 1 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            do {
                let fetched: [FeedCourtSearchResult] = try await client
                    .from("courts")
                    .select("id, name, neighborhood, city")
                    .or("name.ilike.%\(query)%,neighborhood.ilike.%\(query)%")
                    .limit(15)
                    .execute()
                    .value

                guard !Task.isCancelled else { return }
                results = fetched
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                isSearching = false
                print("[NETR] Court tag search error: \(error)")
            }
        }
    }
}
