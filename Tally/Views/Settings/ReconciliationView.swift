import SwiftUI
import SwiftData

struct ReconciliationView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var vm = ReconciliationViewModel()

    var body: some View {
        Form {
            Section("存款（每日剩餘自動累積）") {
                HStack { Text("系統計算"); Spacer(); Text("NT$ \(fmt(vm.savingsSystemBalance))") }
                HStack {
                    Text("實際餘額")
                    TextField("NT$ 0", text: $vm.savingsActualText)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
            }

            Section("零錢罐") {
                ForEach(vm.jars) { jar in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(jar.name).font(.subheadline)
                        HStack {
                            Text("系統：NT$ \(fmt(jar.balance))")
                            Text("實際：")
                            TextField("NT$ 0", text: binding(for: jar)).keyboardType(.decimalPad)
                        }.font(.caption)
                    }
                }
            }

            Section {
                Button { vm.confirm(context: context) } label: {
                    Text("全部確認對賬").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent)
            }

            Section("對賬歷史") {
                let s = AppSettings.fetchOrCreate(context: context)
                ForEach(s.reconciliationHistory.reversed()) { record in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(record.type).font(.caption)
                            Text(fmtDate(record.date)).font(.caption2).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(record.isMatched ? "✓ 一致" : "✗ 差 \(fmt(record.difference))")
                            .font(.caption)
                            .foregroundColor(record.isMatched ? TallyTheme.Colors.greenText : TallyTheme.Colors.redText)
                    }
                }
            }
        }
        .navigationTitle("對賬")
        .onAppear { vm.refresh(context: context) }
    }

    private func binding(for jar: MoneyJar) -> Binding<String> {
        Binding(get: { vm.jarActualTexts[jar.persistentModelID.entityName] ?? "" },
                set: { vm.jarActualTexts[jar.persistentModelID.entityName] = $0 })
    }

    private func fmt(_ v: Decimal) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .decimal; nf.maximumFractionDigits = 0
        return nf.string(from: v as NSDecimalNumber) ?? "0"
    }
    private func fmtDate(_ d: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_TW"); f.dateFormat = "M/d"
        return f.string(from: d)
    }
}
