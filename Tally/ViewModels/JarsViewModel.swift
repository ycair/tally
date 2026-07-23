import Foundation
import SwiftData

@MainActor
final class JarsViewModel: ObservableObject {
    @Published var jars: [MoneyJar] = []
    @Published var totalBalance: Decimal = 0
    @Published var savingsBalance: Decimal = 0
    @Published var fixedCosts: [FixedCost] = []

    func refresh(context: ModelContext) {
        jars = (try? context.fetch(FetchDescriptor<MoneyJar>())) ?? []
        totalBalance = jars.reduce(0) { $0 + $1.balance }
        savingsBalance = AppSettings.fetchOrCreate(context: context).savingsBalance
        fixedCosts = (try? context.fetch(FetchDescriptor<FixedCost>())) ?? []
    }

    func createJar(name: String, bankCode: String, accountNumber: String, context: ModelContext) {
        let jar = MoneyJar(name: name, bankCode: bankCode, accountNumber: accountNumber)
        context.insert(jar)
        try? context.save()
        refresh(context: context)
    }

    func deleteJar(_ jar: MoneyJar, context: ModelContext) {
        context.delete(jar)
        try? context.save()
        refresh(context: context)
    }
}
