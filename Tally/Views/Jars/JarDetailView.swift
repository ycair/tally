import SwiftUI
import SwiftData

struct JarDetailView: View {
    let jar: MoneyJar
    @Environment(\.modelContext) private var context
    @State private var incomes: [IncomeEvent] = []
    @State private var expenses: [Expense] = []
    @State private var showEdit = false
    @State private var editName = ""
    @State private var editBankCode = ""
    @State private var editAccount = ""

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

            Section {
                Button("編輯罐子") {
                    editName = jar.name
                    editBankCode = jar.bankCode
                    editAccount = jar.accountNumber
                    showEdit = true
                }
            }
        }
        .navigationTitle(jar.name)
        .onAppear { loadTransactions() }
        .alert("編輯零錢罐", isPresented: $showEdit) {
            TextField("名稱", text: $editName)
            TextField("銀行代碼", text: $editBankCode)
            TextField("帳號", text: $editAccount)
            Button("取消", role: .cancel) {}
            Button("儲存") {
                jar.name = editName
                jar.bankCode = editBankCode
                jar.accountNumber = editAccount
                try? context.save()
            }
        }
    }

    private func loadTransactions() {
        let allIncomes = (try? context.fetch(FetchDescriptor<IncomeEvent>())) ?? []
        incomes = allIncomes.filter { $0.destination == .jar && $0.jarID == jar.uuid }
        let allExpenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        expenses = allExpenses.filter { $0.source == .jar && $0.jarID == jar.uuid }
    }

    private func formatted(_ v: Decimal) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .decimal; nf.maximumFractionDigits = 0
        return nf.string(from: v as NSDecimalNumber) ?? "0"
    }
}
