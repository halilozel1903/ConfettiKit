import SwiftUI

/// Where particles are emitted: a point, or a rectangle when `width` or `height` is not zero.
///
/// All values are fractions of the drawing area, so the same emitter works on every screen.
public struct ConfettiEmitter: Sendable, Hashable {
    /// The allowed width and height, as fractions of the drawing area.
    public static let extentRange: ClosedRange<Double> = 0...2

    /// The emitter's center. `(0.5, 0.5)` is the middle; values outside `0...1` are allowed.
    public var position: UnitPoint {
        didSet { position = Self.sanitized(position) }
    }

    /// The emitter's width as a fraction of the drawing area's width, `0...2`.
    public var width: Double {
        didSet { width = ConfettiConfiguration.clamp(width, to: Self.extentRange, fallback: 0) }
    }

    /// The emitter's height as a fraction of the drawing area's height, `0...2`.
    public var height: Double {
        didSet { height = ConfettiConfiguration.clamp(height, to: Self.extentRange, fallback: 0) }
    }

    /// Creates an emitter. Non-finite positions fall back to the center.
    public init(position: UnitPoint = .center, width: Double = 0, height: Double = 0) {
        self.position = Self.sanitized(position)
        self.width = ConfettiConfiguration.clamp(width, to: Self.extentRange, fallback: 0)
        self.height = ConfettiConfiguration.clamp(height, to: Self.extentRange, fallback: 0)
    }

    /// A single point.
    public static func point(_ position: UnitPoint) -> ConfettiEmitter {
        ConfettiEmitter(position: position)
    }

    /// The middle of the drawing area.
    public static let center = ConfettiEmitter(position: .center)

    /// A line just above the top edge, for effects that fall into view.
    public static let top = ConfettiEmitter(position: UnitPoint(x: 0.5, y: -0.02), width: 1.1)

    /// A line just below the bottom edge, for effects that rise into view.
    public static let bottom = ConfettiEmitter(position: UnitPoint(x: 0.5, y: 1.02), width: 0.9)

    static func sanitized(_ point: UnitPoint) -> UnitPoint {
        UnitPoint(
            x: point.x.isFinite ? point.x : 0.5,
            y: point.y.isFinite ? point.y : 0.5
        )
    }
}

/// Everything about a celebration effect: how many particles, what they look like, where they
/// come from and how they move.
///
/// Every value is clamped to a sensible range, so no configuration can break the effect.
/// Non-finite values (`.nan`, `.infinity`) fall back to the defaults, and empty `colors` or
/// `shapes` fall back to the default palette and paper shapes.
///
/// Start from a preset and change what you need:
///
/// ```swift
/// var party = ConfettiConfiguration.confetti
/// party.count = 200
/// party.colors = [.indigo, .mint, .yellow]
/// party.emitter = .point(UnitPoint(x: 0.5, y: 1))   // shoot up from the bottom
/// ```
public struct ConfettiConfiguration: Sendable, Hashable {
    // MARK: Ranges

    /// The allowed number of particles per burst.
    public static let countRange: ClosedRange<Int> = 1...400
    /// The allowed number of bursts per firing.
    public static let burstsRange: ClosedRange<Int> = 1...8
    /// The allowed launch speed, in points per second.
    public static let speedRange: ClosedRange<Double> = 0...5000
    /// The allowed gravity, in points per second squared. Negative values make particles rise.
    public static let gravityRange: ClosedRange<Double> = -5000...5000
    /// The allowed drag, per second.
    public static let dragRange: ClosedRange<Double> = 0...20
    /// The allowed particle size, in points.
    public static let sizeRange: ClosedRange<Double> = 1...200
    /// The allowed spin and tumble, in turns per second.
    public static let turnsRange: ClosedRange<Double> = 0...10
    /// The allowed sideways sway, in points.
    public static let wobbleRange: ClosedRange<Double> = 0...200
    /// The allowed particle lifetime, in seconds.
    public static let lifetimeRange: ClosedRange<Double> = 0.2...30
    /// The allowed emission duration and pause between bursts, in seconds.
    public static let timingRange: ClosedRange<Double> = 0...10

