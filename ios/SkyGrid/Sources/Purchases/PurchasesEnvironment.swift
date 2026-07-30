import SwiftUI

private struct PurchasesServicingKey: EnvironmentKey {
    static let defaultValue: any PurchasesServicing = UnconfiguredPurchasesService()
}

extension EnvironmentValues {
    var purchases: any PurchasesServicing {
        get { self[PurchasesServicingKey.self] }
        set { self[PurchasesServicingKey.self] = newValue }
    }
}
