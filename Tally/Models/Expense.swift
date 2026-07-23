import Foundation
import SwiftData

enum ExpenseSource: String, Codable, CaseIterable {
    case dailyBudget
    case jar

    var label: String {
        switch self {
        case .dailyBudget: return "每日額度"
        case .jar: return "零錢罐"
        }
    }
}

@Model
final class Expense {
    var name: String
    var amount: Decimal
    var date: Date
    var receiptNumber: String?
    var location: String?
    var sourceRaw: String
    var jarID: String?

    @Relationship(deleteRule: .cascade, inverse: \LineItem.parent)
    var lineItems: [LineItem] = []

    var source: ExpenseSource {
        get { ExpenseSource(rawValue: sourceRaw) ?? .dailyBudget }
        set { sourceRaw = newValue.rawValue }
    }

    var lineItemsTotal: Decimal {
        lineItems.isEmpty ? amount : lineItems.reduce(0) { $0 + $1.amount }
    }

    init(name: String, amount: Decimal, date: Date = Date(),
         receiptNumber: String? = nil, location: String? = nil,
         source: ExpenseSource = .dailyBudget, jarID: String? = nil) {
        self.name = name
        self.amount = amount
        self.date = date
        self.receiptNumber = receiptNumber
        self.location = location
        self.sourceRaw = source.rawValue
        self.jarID = jarID
    }
}

@Model
final class LineItem {
    var name: String
    var amount: Decimal
    var parent: Expense?

    init(name: String, amount: Decimal, parent: Expense? = nil) {
        self.name = name
        self.amount = amount
        self.parent = parent
    }
}
