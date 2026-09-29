import Foundation
import SwiftUI
import Testing
@testable import ConfettiKit

func isClose(_ a: Double, _ b: Double, tolerance: Double = 1e-9) -> Bool {
    abs(a - b) <= tolerance
}

@Suite("Motion")
struct ConfettiMotionTests {
    @Test func withoutDragMotionIsBallistic() {
        let distance = ConfettiSimulation.displacement(velocity: 100, acceleration: 10, drag: 0, time: 2)
        let speed = ConfettiSimulation.velocity(initial: 100, acceleration: 10, drag: 0, time: 2)
        #expect(isClose(distance, 220))
        #expect(isClose(speed, 120))
    }

    @Test func tinyDragApproachesBallisticMotion() {
        let ballistic = ConfettiSimulation.displacement(velocity: 100, acceleration: 10, drag: 0, time: 2)
        let almost = ConfettiSimulation.displacement(velocity: 100, acceleration: 10, drag: 1e-6, time: 2)
        #expect(isClose(almost, ballistic, tolerance: 1e-3))
    }

    @Test func nothingMovesBeforeTimeStarts() {
        #expect(ConfettiSimulation.displacement(velocity: 300, acceleration: 900, drag: 1, time: 0) == 0)
        #expect(ConfettiSimulation.displacement(velocity: 300, acceleration: 900, drag: 1, time: -1) == 0)
        #expect(ConfettiSimulation.velocity(initial: 300, acceleration: 900, drag: 1, time: -1) == 300)
    }

    @Test func dragLeadsToTerminalVelocity() {
        let terminal = ConfettiSimulation.velocity(initial: -1_000, acceleration: 750, drag: 1.1, time: 40)
        #expect(isClose(terminal, 750 / 1.1, tolerance: 1e-6))

        // Without gravity, drag brings a particle to rest after v/k points.
        let coast = ConfettiSimulation.displacement(velocity: 440, acceleration: 0, drag: 1.1, time: 60)
        #expect(isClose(coast, 400, tolerance: 1e-6))
    }

    @Test func velocityIsTheDerivativeOfDisplacement() {
        let h = 1e-5
        for time in [0.1, 0.5, 1.3, 3.0] {
            let ahead = ConfettiSimulation.displacement(velocity: -800, acceleration: 750, drag: 1.1, time: time + h)
            let behind = ConfettiSimulation.displacement(velocity: -800, acceleration: 750, drag: 1.1, time: time - h)
            let numeric = (ahead - behind) / (2 * h)
            let exact = ConfettiSimulation.velocity(initial: -800, acceleration: 750, drag: 1.1, time: time)
            #expect(isClose(numeric, exact, tolerance: 1e-3))
        }
    }

    @Test func upwardLaunchRisesThenFalls() {
        let early = ConfettiSimulation.displacement(velocity: -900, acceleration: 750, drag: 1.1, time: 0.3)
        let late = ConfettiSimulation.displacement(velocity: -900, acceleration: 750, drag: 1.1, time: 5)
        #expect(early < 0)        // above the start (y grows downwards)
        #expect(late > 0)         // fell back below it
    }
}

@Suite("Fading")
struct ConfettiFadeTests {
    @Test func opacityFadesOverTheLastFraction() {
        #expect(ConfettiSimulation.opacity(age: 0, lifetime: 4, fadeOut: 0.5) == 1)
        #expect(ConfettiSimulation.opacity(age: 2, lifetime: 4, fadeOut: 0.5) == 1)
        #expect(isClose(ConfettiSimulation.opacity(age: 3, lifetime: 4, fadeOut: 0.5), 0.5))
        #expect(isClose(ConfettiSimulation.opacity(age: 3.9, lifetime: 4, fadeOut: 0.5), 0.05))
    }

    @Test func opacityIsZeroOutsideTheLifetime() {
        #expect(ConfettiSimulation.opacity(age: -0.1, lifetime: 4, fadeOut: 0.5) == 0)
        #expect(ConfettiSimulation.opacity(age: 4, lifetime: 4, fadeOut: 0.5) == 0)
        #expect(ConfettiSimulation.opacity(age: 1, lifetime: 0, fadeOut: 0.5) == 0)
    }

    @Test func noFadeKeepsFullOpacity() {
        #expect(ConfettiSimulation.opacity(age: 3.99, lifetime: 4, fadeOut: 0) == 1)
        #expect(ConfettiSimulation.opacity(age: 3.99, lifetime: 4, fadeOut: -2) == 1)
    }

