import Foundation

extension Decimal {
    func roundedDecimal(_ scale: Int) -> Decimal {
        var selfVar = self
        var result = Decimal()
        NSDecimalRound(&result, &selfVar, scale, .plain)
        return result
    }
}

enum BudgetCalculator {

    static func distribute(amount: Decimal, across days: [Date]) -> [(Date, Decimal)] {
        guard !days.isEmpty else { return [] }
        let count = Decimal(days.count)
        let perDay = (amount / count).roundedDecimal(0)
        let total = perDay * count
        let remainder = amount - total
        return days.enumerated().map { i, date in
            (date, i == 0 ? perDay + remainder : perDay)
        }
    }

    static func fixedCostContribution(for cost: FixedCost, on date: Date) -> Decimal {
        let start = FinancialMonth.start(of: date)
        let end = FinancialMonth.end(of: date)
        let allDays = FinancialMonth.datesInPeriod(from: start, to: end)
        let dayCount = Decimal(allDays.count)
        guard dayCount > 0 else { return 0 }

        switch cost.type {
        case .monthly:
            return cost.amount / dayCount

        case .yearly:
            guard cost.amortizeToMonthly else {
                guard let dueMonth = cost.dueMonth else { return 0 }
                let calendar = Calendar.current
                let dueDate = calendar.date(from: DateComponents(year: calendar.component(.year, from: date), month: dueMonth, day: cost.dueDay ?? 1))!
                let dueFMStart = FinancialMonth.start(of: dueDate)
                return start == dueFMStart ? cost.amount / dayCount : 0
            }
            return (cost.amount / 12) / dayCount

        case .installment:
            guard let startMonth = cost.startMonth, let endMonth = cost.endMonth else { return 0 }
            let calendar = Calendar.current
            let currentMonth = calendar.component(.month, from: date)
            if startMonth <= endMonth {
                guard (startMonth...endMonth).contains(currentMonth) else { return 0 }
            } else {
                guard currentMonth >= startMonth || currentMonth <= endMonth else { return 0 }
            }
            return cost.amount / dayCount

        case .scheduled:
            guard let reserveMode = cost.reserveMode, let dueMonth = cost.dueMonth else { return 0 }
            let fmMonth = FinancialMonth.calendar.component(.month, from: start)
            switch reserveMode {
            case .reserved, .notYetReserved:
                let inRange = fmMonth == dueMonth || (fmMonth - 1 == dueMonth &&
                    FinancialMonth.calendar.component(.day, from: date) < 15)
                return inRange ? cost.amount / dayCount : 0
            case .amortized:
                let months = cost.amortizeMonths ?? []
                return months.contains(fmMonth) ? (cost.amount / Decimal(months.count)) / dayCount : 0
            }
        }
    }

    static func computeDaily(
        incomeEvents: [IncomeEvent],
        fixedCosts: [FixedCost],
        expenses: [Expense],
        today: Date
    ) -> (baseAmount: Decimal, penalty: Decimal, spent: Decimal, available: Decimal) {
        var baseAmount: Decimal = 0

        for event in incomeEvents where event.destination == .budget {
            if event.date > today { continue }
            let remaining = FinancialMonth.remainingDays(from: event.date)
            let totalDays = Decimal(remaining.count)
            guard totalDays > 0 else { continue }
            let perDay = (event.amount / totalDays).roundedDecimal(0)
            baseAmount += perDay
        }

        for cost in fixedCosts {
            baseAmount -= fixedCostContribution(for: cost, on: today)
        }

        let calendar = Calendar.current
        let spent = expenses
            .filter { calendar.isDate($0.date, inSameDayAs: today) && $0.source == .dailyBudget }
            .reduce(Decimal.zero) { $0 + $1.amount }

        let penalty = computePenalty(today: today)
        let available = baseAmount - penalty - spent
        return (baseAmount, penalty, spent, available)
    }

    static func computePenalty(today: Date) -> Decimal {
        return 0
    }

    static func settleDay(_ date: Date, baseAmount: Decimal, spent: Decimal)
        -> (leftover: Decimal, status: DayStatus, savingsIncrement: Decimal) {
        let leftover = baseAmount - spent
        if leftover > 0 {
            return (leftover, .green, leftover)
        } else if leftover == 0 {
            return (0, .white, 0)
        } else {
            return (leftover, .red, 0)
        }
    }

    static func progress(baseAmount: Decimal, penalty: Decimal, spent: Decimal) -> Double {
        let denominator = baseAmount - penalty
        guard denominator > 0 else { return 1.0 }
        let ratio = spent / denominator
        return Double(truncating: max(0, min(1, ratio)) as NSDecimalNumber)
    }
}
