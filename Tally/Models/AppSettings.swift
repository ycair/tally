import Foundation
import SwiftData

struct ReconciliationRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var type: String
    var systemBalance: Decimal
    var actualBalance: Decimal
    var difference: Decimal
    var isMatched: Bool
}

@Model
final class AppSettings {
    @Attribute(.unique) var id: String = "singleton"
    var savingsBalance: Decimal = 0
    var verifiedSavingsBalance: Decimal?
    var lastVerifiedDate: Date?
    // Stored as JSON-encoded Data since SwiftData doesn't natively support arrays of Codable structs
    var reconciliationHistoryData: Data?

    var reconciliationHistory: [ReconciliationRecord] {
        get {
            guard let data = reconciliationHistoryData else { return [] }
            return (try? JSONDecoder().decode([ReconciliationRecord].self, from: data)) ?? []
        }
        set {
            reconciliationHistoryData = try? JSONEncoder().encode(newValue)
        }
    }

    init() {}

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
