import SwiftUI
import SwiftData

struct FixedCostFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amountText = ""
    @State private var type: FixedCostType = .monthly
    @State private var bankCode = ""
    @State private var accountNumber = ""
    @State private var hasDeposited = false
    @State private var dueMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var dueDay: Int = 1
    @State private var amortizeToMonthly = false
    @State private var startInstallment = 1
    @State private var endInstallment = 12
    @State private var reserveMode: ReserveMode = .notYetReserved

    var existingCost: FixedCost?
    var onSave: () -> Void
    let months = Array(1...12)

    var body: some View {
        NavigationStack {
            Form {
                Section("基本資訊") {
                    TextField("名稱", text: $name)
                    TextField("金額", text: $amountText).keyboardType(.decimalPad)
                    Picker("類型", selection: $type) {
                        ForEach(FixedCostType.allCases, id: \.self) { t in Text(t.label).tag(t) }
                    }
                }
                switch type {
                case .monthly: EmptyView()
                case .yearly:
                    Section("每年設定") {
                        Picker("月份", selection: $dueMonth) {
                            ForEach(months, id: \.self) { m in Text("\(m) 月").tag(m) }
                        }
                        Toggle("均攤至 12 個財務月", isOn: $amortizeToMonthly)
                    }
                case .installment:
                    Section("分期設定") {
                        Stepper("第 \(startInstallment) 期", value: $startInstallment, in: 1...60)
                        Stepper("共 \(endInstallment) 期", value: $endInstallment, in: 1...60)
                    }
                case .scheduled:
                    Section("預定扣款設定") {
                        Picker("月份", selection: $dueMonth) {
                            ForEach(months, id: \.self) { m in Text("\(m) 月").tag(m) }
                        }
                        Picker("日期", selection: $dueDay) {
                            ForEach(Array(1...31), id: \.self) { d in Text("\(d) 日").tag(d) }
                        }
                        Picker("預留模式", selection: $reserveMode) {
                            ForEach(ReserveMode.allCases, id: \.self) { m in Text(m.label).tag(m) }
                        }
                    }
                }
                Section("專款專用帳戶") {
                    TextField("銀行代碼", text: $bankCode)
                    TextField("帳號", text: $accountNumber)
                    Toggle("已存入", isOn: $hasDeposited)
                }
            }
            .navigationTitle(existingCost != nil ? "編輯固定花銷" : "新增固定花銷")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                        .disabled(name.isEmpty || amountText.isEmpty || bankCode.isEmpty || accountNumber.isEmpty)
                }
            }
            .onAppear {
                if let c = existingCost {
                    name = c.name; amountText = String(describing: c.amount); type = c.type
                    bankCode = c.bankCode; accountNumber = c.accountNumber; hasDeposited = c.hasDeposited
                    dueMonth = c.dueMonth ?? Calendar.current.component(.month, from: Date())
                    dueDay = c.dueDay ?? 1; amortizeToMonthly = c.amortizeToMonthly
                }
            }
        }
    }

    private func save() {
        guard let amount = Decimal(string: amountText) else { return }
        let cost = existingCost ?? FixedCost(name: name, amount: amount, type: type,
                                              bankCode: bankCode, accountNumber: accountNumber)
        cost.name = name; cost.amount = amount; cost.type = type
        cost.bankCode = bankCode; cost.accountNumber = accountNumber; cost.hasDeposited = hasDeposited
        cost.dueMonth = dueMonth; cost.dueDay = dueDay; cost.amortizeToMonthly = amortizeToMonthly
        cost.startMonth = startInstallment; cost.endMonth = endInstallment
        cost.reserveMode = type == .scheduled ? reserveMode : nil
        if existingCost == nil { context.insert(cost) }
        try? context.save()
        NotificationCenter.default.post(name: .tallyDataChanged, object: nil)
        onSave(); dismiss()
    }
}
