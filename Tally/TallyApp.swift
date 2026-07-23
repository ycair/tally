import SwiftUI
import SwiftData

@main
struct TallyApp: App {
    static let container: ModelContainer = {
        let schema = Schema([
            Expense.self, LineItem.self, FixedCost.self,
            IncomeEvent.self, MoneyJar.self, DailyBudget.self,
            AppSettings.self
        ])
        let config = ModelConfiguration(cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(Self.container)
    }
}
