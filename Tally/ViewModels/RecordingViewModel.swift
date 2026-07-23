import Foundation
import SwiftData

struct LineItemDraft: Identifiable {
    let id = UUID()
    var name: String
    var amountText: String
}

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var amountText: String = ""
    @Published var date: Date = Date()
    @Published var receiptNumber: String = ""
    @Published var location: String = ""
    @Published var source: ExpenseSource = .dailyBudget
    @Published var selectedJar: MoneyJar?
    @Published var selectedFixedCost: FixedCost?
    @Published var availableJars: [MoneyJar] = []
    @Published var availableFixedCosts: [FixedCost] = []
    @Published var lineItems: [LineItemDraft] = []
    @Published var showDiscardAlert = false

    var hasContent: Bool {
        !name.isEmpty || !amountText.isEmpty || !receiptNumber.isEmpty
        || !location.isEmpty || !lineItems.isEmpty
    }

    var amount: Decimal {
        Decimal(string: amountText) ?? 0
    }

    var isValid: Bool {
        !name.isEmpty && amount > 0
    }

    func load(_ expense: Expense) {
        name = expense.name
        amountText = String(describing: expense.amount)
        date = expense.date
        receiptNumber = expense.receiptNumber ?? ""
        location = expense.location ?? ""
        source = expense.source
        lineItems = expense.lineItems.map {
            LineItemDraft(name: $0.name, amountText: String(describing: $0.amount))
        }
    }

    func addLineItem() {
        lineItems.append(LineItemDraft(name: "", amountText: ""))
    }

    func save(context: ModelContext) -> Expense {
        let total: Decimal = lineItems.isEmpty ? amount
            : lineItems.reduce(Decimal.zero) { $0 + (Decimal(string: $1.amountText) ?? 0) }

        let expense = Expense(
            name: name.trimmingCharacters(in: .whitespaces),
            amount: total, date: date,
            receiptNumber: receiptNumber.isEmpty ? nil : receiptNumber,
            location: location.isEmpty ? nil : location,
            source: source,
            jarID: source == .jar ? selectedJar?.persistentModelID.entityName : nil,
            fixedCostID: source == .fixedCost ? selectedFixedCost?.persistentModelID.entityName : nil)

        for draft in lineItems where !draft.name.isEmpty {
            expense.lineItems.append(
                LineItem(name: draft.name, amount: Decimal(string: draft.amountText) ?? 0))
        }

        context.insert(expense)
        if source == .jar, let jar = selectedJar {
            jar.balance -= expense.amount
        }
        if source == .fixedCost, let cost = selectedFixedCost {
            cost.depositedAmount -= expense.amount
        }
        do {
            try context.save()
        } catch {
            print("❌ RecordingViewModel save error: \(error)")
        }
        return expense
    }

    func update(_ expense: Expense, context: ModelContext) {
        let total: Decimal = lineItems.isEmpty ? amount
            : lineItems.reduce(Decimal.zero) { $0 + (Decimal(string: $1.amountText) ?? 0) }
        expense.name = name.trimmingCharacters(in: .whitespaces)
        expense.amount = total
        expense.date = date
        expense.receiptNumber = receiptNumber.isEmpty ? nil : receiptNumber
        expense.location = location.isEmpty ? nil : location
        expense.source = source
        expense.jarID = source == .jar ? selectedJar?.persistentModelID.entityName : nil
        expense.lineItems.removeAll()
        for draft in lineItems where !draft.name.isEmpty {
            expense.lineItems.append(
                LineItem(name: draft.name, amount: Decimal(string: draft.amountText) ?? 0))
        }
        do {
            try context.save()
        } catch {
            print("❌ RecordingViewModel update error: \(error)")
        }
    }

    func delete(_ expense: Expense, context: ModelContext) {
        context.delete(expense)
        do {
            try context.save()
        } catch {
            print("❌ RecordingViewModel delete error: \(error)")
        }
    }
}
