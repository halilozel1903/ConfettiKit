import SwiftUI
import Testing
@testable import ConfettiKit

@Suite("Configuration")
struct ConfettiConfigurationTests {
    @Test func defaultsAreTheConfettiPreset() {
        let configuration = ConfettiConfiguration()
        #expect(configuration == .confetti)
        #expect(ConfettiConfiguration.countRange.contains(configuration.count))
        #expect(configuration.shapes == ConfettiShape.paper)
        #expect(configuration.colors == ConfettiConfiguration.defaultColors)
        #expect(configuration.frozenTime == nil)
        #expect(configuration.respectsReduceMotion)
    }

    @Test func valuesAreClampedOnInit() {
        let configuration = ConfettiConfiguration(
            count: 10_000,
            size: 0...900,
            spread: 720,
            speed: -50...9_000,
            bursts: 0,
            burstInterval: -1,
            gravity: -99_999,
            drag: -2,
            spin: 50,
            flip: -1,
            wobble: 1_000,
            lifetime: 0,
            fadeOut: 3,
            frozenTime: -4
        )
        #expect(configuration.count == 400)
        #expect(configuration.size == 1...200)
        #expect(configuration.spread == 360)
        #expect(configuration.speed == 0...5_000)
        #expect(configuration.bursts == 1)
        #expect(configuration.burstInterval == 0)
        #expect(configuration.gravity == -5_000)
        #expect(configuration.drag == 0)
        #expect(configuration.spin == 10)
        #expect(configuration.flip == 0)
        #expect(configuration.wobble == 200)
        #expect(configuration.lifetime == 0.2)
        #expect(configuration.fadeOut == 1)
        #expect(configuration.frozenTime == 0)
    }

    @Test func valuesAreClampedWhenSet() {
        var configuration = ConfettiConfiguration.confetti
        configuration.count = 0
        configuration.bursts = 42
        configuration.spread = -10
        configuration.drag = 99
        configuration.lifetime = 999
        configuration.emissionDuration = 60
        configuration.size = -5...3
        configuration.frozenTime = 1.25
        configuration.tilt = 400
        #expect(configuration.count == 1)
        #expect(configuration.tilt == 180)
        #expect(configuration.bursts == 8)
        #expect(configuration.spread == 0)
        #expect(configuration.drag == 20)
        #expect(configuration.lifetime == 30)
        #expect(configuration.emissionDuration == 10)
        #expect(configuration.size == 1...3)
        #expect(configuration.frozenTime == 1.25)

        configuration.frozenTime = nil
        #expect(configuration.frozenTime == nil)
    }

    @Test func nonFiniteValuesFallBackToDefaults() {
        let configuration = ConfettiConfiguration(
            angle: .nan,
            spread: .infinity,
            speed: 0...Double.infinity,
            gravity: .nan,
            drag: -.infinity,
            lifetime: .nan,
            frozenTime: .nan
        )
        #expect(configuration.angle == 0)
        #expect(configuration.spread == 120)
        #expect(configuration.speed == 400...1_100)
        #expect(configuration.gravity == 750)
        #expect(configuration.drag == 1.1)
        #expect(configuration.lifetime == 3.5)
        #expect(configuration.frozenTime == nil)
    }

    @Test func emptyColorsAndShapesFallBack() {
        let configuration = ConfettiConfiguration(shapes: [], colors: [])
        #expect(configuration.shapes == ConfettiShape.paper)
        #expect(configuration.colors == ConfettiConfiguration.defaultColors)

        var edited = ConfettiConfiguration.hearts
        edited.colors = []
        edited.shapes = []
        #expect(edited.colors == ConfettiConfiguration.defaultColors)
        #expect(edited.shapes == ConfettiShape.paper)
    }

    @Test func anglesAreNormalized() {
        #expect(ConfettiConfiguration(angle: 380).angle == 20)
        #expect(ConfettiConfiguration(angle: -90).angle == 270)
        #expect(ConfettiConfiguration(angle: 360).angle == 0)
        #expect(ConfettiConfiguration(angle: -720).angle == 0)
        #expect(ConfettiConfiguration(angle: 45).angle == 45)

        var configuration = ConfettiConfiguration.confetti
        configuration.angle = -30
        #expect(configuration.angle == 330)
    }

    @Test func emitterIsClamped() {
        let emitter = ConfettiEmitter(position: UnitPoint(x: .nan, y: 0.2), width: 5, height: -1)
        #expect(emitter.position == UnitPoint(x: 0.5, y: 0.2))
        #expect(emitter.width == 2)
        #expect(emitter.height == 0)

        var edited = ConfettiEmitter.center
        edited.width = .nan
        edited.position = UnitPoint(x: 0.1, y: .infinity)
        #expect(edited.width == 0)
        #expect(edited.position == UnitPoint(x: 0.1, y: 0.5))
    }

