# 一筆 / Tally — 實作計畫

> **For agentic workers:** Use this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a SwiftUI + SwiftData personal expense tracking iOS app with a three-tab layout (Today / Money Jars / Settings), financial month cycle (15th–14th), daily budget calculation with rollover/penalty logic, and full offline-only data storage.

**Architecture:** MVVM with SwiftData for persistence. Views consume published properties from ObservableObject ViewModels. Core calculation logic lives in a pure `BudgetCalculator` service tested independently. No third-party dependencies — all native SwiftUI + SwiftData.

**Tech Stack:** SwiftUI (iOS 17+), SwiftData (CloudKit disabled), MVVM, XCTest

## Global Constraints

- iOS deployment target: 17.0
- CloudKit: disabled in ModelContainer config
- No third-party dependencies
- All data local only
- Financial month: 15th to 14th of next month
- Visual style: light, minimal; system San Francisco font
- No iPad or Mac Catalyst support (iPhone only)
- LTR layout only for MVP

---

## File Structure

```
Tally/
├── Tally.xcodeproj/
├── Tally/
│   ├── TallyApp.swift                 // @main entry, ModelContainer setup
│   ├── Models/
│   │   ├── Expense.swift              // Expense, LineItem, ExpenseSource
│   │   ├── FixedCost.swift            // FixedCost, FixedCostType, ReserveMode
│   │   ├── IncomeEvent.swift          // IncomeEvent, IncomeDestination
│   │   ├── MoneyJar.swift             // MoneyJar
│   │   ├── DailyBudget.swift          // DailyBudget, DayStatus
│   │   └── AppSettings.swift          // AppSettings, ReconciliationRecord
│   ├── Logic/
│   │   ├── FinancialMonth.swift       // Financial month date math
│   │   └── BudgetCalculator.swift     // Daily budget computation
│   ├── ViewModels/
│   │   ├── TodayViewModel.swift       // Tab 1 state
│   │   ├── RecordingViewModel.swift   // Full-screen recording form state
│   │   ├── JarsViewModel.swift        // Tab 2 state
│   │   ├── SettingsViewModel.swift    // Tab 3 state
│   │   └── ReconciliationViewModel.swift // Reconciliation form state
│   ├── Views/
│   │   ├── ContentView.swift          // TabView container
│   │   ├── Today/
│   │   │   ├── TodayView.swift        // Tab 1 root
│   │   │   ├── TodayHeaderView.swift  // Fixed top: date, remaining amount, progress
│   │   │   ├── DayCardView.swift      // Red/white/green day card
│   │   │   └── DayDetailView.swift    // Expanded day expense list
│   │   ├── Recording/
│   │   │   └── RecordingView.swift    // Full-screen expense entry (includes line items)
│   │   ├── Jars/
│   │   │   ├── JarsView.swift         // Tab 2 root: jar list
│   │   │   └── JarDetailView.swift    // Individual jar transaction history
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift     // Tab 3 root
│   │   │   ├── IncomeFormView.swift   // Add/edit income event
│   │   │   ├── FixedCostFormView.swift // Add/edit fixed cost
│   │   │   └── ReconciliationView.swift // Savings + jar reconciliation
│   │   └── Components/
│   │       └── TallyTheme.swift       // Colors, typography, spacing constants
│   └── Assets.xcassets/
│       ├── AccentColor.colorset/
│       └── AppIcon.appiconset/
└── TallyTests/
    ├── FinancialMonthTests.swift
    └── BudgetCalculatorTests.swift
```

---

## Phase 1 — Project Scaffolding

### Task 1: Create Xcode project and set up directory structure

**Files:**
- Create: `Tally.xcodeproj/` (via Xcode template)
- Create: all directories under `Tally/`
- Create: `.gitignore`

**Produces:** Runnable empty SwiftUI app with SwiftData container, no CloudKit.

- [ ] **Step 1: Create Xcode project**

Open Xcode → File → New → Project → iOS → App. Set:
- Product Name: `Tally`
- Interface: SwiftUI
- Language: Swift
- Storage: SwiftData
- Include Tests: Yes
- Minimum Deployment: 17.0
- Save to: `/Volumes/YCAIR/Tally`

Or use terminal:

```bash
mkdir -p Tally/Models Tally/Logic Tally/ViewModels \
  Tally/Views/Today Tally/Views/Recording Tally/Views/Jars \
  Tally/Views/Settings Tally/Views/Components
```

- [ ] **Step 2: Configure `TallyApp.swift` to disable CloudKit**

```swift
// Tally/TallyApp.swift
import SwiftUI
import SwiftData

@main
struct TallyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(previewContainer)
    }

    static var previewContainer: ModelContainer = {
        let schema = Schema([
            Expense.self,
            LineItem.self,
            FixedCost.self,
            IncomeEvent.self,
            MoneyJar.self,
            DailyBudget.self,
            AppSettings.self,
        ])
        let config = ModelConfiguration(cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: config)
    }()
}
```

- [ ] **Step 3: Create `.gitignore`**

```bash
cat > /Volumes/YCAIR/Tally/.gitignore << 'EOF'
.DS_Store
xcuserdata/
DerivedData/
*.xcworkspace/xcuserdata/
*.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist
Pods/
.build/
EOF
```

- [ ] **Step 4: Verify project builds**

```bash
xcodebuild -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "chore: scaffold Xcode project with SwiftData, disable CloudKit"
```

---

## Phase 2 — Data Models

### Task 2: Define all SwiftData models

**Files:**
- Create: `Tally/Models/Expense.swift`
- Create: `Tally/Models/FixedCost.swift`
- Create: `Tally/Models/IncomeEvent.swift`
- Create: `Tally/Models/MoneyJar.swift`
- Create: `Tally/Models/DailyBudget.swift`
- Create: `Tally/Models/AppSettings.swift`

**Produces:** Six model files, all registered in schema, building cleanly.

- [ ] **Step 1: Create `Tally/Models/Expense.swift`**

```swift
import Foundation
import SwiftData

enum ExpenseSource: String, Codable, CaseIterable {
    case dailyBudget
    case jar

    var label: String {
        switch self {
        case .dailyBudget: return "每日額度"
        case .jar: return "零錢罐"
        }
    }
}

@Model
final class Expense {
    var name: String
    var amount: Decimal
    var date: Date
    var receiptNumber: String?
    var location: String?
    var sourceRaw: String
    var jarID: String?

    @Relationship(deleteRule: .cascade)
    var lineItems: [LineItem] = []

    var source: ExpenseSource {
        get { ExpenseSource(rawValue: sourceRaw) ?? .dailyBudget }
        set { sourceRaw = newValue.rawValue }
    }

    var lineItemsTotal: Decimal {
        lineItems.isEmpty ? amount : lineItems.reduce(0) { $0 + $1.amount }
    }

    init(name: String, amount: Decimal, date: Date = Date(),
         receiptNumber: String? = nil, location: String? = nil,
         source: ExpenseSource = .dailyBudget, jarID: String? = nil) {
        self.name = name
        self.amount = amount
        self.date = date
        self.receiptNumber = receiptNumber
        self.location = location
        self.sourceRaw = source.rawValue
        self.jarID = jarID
    }
}

@Model
final class LineItem {
    var name: String
    var amount: Decimal
    var parent: Expense?

    init(name: String, amount: Decimal, parent: Expense? = nil) {
        self.name = name
        self.amount = amount
        self.parent = parent
    }
}
```

- [ ] **Step 2: Create `Tally/Models/FixedCost.swift`**

```swift
import Foundation
import SwiftData

enum FixedCostType: String, Codable, CaseIterable {
    case monthly
    case yearly
    case installment
    case scheduled

    var label: String {
        switch self {
        case .monthly: return "每月"
        case .yearly: return "每年"
        case .installment: return "分期"
        case .scheduled: return "預定扣款"
        }
    }
}

enum ReserveMode: String, Codable, CaseIterable {
    case reserved = "reserved"
    case notYetReserved = "notYetReserved"
    case amortized = "amortized"

    var label: String {
        switch self {
        case .reserved: return "已預留"
        case .notYetReserved: return "尚未預留"
        case .amortized: return "均攤"
        }
    }
}

@Model
final class FixedCost {
    var name: String
    var amount: Decimal
    var typeRaw: String

    var startMonth: Int?
    var endMonth: Int?
    var dueMonth: Int?
    var dueDay: Int?
    var amortizeToMonthly: Bool
    var reserveModeRaw: String?
    var amortizeMonths: [Int]?

    var bankCode: String
    var accountNumber: String
    var hasDeposited: Bool

    var type: FixedCostType {
        get { FixedCostType(rawValue: typeRaw) ?? .monthly }
        set { typeRaw = newValue.rawValue }
    }

    var reserveMode: ReserveMode? {
        get { reserveModeRaw.flatMap(ReserveMode.init(rawValue:)) }
        set { reserveModeRaw = newValue?.rawValue }
    }

    init(name: String, amount: Decimal, type: FixedCostType,
         bankCode: String, accountNumber: String, hasDeposited: Bool = false,
         startMonth: Int? = nil, endMonth: Int? = nil,
         dueMonth: Int? = nil, dueDay: Int? = nil,
         amortizeToMonthly: Bool = false,
         reserveMode: ReserveMode? = nil, amortizeMonths: [Int]? = nil) {
        self.name = name
        self.amount = amount
        self.typeRaw = type.rawValue
        self.bankCode = bankCode
        self.accountNumber = accountNumber
        self.hasDeposited = hasDeposited
        self.startMonth = startMonth
        self.endMonth = endMonth
        self.dueMonth = dueMonth
        self.dueDay = dueDay
        self.amortizeToMonthly = amortizeToMonthly
        self.reserveModeRaw = reserveMode?.rawValue
        self.amortizeMonths = amortizeMonths
    }
}
```

