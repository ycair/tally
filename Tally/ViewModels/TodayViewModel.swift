import Foundation
import SwiftData

extension Notification.Name {
    static let tallyDataChanged = Notification.Name("tallyDataChanged")
}

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var todayAvailable: Decimal = 0
    @Published var todayBaseAmount: Decimal = 0
    @Published var todayPenalty: Decimal = 0
    @Published var todaySpent: Decimal = 0
    @Published var todayProgress: Double = 0
    @Published var dailyBudgets: [DailyBudget] = []
    @Published var expensesByDay: [Date: [Expense]] = [:]
    @Published var savingsBalance: Decimal = 0
    @Published var monthDaysRemaining: Int = 0
    @Published var monthTotalDays: Int = 0

    var context: ModelContext?
    private var observer: NSObjectProtocol?

    func startObserving() {
        observer = NotificationCenter.default.addObserver(
            forName: .tallyDataChanged, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stopObserving() {
        if let ob = observer { NotificationCenter.default.removeObserver(ob) }
        observer = nil
    }

    func refresh() {
        guard let context = context else { return }
        let today = Date()
        let fmStart = FinancialMonth.start(of: today)
        let fmEnd = FinancialMonth.end(of: today)
        settlePriorDays(context: context)

        let incomeEvents = fetchAll(IncomeEvent.self, context: context)
        let fixedCosts = fetchAll(FixedCost.self, context: context)
        let expenses = fetchExpensesInRange(from: fmStart, to: fmEnd, context: context)

        let result = BudgetCalculator.computeDaily(
            incomeEvents: incomeEvents, fixedCosts: fixedCosts,
            expenses: expenses, today: today)

        todayBaseAmount = result.baseAmount
        todayPenalty = result.penalty
        todaySpent = result.spent
        todayAvailable = result.available
        todayProgress = BudgetCalculator.progress(
            baseAmount: result.baseAmount, penalty: result.penalty, spent: result.spent)

        let allDays = FinancialMonth.datesInPeriod(from: fmStart, to: fmEnd)
        let existing = fetchBudgetsInRange(from: fmStart, to: fmEnd, context: context)
        let existingMap = Dictionary(uniqueKeysWithValues: existing.map { ($0.date, $0) })

        dailyBudgets = allDays.compactMap { day in
            if let budget = existingMap[day] {
                return budget
            }
            let newBudget = DailyBudget(date: day)
            context.insert(newBudget)
            try? context.save()
            return newBudget
        }.filter { $0.date <= today }

        let dayExpenses = expenses.filter { $0.source == .dailyBudget }
        expensesByDay = Dictionary(grouping: dayExpenses) {
            Calendar.current.startOfDay(for: $0.date)
        }

        if let todayBudget = dailyBudgets.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: today)
        }) {
            todayBudget.baseAmount = todayBaseAmount
            todayBudget.penalty = todayPenalty
            todayBudget.spent = todaySpent
            try? context.save()
        }

        savingsBalance = AppSettings.fetchOrCreate(context: context).savingsBalance
        monthTotalDays = allDays.count
        monthDaysRemaining = allDays.filter { $0 >= Calendar.current.startOfDay(for: today) }.count
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

    private func fetchExpensesInRange(from start: Date, to end: Date, context: ModelContext) -> [Expense] {
        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { $0.date >= start && $0.date <= end })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchBudgetsInRange(from start: Date, to end: Date, context: ModelContext) -> [DailyBudget] {
        let descriptor = FetchDescriptor<DailyBudget>(
            predicate: #Predicate { $0.date >= start && $0.date <= end })
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchExpenses(for date: Date, context: ModelContext) -> [Expense] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay })
        return (try? context.fetch(descriptor)) ?? []
    }
}
