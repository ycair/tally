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
                        todayProgress: viewModel.todayProgress)

                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.4))
                            .frame(width: 36, height: 4)
                        Text("上拉記一筆").font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12).frame(maxWidth: .infinity)
                    .background(TallyTheme.Colors.secondaryBackground)
                    .simultaneousGesture(DragGesture(minimumDistance: 20)
                        .onEnded { if $0.translation.height < -40 { showRecording = true } })

                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.dailyBudgets) { budget in
                            NavigationLink {
                                DayDetailView(date: budget.date)
                            } label: {
                                DayCardView(budget: budget,
                                    expenses: viewModel.expensesByDay[budget.date] ?? [])
                            }.buttonStyle(.plain)
                        }
                    }.padding(.horizontal).padding(.top, 8).padding(.bottom, 100)
                }
            }
            .background(TallyTheme.Colors.background)
            .fullScreenCover(isPresented: $showRecording) {
                RecordingView { viewModel.refresh() }
            }
            .onAppear { viewModel.context = context; viewModel.refresh() }
        }
    }
}