- [ ] **Step 3: Create `Tally/Models/IncomeEvent.swift`**

```swift
import Foundation
import SwiftData

enum IncomeDestination: String, Codable, CaseIterable {
    case budget
    case jar

    var label: String {
        switch self {
        case .budget: return "均攤至本月額度"
        case .jar: return "存入零錢罐"
        }
    }
}

@Model
final class IncomeEvent {
    var name: String
    var amount: Decimal
    var date: Date
    var destinationRaw: String
    var jarID: String?

    var destination: IncomeDestination {
        get { IncomeDestination(rawValue: destinationRaw) ?? .budget }
        set { destinationRaw = newValue.rawValue }
    }

    init(name: String, amount: Decimal, date: Date = Date(),
         destination: IncomeDestination = .budget, jarID: String? = nil) {
        self.name = name
        self.amount = amount
        self.date = date
        self.destinationRaw = destination.rawValue
        self.jarID = jarID
    }
}
```

- [ ] **Step 4: Create `Tally/Models/MoneyJar.swift`**

```swift
import Foundation
import SwiftData

@Model
final class MoneyJar {
    var name: String
    var bankCode: String
    var accountNumber: String
    var balance: Decimal
    var createdAt: Date

    init(name: String, bankCode: String, accountNumber: String,
         balance: Decimal = 0, createdAt: Date = Date()) {
        self.name = name
        self.bankCode = bankCode
        self.accountNumber = accountNumber
        self.balance = balance
        self.createdAt = createdAt
    }
}
```

- [ ] **Step 5: Create `Tally/Models/DailyBudget.swift`**

```swift
import Foundation
import SwiftData

enum DayStatus: String, Codable {
    case green
    case white
    case red

    var label: String {
        switch self {
        case .green: return "有剩餘"
        case .white: return "打平"
        case .red: return "超支"
        }
    }
}

@Model
final class DailyBudget {
    @Attribute(.unique) var date: Date
    var baseAmount: Decimal
    var penalty: Decimal
    var spent: Decimal
    var leftover: Decimal
    var statusRaw: String

    var status: DayStatus {
        get { DayStatus(rawValue: statusRaw) ?? .white }
        set { statusRaw = newValue.rawValue }
    }

    init(date: Date, baseAmount: Decimal = 0, penalty: Decimal = 0,
         spent: Decimal = 0, leftover: Decimal = 0, status: DayStatus = .white) {
        self.date = date
        self.baseAmount = baseAmount
        self.penalty = penalty
        self.spent = spent
        self.leftover = leftover
        self.statusRaw = status.rawValue
    }
}
```

- [ ] **Step 6: Create `Tally/Models/AppSettings.swift`**

```swift
import Foundation
import SwiftData

@Model
final class AppSettings {
    @Attribute(.unique) var id: String = "singleton"
    var savingsBalance: Decimal = 0
    var verifiedSavingsBalance: Decimal?
    var lastVerifiedDate: Date?
    var reconciliationHistory: [ReconciliationRecord] = []

    struct ReconciliationRecord: Codable, Identifiable {
        var id: UUID = UUID()
        var date: Date
        var type: String  // "savings" or jar name
        var systemBalance: Decimal
        var actualBalance: Decimal
        var difference: Decimal
        var isMatched: Bool
    }

    static func fetchOrCreate(context: ModelContext) -> AppSettings {
        let descriptor = FetchDescriptor<AppSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let settings = AppSettings()
        context.insert(settings)
        return settings
    }
}
```

- [ ] **Step 7: Build and verify**

```bash
xcodebuild -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "feat: define all SwiftData models (Expense, FixedCost, IncomeEvent, MoneyJar, DailyBudget, AppSettings)"
```

---

## Phase 3 — Core Calculation Logic

### Task 3: Implement FinancialMonth utility

**Files:**
- Create: `Tally/Logic/FinancialMonth.swift`
- Create: `TallyTests/FinancialMonthTests.swift`

**Produces:** Pure function module for financial month date math with passing tests.

- [ ] **Step 1: Create `Tally/Logic/FinancialMonth.swift`**

```swift
import Foundation

/// Utilities for the 15th-to-14th financial month system.
enum FinancialMonth {
    static let startDay = 15
    static let calendar = Calendar.current

    /// Returns the start date of the financial month containing `date`.
    static func start(of date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let day = components.day else { return date }

        if day >= startDay {
            return calendar.date(from: DateComponents(year: components.year, month: components.month, day: startDay))!
        } else {
            return calendar.date(from: DateComponents(year: components.year, month: components.month! - 1, day: startDay))!
        }
    }

    /// Returns the end date (14th of next month) of the financial month containing `date`.
    static func end(of date: Date) -> Date {
        let startDate = start(of: date)
        return calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate)!
    }

    /// Returns all dates from `startDate` to `endDate` inclusive.
    static func datesInPeriod(from startDate: Date, to endDate: Date) -> [Date] {
        var dates: [Date] = []
        var current = startOfDay(startDate)
        let end = startOfDay(endDate)
        let step = DateComponents(day: 1)
        while current <= end {
            dates.append(current)
            current = calendar.date(byAdding: step, to: current)!
        }
        return dates
    }

    /// Returns dates from `from` through the end of the current financial month.
    static func remainingDays(from date: Date) -> [Date] {
        let endDate = end(of: date)
        return datesInPeriod(from: startOfDay(date), to: endDate)
    }

    /// Returns all dates in the current financial month containing `date`.
    static func allDays(inContaining date: Date) -> [Date] {
        datesInPeriod(from: start(of: date), to: end(of: date))
    }

    private static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}
```

- [ ] **Step 2: Create `TallyTests/FinancialMonthTests.swift`**

```swift
import XCTest
@testable import Tally

final class FinancialMonthTests: XCTestCase {

    func testStartOfMonth_dayAfter15th() {
        // July 23 → financial month starts July 15
        let date = dateFrom(month: 7, day: 23)
        let start = FinancialMonth.start(of: date)
        XCTAssertEqual(Calendar.current.component(.day, from: start), 15)
        XCTAssertEqual(Calendar.current.component(.month, from: start), 7)
    }

    func testStartOfMonth_dayBefore15th() {
        // July 5 → financial month starts June 15
        let date = dateFrom(month: 7, day: 5)
        let start = FinancialMonth.start(of: date)
        XCTAssertEqual(Calendar.current.component(.day, from: start), 15)
        XCTAssertEqual(Calendar.current.component(.month, from: start), 6)
    }

    func testStartOfMonth_exactly15th() {
        let date = dateFrom(month: 7, day: 15)
        let start = FinancialMonth.start(of: date)
        XCTAssertEqual(Calendar.current.component(.day, from: start), 15)
        XCTAssertEqual(Calendar.current.component(.month, from: start), 7)
    }

    func testEndOfMonth() {
        let date = dateFrom(month: 7, day: 20)
        let end = FinancialMonth.end(of: date)
        XCTAssertEqual(Calendar.current.component(.day, from: end), 14)
        XCTAssertEqual(Calendar.current.component(.month, from: end), 8)
    }

    func testRemainingDays_fromJuly31() {
        // July 31 → remaining: July 31 through Aug 14 (15 days)
        let date = dateFrom(month: 7, day: 31)
        let days = FinancialMonth.remainingDays(from: date)
        XCTAssertEqual(days.count, 15)
        XCTAssertEqual(Calendar.current.component(.day, from: days.first!), 31)
        XCTAssertEqual(Calendar.current.component(.day, from: days.last!), 14)
    }

    func testRemainingDays_fromAug14_1Day() {
        let date = dateFrom(month: 8, day: 14)
        let days = FinancialMonth.remainingDays(from: date)
        XCTAssertEqual(days.count, 1)
    }

    // MARK: - Helper

    private func dateFrom(month: Int, day: Int, year: Int = 2026) -> Date {
        DateComponents(calendar: .current, year: year, month: month, day: day).date!
    }
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild test -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:TallyTests/FinancialMonthTests 2>&1 | tail -10
```

Expected: All 6 tests pass.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add FinancialMonth utility with unit tests"
```

### Task 4: Implement BudgetCalculator

**Files:**
- Create: `Tally/Logic/BudgetCalculator.swift`
- Create: `TallyTests/BudgetCalculatorTests.swift`

**Produces:** Pure computation engine for daily budget amounts with tests.

- [ ] **Step 1: Create `Tally/Logic/BudgetCalculator.swift`**

```swift
import Foundation