    @Test func frozenOnlyChangesTheTime() {
        let frozen = ConfettiConfiguration.fireworks.frozen(at: 1.2)
        #expect(frozen.frozenTime == 1.2)
        var unfrozen = frozen
        unfrozen.frozenTime = nil
        #expect(unfrozen == .fireworks)
    }

    @Test func scalingMultipliesDistances() {
        let base = ConfettiConfiguration.confetti
        let half = base.scaled(by: 0.5)
        #expect(half.speed == 200...550)
        #expect(half.gravity == 375)
        #expect(half.wobble == 3)
        #expect(half.size == base.size)
        #expect(half.count == base.count)

        #expect(base.scaled(by: 0) == base)
        #expect(base.scaled(by: -2) == base)
        #expect(base.scaled(by: .nan) == base)
        #expect(base.scaled(by: 100).speed.upperBound == 5_000)
    }

    @Test func physicsMirrorsTheConfiguration() {
        let physics = ConfettiConfiguration.snow.physics
        #expect(physics.gravity == ConfettiConfiguration.snow.gravity)
        #expect(physics.drag == ConfettiConfiguration.snow.drag)
        #expect(physics.fadeOut == ConfettiConfiguration.snow.fadeOut)
    }
}

@Suite("Presets")
struct ConfettiPresetTests {
    @Test func presetsDiffer() {
        let presets: [ConfettiConfiguration] = [.confetti, .emoji, .fireworks, .snow, .hearts]
        #expect(Set(presets).count == presets.count)
    }

    @Test func presetsHaveTheirCharacter() {
        let allEmoji = ConfettiConfiguration.emoji.shapes.allSatisfy { shape in
            if case .emoji = shape { return true }
            return false
        }
        #expect(allEmoji)
        #expect(ConfettiConfiguration.emoji.flip == 0)
        #expect(ConfettiConfiguration.fireworks.bursts > 1)
        #expect(ConfettiConfiguration.fireworks.spread == 360)
        #expect(ConfettiConfiguration.snow.angle == 180)
        #expect(ConfettiConfiguration.snow.emissionDuration > 0)
        #expect(ConfettiConfiguration.hearts.gravity < 0)
        #expect(ConfettiConfiguration.hearts.shapes == [.heart])
    }

    @Test func customEmoji() {
        #expect(ConfettiConfiguration.emoji(["❤️", "🔥"]).shapes == [.emoji("❤️"), .emoji("🔥")])
        #expect(ConfettiConfiguration.emoji([]).shapes == [.emoji("🎉")])
        #expect(ConfettiConfiguration.emoji(["", "⭐️"]).shapes == [.emoji("⭐️")])
    }

    @Test func cannonPointsWhereAsked() {
        let cannon = ConfettiConfiguration.cannon(from: .bottomLeading, angle: -30)
        #expect(cannon.emitter.position == .bottomLeading)
        #expect(cannon.angle == 330)
        #expect(cannon.spread < ConfettiConfiguration.confetti.spread)
    }
}

@Suite("Shapes")
struct ConfettiShapeTests {
    @MainActor
    @Test func customShapesCompareById() {
        let a = ConfettiCustomShape(id: "ring") { rect in Path(ellipseIn: rect) }
        let b = ConfettiCustomShape(id: "ring") { rect in Path(rect) }
        let c = ConfettiCustomShape(id: "pill", Capsule())
        #expect(a == b)
        #expect(a != c)
        #expect(ConfettiShape.custom(a) == ConfettiShape.custom(b))
    }

    @Test func frameSizesFollowTheAspectRatio() {
        #expect(ConfettiShape.rectangle.frameSize(for: 10) == CGSize(width: 10, height: 6))
        #expect(ConfettiShape.strip.frameSize(for: 10) == CGSize(width: 3, height: 10))
        #expect(ConfettiShape.circle.frameSize(for: 10) == CGSize(width: 10, height: 10))
    }

    @Test func vectorShapesHavePathsAndGlyphsDoNot() {
        let rect = CGRect(x: -5, y: -5, width: 10, height: 10)
        let vectors: [ConfettiShape] = [.rectangle, .square, .circle, .triangle, .star, .heart, .strip]
        for shape in vectors {
            let path = shape.path(in: rect)
            #expect(path != nil)
            #expect(path?.isEmpty == false)
        }
        #expect(ConfettiShape.emoji("🎉").path(in: rect) == nil)
        #expect(ConfettiShape.symbol("star.fill").path(in: rect) == nil)
    }

    @Test func starStaysInsideItsRect() throws {
        let rect = CGRect(x: 0, y: 0, width: 20, height: 20)
        let star = try #require(ConfettiShape.star.path(in: rect))
        #expect(rect.insetBy(dx: -0.001, dy: -0.001).contains(star.boundingRect))
    }
}