    /// A bright, balanced palette that reads well on light and dark backgrounds.
    public static let defaultColors: [Color] = [
        Color(red: 1.00, green: 0.23, blue: 0.37),   // raspberry
        Color(red: 1.00, green: 0.62, blue: 0.04),   // tangerine
        Color(red: 1.00, green: 0.84, blue: 0.04),   // lemon
        Color(red: 0.19, green: 0.82, blue: 0.35),   // green
        Color(red: 0.04, green: 0.52, blue: 1.00),   // blue
        Color(red: 0.69, green: 0.32, blue: 0.87),   // purple
        Color(red: 0.39, green: 0.82, blue: 1.00),   // sky
    ]

    // MARK: Look

    /// Particles per burst, `1...400`.
    public var count: Int {
        didSet { count = Self.clamp(count, to: Self.countRange) }
    }

    /// The shapes to pick from, at random. Repeat a shape to make it more common.
    public var shapes: [ConfettiShape] {
        didSet { if shapes.isEmpty { shapes = ConfettiShape.paper } }
    }

    /// The colors to pick from, at random. Emoji ignore them.
    public var colors: [Color] {
        didSet { if colors.isEmpty { colors = Self.defaultColors } }
    }

    /// Particle size in points, picked at random from this range, within `1...200`.
    public var size: ClosedRange<Double> {
        didSet { size = Self.clamp(size, to: Self.sizeRange, fallback: 8...14) }
    }

    // MARK: Emission

    /// Where particles come from.
    public var emitter: ConfettiEmitter

    /// The launch direction in degrees, normalized to `0..<360`: `0` is up, `90` right,
    /// `180` down and `270` left.
    public var angle: Double {
        didSet { angle = Self.normalizedAngle(angle) }
    }

    /// How far launch directions fan out around ``angle``, in degrees, `0...360`.
    public var spread: Double {
        didSet { spread = Self.clamp(spread, to: 0...360, fallback: 120) }
    }

    /// Launch speed in points per second, picked at random from this range, within `0...5000`.
    public var speed: ClosedRange<Double> {
        didSet { speed = Self.clamp(speed, to: Self.speedRange, fallback: 400...1100) }
    }

    /// Seconds over which a burst's particles are released, `0...10`. `0` releases all at once.
    public var emissionDuration: Double {
        didSet { emissionDuration = Self.clamp(emissionDuration, to: Self.timingRange, fallback: 0) }
    }

    /// Bursts per firing, `1...8`. With more than one, each burst starts at a random point of
    /// the ``emitter`` and uses a single color, like a firework shell.
    public var bursts: Int {
        didSet { bursts = Self.clamp(bursts, to: Self.burstsRange) }
    }

    /// Seconds between two bursts, `0...10`.
    public var burstInterval: Double {
        didSet { burstInterval = Self.clamp(burstInterval, to: Self.timingRange, fallback: 0.3) }
    }

    // MARK: Motion

    /// Downward acceleration in points per second squared, `-5000...5000`.
    /// Negative values make particles float up.
    public var gravity: Double {
        didSet { gravity = Self.clamp(gravity, to: Self.gravityRange, fallback: 750) }
    }

    /// Air resistance per second, `0...20`. Higher values slow particles sooner and make them
    /// flutter down at a lower terminal speed (`gravity / drag`).
    public var drag: Double {
        didSet { drag = Self.clamp(drag, to: Self.dragRange, fallback: 1.1) }
    }

    /// The fastest spin in turns per second, `0...10`. Each particle spins at a random speed
    /// and direction up to this.
    public var spin: Double {
        didSet { spin = Self.clamp(spin, to: Self.turnsRange, fallback: 1.5) }
    }

    /// How far particles may be tilted when they appear, in degrees either way, `0...180`.
    /// `180` allows any angle; small values keep hearts and emoji upright.
    public var tilt: Double {
        didSet { tilt = Self.clamp(tilt, to: 0...180, fallback: 180) }
    }

    /// The fastest 3D tumble in turns per second, `0...10`. `0` keeps particles flat, which
    /// suits emoji and symbols.
    public var flip: Double {
        didSet { flip = Self.clamp(flip, to: Self.turnsRange, fallback: 2.5) }
    }

    /// The largest sideways sway in points, `0...200`.
    public var wobble: Double {
        didSet { wobble = Self.clamp(wobble, to: Self.wobbleRange, fallback: 6) }
    }

    // MARK: Timing

    /// The longest a particle lives, in seconds, `0.2...30`. Each lives 80–100 % of this.
    public var lifetime: Double {
        didSet { lifetime = Self.clamp(lifetime, to: Self.lifetimeRange, fallback: 3.5) }
    }