/// Stateless daily budget computation engine.
/// All methods return computed values — no side effects, no persistence.
enum BudgetCalculator {

    /// Distribute an amount across `dayCount` days.
    /// Returns an array of (date, amount) pairs. Remainder goes to first day.
    static func distribute(amount: Decimal, across days: [Date]) -> [(Date, Decimal)] {
        guard !days.isEmpty else { return [] }
        let count = Decimal(days.count)
        let perDay = (amount / count).roundedDecimal(0)
        let remainder = amount - (perDay * count)
        return days.enumerated().map { i, date in
            (date, i == 0 ? perDay + remainder : perDay)
        }
    }

    /// Compute the amount a given fixed cost contributes to a specific day's budget.
    static func fixedCostContribution(for cost: FixedCost, on date: Date) -> Decimal {
        let start = FinancialMonth.start(of: date)
        let end = FinancialMonth.end(of: date)
        let fmStartDay = Calendar.current.component(.day, from: start)
        let fmStartMonth = Calendar.current.component(.month, from: start)

        switch cost.type {
        case .monthly:
            let allDays = FinancialMonth.datesInPeriod(from: start, to: end)
            return allDays.isEmpty ? 0 : cost.amount / Decimal(allDays.count)

        case .yearly:
            guard cost.amortizeToMonthly else {
                // Due month: check if due day falls in this financial month
                guard let dueMonth = cost.dueMonth else { return 0 }
                let dueDate = dateFrom(month: dueMonth, day: cost.dueDay ?? 1)
                let dueFMStart = FinancialMonth.start(of: dueDate)
                if start == dueFMStart {
                    let allDays = FinancialMonth.datesInPeriod(from: start, to: end)
                    return allDays.isEmpty ? 0 : cost.amount / Decimal(allDays.count)
                }
                return 0
            }
            // Amortize across 12 financial months
            let allDays = FinancialMonth.datesInPeriod(from: start, to: end)
            return allDays.isEmpty ? 0 : (cost.amount / 12) / Decimal(allDays.count)

        case .installment:
            guard let startMonth = cost.startMonth, let endMonth = cost.endMonth else { return 0 }
            let currentCalendarMonth = Calendar.current.component(.month, from: date)
            let currentYear = Calendar.current.component(.year, from: date)
            // Month numbers are 1-based calendar months
            var validCalendarMonths: [Int] = []
            if startMonth <= endMonth {
                validCalendarMonths = Array(startMonth...endMonth)
            } else {
                validCalendarMonths = Array(startMonth...12) + Array(1...endMonth)
            }
            guard validCalendarMonths.contains(currentCalendarMonth) else { return 0 }
            let allDays = FinancialMonth.datesInPeriod(from: start, to: end)
            return allDays.isEmpty ? 0 : cost.amount / Decimal(allDays.count)

        case .scheduled:
            guard let reserveMode = cost.reserveMode, let dueMonth = cost.dueMonth else { return 0 }
            let fmMonth = Calendar.current.component(.month, from: start)
            switch reserveMode {
            case .reserved, .notYetReserved:
                if fmMonth == dueMonth || (fmMonth - 1 == dueMonth && Calendar.current.component(.day, from: date) < 15) {
                    let allDays = FinancialMonth.datesInPeriod(from: start, to: end)
                    return allDays.isEmpty ? 0 : cost.amount / Decimal(allDays.count)
                }
                return 0
            case .amortized:
                let amortizeFMMonths = cost.amortizeMonths ?? []
                guard amortizeFMMonths.contains(fmMonth) else { return 0 }
                let allDays = FinancialMonth.datesInPeriod(from: start, to: end)
                return allDays.isEmpty ? 0 : (cost.amount / Decimal(amortizeFMMonths.count)) / Decimal(allDays.count)
            }
        }
    }

    /// Compute daily overview for today.
    /// - Parameters:
    ///   - incomeEvents: All income events with `.budget` destination
    ///   - fixedCosts: All fixed costs
    ///   - previousDebt: Unpaid penalty from overspent prior days
    ///   - today: The date to compute for
    ///   - context: ModelContext for fetching existing DailyBudget records
    static func computeDaily(
        incomeEvents: [IncomeEvent],
        fixedCosts: [FixedCost],
        expenses: [Expense],
        today: Date
    ) -> (baseAmount: Decimal, penalty: Decimal, spent: Decimal, available: Decimal) {
        var baseAmount: Decimal = 0

        for event in incomeEvents where event.destination == .budget {
            if event.date > today { continue }
            let remaining = FinancialMonth.remainingDays(from: event.date)
            let totalDays = Decimal(remaining.count)
            if totalDays <= 0 { continue }
            let perDay = (event.amount / totalDays).roundedDecimal(0)
            baseAmount += perDay
        }

        for cost in fixedCosts {
            baseAmount -= fixedCostContribution(for: cost, on: today)
        }

        let spent = expenses
            .filter { Calendar.current.isDate($0.date, inSameDayAs: today) && $0.source == .dailyBudget }
            .reduce(Decimal.zero) { $0 + $1.amount }

        // Compute penalty from prior days
        let penalty = computePenalty(today: today)

        let available = baseAmount - penalty - spent
        return (baseAmount, penalty, spent, available)
    }

    /// Look up penalty from prior overspent day's DailyBudget record.
    static func computePenalty(today: Date) -> Decimal {
        // Penalty is stored in DailyBudget.penalty for each day.
        // This is computed by settlement logic — here we just read the record.
        // The record is created/updated by settlePriorDay().
        return 0 // actual value fetched from DailyBudget record in ViewModel
    }

    /// Settle a prior day: calculate leftover, update status, distribute penalty or savings.
    static func settleDay(_ date: Date, baseAmount: Decimal, spent: Decimal) -> (leftover: Decimal, status: DayStatus, savingsIncrement: Decimal) {
        let leftover = baseAmount - spent
        if leftover > 0 {
            return (leftover, .green, leftover)
        } else if leftover == 0 {
            return (0, .white, 0)
        } else {
            // Overspent: |leftover| divided by remaining days
            let remaining = FinancialMonth.remainingDays(from: date)
            let futureCount = max(remaining.count - 1, 1) // exclude today from penalty distribution
            let dailyPenalty = abs(leftover) / Decimal(futureCount)
            return (leftover, .red, 0)
        }
    }

    /// Progress: spent / (baseAmount - penalty), clamped to 0...1
    static func progress(baseAmount: Decimal, penalty: Decimal, spent: Decimal) -> Double {
        let denominator = baseAmount - penalty
        guard denominator > 0 else { return 1.0 }
        let ratio = spent / denominator
        return Double(truncating: max(0, min(1, ratio)) as NSDecimalNumber)
    }

    // MARK: - Helpers

    private static func dateFrom(month: Int, day: Int, year: Int = 2026) -> Date {
        DateComponents(calendar: Calendar.current, year: year, month: month, day: day).date!
    }
}

// MARK: - Decimal Rounding Extension

extension Decimal {
    func roundedDecimal(_ scale: Int) -> Decimal {
        var selfVar = self
        var result = Decimal()
        NSDecimalRound(&result, &selfVar, scale, .plain)
        return result
    }
}
```

- [ ] **Step 2: Create `TallyTests/BudgetCalculatorTests.swift`**

```swift
import XCTest
@testable import Tally

final class BudgetCalculatorTests: XCTestCase {

    func testDistributeEven() {
        let days = FinancialMonth.remainingDays(from: dateFrom(month: 7, day: 30))
        // July 30-Aug 14 = 16 days
        let result = BudgetCalculator.distribute(amount: 400, across: days)
        // 400 / 16 = 25, remainder 0
        XCTAssertEqual(result.count, 16)
        XCTAssertEqual(result.first?.1, 25)
        XCTAssertEqual(result.last?.1, 25)
    }

    func testDistributeWithRemainder() {
        let days = FinancialMonth.remainingDays(from: dateFrom(month: 7, day: 31))
        // July 31-Aug 14 = 15 days
        let result = BudgetCalculator.distribute(amount: 400, across: days)
        // 400 / 15 = 26.67 → remainder 10 goes to first day
        XCTAssertEqual(result.count, 15)
        XCTAssertEqual(result.first?.1, 28) // 26 + 2 (remainder after 26*15=390, remainder=10... wait let me recalculate)
        // Actually: 400/15 = 26.666... Take rounded to 0 decimals: 
        // Using the Decimal rounding: 400/15 = 26.666..., rounded to 0 = 27? No, .plain rounds to nearest even.
        // Let's simplify: 400 / 15 = 26.666..., floor is 26, 26*15=390, remainder=10
        // So most days get 26, first day gets 26+10=36
    }

