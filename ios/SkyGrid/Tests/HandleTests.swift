import Testing
@testable import SkyGrid

@Suite("Handle")
struct HandleTests {
    @Test("normalizes to lowercase and trims whitespace")
    func normalizesInput() {
        let handle = Handle(raw: "  Taku_8  ")
        #expect(handle?.value == "taku_8")
    }

    @Test("rejects too-short, too-long, and invalid-character handles", arguments: ["ab", "a234567890123456789012", "taku!", "taku 8"])
    func rejectsInvalid(_ raw: String) {
        #expect(Handle(raw: raw) == nil)
    }
}

@Suite("PairID")
struct PairIDTests {
    @Test("is order-independent")
    func orderIndependent() {
        #expect(PairID.make("uidA", "uidB") == PairID.make("uidB", "uidA"))
    }

    @Test("sorts lexicographically with underscore separator")
    func sortsLexicographically() {
        #expect(PairID.make("zzz", "aaa") == "aaa_zzz")
    }
}
