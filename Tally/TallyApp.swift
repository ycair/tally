import SwiftUI
import SwiftData

@main
struct TallyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Expense.self, LineItem.self, FixedCost.self,
            IncomeEvent.self, MoneyJar.self, DailyBudget.self,
            AppSettings.self
        ])
    }
}
