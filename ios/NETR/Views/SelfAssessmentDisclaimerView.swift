import SwiftUI

struct SelfAssessmentDisclaimerView: View {
    var onContinue: () -> Void
    var onBack: () -> Void

    @State private var appeared = false

    private let points: [(icon: String, text: String)] = [
        ("hand.raised.fill", "Be honest — not humble, not hype. Rate yourself like a coach watching from the sideline would."),
        ("arrow.up.right.circle.fill", "This is your starting point. As you play and get peer ratings, your score will update automatically."),
        ("lock.fill", "Your self-assessment stays locked until you collect 5 peer reviews. That's when it becomes your real NETR score."),
        ("person.2.fill", "Players who rate themselves accurately tend to get more accurate peer ratings back. The court always sorts it out."),
    ]

    var body: some View {
        ZStack {
            NETRTheme.background.ignoresSafeArea()

            Circle()
                .fill(NETRTheme.neonGreen.opacity(0.05))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(y: -100)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 14))
                        }
                        .foregroundStyle(NETRTheme.subtext)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 32)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(NETRTheme.neonGreen.opacity(0.1))
                                    .frame(width: 64, height: 64)
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(NETRTheme.neonGreen.opacity(0.3), lineWidth: 1)
                                    .frame(width: 64, height: 64)
                                Text("🏀")
                                    .font(.system(size: 30))
                            }
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 12)
                            .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.05), value: appeared)

                            Text("BEFORE YOU START")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(NETRTheme.neonGreen)
                                .tracking(2.0)
                                .opacity(appeared ? 1 : 0)
                                .animation(.easeOut(duration: 0.4).delay(0.1), value: appeared)

                            Text("Be real\nwith yourself.")
                                .font(.system(.largeTitle, design: .default, weight: .black).width(.compressed))
                                .foregroundStyle(NETRTheme.text)
                                .lineSpacing(2)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 10)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15), value: appeared)

                            Text("This self-assessment is the foundation of your NETR rating. The more honest you are, the more accurate your starting score — and the faster it reflects who you actually are on the court.")
                                .font(.system(size: 15))
                                .foregroundStyle(NETRTheme.subtext)
                                .lineSpacing(5)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 8)
                                .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 36)

                        VStack(spacing: 0) {
                            ForEach(Array(points.enumerated()), id: \.offset) { i, point in
                                HStack(alignment: .top, spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(NETRTheme.neonGreen.opacity(0.1))
                                            .frame(width: 36, height: 36)
                                        Image(systemName: point.icon)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(NETRTheme.neonGreen)
                                    }
                                    .padding(.top, 1)

                                    Text(point.text)
                                        .font(.system(size: 14))
                                        .foregroundStyle(NETRTheme.subtext)
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 18)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 10)
                                .animation(.easeOut(duration: 0.45).delay(0.25 + Double(i) * 0.08), value: appeared)

                                if i < points.count - 1 {
                                    Divider()
                                        .background(NETRTheme.border)
                                        .padding(.leading, 72)
                                }
                            }
                        }
                        .background(NETRTheme.card)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(NETRTheme.border, lineWidth: 1))
                        .clipShape(.rect(cornerRadius: 20))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.22), value: appeared)

                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(NETRTheme.neonGreen)
                                .frame(width: 3)
                                .clipShape(.rect(cornerRadius: 99))
                            Text("The court doesn't lie — and neither should you.")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(NETRTheme.subtext)
                                .italic()
                                .lineSpacing(3)
                        }
                        .frame(height: 40)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.4).delay(0.55), value: appeared)

                        Spacer(minLength: 120)
                    }
                }

                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        HStack(spacing: 10) {
                            Text("I'm Ready — Let's Go")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [NETRTheme.neonGreen, NETRTheme.darkGreen],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            in: .rect(cornerRadius: 16)
                        )
                        .shadow(color: NETRTheme.neonGreen.opacity(0.35), radius: 16, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)

                    Text("Takes about 2 minutes")
                        .font(.system(size: 12))
                        .foregroundStyle(NETRTheme.muted)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.6), value: appeared)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
        }
    }
}
