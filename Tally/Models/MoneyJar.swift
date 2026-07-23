import Foundation
import SwiftData

@Model
final class MoneyJar {
    var name: String
    var bankCode: String
    var accountNumber: String
    var balance: Decimal
    var createdAt: Date
    var uuid: String = UUID().uuidString

    init(name: String, bankCode: String, accountNumber: String,
         balance: Decimal = 0, createdAt: Date = Date()) {
        self.name = name
        self.bankCode = bankCode
        self.accountNumber = accountNumber
        self.balance = balance
        self.createdAt = createdAt
    }
}
