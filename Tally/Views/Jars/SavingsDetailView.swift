import SwiftUI
import SwiftData

struct SavingsDetailView: View {
    @Environment(\.modelContext) private var context
    @State private var greenDays: [DailyBudget] = []
    @State private var totalSavings: Decimal = 0

    var body: some View {
        List {
            Section("累積存款") {
                HStack {
                    Text("總存款")
                    Spacer()
                    Text("NT$ \(formatted(totalSavings))").font(.title2).monospacedDigit()
                }
            }

            if greenDays.isEmpty {
                Text("尚無記錄").foregroundColor(.secondary)
            } else {
                Section("每日存入記錄") {
                    ForEach(greenDays.reversed()) { day in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(fmtDate(day.date))
                                Text("額度 \(formatted(day.baseAmount)) · 花費 \(formatted(day.spent))")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("+\(formatted(day.leftover))")
                                .foregroundColor(TallyTheme.Colors.greenText)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .navigationTitle("存款")
        .onAppear { loadData() }
    }

    private func loadData() {
        let settings = AppSettings.fetchOrCreate(context: context)
        totalSavings = settings.savingsBalance

        let fmStart = FinancialMonth.start(of: Date())
        let descriptor = FetchDescriptor<DailyBudget>(
            predicate: #Predicate { $0.statusRaw == "green" && $0.leftover > 0 && $0.date >= fmStart })
        greenDays = (try? context.fetch(descriptor)) ?? []
    }

    private func formatted(_ v: Decimal) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .decimal; nf.maximumFractionDigits = 0
        return nf.string(from: v as NSDecimalNumber) ?? "0"
    }

    private func fmtDate(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "M/d EEE"; return f.string(from: d)
    }
}
