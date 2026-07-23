import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @State private var viewModel = TodayViewModel()
    @State private var showRecording = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
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
                            Text("記一筆").font(.caption2).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 12).frame(maxWidth: .infinity)
                        .background(TallyTheme.Colors.secondaryBackground)

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

                // Floating + button
                Button {
                    showRecording = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(TallyTheme.Colors.accent)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .background(TallyTheme.Colors.background)
            .fullScreenCover(isPresented: $showRecording) {
                RecordingView { viewModel.refresh() }
            }
            .onAppear { viewModel.context = context; viewModel.refresh(); viewModel.startObserving() }
            .onDisappear { viewModel.stopObserving() }
        }
    }
}
