import SwiftUI

enum TallyTheme {
    enum Colors {
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.secondarySystemBackground)

        static let greenCard = Color(red: 0.90, green: 0.97, blue: 0.90)
        static let greenText = Color(red: 0.15, green: 0.55, blue: 0.15)
        static let redCard = Color(red: 0.98, green: 0.90, blue: 0.90)
        static let redText = Color(red: 0.75, green: 0.15, blue: 0.15)

        static let accent = Color(red: 0.20, green: 0.45, blue: 0.85)
        static let progressTrack = Color(.systemGray5)
        static let progressFill = accent

        static let primaryAmount = Color(.label)
        static let secondaryAmount = Color(.secondaryLabel)
    }

    enum Typography {
        static let largeAmount: Font = .system(size: 48, weight: .medium, design: .rounded)
        static let titleAmount: Font = .system(size: 28, weight: .medium, design: .rounded)
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
    }
}

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
        case .white: return TallyTheme.Colors.background
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