    /// The last fraction of each particle's life during which it fades out, `0...1`.
    public var fadeOut: Double {
        didSet { fadeOut = Self.clamp(fadeOut, to: 0...1, fallback: 0.3) }
    }

    // MARK: Behavior

    /// When `true` (the default) and Reduce Motion is on, a gentle glow fades in and out in
    /// place of moving particles.
    public var respectsReduceMotion: Bool

    /// Draws the effect at this many seconds after firing, without animating. For previews,
    /// snapshot tests and screenshots; `nil` animates normally. Never negative.
    public var frozenTime: Double? {
        didSet { frozenTime = Self.clampedTime(frozenTime) }
    }

    /// Creates a configuration. Every value is clamped; see the properties for the ranges.
    public init(
        count: Int = 160,
        shapes: [ConfettiShape] = ConfettiShape.paper,
        colors: [Color] = ConfettiConfiguration.defaultColors,
        size: ClosedRange<Double> = 8...14,
        emitter: ConfettiEmitter = .center,
        angle: Double = 0,
        spread: Double = 120,
        speed: ClosedRange<Double> = 400...1100,
        emissionDuration: Double = 0,
        bursts: Int = 1,
        burstInterval: Double = 0.3,
        gravity: Double = 750,
        drag: Double = 1.1,
        spin: Double = 1.5,
        tilt: Double = 180,
        flip: Double = 2.5,
        wobble: Double = 6,
        lifetime: Double = 3.5,
        fadeOut: Double = 0.3,
        respectsReduceMotion: Bool = true,
        frozenTime: Double? = nil
    ) {
        self.count = Self.clamp(count, to: Self.countRange)
        self.shapes = shapes.isEmpty ? ConfettiShape.paper : shapes
        self.colors = colors.isEmpty ? Self.defaultColors : colors
        self.size = Self.clamp(size, to: Self.sizeRange, fallback: 8...14)
        self.emitter = emitter
        self.angle = Self.normalizedAngle(angle)
        self.spread = Self.clamp(spread, to: 0...360, fallback: 120)
        self.speed = Self.clamp(speed, to: Self.speedRange, fallback: 400...1100)
        self.emissionDuration = Self.clamp(emissionDuration, to: Self.timingRange, fallback: 0)
        self.bursts = Self.clamp(bursts, to: Self.burstsRange)
        self.burstInterval = Self.clamp(burstInterval, to: Self.timingRange, fallback: 0.3)
        self.gravity = Self.clamp(gravity, to: Self.gravityRange, fallback: 750)
        self.drag = Self.clamp(drag, to: Self.dragRange, fallback: 1.1)
        self.spin = Self.clamp(spin, to: Self.turnsRange, fallback: 1.5)
        self.tilt = Self.clamp(tilt, to: 0...180, fallback: 180)
        self.flip = Self.clamp(flip, to: Self.turnsRange, fallback: 2.5)
        self.wobble = Self.clamp(wobble, to: Self.wobbleRange, fallback: 6)
        self.lifetime = Self.clamp(lifetime, to: Self.lifetimeRange, fallback: 3.5)
        self.fadeOut = Self.clamp(fadeOut, to: 0...1, fallback: 0.3)
        self.respectsReduceMotion = respectsReduceMotion
        self.frozenTime = Self.clampedTime(frozenTime)
    }

    // MARK: Derived values

    /// Gravity, drag and fade, as used by ``ConfettiSimulation``.
    public var physics: ConfettiPhysics {
        ConfettiPhysics(gravity: gravity, drag: drag, fadeOut: fadeOut)
    }

    /// The same effect, drawn at `seconds` after firing and not animated.
    ///
    /// ```swift
    /// ConfettiView(.fireworks.frozen(at: 1.2), seed: 7)   // identical on every render
    /// ```
    public func frozen(at seconds: Double) -> ConfettiConfiguration {
        var copy = self
        copy.frozenTime = seconds
        return copy
    }

    /// The same effect with every distance (speed, gravity and sway) multiplied by `factor`,
    /// so it fits a smaller or larger area. Particle sizes are unchanged.
    /// A factor that is not positive and finite returns the configuration unchanged.
    ///
    /// ```swift
    /// ConfettiView(.confetti.scaled(by: 0.4))   // for a 200-point card
    /// ```
    public func scaled(by factor: Double) -> ConfettiConfiguration {
        guard factor.isFinite, factor > 0 else { return self }
        var copy = self
        copy.speed = (speed.lowerBound * factor)...(speed.upperBound * factor)
        copy.gravity = gravity * factor
        copy.wobble = wobble * factor
        return copy
    }

