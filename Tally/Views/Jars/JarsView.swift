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
                    HStack(spacing: 24) {
                        NavigationLink {
                            SavingsDetailView()
                        } label: {
                            VStack(spacing: 2) {
                                Text("存款").font(.caption).foregroundColor(.secondary)
                                Text("NT$ \(formatted(vm.savingsBalance))").font(.headline).monospacedDigit()
                            }
                        }
                        .buttonStyle(.plain)
                        Divider().frame(height: 32)
                        VStack(spacing: 2) {
                            Text("零錢罐").font(.caption).foregroundColor(.secondary)
                            Text("NT$ \(formatted(vm.totalBalance))").font(.headline).monospacedDigit()
                        }
                    }
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

                    if !vm.fixedCosts.isEmpty {
                        Section("固定花銷專戶") {
                            ForEach(vm.fixedCosts) { cost in
                                NavigationLink {
                                    FixedCostDetailView(cost: cost)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(cost.name).font(.subheadline).fontWeight(.medium)
                                                Text("\(cost.bankCode) \(cost.accountNumber)")
                                                    .font(.caption).foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text("\(formatted(cost.depositedAmount)) / \(formatted(cost.amount))")
                                                    .font(.subheadline).monospacedDigit()
                                                Text(cost.hasDeposited ? "已存" : "未存")
                                                    .font(.caption2)
                                                    .foregroundColor(cost.hasDeposited ? TallyTheme.Colors.greenText : .orange)
                                                    .fontWeight(.medium)
                                            }
                                        }
                                    }
                                }
                            }
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
