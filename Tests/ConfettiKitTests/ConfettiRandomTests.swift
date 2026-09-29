import Testing
@testable import ConfettiKit

@Suite("Seeded random")
struct ConfettiRandomTests {
    @Test func matchesTheSplitMix64ReferenceValues() {
        var random = ConfettiRandom(seed: 0)
        let first = random.next()
        let second = random.next()
        #expect(first == 0xE220_A839_7B1D_CDAF)
        #expect(second == 0x6E78_9E6A_A1B9_65F4)

        var seeded = ConfettiRandom(seed: 42)
        let value = seeded.next()
        #expect(value == 0xBDD7_3226_2FEB_6E95)
    }

    @Test func sameSeedGivesTheSameSequence() {
        var a = ConfettiRandom(seed: 2026)
        var b = ConfettiRandom(seed: 2026)
        var first: [UInt64] = []
        var second: [UInt64] = []
        for _ in 0..<32 {
            first.append(a.next())
            second.append(b.next())
        }
        #expect(first == second)
    }

    @Test func differentSeedsGiveDifferentSequences() {
        var a = ConfettiRandom(seed: 1)
        var b = ConfettiRandom(seed: 2)
        let valueA = a.next()
        let valueB = b.next()
        #expect(valueA != valueB)
    }

    @Test func unitValuesStayInHalfOpenRange() {
        var random = ConfettiRandom(seed: 7)
        var values: [Double] = []
        for _ in 0..<2_000 {
            values.append(random.unit())
        }
        #expect(values.allSatisfy { $0 >= 0 && $0 < 1 })
        let mean = values.reduce(0, +) / Double(values.count)
        #expect(abs(mean - 0.5) < 0.05)
    }

    @Test func doublesStayInTheirRange() {
        var random = ConfettiRandom(seed: 9)
        var values: [Double] = []
        for _ in 0..<500 {
            values.append(random.double(in: -3...5))
        }
        #expect(values.allSatisfy { (-3...5).contains($0) })

        let fixed = random.double(in: 4...4)
        #expect(fixed == 4)
    }

    @Test func indicesStayInBounds() {
        var random = ConfettiRandom(seed: 11)
        var indices: [Int] = []
        for _ in 0..<500 {
            indices.append(random.index(below: 7))
        }
        #expect(indices.allSatisfy { (0..<7).contains($0) })
        #expect(Set(indices).count == 7)

        let single = random.index(below: 1)
        let none = random.index(below: 0)
        let negative = random.index(below: -4)
        #expect(single == 0)
        #expect(none == 0)
        #expect(negative == 0)
    }
}
