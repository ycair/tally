import SwiftUI

struct TodayHeaderView: View {
    let todayAvailable: Decimal
    let todayBaseAmount: Decimal
    let todayPenalty: Decimal
    let todaySpent: Decimal
    let todayProgress: Double
    let daysRemaining: Int
    let totalDays: Int
    @State private var showDetail = false

    var body: some View {
        VStack(spacing: 12) {
            Text(dateString)
                .font(.subheadline).foregroundColor(.secondary)
            Text("NT$ \(formatted(todayAvailable))")
                .font(TallyTheme.Typography.largeAmount)
                .foregroundColor(todayAvailable < 0 ? TallyTheme.Colors.redText : TallyTheme.Colors.primaryAmount)
            Text(todayAvailable >= 0 ? "還剩這麼多" : "已超支")
                .font(.subheadline).foregroundColor(.secondary)

            if showDetail {
                VStack(spacing: 4) {
                    detailRow("今日基礎額度", "+\(formatted(todayBaseAmount))", TallyTheme.Colors.secondaryAmount)
                    detailRow("前期懲罰", "-\(formatted(todayPenalty))",
                              todayPenalty > 0 ? TallyTheme.Colors.redText : TallyTheme.Colors.secondaryAmount)
                    Divider()
                    detailRow("已花費", "-\(formatted(todaySpent))", TallyTheme.Colors.secondaryAmount)
                }.padding(.horizontal, 32).transition(.opacity)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(TallyTheme.Colors.progressTrack).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(todayProgress >= 1.0 ? TallyTheme.Colors.redText : TallyTheme.Colors.progressFill)
                        .frame(width: geo.size.width * todayProgress, height: 6)
                        .animation(.easeInOut, value: todayProgress)
                }
            }.frame(height: 6).padding(.horizontal, 32)

            Text("\(Int(todayProgress * 100))% 已用")
                .font(.caption2).foregroundColor(.secondary)

            let daysPassed = totalDays - daysRemaining
            let monthRatio = totalDays > 0 ? Double(daysPassed) / Double(totalDays) : 0
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(TallyTheme.Colors.progressTrack)
                        .frame(height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: geo.size.width * monthRatio, height: 3)
                }
            }
            .frame(height: 3)
            .padding(.horizontal, 32)

            Text("本月第 \(daysPassed)/\(totalDays) 天 · 剩 \(daysRemaining) 天")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(.vertical, TallyTheme.Spacing.lg)
        .padding(.horizontal, TallyTheme.Spacing.md)
        .background(TallyTheme.Colors.background)
        .onTapGesture { withAnimation { showDetail.toggle() } }
    }

    private func detailRow(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundColor(color) }.font(.caption)
    }

    private var dateString: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "M 月 d 日 EEEE"; return f.string(from: Date())
    }

    private func formatted(_ v: Decimal) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .decimal; nf.maximumFractionDigits = 0
        return nf.string(from: v as NSDecimalNumber) ?? "0"
    }
}
