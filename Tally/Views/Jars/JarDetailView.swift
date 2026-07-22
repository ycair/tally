import SwiftUI
import SwiftData

struct JarDetailView: View {
    let jar: MoneyJar
    @Environment(\.modelContext) private var context
    @State private var incomes: [IncomeEvent] = []
    @State private var expenses: [Expense] = []

    var body: some View {
        List {
            Section("餘額") {
                Text("NT$ \(formatted(jar.balance))").font(TallyTheme.Typography.titleAmount)
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
                Section("支出記錄") {
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
        }
        .navigationTitle(jar.name)
        .onAppear { loadTransactions() }
    }

    private func loadTransactions() {
        let allIncomes = (try? context.fetch(FetchDescriptor<IncomeEvent>())) ?? []
        incomes = allIncomes.filter { $0.destination == .jar && $0.jarID == jar.persistentModelID.entityName }
        let allExpenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        expenses = allExpenses.filter { $0.source == .jar && $0.jarID == jar.persistentModelID.entityName }
    }

    private func formatted(_ v: Decimal) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .decimal; nf.maximumFractionDigits = 0
        return nf.string(from: v as NSDecimalNumber) ?? "0"
    }
}
