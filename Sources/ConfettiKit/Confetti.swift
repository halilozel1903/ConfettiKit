import SwiftUI

/// Fires a celebration effect over the content every time `trigger` changes.
@MainActor
struct ConfettiModifier<Trigger: Equatable>: ViewModifier {
    let trigger: Trigger
    let configuration: ConfettiConfiguration
    let haptic: SensoryFeedback?
    let seed: UInt64?

    @State private var bursts: [ConfettiBurst] = []
    @State private var fireCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let feedback = haptic
        return content
            .overlay {
                if !bursts.isEmpty {
                    ConfettiCanvas(bursts: bursts, configuration: configuration)
                }
            }
            .onChange(of: trigger) {
                fire()
            }
            .sensoryFeedback(trigger: fireCount) { _, _ in
                feedback
            }
    }

    private func fire() {
        fireCount += 1
        let id = fireCount
        let burstSeed = seed.map { $0 &+ UInt64(id) } ?? UInt64.random(in: UInt64.min...UInt64.max)
        let burst = ConfettiBurst(
            id: id,
            configuration: configuration,
            seed: burstSeed,
            start: Date().timeIntervalSinceReferenceDate,
            isGentle: reduceMotion && configuration.respectsReduceMotion
        )
        bursts.append(burst)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(burst.duration + 0.1))
            bursts.removeAll { $0.id == id }
        }
    }
}

extension View {
    /// Fires a celebration effect over this view every time `trigger` changes.
    ///
    /// ```swift
    /// Button("Complete") { completed += 1 }
    ///     .confetti(trigger: completed)
    ///
    /// ContentView()
    ///     .confetti(.fireworks, trigger: level, haptic: .impact(weight: .heavy))
    /// ```
    ///
    /// The effect is drawn in an overlay the size of this view that ignores touches and is
    /// hidden from VoiceOver, so apply it to a view that covers the area you want (often the
    /// screen's root view, with `.ignoresSafeArea()` on the content if needed). Firing again
    /// before a burst ends adds a new burst on top. Nothing is drawn, and no timeline runs,
    /// between bursts. With Reduce Motion on, a soft glow fades in and out instead (see
    /// ``ConfettiConfiguration/respectsReduceMotion``).
    ///
    /// - Parameters:
    ///   - configuration: The effect: a preset such as `.confetti`, `.emoji`, `.fireworks`,
    ///     `.snow` or `.hearts`, or your own.
    ///   - trigger: Any equatable value. The effect fires when it changes, not on appear.
    ///   - haptic: Sensory feedback played on each firing (a haptic on iPhone), or `nil`.
    ///   - seed: Makes every firing reproducible; `nil` picks a new random layout each time.
    public func confetti<Trigger: Equatable>(
        _ configuration: ConfettiConfiguration = .confetti,
        trigger: Trigger,
        haptic: SensoryFeedback? = .success,
        seed: UInt64? = nil
    ) -> some View {
        modifier(ConfettiModifier(trigger: trigger, configuration: configuration, haptic: haptic, seed: seed))
    }
}

/// A view that plays an effect once when it appears.
///
/// Use it for a celebration screen, or with a frozen configuration for previews, snapshot
/// tests and screenshots:
///
/// ```swift
/// ZStack {
///     SuccessCard()
///     ConfettiView(.confetti)                         // plays once on appear
/// }
///
/// ConfettiView(.fireworks.frozen(at: 1.2), seed: 7)   // a still frame, identical every time
/// ```
///
/// To play it again, give it a new identity with `.id(_:)`. The view fills the space it is
/// offered and ignores touches.
public struct ConfettiView: View {
    private let configuration: ConfettiConfiguration
    private let seed: UInt64?

    @State private var burst: ConfettiBurst?
    @State private var isFinished = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates the view.
    ///
    /// - Parameters:
    ///   - configuration: The effect to play.
    ///   - seed: Makes the particle layout reproducible; `nil` picks a random one (or `0` for a
    ///     frozen configuration).
    public init(_ configuration: ConfettiConfiguration = .confetti, seed: UInt64? = nil) {
        self.configuration = configuration
        self.seed = seed
    }

    private var activeBursts: [ConfettiBurst] {
        guard !isFinished, let burst else { return [] }
        return [burst]
    }

    private var isGentle: Bool {
        reduceMotion && configuration.respectsReduceMotion
    }

    public var body: some View {
        if configuration.frozenTime != nil {
            // A still frame needs no state: build it right away, so the very first render
            // (a preview or a snapshot) already shows the particles.
            ConfettiCanvas(bursts: [makeBurst(start: 0)], configuration: configuration)
        } else {
            ConfettiCanvas(bursts: activeBursts, configuration: configuration)
                .task {
                    guard burst == nil else { return }
                    let newBurst = makeBurst(start: Date().timeIntervalSinceReferenceDate)
                    burst = newBurst
                    try? await Task.sleep(for: .seconds(newBurst.duration + 0.1))
                    isFinished = true
                }
        }
    }

    private func makeBurst(start: TimeInterval) -> ConfettiBurst {
        ConfettiBurst(
            id: 0,
            configuration: configuration,
            // A frozen frame without a seed still has to look the same on every render.
            seed: seed ?? (configuration.frozenTime == nil ? UInt64.random(in: UInt64.min...UInt64.max) : 0),
            start: start,
            isGentle: isGentle
        )
    }
}
