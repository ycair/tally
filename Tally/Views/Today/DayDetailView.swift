import SwiftUI
import SwiftData

struct DayDetailView: View {
    let date: Date
    @Environment(\.modelContext) private var context
    @State private var expenses: [Expense] = []

    var body: some View {
        List {
            if expenses.isEmpty { Text("這天沒有記錄").foregroundColor(.secondary) }
            ForEach(expenses) { expense in
                HStack {
                    VStack(alignment: .leading) {
                        Text(expense.name).font(.body)
                        Text(expense.date, style: .time).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("-\(formatted(expense.amount))").font(.body).monospacedDigit()
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        context.delete(expense); try? context.save(); loadExpenses()
                    } label: { Label("刪除", systemImage: "trash") }
                }
            }
        }
        .navigationTitle(dateLabel).navigationBarTitleDisplayMode(.inline)
        .onAppear { loadExpenses() }
    }

    private var dateLabel: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "M 月 d 日 EEEE"; return f.string(from: date)
    }

    private func loadExpenses() {
        let sod = Calendar.current.startOfDay(for: date)
        let eod = Calendar.current.date(byAdding: .day, value: 1, to: sod)!
        var d = FetchDescriptor<Expense>(predicate: #Predicate { $0.date >= sod && $0.date < eod })
        expenses = (try? context.fetch(d)) ?? []
    }

    private func formatted(_ v: Decimal) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .decimal; nf.maximumFractionDigits = 0
        return nf.string(from: v as NSDecimalNumber) ?? "0"
    }
}
