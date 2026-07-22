import Foundation
import SwiftData

enum DayStatus: String, Codable {
    case green
    case white
    case red

    var label: String {
        switch self {
        case .green: return "有剩餘"
        case .white: return "打平"
        case .red: return "超支"
        }
    }
}

@Model
final class DailyBudget {
    var date: Date
    var baseAmount: Decimal
    var penalty: Decimal
    var spent: Decimal
    var leftover: Decimal
    var statusRaw: String

    var status: DayStatus {
        get { DayStatus(rawValue: statusRaw) ?? .white }
        set { statusRaw = newValue.rawValue }
    }

    init(date: Date, baseAmount: Decimal = 0, penalty: Decimal = 0,
         spent: Decimal = 0, leftover: Decimal = 0, status: DayStatus = .white) {
        self.date = date
        self.baseAmount = baseAmount
        self.penalty = penalty
        self.spent = spent
        self.leftover = leftover
        self.statusRaw = status.rawValue
    }
}
