import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("今天", systemImage: "wallet.pass") }
            JarsView()
                .tabItem { Label("零錢罐", systemImage: "archivebox") }
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .tint(TallyTheme.Colors.accent)
    }
}

#Preview {
    ContentView()
}
