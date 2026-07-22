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
    @State private var availableJars: [MoneyJar] = []

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
            }
            .navigationTitle(existingEvent != nil ? "編輯收入" : "新增收入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }.disabled(name.isEmpty || amountText.isEmpty)
                }
            }
            .onAppear {
                availableJars = (try? context.fetch(FetchDescriptor<MoneyJar>())) ?? []
                if let e = existingEvent {
                    name = e.name; amountText = String(describing: e.amount)
                    date = e.date; destination = e.destination
                }
            }
        }
    }

    private func save() {
        guard let amount = Decimal(string: amountText) else { return }
        let event = existingEvent ?? IncomeEvent(name: name, amount: amount, date: date, destination: destination)
        if existingEvent == nil { context.insert(event) }
        if destination == .jar, let jar = selectedJar {
            event.jarID = jar.persistentModelID.entityName
            jar.balance += amount
        }
        try? context.save()
        onSave(); dismiss()
    }
}
