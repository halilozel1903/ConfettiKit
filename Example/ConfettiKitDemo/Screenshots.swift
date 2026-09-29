import ConfettiKit
import Foundation

/// Scenes used by CI to capture the README screenshots.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
enum ScreenshotScene: String {
    /// The "You did it!" card with confetti frozen mid-flight.
    case burst
    /// Every preset side by side, frozen mid-animation.
    case presets

    static var current: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }
}

extension ConfettiConfiguration {
    /// Freezes the effect at `seconds` in screenshot scenes so every capture looks the same.
    func frozen(at seconds: Double, if isFrozen: Bool) -> ConfettiConfiguration {
        isFrozen ? frozen(at: seconds) : self
    }

    /// Shrinks a full-screen preset to fit a small tile: distances, particle sizes and count.
    func miniature(scale: Double, sizeFactor: Double = 0.6, countFactor: Double = 0.6) -> ConfettiConfiguration {
        var copy = scaled(by: scale)
        copy.size = (size.lowerBound * sizeFactor)...(size.upperBound * sizeFactor)
        copy.count = Int((Double(count) * countFactor).rounded())
        return copy
    }
}