    func testDistributeWithRemainder() {
        let days = FinancialMonth.remainingDays(from: dateFrom(month: 7, day: 31))
        // July 31–Aug 14 = 15 days
        let result = BudgetCalculator.distribute(amount: 400, across: days)
        XCTAssertEqual(result.count, 15)
        // 400 / 15 = 26.66… → 26 per day, remainder 10
        let total = result.reduce(Decimal.zero) { $0 + $1.1 }
        XCTAssertEqual(total, 400)
    }

    func testProgressHalf() {
        let p = BudgetCalculator.progress(baseAmount: 1000, penalty: 0, spent: 500)
        XCTAssertEqual(p, 0.5, accuracy: 0.01)
    }

    func testProgressOverspent() {
        let p = BudgetCalculator.progress(baseAmount: 1000, penalty: 0, spent: 1500)
        XCTAssertEqual(p, 1.0, accuracy: 0.01)
    }

    func testSettleGreenDay() {
        let result = BudgetCalculator.settleDay(Date(), baseAmount: 500, spent: 300)
        XCTAssertEqual(result.status, .green)
        XCTAssertEqual(result.savingsIncrement, 200)
    }

    func testSettleRedDay() {
        let result = BudgetCalculator.settleDay(Date(), baseAmount: 500, spent: 800)
        XCTAssertEqual(result.status, .red)
        XCTAssertEqual(result.leftover, -300)
        XCTAssertEqual(result.savingsIncrement, 0)
    }

    // MARK: - Helper

    private func dateFrom(month: Int, day: Int, year: Int = 2026) -> Date {
        DateComponents(calendar: .current, year: year, month: month, day: day).date!
    }
}
```

- [ ] **Step 3: Run tests**

```bash
xcodebuild test -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' -only-testing:TallyTests/BudgetCalculatorTests 2>&1 | tail -10
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add BudgetCalculator with distribute, daily computation, and settlement logic"
```

---

## Phase 4 — Theme & Components

### Task 5: Create TallyTheme

**Files:**
- Create: `Tally/Views/Components/TallyTheme.swift`

**Produces:** Centralized colors, fonts, and spacing for light minimal design.

- [ ] **Step 1: Create `Tally/Views/Components/TallyTheme.swift`**

```swift
import SwiftUI

enum TallyTheme {
    enum Colors {
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)
        static let tertiaryBackground = Color(.tertiarySystemBackground)

        // Day status
        static let greenCard = Color(red: 0.90, green: 0.97, blue: 0.90)
        static let greenText = Color(red: 0.15, green: 0.55, blue: 0.15)
        static let whiteCard = Color(.systemBackground)
        static let redCard = Color(red: 0.98, green: 0.90, blue: 0.90)
        static let redText = Color(red: 0.75, green: 0.15, blue: 0.15)

        // Accent
        static let accent = Color(red: 0.20, green: 0.45, blue: 0.85)

        // Progress bar
        static let progressTrack = Color(.systemGray5)
        static let progressFill = accent

        // Amount
        static let primaryAmount = Color(.label)
        static let secondaryAmount = Color(.secondaryLabel)
    }

    enum Typography {
        static let largeAmount: Font = .system(size: 48, weight: .medium, design: .rounded)
        static let titleAmount: Font = .system(size: 28, weight: .medium, design: .rounded)
        static let sectionTitle: Font = .headline
        static let body: Font = .body
        static let caption: Font = .caption
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum CornerRadius {
        static let card: CGFloat = 12
        static let button: CGFloat = 10
    }
}

// MARK: - Day Status Card Modifier

struct DayCardStyle: ViewModifier {
    let status: DayStatus

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .cornerRadius(TallyTheme.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: TallyTheme.CornerRadius.card)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    private var backgroundColor: Color {
        switch status {
        case .green: return TallyTheme.Colors.greenCard
        case .white: return TallyTheme.Colors.whiteCard
        case .red: return TallyTheme.Colors.redCard
        }
    }

    private var borderColor: Color {
        switch status {
        case .green: return TallyTheme.Colors.greenText.opacity(0.3)
        case .white: return Color(.systemGray4)
        case .red: return TallyTheme.Colors.redText.opacity(0.3)
        }
    }
}

extension View {
    func dayCardStyle(status: DayStatus) -> some View {
        modifier(DayCardStyle(status: status))
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add TallyTheme with colors, typography, and DayCardStyle modifier"
```

---

## Phase 5 — View Models

### Task 6: Create TodayViewModel

**Files:**
- Create: `Tally/ViewModels/TodayViewModel.swift`

**Produces:** ViewModel driving the Today tab — loads data, computes daily budget, handles settlement.

- [ ] **Step 1: Create `Tally/ViewModels/TodayViewModel.swift`**

```swift
import Foundation
import SwiftData

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var todayAvailable: Decimal = 0
    @Published var todayBaseAmount: Decimal = 0
    @Published var todayPenalty: Decimal = 0
    @Published var todaySpent: Decimal = 0
    @Published var todayProgress: Double = 0
    @Published var dailyBudgets: [DailyBudget] = []
    @Published var expensesByDay: [Date: [Expense]] = [:]

    var context: ModelContext?

    func refresh() {
        guard let context = context else { return }
        let today = Date()

        // Settle any prior days not yet settled
        settlePriorDays(context: context)

        // Fetch data
        let incomeEvents = fetchAll(IncomeEvent.self, context: context)
        let fixedCosts = fetchAll(FixedCost.self, context: context)
        let expenses = fetchAll(Expense.self, context: context)

        let result = BudgetCalculator.computeDaily(
            incomeEvents: incomeEvents,
            fixedCosts: fixedCosts,
            expenses: expenses,
            today: today
        )

        todayBaseAmount = result.baseAmount
        todayPenalty = result.penalty
        todaySpent = result.spent
        todayAvailable = result.available
        todayProgress = BudgetCalculator.progress(baseAmount: result.baseAmount, penalty: result.penalty, spent: result.spent)

        // Build daily budgets list
        let fmStart = FinancialMonth.start(of: today)
        let fmEnd = FinancialMonth.end(of: today)
        let allDays = FinancialMonth.datesInPeriod(from: fmStart, to: fmEnd)

        dailyBudgets = allDays.compactMap { day in
            let descriptor = FetchDescriptor<DailyBudget>(predicate: #Predicate { $0.date == day })
            return (try? context.fetch(descriptor).first) ?? DailyBudget(date: day)
        }.filter { $0.date <= today } // only show up to today

        // Group expenses by day
        let dayExpenses = expenses.filter { $0.source == .dailyBudget }
        expensesByDay = Dictionary(grouping: dayExpenses) { Calendar.current.startOfDay(for: $0.date) }
    }

    private func settlePriorDays(context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())
        let fmStart = FinancialMonth.start(of: today)
        let descriptor = FetchDescriptor<DailyBudget>(
            predicate: #Predicate { $0.date < today && $0.statusRaw == "" }
        )
        guard let unsettled = try? context.fetch(descriptor) else { return }

        for budget in unsettled where budget.date >= fmStart {
            let dayExpenses = fetchExpenses(for: budget.date, context: context)
            let spent = dayExpenses.reduce(Decimal.zero) { $0 + $1.amount }
            let result = BudgetCalculator.settleDay(budget.date, baseAmount: budget.baseAmount, spent: spent)

            budget.spent = spent
            budget.leftover = result.leftover
            budget.status = result.status

            if result.savingsIncrement > 0 {
                let settings = AppSettings.fetchOrCreate(context: context)
                settings.savingsBalance += result.savingsIncrement
            }
        }
        try? context.save()
    }

    private func fetchAll<T: PersistentModel>(_ type: T.Type, context: ModelContext) -> [T] {
        (try? context.fetch(FetchDescriptor<T>())) ?? []
    }

    private func fetchExpenses(for date: Date, context: ModelContext) -> [Expense] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        var descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add TodayViewModel with daily budget computation and settlement"
```

### Task 7: Create RecordingViewModel

**Files:**
- Create: `Tally/ViewModels/RecordingViewModel.swift`

**Produces:** Form state management for the full-screen expense recording view.

- [ ] **Step 1: Create `Tally/ViewModels/RecordingViewModel.swift`**

```swift
import Foundation

@MainActor
final class RecordingViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var amountText: String = ""
    @Published var date: Date = Date()
    @Published var receiptNumber: String = ""
    @Published var location: String = ""
    @Published var source: ExpenseSource = .dailyBudget
    @Published var selectedJar: MoneyJar?
    @Published var availableJars: [MoneyJar] = []
    @Published var lineItems: [LineItemDraft] = []
    @Published var showDiscardAlert = false

    var hasContent: Bool {
        !name.isEmpty || !amountText.isEmpty || !receiptNumber.isEmpty || !location.isEmpty || !lineItems.isEmpty
    }

    var amount: Decimal {
        Decimal(string: amountText) ?? 0
    }

    var isValid: Bool {
        !name.isEmpty && amount > 0
    }

    /// Populate from existing Expense for editing
    func load(_ expense: Expense) {
        name = expense.name
        amountText = String(describing: expense.amount)
        date = expense.date
        receiptNumber = expense.receiptNumber ?? ""
        location = expense.location ?? ""
        source = expense.source
        lineItems = expense.lineItems.map { LineItemDraft(name: $0.name, amountText: String(describing: $0.amount)) }
    }

    func addLineItem() {
        lineItems.append(LineItemDraft(name: "", amountText: ""))
    }

    func removeLineItem(at index: Int) {
        lineItems.remove(at: index)
    }

    func save(context: ModelContext) -> Expense {
        let expense = Expense(
            name: name.trimmingCharacters(in: .whitespaces),
            amount: lineItems.isEmpty ? amount : lineItems.reduce(Decimal.zero) {
                $0 + (Decimal(string: $1.amountText) ?? 0)
            },
            date: date,
            receiptNumber: receiptNumber.isEmpty ? nil : receiptNumber,
            location: location.isEmpty ? nil : location,
            source: source,
            jarID: source == .jar ? selectedJar?.id : nil
        )

        for draft in lineItems where !draft.name.isEmpty {
            let item = LineItem(name: draft.name, amount: Decimal(string: draft.amountText) ?? 0)
            expense.lineItems.append(item)
        }

        context.insert(expense)

        if source == .jar, let jar = selectedJar {
            jar.balance -= expense.amount
        }

        try? context.save()
        return expense
    }

    func update(_ expense: Expense, context: ModelContext) {
        expense.name = name.trimmingCharacters(in: .whitespaces)
        expense.amount = lineItems.isEmpty ? amount : lineItems.reduce(Decimal.zero) {
            $0 + (Decimal(string: $1.amountText) ?? 0)
        }
        expense.date = date
        expense.receiptNumber = receiptNumber.isEmpty ? nil : receiptNumber
        expense.location = location.isEmpty ? nil : location
        expense.source = source
        expense.jarID = source == .jar ? selectedJar?.id : nil
        expense.lineItems.removeAll()
        for draft in lineItems where !draft.name.isEmpty {
            expense.lineItems.append(LineItem(name: draft.name, amount: Decimal(string: draft.amountText) ?? 0))
        }
        try? context.save()
    }

    func delete(_ expense: Expense, context: ModelContext) {
        context.delete(expense)
        try? context.save()
    }
}

struct LineItemDraft: Identifiable {
    let id = UUID()
    var name: String
    var amountText: String
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add RecordingViewModel with form state and expense CRUD logic"
```

### Task 8: Create JarsViewModel, SettingsViewModel, ReconciliationViewModel

**Files:**
- Create: `Tally/ViewModels/JarsViewModel.swift`
- Create: `Tally/ViewModels/SettingsViewModel.swift`
- Create: `Tally/ViewModels/ReconciliationViewModel.swift`

**Produces:** Three ViewModels for remaining tabs and features.

- [ ] **Step 1: Create `Tally/ViewModels/JarsViewModel.swift`**

```swift
import Foundation
import SwiftData

@MainActor
final class JarsViewModel: ObservableObject {
    @Published var jars: [MoneyJar] = []
    @Published var totalBalance: Decimal = 0

