import SwiftUI

/// What a particle looks like.
///
/// ```swift
/// var configuration = ConfettiConfiguration.confetti
/// configuration.shapes = [.star, .circle, .emoji("🎈"), .symbol("sparkle")]
/// configuration.shapes.append(.custom(ConfettiCustomShape(id: "capsule", Capsule())))
/// ```
public enum ConfettiShape: Sendable, Hashable {
    /// A paper rectangle, 1 : 0.6.
    case rectangle
    /// A square.
    case square
    /// A round dot.
    case circle
    /// An equilateral-ish triangle.
    case triangle
    /// A five-pointed star.
    case star
    /// A heart.
    case heart
    /// A long, thin ribbon, 0.3 : 1.
    case strip
    /// An emoji or any short text, drawn at the particle's size. Colors are ignored.
    case emoji(String)
    /// An SF Symbol, tinted with the particle's color.
    case symbol(String)
    /// Your own shape.
    case custom(ConfettiCustomShape)

    /// The classic mix: rectangles, ribbons, dots and triangles.
    public static let paper: [ConfettiShape] = [.rectangle, .rectangle, .strip, .circle, .triangle, .square]

    /// The size of the box the shape is drawn in, for a particle of `size` points.
    func frameSize(for size: Double) -> CGSize {
        switch self {
        case .rectangle:
            CGSize(width: size, height: size * 0.6)
        case .strip:
            CGSize(width: size * 0.3, height: size)
        default:
            CGSize(width: size, height: size)
        }
    }

    /// The outline of a vector shape in `rect`, or `nil` for text and symbols.
    func path(in rect: CGRect) -> Path? {
        switch self {
        case .rectangle, .square:
            return Path(rect)
        case .strip:
            return Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.3)
        case .circle:
            return Path(ellipseIn: rect)
        case .triangle:
            return ConfettiPaths.triangle(in: rect)
        case .star:
            return ConfettiPaths.star(in: rect)
        case .heart:
            return ConfettiPaths.heart(in: rect)
        case .custom(let shape):
            return shape.path(rect)
        case .emoji, .symbol:
            return nil
        }
    }
}

/// A particle shape of your own, identified by `id` so configurations stay comparable.
///
/// ```swift
/// let ring = ConfettiCustomShape(id: "ring") { rect in
///     Path(ellipseIn: rect).strokedPath(StrokeStyle(lineWidth: rect.width * 0.2))
/// }
/// let pill = ConfettiCustomShape(id: "pill", Capsule())
/// ```
public struct ConfettiCustomShape: Sendable, Hashable {
    /// Identifies the shape: two custom shapes with the same `id` are considered equal.
    public let id: String
    let path: @Sendable (CGRect) -> Path

    /// Creates a shape from a closure that draws it into a rectangle.
    public init(id: String, path: @escaping @Sendable (CGRect) -> Path) {
        self.id = id
        self.path = path
    }

    /// Creates a shape from any SwiftUI `Shape`.
    public init<S: Shape & Sendable>(id: String, _ shape: S) {
        self.init(id: id) { rect in shape.path(in: rect) }
    }

    public static func == (lhs: ConfettiCustomShape, rhs: ConfettiCustomShape) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Outlines for the built-in shapes, drawn into any rectangle.
enum ConfettiPaths {
    static func triangle(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    static func star(in rect: CGRect, points: Int = 5, innerRatio: Double = 0.45) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = Double(min(rect.width, rect.height)) / 2
        let inner = outer * innerRatio
        var path = Path()
        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = Double(index) * .pi / Double(points) - .pi / 2
            let point = CGPoint(x: center.x + CGFloat(radius * cos(angle)), y: center.y + CGFloat(radius * sin(angle)))
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    static func heart(in rect: CGRect) -> Path {
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + rect.width * CGFloat(x), y: rect.minY + rect.height * CGFloat(y))
        }
        var path = Path()
        path.move(to: point(0.5, 0.95))
        path.addCurve(to: point(0, 0.34), control1: point(0.28, 0.78), control2: point(0, 0.6))
        path.addCurve(to: point(0.5, 0.2), control1: point(0, 0.02), control2: point(0.42, -0.02))
        path.addCurve(to: point(1, 0.34), control1: point(0.58, -0.02), control2: point(1, 0.02))
        path.addCurve(to: point(0.5, 0.95), control1: point(1, 0.6), control2: point(0.72, 0.78))
        path.closeSubpath()
        return path
    }
}
