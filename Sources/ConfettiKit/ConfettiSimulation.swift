import Foundation

/// A 2D vector in points (or unit coordinates, where noted).
public struct ConfettiVector: Sendable, Hashable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static let zero = ConfettiVector(x: 0, y: 0)

    /// The vector's length.
    public var length: Double { (x * x + y * y).squareRoot() }
}

/// Everything about one particle that is decided when it is emitted.
///
/// A particle never stores its current position: ``ConfettiSimulation/state(of:at:in:physics:)``
/// computes it in closed form from these values and the elapsed time. That makes every frame
/// independent of the frame rate and lets any moment be drawn directly (see
/// ``ConfettiConfiguration/frozen(at:)``).
public struct ConfettiParticle: Sendable, Hashable {
    /// Where the particle starts, in unit coordinates of the drawing area (`0...1` inside).
    public var origin: ConfettiVector
    /// The launch velocity in points per second. Positive `y` points down.
    public var velocity: ConfettiVector
    /// Seconds after the effect fires before the particle appears.
    public var delay: Double
    /// Seconds the particle lives once it has appeared.
    public var lifetime: Double
    /// The particle's size in points.
    public var size: Double
    /// The initial rotation in radians.
    public var rotation: Double
    /// Rotation speed in radians per second.
    public var spin: Double
    /// Speed of the 3D tumble in radians per second; `0` keeps the particle flat.
    public var flipSpeed: Double
    /// The tumble's starting phase in radians.
    public var flipPhase: Double
    /// Sideways sway in points.
    public var wobbleAmplitude: Double
    /// Sways per second.
    public var wobbleFrequency: Double
    /// The sway's starting phase in radians.
    public var wobblePhase: Double
    /// Index into the configuration's colors.
    public var colorIndex: Int
    /// Index into the configuration's shapes.
    public var shapeIndex: Int

    public init(
        origin: ConfettiVector,
        velocity: ConfettiVector,
        delay: Double = 0,
        lifetime: Double = 3,
        size: Double = 10,
        rotation: Double = 0,
        spin: Double = 0,
        flipSpeed: Double = 0,
        flipPhase: Double = 0,
        wobbleAmplitude: Double = 0,
        wobbleFrequency: Double = 0,
        wobblePhase: Double = 0,
        colorIndex: Int = 0,
        shapeIndex: Int = 0
    ) {
        self.origin = origin
        self.velocity = velocity
        self.delay = delay
        self.lifetime = lifetime
        self.size = size
        self.rotation = rotation
        self.spin = spin
        self.flipSpeed = flipSpeed
        self.flipPhase = flipPhase
        self.wobbleAmplitude = wobbleAmplitude
        self.wobbleFrequency = wobbleFrequency
        self.wobblePhase = wobblePhase
        self.colorIndex = colorIndex
        self.shapeIndex = shapeIndex
    }
}

/// Where a particle is and how it looks at one moment.
public struct ConfettiParticleState: Sendable, Hashable {
    /// The center in points, in the drawing area's coordinates.
    public var position: ConfettiVector
    /// The rotation in radians.
    public var rotation: Double
    /// The horizontal scale of the 3D tumble, in `-1...1`.
    public var flip: Double
    /// The opacity, in `0...1`.
    public var opacity: Double
}

/// The forces acting on every particle of an effect.
public struct ConfettiPhysics: Sendable, Hashable {
    /// Downward acceleration in points per second squared. Negative values make particles rise.
    public var gravity: Double
    /// Air resistance: the fraction of velocity lost per second, roughly. `0` means none.
    public var drag: Double
    /// The last fraction of each particle's lifetime during which it fades out, in `0...1`.
    public var fadeOut: Double

    public init(gravity: Double, drag: Double, fadeOut: Double) {
        self.gravity = gravity
        self.drag = max(0, drag)
        self.fadeOut = min(max(fadeOut, 0), 1)
    }
}

