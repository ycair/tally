import Foundation
import SwiftData

@MainActor
final class ReconciliationViewModel: ObservableObject {
    @Published var savingsSystemBalance: Decimal = 0
    @Published var savingsActualText: String = ""
    @Published var jars: [MoneyJar] = []
    @Published var jarActualTexts: [String: String] = [:]
    @Published var lastReconciliation: ReconciliationRecord?

    func refresh(context: ModelContext) {
        let settings = AppSettings.fetchOrCreate(context: context)
        savingsSystemBalance = settings.savingsBalance
        lastReconciliation = settings.reconciliationHistory.last

        jars = (try? context.fetch(FetchDescriptor<MoneyJar>())) ?? []
        for jar in jars {
            if jarActualTexts[jar.persistentModelID.entityName] == nil {
                jarActualTexts[jar.persistentModelID.entityName] = ""
            }
        }
    }

    func confirm(context: ModelContext) {
        let settings = AppSettings.fetchOrCreate(context: context)
        let now = Date()
        let savingsActual = Decimal(string: savingsActualText) ?? 0

        let savingsRecord = ReconciliationRecord(
            date: now, type: "\u{5B58}\u{6B3E}",
            systemBalance: savingsSystemBalance,
            actualBalance: savingsActual,
            difference: savingsActual - savingsSystemBalance,
            isMatched: savingsActual == savingsSystemBalance)
        settings.reconciliationHistory.append(savingsRecord)
        settings.verifiedSavingsBalance = savingsActual
        settings.lastVerifiedDate = now

        for jar in jars {
            let jarID = jar.persistentModelID.entityName
            let actual = Decimal(string: jarActualTexts[jarID] ?? "") ?? 0
            let record = ReconciliationRecord(
                date: now, type: jar.name,
                systemBalance: jar.balance,
                actualBalance: actual,
                difference: actual - jar.balance,
                isMatched: actual == jar.balance)
            settings.reconciliationHistory.append(record)
        }
        try? context.save()
    }
}
