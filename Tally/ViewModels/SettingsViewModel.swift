import Foundation
import SwiftData

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var incomeEvents: [IncomeEvent] = []
    @Published var fixedCosts: [FixedCost] = []
    @Published var thisMonthFixedCostTotal: Decimal = 0

    func refresh(context: ModelContext) {
        incomeEvents = (try? context.fetch(FetchDescriptor<IncomeEvent>())) ?? []
        fixedCosts = (try? context.fetch(FetchDescriptor<FixedCost>())) ?? []

        let today = Date()
        let fmStart = FinancialMonth.start(of: today)
        let fmEnd = FinancialMonth.end(of: today)
        let days = Decimal(FinancialMonth.datesInPeriod(from: fmStart, to: fmEnd).count)

        thisMonthFixedCostTotal = fixedCosts.reduce(0) { total, cost in
            total + BudgetCalculator.fixedCostContribution(for: cost, on: fmStart) * days
        }
    }

    private func notifyDataChanged() {
        NotificationCenter.default.post(name: .tallyDataChanged, object: nil)
    }

    func addIncome(_ event: IncomeEvent, context: ModelContext) {
        context.insert(event)
        if event.destination == .jar, let jarID = event.jarID {
            let jars = (try? context.fetch(FetchDescriptor<MoneyJar>())) ?? []
            if let jar = jars.first(where: { $0.persistentModelID.entityName == jarID }) {
                jar.balance += event.amount
            }
        }
        try? context.save()
        refresh(context: context)
        notifyDataChanged()
    }

    func deleteIncome(_ event: IncomeEvent, context: ModelContext) {
        context.delete(event)
        try? context.save()
        refresh(context: context)
        notifyDataChanged()
    }

    func addFixedCost(_ cost: FixedCost, context: ModelContext) {
        context.insert(cost)
        try? context.save()
        refresh(context: context)
        notifyDataChanged()
    }

    func deleteFixedCost(_ cost: FixedCost, context: ModelContext) {
        context.delete(cost)
        try? context.save()
        refresh(context: context)
        notifyDataChanged()
    }
}