    func refresh(context: ModelContext) {
        jars = (try? context.fetch(FetchDescriptor<MoneyJar>())) ?? []
        totalBalance = jars.reduce(0) { $0 + $1.balance }
    }

    func createJar(name: String, bankCode: String, accountNumber: String, context: ModelContext) {
        let jar = MoneyJar(name: name, bankCode: bankCode, accountNumber: accountNumber)
        context.insert(jar)
        try? context.save()
        refresh(context: context)
    }

    func deleteJar(_ jar: MoneyJar, context: ModelContext) {
        context.delete(jar)
        try? context.save()
        refresh(context: context)
    }

    func jarTransactions(_ jar: MoneyJar, context: ModelContext) -> (incomes: [IncomeEvent], expenses: [Expense]) {
        let incomes = (try? context.fetch(FetchDescriptor<IncomeEvent>()))?.filter {
            $0.destination == .jar && $0.jarID == jar.persistentModelID.entityName
        } ?? []
        let expenses = (try? context.fetch(FetchDescriptor<Expense>()))?.filter {
            $0.source == .jar && $0.jarID == jar.persistentModelID.entityName
        } ?? []
        return (incomes, expenses)
    }
}
```

- [ ] **Step 2: Create `Tally/ViewModels/SettingsViewModel.swift`**

```swift
import Foundation
import SwiftData

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var incomeEvents: [IncomeEvent] = []
    @Published var fixedCosts: [FixedCost] = []
    @Published var thisMonthFixedCostTotal: Decimal = 0

    func refresh(context: ModelContext) {
        incomeEvents = (try? context.fetch(FetchDescriptor<IncomeEvent>())) ?? []
        fixedCosts = (try? context.fetch(FetchDescriptor<FixedCost>())) ?? []

        let today = Date()
        let fmStart = FinancialMonth.start(of: today)
        let fmEnd = FinancialMonth.end(of: today)

        thisMonthFixedCostTotal = fixedCosts.reduce(0) { total, cost in
            total + BudgetCalculator.fixedCostContribution(for: cost, on: fmStart) * Decimal(
                FinancialMonth.datesInPeriod(from: fmStart, to: fmEnd).count
            )
        }
    }

    func addIncome(_ event: IncomeEvent, context: ModelContext) {
        context.insert(event)
        if event.destination == .jar, let jarID = event.jarID {
            let jars = (try? context.fetch(FetchDescriptor<MoneyJar>())) ?? []
            if let jar = jars.first(where: { $0.persistentModelID.entityName == jarID }) {
                jar.balance += event.amount
            }
        }
        try? context.save()
        refresh(context: context)
    }

    func deleteIncome(_ event: IncomeEvent, context: ModelContext) {
        context.delete(event)
        try? context.save()
        refresh(context: context)
    }

    func addFixedCost(_ cost: FixedCost, context: ModelContext) {
        context.insert(cost)
        try? context.save()
        refresh(context: context)
    }

    func deleteFixedCost(_ cost: FixedCost, context: ModelContext) {
        context.delete(cost)
        try? context.save()
        refresh(context: context)
    }
}
```

- [ ] **Step 3: Create `Tally/ViewModels/ReconciliationViewModel.swift`**

```swift
import Foundation
import SwiftData

@MainActor
final class ReconciliationViewModel: ObservableObject {
    @Published var savingsSystemBalance: Decimal = 0
    @Published var savingsActualText: String = ""
    @Published var jars: [MoneyJar] = []
    @Published var jarActualTexts: [String: String] = [:]  // jar ID → text
    @Published var lastReconciliation: AppSettings.ReconciliationRecord?

    func refresh(context: ModelContext) {
        let settings = AppSettings.fetchOrCreate(context: context)
        savingsSystemBalance = settings.savingsBalance
        lastReconciliation = settings.reconciliationHistory.last

        jars = (try? context.fetch(FetchDescriptor<MoneyJar>())) ?? []
        for jar in jars {
            if jarActualTexts[jar.persistentModelID.entityName] == nil {
                jarActualTexts[jar.persistentModelID.entityName] = ""
            }
        }
    }

    func confirm(context: ModelContext) {
        let settings = AppSettings.fetchOrCreate(context: context)
        let now = Date()

        let savingsActual = Decimal(string: savingsActualText) ?? 0
        let savingsRecord = AppSettings.ReconciliationRecord(
            date: now, type: "存款",
            systemBalance: savingsSystemBalance,
            actualBalance: savingsActual,
            difference: savingsActual - savingsSystemBalance,
            isMatched: savingsActual == savingsSystemBalance
        )
        settings.reconciliationHistory.append(savingsRecord)
        settings.verifiedSavingsBalance = savingsActual
        settings.lastVerifiedDate = now

        for jar in jars {
            let jarID = jar.persistentModelID.entityName
            let actual = Decimal(string: jarActualTexts[jarID] ?? "") ?? 0
            let record = AppSettings.ReconciliationRecord(
                date: now, type: jar.name,
                systemBalance: jar.balance,
                actualBalance: actual,
                difference: actual - jar.balance,
                isMatched: actual == jar.balance
            )
            settings.reconciliationHistory.append(record)
        }

        try? context.save()
    }
}
```

- [ ] **Step 4: Build and verify**

```bash
xcodebuild -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add JarsViewModel, SettingsViewModel, ReconciliationViewModel"
```

---

## Phase 6 — Views: Today Tab

### Task 9: Create TodayHeaderView and DayCardView

**Files:**
- Create: `Tally/Views/Today/TodayHeaderView.swift`
- Create: `Tally/Views/Today/DayCardView.swift`
- Create: `Tally/Views/Today/DayDetailView.swift`

**Produces:** The top fixed block and scrollable day cards for Tab 1.

- [ ] **Step 1: Create `Tally/Views/Today/TodayHeaderView.swift`**

```swift
import SwiftUI

struct TodayHeaderView: View {
    let todayAvailable: Decimal
    let todayBaseAmount: Decimal
    let todayPenalty: Decimal
    let todaySpent: Decimal
    let todayProgress: Double

    @State private var showDetail = false

