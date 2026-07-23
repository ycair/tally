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
                    TextField("項目名稱", text: $vm.name)
                        .font(.largeTitle).multilineTextAlignment(.center).padding(.horizontal)
                    Divider()
                    HStack {
                        Text("NT$").font(.largeTitle).foregroundColor(.secondary)
                        TextField("0", text: $vm.amountText)
                            .font(TallyTheme.Typography.largeAmount)
                            .keyboardType(.decimalPad).multilineTextAlignment(.center)
                    }.padding(.horizontal)

                    Group {
                        HStack {
                            Text("來源")
                            Spacer()
                            Picker("來源", selection: $vm.source) {
                                ForEach(ExpenseSource.allCases, id: \.self) { s in
                                    Text(s.label).tag(s)
                                }
                            }
                        }
                        if vm.source == .jar {
                            Picker("零錢罐", selection: $vm.selectedJar) {
                                Text("選擇罐子").tag(nil as MoneyJar?)
                                ForEach(vm.availableJars) { Text($0.name).tag($0 as MoneyJar?) }
                            }
                        }
                        if vm.source == .fixedCost {
                            Picker("固定花銷", selection: $vm.selectedFixedCost) {
                                Text("選擇").tag(nil as FixedCost?)
                                ForEach(vm.availableFixedCosts) { cost in
                                    Text(cost.name).tag(cost as FixedCost?)
                                }
                            }
                        }
                        DatePicker("時間", selection: $vm.date, displayedComponents: [.date, .hourAndMinute])
                        TextField("地點", text: $vm.location, prompt: Text("添加快取地點"))
                        TextField("發票號碼", text: $vm.receiptNumber, prompt: Text("輸入發票號碼"))
                    }.padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Button { withAnimation { showLineItems.toggle() } } label: {
                            HStack {
                                Image(systemName: showLineItems ? "chevron.down" : "plus.circle")
                                Text("消費細項")
                                Spacer()
                                if !vm.lineItems.isEmpty { Text("\(vm.lineItems.count) 項").foregroundColor(.secondary) }
                            }
                        }
                        if showLineItems {
                            ForEach($vm.lineItems) { $item in
                                HStack {
                                    TextField("名稱", text: $item.name).frame(maxWidth: .infinity)
                                    TextField("金額", text: $item.amountText).keyboardType(.decimalPad).frame(width: 100)
                                }
                            }
                            .onDelete { vm.lineItems.remove(atOffsets: $0) }
                            Button("＋ 新增細項") { vm.addLineItem() }.font(.caption)
                        }
                    }.padding(.horizontal)

                    if existingExpense != nil {
                        Button(role: .destructive) {
                            vm.delete(existingExpense!, context: context)
                            NotificationCenter.default.post(name: .tallyDataChanged, object: nil)
                            onDismiss?(); dismiss()
                        } label: { Text("刪除此筆") }.padding(.top)
                    }
                }.padding(.vertical, 32)
            }
            .background(TallyTheme.Colors.background)
            .navigationTitle(existingExpense != nil ? "編輯" : "記一筆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { vm.hasContent ? (showDiscardAlert = true) : dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") { save() }.disabled(!vm.isValid)
                }
            }
            .alert("捨棄內容？", isPresented: $showDiscardAlert) {
                Button("捨棄", role: .destructive) { dismiss() }
                Button("繼續編輯", role: .cancel) {}
            } message: { Text("已經有輸入內容，確定要捨棄嗎？") }
            .onAppear {
                vm.availableJars = (try? context.fetch(FetchDescriptor<MoneyJar>())) ?? []
                vm.availableFixedCosts = (try? context.fetch(FetchDescriptor<FixedCost>())) ?? []
                if let e = existingExpense { vm.load(e) }
            }
        }
    }

    private func save() {
        if let e = existingExpense { vm.update(e, context: context) }
        else { _ = vm.save(context: context) }
        NotificationCenter.default.post(name: .tallyDataChanged, object: nil)
        onDismiss?(); dismiss()
    }
}
