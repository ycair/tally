import Foundation
import SwiftData

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var todayAvailable: Decimal = 0
    @Published var todayBaseAmount: Decimal = 0
    @Published var todayPenalty: Decimal = 0
    @Published var todaySpent: Decimal = 0
    @Published var todayProgress: Double = 0
    @Published var dailyBudgets: [DailyBudget] = []
    @Published var expensesByDay: [Date: [Expense]] = [:]

    var context: ModelContext?

    func refresh() {
        guard let context = context else { return }
        let today = Date()
        settlePriorDays(context: context)

        let incomeEvents = fetchAll(IncomeEvent.self, context: context)
        let fixedCosts = fetchAll(FixedCost.self, context: context)
        let expenses = fetchAll(Expense.self, context: context)

        let result = BudgetCalculator.computeDaily(
            incomeEvents: incomeEvents, fixedCosts: fixedCosts,
            expenses: expenses, today: today)

        todayBaseAmount = result.baseAmount
        todayPenalty = result.penalty
        todaySpent = result.spent
        todayAvailable = result.available
        todayProgress = BudgetCalculator.progress(
            baseAmount: result.baseAmount, penalty: result.penalty, spent: result.spent)

        let fmStart = FinancialMonth.start(of: today)
        let fmEnd = FinancialMonth.end(of: today)
        let allDays = FinancialMonth.datesInPeriod(from: fmStart, to: fmEnd)

        dailyBudgets = allDays.compactMap { day in
            let descriptor = FetchDescriptor<DailyBudget>(
                predicate: #Predicate { $0.date == day })
            return (try? context.fetch(descriptor).first) ?? DailyBudget(date: day)
        }.filter { $0.date <= today }

        let dayExpenses = expenses.filter { $0.source == .dailyBudget }
        expensesByDay = Dictionary(grouping: dayExpenses) {
            Calendar.current.startOfDay(for: $0.date)
        }
    }

    private func settlePriorDays(context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())
        let fmStart = FinancialMonth.start(of: today)
        let descriptor = FetchDescriptor<DailyBudget>(
            predicate: #Predicate { $0.date < today && $0.statusRaw == "" })
        guard let unsettled = try? context.fetch(descriptor) else { return }

        for budget in unsettled where budget.date >= fmStart {
            let dayExpenses = fetchExpenses(for: budget.date, context: context)
            let spent = dayExpenses.reduce(Decimal.zero) { $0 + $1.amount }
            let result = BudgetCalculator.settleDay(
                budget.date, baseAmount: budget.baseAmount, spent: spent)
            budget.spent = spent
            budget.leftover = result.leftover
            budget.status = result.status
            if result.savingsIncrement > 0 {
                let settings = AppSettings.fetchOrCreate(context: context)
                settings.savingsBalance += result.savingsIncrement
            }
        }
        try? context.save()
    }

    private func fetchAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    private func fetchExpenses(for date: Date, context: ModelContext) -> [Expense] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        var descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay })
        return (try? context.fetch(descriptor)) ?? []
    }
}