    @Test func gentleFadeRisesAndFalls() {
        let duration = ConfettiSimulation.gentleFadeDuration
        #expect(ConfettiSimulation.gentleFadeOpacity(time: 0) == 0)
        #expect(ConfettiSimulation.gentleFadeOpacity(time: -1) == 0)
        #expect(ConfettiSimulation.gentleFadeOpacity(time: duration) == 0)
        #expect(isClose(ConfettiSimulation.gentleFadeOpacity(time: duration / 2), 1))
        let quarter = ConfettiSimulation.gentleFadeOpacity(time: duration / 4)
        #expect(quarter > 0 && quarter < 1)
        #expect(ConfettiSimulation.gentleFadeOpacity(time: 1, duration: 0) == 0)
    }
}

@Suite("Particle state")
struct ConfettiStateTests {
    let physics = ConfettiPhysics(gravity: 750, drag: 1.1, fadeOut: 0.3)
    let size = CGSize(width: 400, height: 800)

    var particle: ConfettiParticle {
        ConfettiParticle(
            origin: ConfettiVector(x: 0.5, y: 0.25),
            velocity: ConfettiVector(x: 120, y: -600),
            delay: 0.5,
            lifetime: 3,
            size: 10,
            rotation: 1,
            spin: 2,
            flipSpeed: 0,
            flipPhase: 0,
            wobbleAmplitude: 0
        )
    }

    @Test func particleIsHiddenBeforeItsDelayAndAfterItsLifetime() {
        #expect(ConfettiSimulation.state(of: particle, at: 0.49, in: size, physics: physics) == nil)
        #expect(ConfettiSimulation.state(of: particle, at: 3.5, in: size, physics: physics) == nil)
        #expect(ConfettiSimulation.state(of: particle, at: .nan, in: size, physics: physics) == nil)
        #expect(ConfettiSimulation.state(of: particle, at: 0.5, in: size, physics: physics) != nil)
    }

    @Test func particleStartsAtItsOriginInPoints() throws {
        let state = try #require(ConfettiSimulation.state(of: particle, at: 0.5, in: size, physics: physics))
        #expect(state.position == ConfettiVector(x: 200, y: 200))
        #expect(state.rotation == 1)
        #expect(state.flip == 1)
        #expect(state.opacity == 1)
    }

    @Test func positionFollowsTheClosedForm() throws {
        let state = try #require(ConfettiSimulation.state(of: particle, at: 1.5, in: size, physics: physics))
        let x = 200 + ConfettiSimulation.displacement(velocity: 120, acceleration: 0, drag: 1.1, time: 1)
        let y = 200 + ConfettiSimulation.displacement(velocity: -600, acceleration: 750, drag: 1.1, time: 1)
        #expect(isClose(state.position.x, x))
        #expect(isClose(state.position.y, y))
        #expect(isClose(state.rotation, 3))
    }

    @Test func wobbleAndFlipAreApplied() throws {
        var swaying = particle
        swaying.wobbleAmplitude = 10
        swaying.wobbleFrequency = 0.25        // a quarter sway per second
        swaying.flipSpeed = .pi
        let still = try #require(ConfettiSimulation.state(of: particle, at: 1.5, in: size, physics: physics))
        let moved = try #require(ConfettiSimulation.state(of: swaying, at: 1.5, in: size, physics: physics))
        #expect(isClose(moved.position.x - still.position.x, 10))     // sin(π/2) · 10
        #expect(isClose(moved.flip, -1))                              // cos(π)
        #expect(moved.position.y == still.position.y)
    }

    @Test func stateIsIndependentOfHowOftenItIsSampled() {
        let direct = ConfettiSimulation.state(of: particle, at: 2, in: size, physics: physics)
        _ = ConfettiSimulation.state(of: particle, at: 1, in: size, physics: physics)
        let again = ConfettiSimulation.state(of: particle, at: 2, in: size, physics: physics)
        #expect(direct == again)
    }

    @Test func durationIsTheLastParticleToDisappear() {
        var late = particle
        late.delay = 2
        late.lifetime = 4
        #expect(ConfettiSimulation.duration(of: [particle, late]) == 6)
        #expect(ConfettiSimulation.duration(of: []) == 0)
    }
}

