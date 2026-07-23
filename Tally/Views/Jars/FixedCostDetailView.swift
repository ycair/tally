import SwiftUI
import SwiftData

struct FixedCostDetailView: View {
    let cost: FixedCost
    @Environment(\.modelContext) private var context
    @State private var incomes: [IncomeEvent] = []
    @State private var expenses: [Expense] = []

    var body: some View {
        List {
            Section("存入進度") {
                HStack {
                    Text("已存入")
                    Spacer()
                    Text("\(formatted(cost.depositedAmount)) / \(formatted(cost.amount))")
                        .monospacedDigit()
                }
                HStack {
                    Text("狀態")
                    Spacer()
                    Text(cost.hasDeposited ? "已存" : "未存")
                        .foregroundColor(cost.hasDeposited ? TallyTheme.Colors.greenText : .orange)
                        .fontWeight(.medium)
                }
            }

            if !incomes.isEmpty {
                Section("存入記錄") {
                    ForEach(incomes) { income in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(income.name)
                                Text(income.date, style: .date).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("+\(formatted(income.amount))").foregroundColor(TallyTheme.Colors.greenText)
                        }
                    }
                }
            }

            if !expenses.isEmpty {
                Section("扣款記錄") {
                    ForEach(expenses) { expense in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(expense.name)
                                Text(expense.date, style: .date).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("-\(formatted(expense.amount))").foregroundColor(TallyTheme.Colors.redText)
                        }
                    }
                }
            }

            Section {
                Text("\(cost.bankCode) \(cost.accountNumber)")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .navigationTitle(cost.name)
        .onAppear { loadTransactions() }
    }

    private func loadTransactions() {
        let allIncomes = (try? context.fetch(FetchDescriptor<IncomeEvent>())) ?? []
        incomes = allIncomes.filter {
            $0.destination == .fixedCost &&
            ($0.fixedCostID == cost.uuid || $0.fixedCostID == cost.persistentModelID.entityName)
        }
        let allExpenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        expenses = allExpenses.filter {
            $0.source == .fixedCost &&
            ($0.fixedCostID == cost.uuid || $0.fixedCostID == cost.persistentModelID.entityName)
        }
    }

    private func formatted(_ v: Decimal) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .decimal; nf.maximumFractionDigits = 0
        return nf.string(from: v as NSDecimalNumber) ?? "0"
    }
}