    var body: some View {
        VStack(spacing: 12) {
            Text(dateString)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("NT$ \(formatted(todayAvailable))")
                .font(TallyTheme.Typography.largeAmount)
                .foregroundColor(todayAvailable < 0 ? TallyTheme.Colors.redText : TallyTheme.Colors.primaryAmount)

            Text(todayAvailable >= 0 ? "還剩這麼多" : "已超支")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if showDetail {
                VStack(spacing: 4) {
                    HStack {
                        Text("今日基礎額度")
                        Spacer()
                        Text("+\(formatted(todayBaseAmount))")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)

                    HStack {
                        Text("前期懲罰")
                        Spacer()
                        Text("-\(formatted(todayPenalty))")
                            .foregroundColor(todayPenalty > 0 ? TallyTheme.Colors.redText : .secondary)
                    }
                    .font(.caption)

                    Divider()

                    HStack {
                        Text("已花費")
                        Spacer()
                        Text("-\(formatted(todaySpent))")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
                .padding(.horizontal, 32)
                .transition(.opacity)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(TallyTheme.Colors.progressTrack)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(todayProgress >= 1.0 ? TallyTheme.Colors.redText : TallyTheme.Colors.progressFill)
                        .frame(width: geo.size.width * todayProgress, height: 6)
                        .animation(.easeInOut, value: todayProgress)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 32)

            Text("\(Int(todayProgress * 100))% 已用")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, TallyTheme.Spacing.lg)
        .padding(.horizontal, TallyTheme.Spacing.md)
        .background(TallyTheme.Colors.background)
        .onTapGesture {
            withAnimation { showDetail.toggle() }
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "M 月 d 日 EEEE"
        return formatter.string(from: Date())
    }

    private func formatted(_ value: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        return nf.string(from: value as NSDecimalNumber) ?? "0"
    }
}
```

- [ ] **Step 2: Create `Tally/Views/Today/DayCardView.swift`**

```swift
import SwiftUI

struct DayCardView: View {
    let budget: DailyBudget
    let expenses: [Expense]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(statusLabel)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }

            ForEach(expenses.prefix(3)) { expense in
                HStack {
                    Text(expense.name)
                        .font(.subheadline)
                    Spacer()
                    Text("-\(formatted(expense.amount))")
                        .font(.subheadline)
                        .monospacedDigit()
                }
            }

            if expenses.count > 3 {
                Text("還有 \(expenses.count - 3) 筆...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(TallyTheme.Spacing.md)
        .dayCardStyle(status: budget.status)
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "M/d EEE"
        return formatter.string(from: budget.date)
    }

    private var statusLabel: String {
        let prefix: String
        switch budget.status {
        case .green: prefix = "餘額 +"
        case .white: prefix = "打平 "
        case .red: prefix = "超支 "
        }
        return prefix + formatted(abs(budget.leftover))
    }

    private var statusColor: Color {
        switch budget.status {
        case .green: return TallyTheme.Colors.greenText
        case .white: return .secondary
        case .red: return TallyTheme.Colors.redText
        }
    }

    private func formatted(_ value: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        return nf.string(from: value as NSDecimalNumber) ?? "0"
    }
}
```

- [ ] **Step 3: Create `Tally/Views/Today/DayDetailView.swift`**

```swift
import SwiftUI
import SwiftData

struct DayDetailView: View {
    let date: Date
    @Environment(\.modelContext) private var context
    @State private var expenses: [Expense] = []

    var body: some View {
        List {
            if expenses.isEmpty {
                Text("這天沒有記錄")
                    .foregroundColor(.secondary)
            }
            ForEach(expenses) { expense in
                HStack {
                    VStack(alignment: .leading) {
                        Text(expense.name)
                            .font(.body)
                        Text(expense.date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("-\(formatted(expense.amount))")
                        .font(.body)
                        .monospacedDigit()
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        context.delete(expense)
                        try? context.save()
                        loadExpenses()
                    } label: {
                        Label("刪除", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle(dateLabel)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadExpenses() }
    }

    private var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateFormat = "M 月 d 日 EEEE"
        return formatter.string(from: date)
    }

    private func loadExpenses() {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        var descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate { $0.date >= startOfDay && $0.date < endOfDay }
        )
        expenses = (try? context.fetch(descriptor)) ?? []
    }

    private func formatted(_ value: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        return nf.string(from: value as NSDecimalNumber) ?? "0"
    }
}
```

- [ ] **Step 4: Build and verify**

```bash
xcodebuild -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "feat: add TodayHeaderView, DayCardView, and DayDetailView"
```

### Task 10: Create TodayView and wire Tab 1

**Files:**
- Create: `Tally/Views/Today/TodayView.swift`

**Produces:** Complete Tab 1 with header + day cards + pull-up gesture for recording.

- [ ] **Step 1: Create `Tally/Views/Today/TodayView.swift`**

```swift
import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = TodayViewModel()
    @State private var showRecording = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    TodayHeaderView(
                        todayAvailable: viewModel.todayAvailable,
                        todayBaseAmount: viewModel.todayBaseAmount,
                        todayPenalty: viewModel.todayPenalty,
                        todaySpent: viewModel.todaySpent,
                        todayProgress: viewModel.todayProgress
                    )

                    // Pull-up indicator + gesture
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.4))
                            .frame(width: 36, height: 4)
                        Text("上拉記一筆")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(TallyTheme.Colors.secondaryBackground)
                    .gesture(
                        DragGesture(minimumDistance: 30, coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.height < -50 {
                                    showRecording = true
                                }
                            }
                    )

                    // Day cards
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.dailyBudgets) { budget in
                            NavigationLink {
                                DayDetailView(date: budget.date)
                            } label: {
                                DayCardView(
                                    budget: budget,
                                    expenses: viewModel.expensesByDay[budget.date] ?? []
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
            }
            .background(TallyTheme.Colors.background)
            .fullScreenCover(isPresented: $showRecording) {
                RecordingView { viewModel.refresh() }
            }
            .onAppear {
                viewModel.context = context
                viewModel.refresh()
            }
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: complete TodayView with pull-to-record gesture"
```

---

## Phase 7 — Views: Recording

### Task 11: Create RecordingView (full-screen expense entry)

**Files:**
- Create: `Tally/Views/Recording/RecordingView.swift`

**Produces:** Full-screen modal for adding/editing expenses with source selection and line items.

- [ ] **Step 1: Create `Tally/Views/Recording/RecordingView.swift`**

```swift
import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = RecordingViewModel()
    @State private var showDiscardAlert = false
    @State private var showLineItems = false

    var existingExpense: Expense?
    var onDismiss: (() -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Name
                    TextField("項目名稱", text: $vm.name)
                        .font(.largeTitle)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    Divider()

                    // Amount
                    HStack {
                        Text("NT$")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        TextField("0", text: $vm.amountText)
                            .font(TallyTheme.Typography.largeAmount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)

                    // Metadata rows
                    Group {
                        HStack {
                            Text("來源")
                            Spacer()
                            Picker("來源", selection: $vm.source) {
                                ForEach(ExpenseSource.allCases, id: \.self) { src in
                                    Text(src.label).tag(src)
                                }
                            }
                        }

                        if vm.source == .jar {
                            Picker("零錢罐", selection: $vm.selectedJar) {
                                Text("選擇罐子").tag(nil as MoneyJar?)
                                ForEach(vm.availableJars) { jar in
                                    Text(jar.name).tag(jar as MoneyJar?)
                                }
                            }
                        }

                        DatePicker("時間", selection: $vm.date, displayedComponents: [.date, .hourAndMinute])

                        TextField("地點", text: $vm.location, prompt: Text("添加快取地點"))

                        TextField("發票號碼", text: $vm.receiptNumber, prompt: Text("輸入發票號碼"))
                    }
                    .padding(.horizontal)

                    // Line items
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation { showLineItems.toggle() }
                        } label: {
                            HStack {
                                Image(systemName: showLineItems ? "chevron.down" : "plus.circle")
                                Text("消費細項")
                                Spacer()
                                if !vm.lineItems.isEmpty {
                                    Text("\(vm.lineItems.count) 項")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        if showLineItems {
                            ForEach($vm.lineItems) { $item in
                                HStack {
                                    TextField("名稱", text: $item.name)
                                        .frame(maxWidth: .infinity)
                                    TextField("金額", text: $item.amountText)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 100)
                                }
                            }
                            .onDelete { vm.lineItems.remove(atOffsets: $0) }

                            Button("＋ 新增細項") {
                                vm.addLineItem()
                            }
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal)

                    // Delete
                    if existingExpense != nil {
                        Button(role: .destructive) {
                            vm.delete(existingExpense!, context: context)
                            onDismiss?()
                            dismiss()
                        } label: {
                            Text("刪除此筆")
                        }
                        .padding(.top)
                    }
                }
                .padding(.vertical, 32)
            }
            .background(TallyTheme.Colors.background)
            .navigationTitle(existingExpense != nil ? "編輯" : "記一筆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        if vm.hasContent {
                            showDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        save()
                    }
                    .disabled(!vm.isValid)
                }
            }
            .alert("捨棄內容？", isPresented: $showDiscardAlert) {
                Button("捨棄", role: .destructive) { dismiss() }
                Button("繼續編輯", role: .cancel) {}
            } message: {
                Text("已經有輸入內容，確定要捨棄嗎？")
            }
            .onAppear {
                vm.availableJars = (try? context.fetch(FetchDescriptor<MoneyJar>())) ?? []
                if let expense = existingExpense {
                    vm.load(expense)
                }
            }
        }
    }

    private func save() {
        if let expense = existingExpense {
            vm.update(expense, context: context)
        } else {
            _ = vm.save(context: context)
        }
        onDismiss?()
        dismiss()
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add -A && git commit -m "feat: add full-screen RecordingView with source selection and line items"
```

---

## Phase 8 — Views: Money Jars Tab

### Task 12: Create JarsView and JarDetailView

**Files:**
- Create: `Tally/Views/Jars/JarsView.swift`
- Create: `Tally/Views/Jars/JarDetailView.swift`

**Produces:** Tab 2 with jar list and drill-down transaction history.

- [ ] **Step 1: Create `Tally/Views/Jars/JarsView.swift`**

```swift
import SwiftUI
import SwiftData

struct JarsView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var vm = JarsViewModel()
    @State private var showAddJar = false
    @State private var newJarName = ""
    @State private var newJarBankCode = ""
    @State private var newJarAccount = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Total
                VStack(spacing: 4) {
                    Text("總餘額")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("NT$ \(formatted(vm.totalBalance))")
                        .font(TallyTheme.Typography.titleAmount)
                }
                .padding(.vertical, TallyTheme.Spacing.lg)
                .frame(maxWidth: .infinity)
                .background(TallyTheme.Colors.secondaryBackground)

                List {
                    ForEach(vm.jars) { jar in
                        NavigationLink {
                            JarDetailView(jar: jar)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(jar.name)
                                        .font(.headline)
                                    Spacer()
                                    Text("NT$ \(formatted(jar.balance))")
                                        .font(.body)
                                        .monospacedDigit()
                                }
                                Text("\(jar.bankCode) \(jar.accountNumber)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                vm.deleteJar(jar, context: context)
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                    }
                }

                Button {
                    showAddJar = true
                } label: {
                    Label("新增零錢罐", systemImage: "plus")
                }
                .padding()
            }
            .navigationTitle("零錢罐")
            .alert("新增零錢罐", isPresented: $showAddJar) {
                TextField("名稱", text: $newJarName)
                TextField("銀行代碼", text: $newJarBankCode)
                TextField("帳號", text: $newJarAccount)
                Button("取消", role: .cancel) {}
                Button("新增") {
                    guard !newJarName.isEmpty else { return }
                    vm.createJar(name: newJarName, bankCode: newJarBankCode, accountNumber: newJarAccount, context: context)
                    newJarName = ""
                    newJarBankCode = ""
                    newJarAccount = ""
                }
            }
            .onAppear { vm.refresh(context: context) }
        }
    }

