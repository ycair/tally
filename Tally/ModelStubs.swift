import Foundation
import SwiftData

// MARK: - Stubs (replaced by Task 2)

@Model final class Expense {
    var name: String = ""; var amount: Decimal = 0; var date: Date = Date()
    init() {}
}

@Model final class LineItem {
    var name: String = ""; var amount: Decimal = 0
    init() {}
}

@Model final class FixedCost {
    var name: String = ""; var amount: Decimal = 0
    init() {}
}

@Model final class IncomeEvent {
    var name: String = ""; var amount: Decimal = 0; var date: Date = Date()
    init() {}
}

@Model final class MoneyJar {
    var name: String = ""; var bankCode: String = ""; var accountNumber: String = ""; var balance: Decimal = 0
    init() {}
}

@Model final class DailyBudget {
    var date: Date = Date(); var baseAmount: Decimal = 0; var penalty: Decimal = 0
    var spent: Decimal = 0; var leftover: Decimal = 0; var statusRaw: String = ""
    init() {}
}

@Model final class AppSettings {
    @Attribute(.unique) var id: String = "singleton"; var savingsBalance: Decimal = 0
    init() {}
}
