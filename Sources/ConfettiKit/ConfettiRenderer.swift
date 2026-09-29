import SwiftUI

/// One firing of an effect: its particles and when it started.
struct ConfettiBurst: Identifiable, Sendable, Equatable {
    let id: Int
    let particles: [ConfettiParticle]
    /// Start time, in seconds since the reference date (the `TimelineView` clock).
    let start: TimeInterval
    /// Draws the Reduce Motion glow instead of particles.
    let isGentle: Bool
    /// Seconds until the burst has nothing left to draw.
    let duration: Double

    init(id: Int, configuration: ConfettiConfiguration, seed: UInt64, start: TimeInterval, isGentle: Bool) {
        let particles = isGentle ? [] : ConfettiSimulation.particles(for: configuration, seed: seed)
        self.id = id
        self.particles = particles
        self.start = start
        self.isGentle = isGentle
        self.duration = isGentle ? ConfettiSimulation.gentleFadeDuration : ConfettiSimulation.duration(of: particles)
    }
}

/// Text and symbols resolved once per frame and shared by every particle that uses them.
@MainActor
struct ConfettiGlyphs {
    /// The font size glyphs are resolved at; particles scale them to their own size.
    static let baseSize: Double = 48

    private var cache: [ConfettiShape: GraphicsContext.ResolvedText] = [:]

    mutating func glyph(for shape: ConfettiShape, in context: GraphicsContext) -> GraphicsContext.ResolvedText? {
        if let cached = cache[shape] { return cached }
        let text: Text
        switch shape {
        case .emoji(let string):
            text = Text(verbatim: string)
        case .symbol(let name):
            text = Text(Image(systemName: name))
        default:
            return nil
        }
        let resolved = context.resolve(text.font(.system(size: CGFloat(Self.baseSize))))
        cache[shape] = resolved
        return resolved
    }
}

/// Draws bursts into a `Canvas`. Runs inside the canvas renderer, on the main actor.
@MainActor
enum ConfettiRenderer {
    static func draw(
        _ burst: ConfettiBurst,
        at time: Double,
        configuration: ConfettiConfiguration,
        in context: GraphicsContext,
        size: CGSize,
        glyphs: inout ConfettiGlyphs
    ) {
        if burst.isGentle {
            drawGentle(at: time, configuration: configuration, in: context, size: size, glyphs: &glyphs)
            return
        }

        let physics = configuration.physics
        let shapes = configuration.shapes
        let colors = configuration.colors

        for particle in burst.particles {
            guard
                let state = ConfettiSimulation.state(of: particle, at: time, in: size, physics: physics),
                state.opacity > 0
            else { continue }

            let shape = shapes[particle.shapeIndex % shapes.count]
            let color = colors[particle.colorIndex % colors.count]

            var layer = context
            layer.opacity = state.opacity
            layer.translateBy(x: CGFloat(state.position.x), y: CGFloat(state.position.y))
            layer.rotate(by: .radians(state.rotation))
            if state.flip != 1 {
                layer.scaleBy(x: CGFloat(state.flip), y: 1)
            }

            if var glyph = glyphs.glyph(for: shape, in: context) {
                if case .symbol = shape {
                    glyph.shading = .color(color)
                }
                let scale = CGFloat(particle.size / ConfettiGlyphs.baseSize)
                layer.scaleBy(x: scale, y: scale)
                layer.draw(glyph, at: .zero, anchor: .center)
            } else {
                let frame = shape.frameSize(for: particle.size)
                let rect = CGRect(
                    x: -frame.width / 2,
                    y: -frame.height / 2,
                    width: frame.width,
                    height: frame.height
                )
                if let path = shape.path(in: rect) {
                    layer.fill(path, with: .color(color))
                }
            }
        }
    }

    /// The Reduce Motion version: a soft glow in the effect's colors (and its first emoji, if
    /// any) that fades in and out in place.
    static func drawGentle(
        at time: Double,
        configuration: ConfettiConfiguration,
        in context: GraphicsContext,
        size: CGSize,
        glyphs: inout ConfettiGlyphs
    ) {
        let opacity = ConfettiSimulation.gentleFadeOpacity(time: time)
        guard opacity > 0, size.width > 0, size.height > 0 else { return }

        let position = configuration.emitter.position
        let center = CGPoint(
            x: min(max(position.x, 0), 1) * size.width,
            y: min(max(position.y, 0), 1) * size.height
        )
        let radius = max(size.width, size.height) * 0.4
        let colors = Array(configuration.colors.prefix(3))

        var layer = context
        layer.opacity = opacity
        for (index, color) in colors.enumerated() {
            let angle = Double(index) * 2 * .pi / Double(colors.count) - .pi / 2
            let glowCenter = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius * 0.2,
                y: center.y + CGFloat(sin(angle)) * radius * 0.2
            )
            let rect = CGRect(
                x: glowCenter.x - radius,
                y: glowCenter.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            layer.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.35), color.opacity(0)]),
                    center: glowCenter,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }

        let firstGlyph = configuration.shapes.first { shape in
            if case .emoji = shape { return true }
            return false
        }
        if let firstGlyph, let glyph = glyphs.glyph(for: firstGlyph, in: context) {
            var emojiLayer = layer
            emojiLayer.translateBy(x: center.x, y: center.y)
            let scale = CGFloat(0.9 + 0.2 * opacity)
            emojiLayer.scaleBy(x: scale, y: scale)
            emojiLayer.draw(glyph, at: .zero, anchor: .center)
        }
    }
}

/// Draws any number of bursts, animated by a `TimelineView` that only runs while there is
/// something to draw.
struct ConfettiCanvas: View {
    let bursts: [ConfettiBurst]
    let configuration: ConfettiConfiguration

    var body: some View {
        let isPaused = bursts.isEmpty || configuration.frozenTime != nil
        TimelineView(.animation(minimumInterval: nil, paused: isPaused)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                var glyphs = ConfettiGlyphs()
                for burst in bursts {
                    let time = configuration.frozenTime ?? (now - burst.start)
                    ConfettiRenderer.draw(
                        burst,
                        at: time,
                        configuration: configuration,
                        in: context,
                        size: size,
                        glyphs: &glyphs
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