    // MARK: Clamping

    static func clamp(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    static func clamp(
        _ value: ClosedRange<Double>,
        to range: ClosedRange<Double>,
        fallback: ClosedRange<Double>
    ) -> ClosedRange<Double> {
        guard value.lowerBound.isFinite, value.upperBound.isFinite else { return fallback }
        let lower = clamp(value.lowerBound, to: range, fallback: fallback.lowerBound)
        let upper = clamp(value.upperBound, to: range, fallback: fallback.upperBound)
        return min(lower, upper)...max(lower, upper)
    }

    static func normalizedAngle(_ degrees: Double) -> Double {
        guard degrees.isFinite else { return 0 }
        var angle = degrees.truncatingRemainder(dividingBy: 360)
        if angle < 0 { angle += 360 }
        if angle >= 360 { angle = 0 }
        return angle == 0 ? 0 : angle   // folds -0.0 into 0
    }

    static func clampedTime(_ time: Double?) -> Double? {
        guard let time, !time.isNaN else { return nil }
        return min(max(time, 0), 3600)
    }
}

// MARK: - Presets

extension ConfettiConfiguration {
    /// Paper confetti bursting up from the middle, then fluttering down.
    public static let confetti = ConfettiConfiguration()

    /// A confetti cannon: a narrow, fast jet from `position` in the direction `angle`
    /// (degrees, `0` is up, `90` right).
    ///
    /// ```swift
    /// ZStack {
    ///     ConfettiView(.cannon(from: .bottomLeading, angle: 30))
    ///     ConfettiView(.cannon(from: .bottomTrailing, angle: -30))
    /// }
    /// ```
    public static func cannon(from position: UnitPoint, angle: Double) -> ConfettiConfiguration {
        ConfettiConfiguration(
            count: 80,
            emitter: .point(position),
            angle: angle,
            spread: 28,
            speed: 700...1300
        )
    }

    /// A burst of emoji. Emoji stay upright-ish and do not tumble.
    public static let emoji = ConfettiConfiguration.emoji(["🎉", "🥳", "✨", "🎊", "⭐️"])

    /// A burst of your own emoji (or any short strings).
    ///
    /// ```swift
    /// .confetti(trigger: likes, .emoji(["❤️", "😍"]))
    /// ```
    public static func emoji(_ emoji: [String]) -> ConfettiConfiguration {
        let strings = emoji.filter { !$0.isEmpty }
        return ConfettiConfiguration(
            count: 45,
            shapes: strings.isEmpty ? [ConfettiShape.emoji("🎉")] : strings.map { ConfettiShape.emoji($0) },
            size: 24...40,
            emitter: .point(UnitPoint(x: 0.5, y: 0.55)),
            spread: 110,
            speed: 450...1000,
            gravity: 1000,
            drag: 1.4,
            spin: 0.25,
            tilt: 20,
            flip: 0,
            wobble: 0,
            lifetime: 3,
            fadeOut: 0.25
        )
    }

    /// Four firework shells bursting across the top half, one color each.
    public static let fireworks = ConfettiConfiguration(
        count: 70,
        shapes: [.circle, .circle, .circle, .star],
        colors: [
            Color(red: 1.00, green: 0.30, blue: 0.40),
            Color(red: 1.00, green: 0.78, blue: 0.20),
            Color(red: 0.30, green: 0.85, blue: 1.00),
            Color(red: 0.55, green: 1.00, blue: 0.45),
            Color(red: 0.85, green: 0.45, blue: 1.00),
        ],
        size: 4...8,
        emitter: ConfettiEmitter(position: UnitPoint(x: 0.5, y: 0.3), width: 0.6, height: 0.25),
        spread: 360,
        speed: 280...340,
        bursts: 4,
        burstInterval: 0.35,
        gravity: 160,
        drag: 1.9,
        spin: 0.5,
        flip: 0,
        wobble: 0,
        lifetime: 2.2,
        fadeOut: 0.5
    )

