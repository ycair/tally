import SwiftUI

struct DayCardView: View {
    let budget: DailyBudget
    let expenses: [Expense]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayLabel).font(.subheadline).fontWeight(.medium)
                Spacer()
                Text(statusLabel).font(.caption).foregroundColor(statusColor)
            }
            ForEach(expenses.prefix(3)) { expense in
                HStack {
                    Text(expense.name).font(.subheadline)
                    Spacer()
                    Text("-\(formatted(expense.amount))").font(.subheadline).monospacedDigit()
                }
            }
            if expenses.count > 3 {
                Text("還有 \(expenses.count - 3) 筆...").font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(TallyTheme.Spacing.md)
        .dayCardStyle(status: budget.status)
    }

    private var dayLabel: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "M/d EEE"; return f.string(from: budget.date)
    }

    private var statusLabel: String {
        switch budget.status {
        case .green: return "餘額 +\(formatted(abs(budget.leftover)))"
        case .white: return "打平"
        case .red: return "超支 \(formatted(abs(budget.leftover)))"
        }
    }

    private var statusColor: Color {
        switch budget.status {
        case .green: return TallyTheme.Colors.greenText
        case .white: return .secondary
        case .red: return TallyTheme.Colors.redText
        }
    }

    private func formatted(_ v: Decimal) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .decimal; nf.maximumFractionDigits = 0
        return nf.string(from: v as NSDecimalNumber) ?? "0"
    }
}