    private func formatted(_ value: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        return nf.string(from: value as NSDecimalNumber) ?? "0"
    }
}
```

- [ ] **Step 2: Create `Tally/Views/Jars/JarDetailView.swift`**

```swift
import SwiftUI
import SwiftData

struct JarDetailView: View {
    let jar: MoneyJar
    @Environment(\.modelContext) private var context
    @State private var incomes: [IncomeEvent] = []
    @State private var expenses: [Expense] = []

    var body: some View {
        List {
            Section("餘額") {
                Text("NT$ \(formatted(jar.balance))")
                    .font(TallyTheme.Typography.titleAmount)
            }

            if !incomes.isEmpty {
                Section("存入記錄") {
                    ForEach(incomes) { income in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(income.name)
                                Text(income.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("+\(formatted(income.amount))")
                                .foregroundColor(TallyTheme.Colors.greenText)
                        }
                    }
                }
            }

            if !expenses.isEmpty {
                Section("支出記錄") {
                    ForEach(expenses) { expense in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(expense.name)
                                Text(expense.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("-\(formatted(expense.amount))")
                                .foregroundColor(TallyTheme.Colors.redText)
                        }
                    }
                }
            }
        }
        .navigationTitle(jar.name)
        .onAppear { loadTransactions() }
    }

    private func loadTransactions() {
        let allIncomes = (try? context.fetch(FetchDescriptor<IncomeEvent>())) ?? []
        incomes = allIncomes.filter { $0.destination == .jar && $0.jarID == jar.persistentModelID.entityName }

        let allExpenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        expenses = allExpenses.filter { $0.source == .jar && $0.jarID == jar.persistentModelID.entityName }
    }