    /// Snowflakes drifting down from the top edge.
    public static let snow = ConfettiConfiguration(
        count: 90,
        shapes: [.circle, .circle, .symbol("snowflake")],
        colors: [
            Color(red: 0.80, green: 0.90, blue: 1.00),
            Color(red: 0.93, green: 0.97, blue: 1.00),
            Color(red: 0.62, green: 0.80, blue: 0.98),
        ],
        size: 4...12,
        emitter: .top,
        angle: 180,
        spread: 30,
        speed: 20...70,
        emissionDuration: 3,
        gravity: 45,
        drag: 0.8,
        spin: 0.2,
        flip: 0,
        wobble: 18,
        lifetime: 8,
        fadeOut: 0.2
    )

    /// Hearts floating up from the bottom edge.
    public static let hearts = ConfettiConfiguration(
        count: 40,
        shapes: [.heart],
        colors: [
            Color(red: 1.00, green: 0.18, blue: 0.33),
            Color(red: 1.00, green: 0.42, blue: 0.62),
            Color(red: 0.93, green: 0.10, blue: 0.45),
            Color(red: 1.00, green: 0.65, blue: 0.75),
        ],
        size: 14...28,
        emitter: .bottom,
        angle: 0,
        spread: 24,
        speed: 280...560,
        emissionDuration: 1.2,
        gravity: -40,
        drag: 1.2,
        spin: 0.15,
        tilt: 20,
        flip: 0,
        wobble: 14,
        lifetime: 4,
        fadeOut: 0.35
    )
}

// MARK: - Emission

extension ConfettiSimulation {
    /// The particles of one firing of `configuration`. The same seed always gives the same
    /// particles.
    ///
    /// Every particle consumes the same number of random values whatever the configuration,
    /// so changing, say, the colors never moves the particles.
    public static func particles(for configuration: ConfettiConfiguration, seed: UInt64) -> [ConfettiParticle] {
        var random = ConfettiRandom(seed: seed)
        let emitter = configuration.emitter
        let isClustered = configuration.bursts > 1
        let colorCount = configuration.colors.count
        let shapeCount = configuration.shapes.count

        var particles: [ConfettiParticle] = []
        particles.reserveCapacity(configuration.count * configuration.bursts)

        for burst in 0..<configuration.bursts {
            let burstDelay = Double(burst) * configuration.burstInterval
            let burstOrigin = point(in: emitter, u: random.unit(), v: random.unit())
            let burstColor = random.index(below: colorCount)

            for _ in 0..<configuration.count {
                let ownOrigin = point(in: emitter, u: random.unit(), v: random.unit())
                let emission = random.unit() * configuration.emissionDuration
                let direction = (configuration.angle + (random.unit() - 0.5) * configuration.spread) * .pi / 180
                let speed = random.double(in: configuration.speed)
                let lifetime = configuration.lifetime * random.double(in: 0.8...1)
                let size = random.double(in: configuration.size)
                let rotation = random.double(in: -1...1) * configuration.tilt * .pi / 180
                let spin = random.double(in: -1...1) * configuration.spin * 2 * .pi
                let flipSpeed = random.double(in: 0.5...1) * configuration.flip * 2 * .pi
                let flipPhase = random.unit() * 2 * .pi
                let wobbleAmplitude = random.double(in: 0.5...1) * configuration.wobble
                let wobbleFrequency = random.double(in: 0.4...1.1)
                let wobblePhase = random.unit() * 2 * .pi
                let color = random.index(below: colorCount)
                let shape = random.index(below: shapeCount)

                particles.append(ConfettiParticle(
                    origin: isClustered ? burstOrigin : ownOrigin,
                    velocity: ConfettiVector(x: sin(direction) * speed, y: -cos(direction) * speed),
                    delay: burstDelay + emission,
                    lifetime: lifetime,
                    size: size,
                    rotation: rotation,
                    spin: spin,
                    flipSpeed: flipSpeed,
                    flipPhase: flipSpeed == 0 ? 0 : flipPhase,
                    wobbleAmplitude: wobbleAmplitude,
                    wobbleFrequency: wobbleAmplitude == 0 ? 0 : wobbleFrequency,
                    wobblePhase: wobbleAmplitude == 0 ? 0 : wobblePhase,
                    colorIndex: isClustered ? burstColor : color,
                    shapeIndex: shape
                ))
            }
        }
        return particles
    }

    /// A random point of the emitter's rectangle, in unit coordinates.
    static func point(in emitter: ConfettiEmitter, u: Double, v: Double) -> ConfettiVector {
        ConfettiVector(
            x: Double(emitter.position.x) + (u - 0.5) * emitter.width,
            y: Double(emitter.position.y) + (v - 0.5) * emitter.height
        )
    }
}
