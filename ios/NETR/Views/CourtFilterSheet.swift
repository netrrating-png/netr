import SwiftUI
import Supabase
import Auth
import PostgREST

struct CourtFilterSheet: View {
    @Bindable var viewModel: CourtsViewModel
    @Binding var isPresented: Bool

    // Local draft state — only applied on "Show Courts"
    @State private var draftDistance: Double? = nil
    @State private var draftSurfaces: Set<SurfaceType> = []
    @State private var draftCourtType: Bool? = nil   // nil=any, true=full, false=half
    @State private var draftIndoor: Bool? = nil      // nil=any, true=indoor, false=outdoor
    @State private var showLocationAlert: Bool = false

    private let distanceOptions: [(label: String, value: Double?)] = [
        ("Any distance", nil),
        ("Within 1 mi", 1),
        ("Within 5 mi", 5),
        ("Within 10 mi", 10),
        ("Within 25 mi", 25)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // ── Handle ────────────────────────────────────────────────────
            Capsule()
                .fill(NETRTheme.border)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // ── Header ────────────────────────────────────────────────────
            HStack {
                Text("FILTER COURTS")
                    .font(NETRTheme.headingFont(size: .headline))
                    .foregroundStyle(NETRTheme.text)
                Spacer()
                if hasChanges {
                    Button("Reset") {
                        draftDistance = nil
                        draftSurfaces = []
                        draftCourtType = nil
                        draftIndoor = nil
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NETRTheme.neonGreen)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            ScrollView {
                VStack(spacing: 28) {

                    // ── Distance ─────────────────────────────────────────
                    filterSection(title: "DISTANCE", icon: "map-pin") {
                        VStack(spacing: 8) {
                            if viewModel.userLocation == nil {
                                HStack(spacing: 6) {
                                    LucideIcon("map-pin-off", size: 12)
                                    Text("Enable location to filter by distance")
                                        .font(.caption)
                                }
                                .foregroundStyle(NETRTheme.subtext)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                                .padding(.bottom, 2)
                            }
                            ForEach(distanceOptions, id: \.label) { option in
                                let selected = draftDistance == option.value
                                Button {
                                    withAnimation(.snappy) { draftDistance = option.value }
                                } label: {
                                    HStack {
                                        Text(option.label)
                                            .font(.subheadline.weight(selected ? .semibold : .regular))
                                            .foregroundStyle(selected ? NETRTheme.text : NETRTheme.subtext)
                                        Spacer()
                                        if selected {
                                            LucideIcon("check", size: 14)
                                                .foregroundStyle(NETRTheme.neonGreen)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 11)
                                    .background(
                                        selected ? NETRTheme.neonGreen.opacity(0.08) : NETRTheme.card,
                                        in: .rect(cornerRadius: 10)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selected ? NETRTheme.neonGreen.opacity(0.35) : NETRTheme.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PressButtonStyle())
                            }
                        }
                    }

                    // ── Surface type ─────────────────────────────────────
                    filterSection(title: "SURFACE", icon: "layers") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(SurfaceType.allCases, id: \.self) { surface in
                                let selected = draftSurfaces.contains(surface)
                                Button {
                                    withAnimation(.snappy) {
                                        if selected { draftSurfaces.remove(surface) }
                                        else { draftSurfaces.insert(surface) }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        LucideIcon(surfaceIcon(surface), size: 12)
                                        Text(surface.rawValue)
                                            .font(.system(size: 13, weight: selected ? .semibold : .regular))
                                    }
                                    .foregroundStyle(selected ? NETRTheme.background : NETRTheme.subtext)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selected ? NETRTheme.neonGreen : NETRTheme.card, in: .rect(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selected ? Color.clear : NETRTheme.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PressButtonStyle())
                            }
                        }
                    }

                    // ── Court type ───────────────────────────────────────
                    filterSection(title: "COURT TYPE", icon: "layout-grid") {
                        HStack(spacing: 8) {
                            courtTypeButton(label: "Any", icon: "circle-dashed", value: nil)
                            courtTypeButton(label: "Full Court", icon: "layout-grid", value: true)
                            courtTypeButton(label: "Half Court", icon: "grid-2x2", value: false)
                        }
                    }

                    // ── Indoor / Outdoor ──────────────────────────────────
                    filterSection(title: "SETTING", icon: "home") {
                        HStack(spacing: 8) {
                            indoorButton(label: "Any", icon: "circle-dashed", value: nil)
                            indoorButton(label: "Indoor", icon: "home", value: true)
                            indoorButton(label: "Outdoor", icon: "sun", value: false)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)

            // ── Apply button ──────────────────────────────────────────────
            VStack(spacing: 0) {
                Divider().overlay(NETRTheme.border)
                Button {
                    applyFilters()
                } label: {
                    HStack(spacing: 8) {
                        LucideIcon("sliders-horizontal", size: 15)
                        Text(applyCTA)
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(NETRTheme.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(NETRTheme.neonGreen, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(PressButtonStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(NETRTheme.surface)
        }
        .background(NETRTheme.surface)
        .onAppear {
            draftDistance = viewModel.filterMaxDistance
            draftSurfaces = viewModel.filterSurfaces
            draftCourtType = viewModel.filterCourtType
            draftIndoor = viewModel.filterIndoor
        }
        .alert("Location Required", isPresented: $showLocationAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Distance filtering requires your location. Enable it in Settings → NETR → Location → While Using the App.")
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────

    @ViewBuilder
    private func filterSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                LucideIcon(icon, size: 12)
                    .foregroundStyle(NETRTheme.neonGreen)
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NETRTheme.subtext)
                    .kerning(0.8)
            }
            content()
        }
    }

    @ViewBuilder
    private func courtTypeButton(label: String, icon: String, value: Bool?) -> some View {
        let selected = draftCourtType == value
        Button {
            withAnimation(.snappy) { draftCourtType = value }
        } label: {
            VStack(spacing: 5) {
                LucideIcon(icon, size: 14)
                Text(label)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
            }
            .foregroundStyle(selected ? NETRTheme.background : NETRTheme.subtext)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? NETRTheme.neonGreen : NETRTheme.card, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.clear : NETRTheme.border, lineWidth: 1))
        }
        .buttonStyle(PressButtonStyle())
    }

    @ViewBuilder
    private func indoorButton(label: String, icon: String, value: Bool?) -> some View {
        let selected = draftIndoor == value
        Button {
            withAnimation(.snappy) { draftIndoor = value }
        } label: {
            VStack(spacing: 5) {
                LucideIcon(icon, size: 14)
                Text(label)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
            }
            .foregroundStyle(selected ? NETRTheme.background : NETRTheme.subtext)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(selected ? NETRTheme.neonGreen : NETRTheme.card, in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? Color.clear : NETRTheme.border, lineWidth: 1))
        }
        .buttonStyle(PressButtonStyle())
    }

    private func surfaceIcon(_ surface: SurfaceType) -> String {
        switch surface {
        case .asphalt: return "road"
        case .concrete: return "square"
        case .rubber: return "circle"
        case .hardwood: return "panels-top-left"
        }
    }

    private var hasChanges: Bool {
        draftDistance != nil || !draftSurfaces.isEmpty || draftCourtType != nil || draftIndoor != nil
    }

    private var applyCTA: String {
        if !hasChanges { return "Show All Courts" }
        var parts: [String] = []
        if let d = draftDistance { parts.append("≤\(Int(d))mi") }
        if !draftSurfaces.isEmpty { parts.append(draftSurfaces.map { $0.rawValue }.sorted().joined(separator: "/")) }
        if let ct = draftCourtType { parts.append(ct ? "Full" : "Half") }
        if let indoor = draftIndoor { parts.append(indoor ? "Indoor" : "Outdoor") }
        return "Show Courts — \(parts.joined(separator: " · "))"
    }

    private func applyFilters() {
        if draftDistance != nil && viewModel.userLocation == nil {
            showLocationAlert = true
            return
        }
        viewModel.filterMaxDistance = draftDistance
        viewModel.filterSurfaces = draftSurfaces
        viewModel.filterCourtType = draftCourtType
        viewModel.filterIndoor = draftIndoor
        viewModel.isExploring = true
        isPresented = false
    }
}
