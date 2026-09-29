import ConfettiKit
import SwiftUI
import UIKit

/// Every preset in its own tile. Tap a tile to play it again.
struct PresetsView: View {
    /// Freezes every tile mid-animation (screenshot scenes).
    var isFrozen = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 18) {
                    ForEach(PresetDemo.all) { demo in
                        PresetTile(demo: demo, isFrozen: isFrozen)
                    }
                }
                .padding(16)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Presets")
        }
    }
}

/// A preset, shrunk to fit a tile, and the moment its screenshot is frozen at.
struct PresetDemo: Identifiable {
    let id: String
    let code: String
    let configuration: ConfettiConfiguration
    let frozenTime: Double
    let seed: UInt64
    /// Draws the tile on a night sky, for effects that glow.
    var isNight = false

    static let all: [PresetDemo] = [
        PresetDemo(
            id: "Confetti",
            code: ".confetti",
            configuration: {
                var configuration = ConfettiConfiguration.confetti.miniature(scale: 0.35, countFactor: 0.7)
                configuration.emitter = .point(UnitPoint(x: 0.5, y: 0.6))
                return configuration
            }(),
            frozenTime: 0.9,
            seed: 3
        ),
        PresetDemo(
            id: "Emoji",
            code: ".emoji",
            configuration: {
                var configuration = ConfettiConfiguration.emoji.miniature(scale: 0.35, countFactor: 0.5)
                configuration.emitter = .point(UnitPoint(x: 0.5, y: 0.6))
                return configuration
            }(),
            frozenTime: 0.75,
            seed: 3
        ),
        PresetDemo(
            id: "Fireworks",
            code: ".fireworks",
            configuration: ConfettiConfiguration.fireworks.miniature(scale: 0.3, sizeFactor: 0.9, countFactor: 0.7),
            frozenTime: 1.2,
            seed: 3,
            isNight: true
        ),
        PresetDemo(
            id: "Snow",
            code: ".snow",
            configuration: ConfettiConfiguration.snow.miniature(scale: 0.8, sizeFactor: 0.8, countFactor: 0.7),
            frozenTime: 5,
            seed: 3,
            isNight: true
        ),
        PresetDemo(
            id: "Hearts",
            code: ".hearts",
            configuration: ConfettiConfiguration.hearts.miniature(scale: 0.35, sizeFactor: 0.7, countFactor: 0.8),
            frozenTime: 1.8,
            seed: 3
        ),
        PresetDemo(
            id: "Custom",
            code: "stars + symbols",
            configuration: ConfettiConfiguration(
                count: 46,
                shapes: [.star, .star, .symbol("sparkle"), .custom(.ring)],
                colors: [
                    Color(red: 1.0, green: 0.78, blue: 0.1),
                    Color(red: 1.0, green: 0.55, blue: 0.1),
                    Color(red: 0.6, green: 0.35, blue: 1.0),
                ],
                size: 7...14,
                emitter: .point(UnitPoint(x: 0.5, y: 0.42)),
                spread: 360,
                speed: 90...220,
                gravity: 150,
                drag: 1.4,
                flip: 1,
                lifetime: 3
            ),
            frozenTime: 0.8,
            seed: 5
        ),
    ]
}

extension ConfettiCustomShape {
    /// A thin ring, drawn from a closure.
    static let ring = ConfettiCustomShape(id: "ring") { rect in
        Path(ellipseIn: rect).strokedPath(StrokeStyle(lineWidth: rect.width * 0.22))
    }
}

private struct PresetTile: View {
    let demo: PresetDemo
    let isFrozen: Bool

    @State private var replays = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                background
                ConfettiView(demo.configuration.frozen(at: demo.frozenTime, if: isFrozen), seed: demo.seed)
                    .id(replays)
            }
            .frame(height: 168)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .onTapGesture { replays += 1 }
            .accessibilityElement()
            .accessibilityLabel("\(demo.id) preset")
            .accessibilityHint("Plays the effect again")
            .accessibilityAddTraits(.isButton)

            VStack(alignment: .leading, spacing: 2) {
                Text(demo.id)
                    .font(.headline)
                Text(demo.code)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var background: some View {
        if demo.isNight {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.07, blue: 0.2), Color(red: 0.16, green: 0.1, blue: 0.32)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            Color(uiColor: .secondarySystemGroupedBackground)
        }
    }
}

#Preview {
    PresetsView()
}

#Preview("Frozen") {
    PresetsView(isFrozen: true)
}
