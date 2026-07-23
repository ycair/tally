import SwiftUI
import SwiftData

struct IncomeFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amountText = ""
    @State private var date = Date()
    @State private var destination: IncomeDestination = .budget
    @State private var selectedJar: MoneyJar?
    @State private var selectedFixedCost: FixedCost?
    @State private var availableJars: [MoneyJar] = []
    @State private var availableFixedCosts: [FixedCost] = []
    @State private var showAlreadyDepositedAlert = false

    var existingEvent: IncomeEvent?
    var onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("名稱（例：薪資）", text: $name)
                TextField("金額", text: $amountText).keyboardType(.decimalPad)
                DatePicker("日期", selection: $date, displayedComponents: .date)
                Picker("存入目標", selection: $destination) {
                    ForEach(IncomeDestination.allCases, id: \.self) { d in Text(d.label).tag(d) }
                }
                if destination == .jar {
                    Picker("零錢罐", selection: $selectedJar) {
                        Text("選擇").tag(nil as MoneyJar?)
                        ForEach(availableJars) { Text($0.name).tag($0 as MoneyJar?) }
                    }
                }
                if destination == .fixedCost {
                    Picker("固定花銷", selection: $selectedFixedCost) {
                        Text("選擇").tag(nil as FixedCost?)
                        ForEach(availableFixedCosts) { cost in
                            Text(cost.name).tag(cost as FixedCost?)
                        }
                    }
                }
            }
            .navigationTitle(existingEvent != nil ? "編輯收入" : "新增收入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        if destination == .fixedCost, let cost = selectedFixedCost, cost.hasDeposited {
                            showAlreadyDepositedAlert = true
                        } else {
                            performSave()
                        }
                    }
                    .disabled(name.isEmpty || amountText.isEmpty)
                }
            }
            .alert("已存入", isPresented: $showAlreadyDepositedAlert) {
                Button("仍要存入") { performSave() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("「\(selectedFixedCost?.name ?? "")」本月已存入，是否仍要存入？")
            }
            .onAppear {
                availableJars = (try? context.fetch(FetchDescriptor<MoneyJar>())) ?? []
                availableFixedCosts = (try? context.fetch(FetchDescriptor<FixedCost>())) ?? []
                if let e = existingEvent {
                    name = e.name; amountText = String(describing: e.amount)
                    date = e.date; destination = e.destination
                    if e.destination == .jar, let jid = e.jarID {
                        selectedJar = availableJars.first { $0.uuid == jid }
                    }
                    if e.destination == .fixedCost, let cid = e.fixedCostID {
                        selectedFixedCost = availableFixedCosts.first { $0.uuid == cid }
                    }
                }
            }
        }
    }

    private func performSave() {
        guard let amount = Decimal(string: amountText) else { return }
        let event = existingEvent ?? IncomeEvent(name: name, amount: amount, date: date, destination: destination)
        if existingEvent == nil { context.insert(event) }

        // Reverse old destination if editing
        if let oldEvent = existingEvent {
            let oldAmount = oldEvent.amount
            switch oldEvent.destination {
            case .jar:
                if let oldJarID = oldEvent.jarID {
                    let jars = (try? context.fetch(FetchDescriptor<MoneyJar>())) ?? []
                    if let oldJar = jars.first(where: { $0.uuid == oldJarID }) {
                        oldJar.balance -= oldAmount
                    }
                }
            case .fixedCost:
                if let oldCostID = oldEvent.fixedCostID {
                    let costs = (try? context.fetch(FetchDescriptor<FixedCost>())) ?? []
                    if let oldCost = costs.first(where: { $0.uuid == oldCostID }) {
                        oldCost.depositedAmount -= oldAmount
                    }
                }
            case .budget: break
            }
        }

        switch destination {
        case .jar:
            if let jar = selectedJar {
                event.jarID = jar.uuid
                event.fixedCostID = nil
                jar.balance += amount
            }
        case .fixedCost:
            if let cost = selectedFixedCost {
                event.jarID = nil
                event.fixedCostID = cost.uuid
                cost.depositedAmount += amount
                cost.hasDeposited = true
            }
        case .budget:
            event.jarID = nil
            event.fixedCostID = nil
        }

        try? context.save()
        NotificationCenter.default.post(name: .tallyDataChanged, object: nil)
        onSave(); dismiss()
    }
}
