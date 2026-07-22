import Foundation

enum FinancialMonth {
    static let startDay = 15
    static let calendar = Calendar.current

    static func start(of date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let day = components.day else { return date }
        if day >= startDay {
            return calendar.date(from: DateComponents(year: components.year, month: components.month, day: startDay))!
        } else {
            let prevMonth = calendar.date(byAdding: .month, value: -1, to: date)!
            let prevComps = calendar.dateComponents([.year, .month], from: prevMonth)
            return calendar.date(from: DateComponents(year: prevComps.year, month: prevComps.month, day: startDay))!
        }
    }

    static func end(of date: Date) -> Date {
        let startDate = start(of: date)
        return calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startDate)!
    }

    static func datesInPeriod(from startDate: Date, to endDate: Date) -> [Date] {
        var dates: [Date] = []
        var current = startOfDay(startDate)
        let end = startOfDay(endDate)
        while current <= end {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return dates
    }

    static func remainingDays(from date: Date) -> [Date] {
        let endDate = end(of: date)
        return datesInPeriod(from: startOfDay(date), to: endDate)
    }

    static func allDays(inContaining date: Date) -> [Date] {
        datesInPeriod(from: start(of: date), to: end(of: date))
    }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }
}