/// The pure particle math behind ConfettiKit. It has no SwiftUI dependency and no state:
/// the same inputs always give the same outputs.
///
/// Motion uses linear drag, which has an exact solution. With launch velocity `v`,
/// acceleration `a` and drag `k`, after `t` seconds:
///
/// ```
/// velocity(t)     = v·e^(−kt) + (a/k)·(1 − e^(−kt))
/// displacement(t) = (v − a/k)·(1 − e^(−kt))/k + (a/k)·t
/// ```
///
/// which becomes `v·t + a·t²/2` as `k` approaches zero. Particles therefore slow down,
/// reach a terminal velocity of `a/k` and flutter down instead of accelerating forever.
public enum ConfettiSimulation {
    /// How long the gentle Reduce Motion fade lasts, in seconds.
    public static let gentleFadeDuration: Double = 1.6

    /// Drag below this is treated as zero, where the closed form would divide by ~0.
    static let dragEpsilon = 1e-9

    /// The distance travelled along one axis after `time` seconds.
    public static func displacement(velocity: Double, acceleration: Double, drag: Double, time: Double) -> Double {
        guard time > 0 else { return 0 }
        guard drag > dragEpsilon else {
            return velocity * time + 0.5 * acceleration * time * time
        }
        let decay = 1 - exp(-drag * time)
        let terminal = acceleration / drag
        return (velocity - terminal) * decay / drag + terminal * time
    }

    /// The velocity along one axis after `time` seconds.
    public static func velocity(initial: Double, acceleration: Double, drag: Double, time: Double) -> Double {
        guard time > 0 else { return initial }
        guard drag > dragEpsilon else {
            return initial + acceleration * time
        }
        let falloff = exp(-drag * time)
        return initial * falloff + acceleration / drag * (1 - falloff)
    }

    /// A particle's opacity at `age` seconds: `1`, then a linear fade over the last `fadeOut`
    /// fraction of its `lifetime`, and `0` before birth and after death.
    public static func opacity(age: Double, lifetime: Double, fadeOut: Double) -> Double {
        guard lifetime > 0, age >= 0, age < lifetime else { return 0 }
        let fade = min(max(fadeOut, 0), 1)
        let fadeStart = lifetime * (1 - fade)
        guard fade > 0, age > fadeStart else { return 1 }
        return min(max((lifetime - age) / (lifetime - fadeStart), 0), 1)
    }

    /// The particle's state `time` seconds after the effect fired, or `nil` while it is not
    /// yet born or already gone.
    ///
    /// - Parameters:
    ///   - particle: The particle.
    ///   - time: Seconds since the effect fired.
    ///   - size: The drawing area in points; the particle's origin is relative to it.
    ///   - physics: Gravity, drag and fade.
    public static func state(
        of particle: ConfettiParticle,
        at time: Double,
        in size: CGSize,
        physics: ConfettiPhysics
    ) -> ConfettiParticleState? {
        let age = time - particle.delay
        guard age.isFinite, age >= 0, age < particle.lifetime else { return nil }

        let sway = particle.wobbleAmplitude == 0 ? 0 :
            particle.wobbleAmplitude * sin(2 * .pi * particle.wobbleFrequency * age + particle.wobblePhase)
        let x = particle.origin.x * Double(size.width)
            + displacement(velocity: particle.velocity.x, acceleration: 0, drag: physics.drag, time: age)
            + sway
        let y = particle.origin.y * Double(size.height)
            + displacement(velocity: particle.velocity.y, acceleration: physics.gravity, drag: physics.drag, time: age)

        let flip = particle.flipSpeed == 0 ? 1 : cos(particle.flipPhase + particle.flipSpeed * age)

        return ConfettiParticleState(
            position: ConfettiVector(x: x, y: y),
            rotation: particle.rotation + particle.spin * age,
            flip: flip,
            opacity: opacity(age: age, lifetime: particle.lifetime, fadeOut: physics.fadeOut)
        )
    }

    /// Seconds from firing until the last particle is gone.
    public static func duration(of particles: [ConfettiParticle]) -> Double {
        particles.reduce(0.0) { max($0, $1.delay + $1.lifetime) }
    }

    /// The opacity of the Reduce Motion glow `time` seconds after firing: it eases in and back
    /// out over `duration` seconds, and is `0` outside.
    public static func gentleFadeOpacity(time: Double, duration: Double = gentleFadeDuration) -> Double {
        guard duration > 0, time > 0, time < duration else { return 0 }
        let wave = sin(.pi * time / duration)
        return wave * wave
    }
}
