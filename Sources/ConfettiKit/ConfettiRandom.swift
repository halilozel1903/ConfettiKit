import Foundation

/// A small, fast, seeded random number generator (SplitMix64).
///
/// The same seed always produces the same sequence, on every device and OS version, so a
/// burst of particles can be reproduced exactly: in previews, snapshot tests and screenshots.
///
/// ```swift
/// var random = ConfettiRandom(seed: 42)
/// let angle = random.double(in: -30...30)
/// ```
public struct ConfettiRandom: RandomNumberGenerator, Sendable, Hashable {
    private var state: UInt64

    /// Creates a generator. Equal seeds produce equal sequences.
    public init(seed: UInt64) {
        state = seed
    }

    /// The next 64 random bits.
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniformly distributed value in `0..<1`.
    ///
    /// Implemented here rather than with `Double.random(in:using:)`, whose algorithm is not
    /// guaranteed to stay the same across standard library versions.
    public mutating func unit() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }

    /// A uniformly distributed value in `range`. A zero-width range returns its bound.
    public mutating func double(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * unit()
    }

    /// A uniformly distributed index in `0..<count`, or `0` when `count` is not positive.
    public mutating func index(below count: Int) -> Int {
        let bits = next()
        guard count > 1 else { return 0 }
        return Int(bits % UInt64(count))
    }
}
