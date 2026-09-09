import RevenueCat
import Testing
@testable import SkyGrid

@Suite("RevenueCat catalog mapping")
struct RevenueCatServiceTests {
    @Test("custom packages retain only the approved Sky Grid products")
    func customPackageUsesCanonicalProductID() {
        #expect(RevenueCatService.period(
            for: .custom,
            productID: "com.takmin.skygrid.pro.monthly"
        ) == .monthly)
        #expect(RevenueCatService.period(
            for: .custom,
            productID: "com.takmin.skygrid.pro.annual"
        ) == .annual)
        #expect(RevenueCatService.period(
            for: .custom,
            productID: "com.takmin.skygrid.pro.lifetime"
        ) == .lifetime)
        #expect(RevenueCatService.period(
            for: .monthly,
            productID: RevenueCatConfig.secondChanceProductID
        ) == .monthly)
        #expect(RevenueCatService.period(
            for: .custom,
            productID: "com.takmin.skygrid.unapproved"
        ) == .unknown)
    }

    @Test("a non-supported predefined package cannot be relabelled as a paid plan")
    func weeklyPackageIsNeverIncluded() {
        #expect(RevenueCatService.period(
            for: .weekly,
            productID: "com.takmin.skygrid.pro.monthly"
        ) == .unknown)
    }
}
