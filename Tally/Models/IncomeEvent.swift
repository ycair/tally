import Foundation
import SwiftData

enum IncomeDestination: String, Codable, CaseIterable {
    case budget
    case jar
    case fixedCost

    var label: String {
        switch self {
        case .budget: return "均攤至本月額度"
        case .jar: return "存入零錢罐"
        case .fixedCost: return "存入固定花銷專戶"
        }
    }
}

@Model
final class IncomeEvent {
    var name: String
    var amount: Decimal
    var date: Date
    var destinationRaw: String
    var jarID: String?
    var fixedCostID: String?

    var destination: IncomeDestination {
        get { IncomeDestination(rawValue: destinationRaw) ?? .budget }
        set { destinationRaw = newValue.rawValue }
    }

    init(name: String, amount: Decimal, date: Date = Date(),
         destination: IncomeDestination = .budget, jarID: String? = nil,
         fixedCostID: String? = nil) {
        self.name = name
        self.amount = amount
        self.date = date
        self.destinationRaw = destination.rawValue
        self.jarID = jarID
        self.fixedCostID = fixedCostID
    }
}
