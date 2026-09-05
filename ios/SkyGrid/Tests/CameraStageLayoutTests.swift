import CoreGraphics
import Testing
@testable import SkyGrid

@Suite("CameraStageLayout")
struct CameraStageLayoutTests {
    @Test("iPhone viewfinder remains inset and vertically dominant")
    func phoneViewfinderIsInset() {
        let container = CGSize(width: 402, height: 874)
        let size = CameraStageLayout.viewfinderSize(
            in: container,
            safeVerticalInsets: 93
        )

        #expect(size.width == container.width - CameraStageLayout.horizontalInset * 2)
        #expect(size.width < container.width)
        #expect(size.height > size.width)
        #expect(size.height <= (container.height - 93) * CameraStageLayout.maximumSafeHeightFraction)
    }

    @Test("large screens retain a bounded camera window")
    func largeScreenIsBounded() {
        let size = CameraStageLayout.viewfinderSize(
            in: CGSize(width: 1_024, height: 1_366),
            safeVerticalInsets: 48
        )

        #expect(size.width == CameraStageLayout.maximumViewfinderWidth)
        #expect(size.height == size.width * CameraStageLayout.viewfinderHeightToWidth)
    }

    @Test("degenerate containers never produce negative geometry")
    func degenerateContainerIsSafe() {
        let size = CameraStageLayout.viewfinderSize(
            in: CGSize(width: 20, height: 20),
            safeVerticalInsets: 40
        )

        #expect(size == .zero)
    }
}
