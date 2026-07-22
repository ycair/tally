import Foundation
import SwiftData

enum IncomeDestination: String, Codable, CaseIterable {
    case budget
    case jar

    var label: String {
        switch self {
        case .budget: return "均攤至本月額度"
        case .jar: return "存入零錢罐"
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

    var destination: IncomeDestination {
        get { IncomeDestination(rawValue: destinationRaw) ?? .budget }
        set { destinationRaw = newValue.rawValue }
    }

    init(name: String, amount: Decimal, date: Date = Date(),
         destination: IncomeDestination = .budget, jarID: String? = nil) {
        self.name = name
        self.amount = amount
        self.date = date
        self.destinationRaw = destination.rawValue
        self.jarID = jarID
    }
}
