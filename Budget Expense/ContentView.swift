import SwiftUI

struct ContentView: View {
    @State private var store = AppStore()
    @Environment(\.authenticationManager) private var authManager

    var body: some View {
        TabView {

            Tab("Overview", systemImage: "chart.bar.fill") {
                NavigationStack {
                    DashboardView()
                        .navigationTitle("Overview")
                }
            }

            Tab("Wallets", systemImage: "wallet.bifold") {
                NavigationStack {
                    DebitView()
                        .navigationTitle("Wallets")
                }
            }

            Tab("Credit", systemImage: "creditcard.fill") {
                NavigationStack {
                    CreditCardListView()
                        .navigationTitle("Credit Cards")
                }
            }

            Tab("Receivables", systemImage: "person.2.fill") {
                NavigationStack {
                    DebtListView()
                        .navigationTitle("Receivables")
                }
            }
            
            
            Tab("Settings", systemImage: "gear"){
                NavigationStack{
                    SettingView()
                        .navigationTitle("Settings")
                }
            }
            
        }
        .environment(store)
        .preferredColorScheme(.dark)

        // ✅ RESET ke native tab bar
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    ContentView()
        .environment(\.authenticationManager, AuthenticationManager())
}
