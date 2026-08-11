import Testing
import CoreGraphics
@testable import SkyGrid

/// The share card's contact sheet packs a different shape at every count, and the
/// counts that matter to a real user are months apart. These pin the three that the
/// card is actually judged on: the first morning, a typical sparse year, and a
/// complete one.
@Suite("ContactSheetLayout")
struct ContactSheetLayoutTests {
    /// The panel the year card gives the sheet: 920 wide minus the 34pt inset on
    /// each side, 680 tall minus the same.
    private let panel = CGSize(width: 852, height: 612)

    @Test("an empty sheet has no layout, so the view draws its empty state instead")
    func emptyCountHasNoLayout() {
        #expect(ContactSheetLayout.layout(count: 0, in: panel) == nil)
    }

    @Test("a single capture is capped rather than blown up to fill the panel")
    func singleCaptureIsCapped() throws {
        let layout = try #require(ContactSheetLayout.layout(count: 1, in: panel))

        #expect(layout.columns == 1)
        #expect(layout.rows == 1)
        // Without the cap this would be 612 — a cached thumbnail stretched across
        // most of the card.
        #expect(layout.cellSide == ContactSheetLayout.maximumCellSide)
    }

    @Test("a sparse year gives each captured morning a tile many times the old 30pt cell")
    func sparseYearProducesLargeTiles() throws {
        // 20 is the representative count that motivated the redesign: on the old
        // literal 31×12 calendar each of these was a 30pt cell — about 3px once the
        // card is a story-tray thumbnail — inside a field of 345 empty ones.
        let layout = try #require(ContactSheetLayout.layout(count: 20, in: panel))

        #expect(layout.columns == 5)
        #expect(layout.rows == 4)
        #expect(layout.cellSide > 120)
    }

    @Test("a complete year still fits every capture inside the panel")
    func fullYearFitsInsidePanel() throws {
        let layout = try #require(ContactSheetLayout.layout(count: 365, in: panel))

        #expect(layout.columns * layout.rows >= 365)
        #expect(layout.origin.x >= 0)
        #expect(layout.origin.y >= 0)

        let last = ContactSheetLayout.rect(at: 364, layout: layout)
        #expect(last.maxX <= panel.width)
        #expect(last.maxY <= panel.height)
    }

    @Test("every capture is drawn inside the panel at each representative count",
          arguments: [1, 2, 20, 50, 145, 365, 366])
    func everyTileStaysInsideThePanel(count: Int) throws {
        let layout = try #require(ContactSheetLayout.layout(count: count, in: panel))

        for index in 0..<count {
            let rect = ContactSheetLayout.rect(at: index, layout: layout)
            #expect(rect.minX >= 0)
            #expect(rect.minY >= 0)
            #expect(rect.maxX <= panel.width)
            #expect(rect.maxY <= panel.height)
        }
    }

    @Test("the packed block is centred in the panel")
    func blockIsCentred() throws {
        let layout = try #require(ContactSheetLayout.layout(count: 20, in: panel))
        let first = ContactSheetLayout.rect(at: 0, layout: layout)
        let last = ContactSheetLayout.rect(at: 19, layout: layout)

        #expect(abs(first.minX - (panel.width - last.maxX)) < 1)
        #expect(abs(first.minY - (panel.height - last.maxY)) < 1)
    }

    @Test("tiles are laid out left to right, then top to bottom")
    func tilesFollowReadingOrder() throws {
        let layout = try #require(ContactSheetLayout.layout(count: 20, in: panel))
        let first = ContactSheetLayout.rect(at: 0, layout: layout)
        let second = ContactSheetLayout.rect(at: 1, layout: layout)
        let firstOfSecondRow = ContactSheetLayout.rect(at: layout.columns, layout: layout)

        #expect(second.minX > first.minX)
        #expect(second.minY == first.minY)
        #expect(firstOfSecondRow.minX == first.minX)
        #expect(firstOfSecondRow.minY > first.minY)
    }

    @Test("the gutter tightens as the sheet gets denser, so photos keep the area")
    func gapTightensWithDensity() {
        #expect(ContactSheetLayout.gap(forCount: 20) == 10)
        #expect(ContactSheetLayout.gap(forCount: 50) == 6)
        #expect(ContactSheetLayout.gap(forCount: 365) == 4)
        // Boundaries pinned so a future tweak to one branch cannot silently shift
        // the others.
        #expect(ContactSheetLayout.gap(forCount: 49) == 10)
        #expect(ContactSheetLayout.gap(forCount: 144) == 6)
    }

    @Test("tiles never overlap")
    func tilesDoNotOverlap() throws {
        let layout = try #require(ContactSheetLayout.layout(count: 20, in: panel))
        let first = ContactSheetLayout.rect(at: 0, layout: layout)
        let second = ContactSheetLayout.rect(at: 1, layout: layout)

        #expect(second.minX >= first.maxX)
    }

    @Test("a degenerate panel produces no layout rather than a zero-sized tile")
    func degeneratePanelHasNoLayout() {
        #expect(ContactSheetLayout.layout(count: 20, in: .zero) == nil)
        #expect(ContactSheetLayout.layout(count: 20, in: CGSize(width: 852, height: 0)) == nil)
    }
}
