import ConfettiKit
import SwiftUI

/// A "course complete" screen: confetti bursts from behind the card and two cannons fire
/// from the bottom corners.
struct CelebrateView: View {
    /// Draws the confetti frozen mid-flight (screenshot scenes).
    var isFrozen = false

    @State private var celebrations = 0

    /// The central burst, from just above the middle of the screen.
    private static let burst: ConfettiConfiguration = {
        var configuration = ConfettiConfiguration.confetti
        configuration.emitter = .point(UnitPoint(x: 0.5, y: 0.42))
        return configuration
    }()

    private static let leftCannon = ConfettiConfiguration.cannon(from: UnitPoint(x: 0, y: 1), angle: 32)
    private static let rightCannon = ConfettiConfiguration.cannon(from: UnitPoint(x: 1, y: 1), angle: -32)

    /// Where the frozen screenshot stops the clock: particles are spread across the screen,
    /// still rising in the middle and already fluttering at the edges.
    private static let frozenTime = 0.9

    var body: some View {
        ZStack {
            confettiLayer
                .ignoresSafeArea()

            SuccessCard {
                celebrations += 1
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 460)
        }
        .task {
            // Celebrate once when the screen opens.
            guard !isFrozen else { return }
            try? await Task.sleep(for: .milliseconds(450))
            celebrations += 1
        }
    }

    /// The background, with the confetti drawn on it: behind the card, so the text stays
    /// readable and the glass card blurs the particles passing underneath.
    @ViewBuilder
    private var confettiLayer: some View {
        if isFrozen {
            CelebrationBackground()
                .overlay {
                    ZStack {
                        ConfettiView(Self.burst.frozen(at: Self.frozenTime), seed: 7)
                        ConfettiView(Self.leftCannon.frozen(at: Self.frozenTime), seed: 11)
                        ConfettiView(Self.rightCannon.frozen(at: Self.frozenTime), seed: 12)
                    }
                }
        } else {
            CelebrationBackground()
                .confetti(Self.burst, trigger: celebrations)
                .confetti(Self.leftCannon, trigger: celebrations, haptic: nil)
                .confetti(Self.rightCannon, trigger: celebrations, haptic: nil)
        }
    }
}

/// A soft gradient that suits both appearances.
private struct CelebrationBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors: [Color] = colorScheme == .dark
            ? [Color(red: 0.07, green: 0.06, blue: 0.16), Color(red: 0.16, green: 0.08, blue: 0.24)]
            : [Color(red: 0.96, green: 0.95, blue: 1.00), Color(red: 1.00, green: 0.93, blue: 0.90)]
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }
}

private struct SuccessCard: View {
    let onCelebrate: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.78, blue: 0.2), Color(red: 1.0, green: 0.5, blue: 0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                    .shadow(color: .orange.opacity(0.35), radius: 12, y: 6)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("You did it!")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("All 30 lessons of Swift Basics are complete.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 0) {
                Stat(value: "30", label: "Lessons")
                Stat(value: "12", label: "Day streak")
                Stat(value: "2,480", label: "XP")
            }
            .padding(.vertical, 4)

            Button(action: onCelebrate) {
                Label("Celebrate again", systemImage: "party.popper.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(Color(red: 0.45, green: 0.3, blue: 0.95))
        }
        .padding(24)
        .cardBackground(cornerRadius: 32)
    }
}

private struct Stat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

extension View {
    /// Liquid Glass on iOS 26, a regular material before.
    @ViewBuilder
    func cardBackground(cornerRadius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.25), lineWidth: 1))
        }
    }
}

#Preview {
    CelebrateView()
}

#Preview("Frozen") {
    CelebrateView(isFrozen: true)
}
