import SwiftUI
import Supabase
import Auth
import PostgREST

struct VibeDecalView: View {
    let vibe: Double?
    var size: DecalSize = .medium

    enum DecalSize {
        case small
        case medium
        case large
    }

    private var tier: VibeTier {
        VibeTier.from(score: vibe) ?? .none
    }

    private var vibeColor: Color {
        Color(red: tier.color.red, green: tier.color.green, blue: tier.color.blue)
    }

    var body: some View {
        switch size {
        case .small:
            Circle()
                .fill(vibeColor)
                .frame(width: 10, height: 10)
                .shadow(color: vibeColor.opacity(0.8), radius: 4)

        case .medium:
            HStack(spacing: 6) {
                Circle()
                    .fill(vibeColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: vibeColor.opacity(0.8), radius: 4)
                Text(tier.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(vibeColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(vibeColor.opacity(0.12), in: .capsule)
            .overlay(Capsule().stroke(vibeColor.opacity(0.3), lineWidth: 1))

        case .large:
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(vibeColor)
                        .frame(width: 12, height: 12)
                        .shadow(color: vibeColor.opacity(0.9), radius: 6)
                    Text(tier.label.uppercased())
                        .font(.system(size: 11, weight: .black))
                        .tracking(1.2)
                        .foregroundStyle(vibeColor)
                }
                if let vibe {
                    Text(String(format: "%.1f VIBE", vibe))
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(vibeColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(vibeColor.opacity(0.10), in: .rect(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(vibeColor.opacity(0.25), lineWidth: 1)
            )
        }
    }
}

struct VibeDecalLockedView: View {
    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(NETRTheme.subtext)
                .frame(width: 8, height: 8)
            Text("VIBE PENDING")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(NETRTheme.subtext)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(NETRTheme.subtext.opacity(0.08), in: .capsule)
        .overlay(Capsule().stroke(NETRTheme.subtext.opacity(0.2), lineWidth: 1))
    }
}