@Suite("Emission")
struct ConfettiEmissionTests {
    @Test func sameSeedGivesTheSameParticles() {
        let a = ConfettiSimulation.particles(for: .confetti, seed: 42)
        let b = ConfettiSimulation.particles(for: .confetti, seed: 42)
        let c = ConfettiSimulation.particles(for: .confetti, seed: 43)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func emitsCountTimesBursts() {
        var configuration = ConfettiConfiguration.confetti
        configuration.count = 25
        configuration.bursts = 3
        #expect(ConfettiSimulation.particles(for: configuration, seed: 1).count == 75)
    }

    @Test func particlesRespectTheConfiguredRanges() {
        let configuration = ConfettiConfiguration.confetti
        let particles = ConfettiSimulation.particles(for: configuration, seed: 5)
        for particle in particles {
            #expect(configuration.size.contains(particle.size))
            #expect(particle.lifetime <= configuration.lifetime)
            #expect(particle.lifetime >= configuration.lifetime * 0.8)
            let speed = particle.velocity.length
            #expect(speed >= configuration.speed.lowerBound - 1e-6)
            #expect(speed <= configuration.speed.upperBound + 1e-6)
            #expect(configuration.colors.indices.contains(particle.colorIndex))
            #expect(configuration.shapes.indices.contains(particle.shapeIndex))
            #expect(particle.delay == 0)
        }
    }

    @Test func directionsStayInsideTheSpread() {
        var configuration = ConfettiConfiguration.confetti
        configuration.angle = 90          // to the right
        configuration.spread = 60
        let particles = ConfettiSimulation.particles(for: configuration, seed: 8)
        for particle in particles {
            // Angle measured clockwise from "up", in degrees.
            let degrees = atan2(particle.velocity.x, -particle.velocity.y) * 180 / .pi
            #expect(degrees >= 60 - 1e-6)
            #expect(degrees <= 120 + 1e-6)
        }
    }

    @Test func emissionIsSpreadOverTheEmissionDuration() {
        var configuration = ConfettiConfiguration.snow
        configuration.emissionDuration = 2
        let particles = ConfettiSimulation.particles(for: configuration, seed: 3)
        #expect(particles.allSatisfy { (0..<2).contains($0.delay) })
        #expect(Set(particles.map(\.delay)).count > 1)
    }

    @Test func multipleBurstsAreClusteredAndStaggered() {
        var configuration = ConfettiConfiguration.fireworks
        configuration.count = 10
        configuration.bursts = 3
        configuration.burstInterval = 0.5
        let particles = ConfettiSimulation.particles(for: configuration, seed: 12)
        let bursts = stride(from: 0, to: particles.count, by: 10).map { Array(particles[$0..<($0 + 10)]) }
        #expect(bursts.count == 3)
        for (index, burst) in bursts.enumerated() {
            #expect(Set(burst.map(\.origin)).count == 1)
            #expect(Set(burst.map(\.colorIndex)).count == 1)
            #expect(burst.allSatisfy { $0.delay == Double(index) * 0.5 })
        }
    }

    @Test func singleBurstParticlesUseTheWholeEmitter() {
        let configuration = ConfettiConfiguration.snow   // a line across the top
        let particles = ConfettiSimulation.particles(for: configuration, seed: 21)
        let xs = particles.map(\.origin.x)
        #expect(Set(xs).count == particles.count)
        #expect(xs.allSatisfy { (-0.05...1.05).contains($0) })
    }

    @Test func changingColorsDoesNotMoveParticles() {
        var recolored = ConfettiConfiguration.confetti
        recolored.colors = [.black, .white]
        let original = ConfettiSimulation.particles(for: .confetti, seed: 99)
        let other = ConfettiSimulation.particles(for: recolored, seed: 99)
        #expect(original.map(\.origin) == other.map(\.origin))
        #expect(original.map(\.velocity) == other.map(\.velocity))
    }

    @Test func tiltLimitsTheStartingRotation() {
        let limit = ConfettiConfiguration.hearts.tilt * .pi / 180
        let particles = ConfettiSimulation.particles(for: .hearts, seed: 6)
        #expect(particles.allSatisfy { abs($0.rotation) <= limit })
    }

    @Test func flatPresetsDoNotTumble() {
        let particles = ConfettiSimulation.particles(for: .emoji, seed: 4)
        #expect(particles.allSatisfy { $0.flipSpeed == 0 && $0.flipPhase == 0 })
        let physics = ConfettiConfiguration.emoji.physics
        let size = CGSize(width: 300, height: 600)
        let flips = particles.compactMap { ConfettiSimulation.state(of: $0, at: 0.4, in: size, physics: physics)?.flip }
        #expect(!flips.isEmpty)
        #expect(flips.allSatisfy { $0 == 1 })
    }
}
