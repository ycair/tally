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
                VStack(spacing: 4) {
                    Text("總餘額").font(.caption).foregroundColor(.secondary)
                    Text("NT$ \(formatted(vm.totalBalance))").font(TallyTheme.Typography.titleAmount)
                }
                .padding(.vertical, TallyTheme.Spacing.lg).frame(maxWidth: .infinity)
                .background(TallyTheme.Colors.secondaryBackground)

                List {
                    ForEach(vm.jars) { jar in
                        NavigationLink {
                            JarDetailView(jar: jar)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(jar.name).font(.headline)
                                    Spacer()
                                    Text("NT$ \(formatted(jar.balance))").font(.body).monospacedDigit()
                                }
                                Text("\(jar.bankCode) \(jar.accountNumber)").font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                vm.deleteJar(jar, context: context)
                            } label: { Label("刪除", systemImage: "trash") }
                        }
                    }
                }
                Button { showAddJar = true } label: {
                    Label("新增零錢罐", systemImage: "plus")
                }.padding()
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
                    newJarName = ""; newJarBankCode = ""; newJarAccount = ""
                }
            }
            .onAppear { vm.refresh(context: context) }
        }
    }

    private func formatted(_ v: Decimal) -> String {
        let nf = NumberFormatter(); nf.numberStyle = .decimal; nf.maximumFractionDigits = 0
        return nf.string(from: v as NSDecimalNumber) ?? "0"
    }
}
