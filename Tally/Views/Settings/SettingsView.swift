import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var vm = SettingsViewModel()
    @State private var showIncomeForm = false
    @State private var showFixedCostForm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(vm.incomeEvents) { event in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(event.name).font(.body)
                                Text(fmtDate(event.date)).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("+\(fmt(event.amount))")
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                vm.deleteIncome(event, context: context)
                            } label: { Label("刪除", systemImage: "trash") }
                        }
                    }
                    Button { showIncomeForm = true } label: {
                        Label("新增收入", systemImage: "plus")
                    }
                } header: { Text("收入記錄 (\(vm.incomeEvents.count) 筆)") }

                Section {
                    ForEach(vm.fixedCosts) { cost in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(cost.name).font(.body)
                                Spacer()
                                Text("-\(fmt(cost.amount))")
                            }
                            HStack(spacing: 4) {
                                Text(cost.type.label)
                                Text("·")
                                Text(cost.bankCode)
                                Text("·")
                                Text(cost.hasDeposited ? "已存" : "未存")
                                    .foregroundColor(cost.hasDeposited ? TallyTheme.Colors.greenText : .orange)
                                    .fontWeight(.medium)
                            }
                            .font(.caption).foregroundColor(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                vm.deleteFixedCost(cost, context: context)
                            } label: { Label("刪除", systemImage: "trash") }
                        }
                    }
                    Button { showFixedCostForm = true } label: {
                        Label("新增固定花銷", systemImage: "plus")
                    }
                } header: { Text("固定花銷 (\(vm.fixedCosts.count) 筆) · 本月合計 -\(fmt(vm.thisMonthFixedCostTotal))") }

                Section {
                    NavigationLink { ReconciliationView() } label: {
                        HStack {
                            Text("存款對賬")
                            Spacer()
                            let s = AppSettings.fetchOrCreate(context: context)
                            if let last = s.reconciliationHistory.last {
                                Text(fmtDate(last.date)).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    HStack { Text("財務月週期"); Spacer(); Text("每月 15 日起").foregroundColor(.secondary) }
                    HStack { Text("資料儲存"); Spacer(); Text("僅本機").foregroundColor(.secondary) }
                }
            }
            .navigationTitle("設定")
            .sheet(isPresented: $showIncomeForm) { IncomeFormView { vm.refresh(context: context) } }
            .sheet(isPresented: $showFixedCostForm) { FixedCostFormView { vm.refresh(context: context) } }
            .onAppear { vm.refresh(context: context) }
        }
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
