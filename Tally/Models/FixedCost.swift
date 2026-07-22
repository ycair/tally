import Foundation
import SwiftData

enum FixedCostType: String, Codable, CaseIterable {
    case monthly
    case yearly
    case installment
    case scheduled

    var label: String {
        switch self {
        case .monthly: return "每月"
        case .yearly: return "每年"
        case .installment: return "分期"
        case .scheduled: return "預定扣款"
        }
    }
}

enum ReserveMode: String, Codable, CaseIterable {
    case reserved = "reserved"
    case notYetReserved = "notYetReserved"
    case amortized = "amortized"

    var label: String {
        switch self {
        case .reserved: return "已預留"
        case .notYetReserved: return "尚未預留"
        case .amortized: return "均攤"
        }
    }
}

@Model
final class FixedCost {
    var name: String
    var amount: Decimal
    var typeRaw: String
    var startMonth: Int?
    var endMonth: Int?
    var dueMonth: Int?
    var dueDay: Int?
    var amortizeToMonthly: Bool
    var reserveModeRaw: String?
    var amortizeMonths: [Int]?
    var bankCode: String
    var accountNumber: String
    var hasDeposited: Bool

    var type: FixedCostType {
        get { FixedCostType(rawValue: typeRaw) ?? .monthly }
        set { typeRaw = newValue.rawValue }
    }

    var reserveMode: ReserveMode? {
        get { reserveModeRaw.flatMap(ReserveMode.init(rawValue:)) }
        set { reserveModeRaw = newValue?.rawValue }
    }

    init(name: String, amount: Decimal, type: FixedCostType,
         bankCode: String, accountNumber: String, hasDeposited: Bool = false,
         startMonth: Int? = nil, endMonth: Int? = nil,
         dueMonth: Int? = nil, dueDay: Int? = nil,
         amortizeToMonthly: Bool = false,
         reserveMode: ReserveMode? = nil, amortizeMonths: [Int]? = nil) {
        self.name = name
        self.amount = amount
        self.typeRaw = type.rawValue
        self.bankCode = bankCode
        self.accountNumber = accountNumber
        self.hasDeposited = hasDeposited
        self.startMonth = startMonth
        self.endMonth = endMonth
        self.dueMonth = dueMonth
        self.dueDay = dueDay
        self.amortizeToMonthly = amortizeToMonthly
        self.reserveModeRaw = reserveMode?.rawValue
        self.amortizeMonths = amortizeMonths
    }
}