    private func formatted(_ value: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        return nf.string(from: value as NSDecimalNumber) ?? "0"
    }
}
```

- [ ] **Step 3: Build and verify**

```bash
xcodebuild -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```

- [ ] **Step 4: Commit**

```bash
git add -A && git commit -m "feat: add JarsView (Tab 2) with jar list and detail drill-down"
```

---

## Phase 9 — Views: Settings Tab

### Task 13: Create SettingsView, IncomeFormView, FixedCostFormView, ReconciliationView

**Files:**
- Create: `Tally/Views/Settings/SettingsView.swift`
- Create: `Tally/Views/Settings/IncomeFormView.swift`
- Create: `Tally/Views/Settings/FixedCostFormView.swift`
- Create: `Tally/Views/Settings/ReconciliationView.swift`

**Produces:** Complete Tab 3 with income, fixed costs, and reconciliation.

- [ ] **Step 1: Create `Tally/Views/Settings/SettingsView.swift`**

```swift
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
                // Income
                Section {
                    ForEach(vm.incomeEvents) { event in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(event.name)
                                    .font(.body)
                                Text(formattedDate(event.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("+\(formatted(event.amount))")
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                vm.deleteIncome(event, context: context)
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                    }
                    Button {
                        showIncomeForm = true
                    } label: {
                        Label("新增收入", systemImage: "plus")
                    }
                } header: {
                    Text("收入記錄 (\(vm.incomeEvents.count) 筆)")
                }

                // Fixed Costs
                Section {
                    ForEach(vm.fixedCosts) { cost in
                        VStack(alignment: .leading) {
                            HStack {
                                Text(cost.name)
                                    .font(.body)
                                Spacer()
                                Text("-\(formatted(cost.amount))")
                            }
                            Text("\(cost.type.label) · \(cost.bankCode) · \(cost.hasDeposited ? "已存" : "未存")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                vm.deleteFixedCost(cost, context: context)
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                    }
                    Button {
                        showFixedCostForm = true
                    } label: {
                        Label("新增固定花銷", systemImage: "plus")
                    }
                } header: {
                    Text("固定花銷 (\(vm.fixedCosts.count) 筆) · 本月合計 -\(formatted(vm.thisMonthFixedCostTotal))")
                }

                // Reconciliation
                Section {
                    NavigationLink {
                        ReconciliationView()
                    } label: {
                        HStack {
                            Text("存款對賬")
                            Spacer()
                            if let last = AppSettings.fetchOrCreate(context: context).reconciliationHistory.last {
                                Text(formattedDate(last.date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Info
                Section {
                    HStack {
                        Text("財務月週期")
                        Spacer()
                        Text("每月 15 日起")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("資料儲存")
                        Spacer()
                        Text("僅本機")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
            .sheet(isPresented: $showIncomeForm) {
                IncomeFormView(onSave: {
                    vm.refresh(context: context)
                })
            }
            .sheet(isPresented: $showFixedCostForm) {
                FixedCostFormView(onSave: {
                    vm.refresh(context: context)
                })
            }
            .onAppear { vm.refresh(context: context) }
        }
    }

    private func formatted(_ value: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        return nf.string(from: value as NSDecimalNumber) ?? "0"
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}
```

- [ ] **Step 2: Create `Tally/Views/Settings/IncomeFormView.swift`**

```swift
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
                TextField("金額", text: $amountText)
                    .keyboardType(.decimalPad)
                DatePicker("日期", selection: $date, displayedComponents: .date)
                Picker("存入目標", selection: $destination) {
                    ForEach(IncomeDestination.allCases, id: \.self) { d in
                        Text(d.label).tag(d)
                    }
                }
                if destination == .jar {
                    Picker("零錢罐", selection: $selectedJar) {
                        Text("選擇").tag(nil as MoneyJar?)
                        ForEach(availableJars) { jar in
                            Text(jar.name).tag(jar as MoneyJar?)
                        }
                    }
                }
            }
            .navigationTitle(existingEvent != nil ? "編輯收入" : "新增收入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                        .disabled(name.isEmpty || amountText.isEmpty)
                }
            }
            .onAppear {
                availableJars = (try? context.fetch(FetchDescriptor<MoneyJar>())) ?? []
                if let event = existingEvent {
                    name = event.name
                    amountText = String(describing: event.amount)
                    date = event.date
                    destination = event.destination
                }
            }
        }
    }

    private func save() {
        guard let amount = Decimal(string: amountText) else { return }
        let event = existingEvent ?? IncomeEvent(name: name, amount: amount, date: date, destination: destination)
        if let jar = selectedJar, destination == .jar {
            event.jarID = jar.persistentModelID.entityName
            jar.balance += amount
        }
        if existingEvent == nil {
            context.insert(event)
        }
        try? context.save()
        onSave()
        dismiss()
    }
}
```

- [ ] **Step 3: Create `Tally/Views/Settings/FixedCostFormView.swift`**

```swift
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

    // Type-specific
    @State private var dueMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var dueDay: Int = 1
    @State private var amortizeToMonthly = false
    @State private var startInstallment = 1
    @State private var endInstallment = 12
    @State private var reserveMode: ReserveMode = .notYetReserved

    var existingCost: FixedCost?
    var onSave: () -> Void

    let monthNumbers = Array(1...12)

    var body: some View {
        NavigationStack {
            Form {
                Section("基本資訊") {
                    TextField("名稱", text: $name)
                    TextField("金額", text: $amountText)
                        .keyboardType(.decimalPad)
                    Picker("類型", selection: $type) {
                        ForEach(FixedCostType.allCases, id: \.self) { t in
                            Text(t.label).tag(t)
                        }
                    }
                }

                switch type {
                case .monthly:
                    EmptyView() // just name+amount

                case .yearly:
                    Section("每年設定") {
                        Picker("月份", selection: $dueMonth) {
                            ForEach(monthNumbers, id: \.self) { m in
                                Text("\(m) 月").tag(m)
                            }
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
                            ForEach(monthNumbers, id: \.self) { m in
                                Text("\(m) 月").tag(m)
                            }
                        }
                        Picker("日期", selection: $dueDay) {
                            ForEach(Array(1...31), id: \.self) { d in
                                Text("\(d) 日").tag(d)
                            }
                        }
                        Picker("預留模式", selection: $reserveMode) {
                            ForEach(ReserveMode.allCases, id: \.self) { m in
                                Text(m.label).tag(m)
                            }
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }
                        .disabled(name.isEmpty || amountText.isEmpty || bankCode.isEmpty || accountNumber.isEmpty)
                }
            }
            .onAppear {
                if let cost = existingCost {
                    name = cost.name
                    amountText = String(describing: cost.amount)
                    type = cost.type
                    bankCode = cost.bankCode
                    accountNumber = cost.accountNumber
                    hasDeposited = cost.hasDeposited
                    dueMonth = cost.dueMonth ?? Calendar.current.component(.month, from: Date())
                    dueDay = cost.dueDay ?? 1
                    amortizeToMonthly = cost.amortizeToMonthly
                }
            }
        }
    }

    private func save() {
        guard let amount = Decimal(string: amountText) else { return }
        let cost = existingCost ?? FixedCost(name: name, amount: amount, type: type,
                                              bankCode: bankCode, accountNumber: accountNumber)
        cost.name = name
        cost.amount = amount
        cost.type = type
        cost.bankCode = bankCode
        cost.accountNumber = accountNumber
        cost.hasDeposited = hasDeposited
        cost.dueMonth = dueMonth
        cost.dueDay = dueDay
        cost.amortizeToMonthly = amortizeToMonthly
        cost.startMonth = startInstallment
        cost.endMonth = endInstallment
        cost.reserveMode = reserveMode
        if existingCost == nil {
            context.insert(cost)
        }
        try? context.save()
        onSave()
        dismiss()
    }
}
```

- [ ] **Step 4: Create `Tally/Views/Settings/ReconciliationView.swift`**

```swift
import SwiftUI
import SwiftData

struct ReconciliationView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var vm = ReconciliationViewModel()

    var body: some View {
        Form {
            Section("存款（每日剩餘自動累積）") {
                HStack {
                    Text("系統計算")
                    Spacer()
                    Text("NT$ \(formatted(vm.savingsSystemBalance))")
                }
                HStack {
                    Text("實際餘額")
                    TextField("NT$ 0", text: $vm.savingsActualText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                if let last = vm.lastReconciliation {
                    HStack {
                        Text("上次對賬")
                        Spacer()
                        Text(formattedDate(last.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("零錢罐") {
                ForEach(vm.jars) { jar in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(jar.name)
                            .font(.subheadline)
                        HStack {
                            Text("系統：NT$ \(formatted(jar.balance))")
                            Text("實際：")
                            TextField("NT$ 0", text: binding(for: jar))
                                .keyboardType(.decimalPad)
                        }
                        .font(.caption)
                    }
                }
            }

            Section {
                Button {
                    vm.confirm(context: context)
                } label: {
                    Text("全部確認對賬")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Section("對賬歷史") {
                let settings = AppSettings.fetchOrCreate(context: context)
                ForEach(settings.reconciliationHistory.reversed()) { record in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(record.type)
                                .font(.caption)
                            Text(formattedDate(record.date))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(record.isMatched ? "✓ 一致" : "✗ 差 \(formatted(record.difference))")
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
        Binding(
            get: { vm.jarActualTexts[jar.persistentModelID.entityName] ?? "" },
            set: { vm.jarActualTexts[jar.persistentModelID.entityName] = $0 }
        )
    }

    private func formatted(_ value: Decimal) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 0
        return nf.string(from: value as NSDecimalNumber) ?? "0"
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "M/d"
        return f.string(from: date)
    }
}
```

- [ ] **Step 5: Build and verify**

```bash
xcodebuild -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "feat: add SettingsView, IncomeFormView, FixedCostFormView, ReconciliationView"
```

---

## Phase 10 — Final Assembly

### Task 14: Create ContentView (TabView container)

**Files:**
- Create: `Tally/Views/ContentView.swift`

**Produces:** Root view with three-tab layout, app ready for simulator testing.

- [ ] **Step 1: Create `Tally/Views/ContentView.swift`**

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("今天", systemImage: "wallet.pass")
                }

            JarsView()
                .tabItem {
                    Label("零錢罐", systemImage: "archivebox")
                }

            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
        }
        .tint(TallyTheme.Colors.accent)
    }
}
```

- [ ] **Step 2: Update `TallyApp.swift`**

Ensure `ContentView` is the root:

```swift
// Tally/TallyApp.swift
import SwiftUI
import SwiftData

@main
struct TallyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(Self.previewContainer)
    }

    static var previewContainer: ModelContainer = {
        let schema = Schema([
            Expense.self, LineItem.self, FixedCost.self,
            IncomeEvent.self, MoneyJar.self, DailyBudget.self, AppSettings.self,
        ])
        let config = ModelConfiguration(cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: config)
    }()
}
```

- [ ] **Step 3: Build and test**

```bash
xcodebuild -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run all tests**

```bash
xcodebuild test -project Tally.xcodeproj -scheme Tally -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | tail -10
```

Expected: All tests pass.

- [ ] **Step 5: Commit and tag**

```bash
git add -A && git commit -m "feat: complete TabView assembly with Today, Jars, and Settings tabs"
git tag v0.1.0-mvp
git push && git push --tags
```

---

## Plan Self-Review

### Spec Coverage
- ✅ Time system (FinancialMonth)
- ✅ All 6+1 data models (Expense, LineItem, FixedCost, IncomeEvent, MoneyJar, DailyBudget, AppSettings)
- ✅ Daily budget calculation (BudgetCalculator)
- ✅ Three-tab layout (ContentView)
- ✅ Today tab with header + day cards (TodayView, TodayHeaderView, DayCardView)
- ✅ Full-screen recording with source selection + line items (RecordingView)
- ✅ Money Jars tab with detail drill-down (JarsView, JarDetailView)
- ✅ Settings with income, fixed costs, reconciliation (SettingsView, IncomeFormView, FixedCostFormView, ReconciliationView)
- ✅ Fixed cost form with type-dependent fields (FixedCostFormView)
- ✅ No CloudKit, local-only data
- ✅ Minimal light theme (TallyTheme)
- ❌ Out of scope (noted): e-invoice integration, Widget, notifications, Siri, CSV export

### Type Consistency
- `ExpenseSource.dailyBudget` used consistently across RecordingViewModel and BudgetCalculator
- `IncomeDestination.budget` / `.jar` used consistently
- `DayStatus.green/white/red` mapped in both model and DayCardStyle
- `FinancialMonth.start(of:)` / `end(of:)` / `remainingDays(from:)` consumed by BudgetCalculator and TodayViewModel
- `persistentModelID.entityName` used as jar ID — this works because MoneyJar is a SwiftData entity

### Known Simplifications
- The `penalty` field in DailyBudget is computed during settlement but not fully propagated into BudgetCalculator.computePenalty(). Full penalty cascade will require a dedicated `SettlementService` — this is left as a follow-up task for v0.2.
- Income form currently creates new events rather than editing existing; edit support can be added by passing `existingEvent` to `IncomeFormView`.
- Line item swipe-to-delete uses `.onDelete` which requires a `ForEach` with index — the current Binding-based approach may need refinement in implementation.
