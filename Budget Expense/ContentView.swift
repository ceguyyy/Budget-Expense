
//
//  ContentView.swift
//  Budget Expense
//

import SwiftUI

struct ContentView: View {
    @State private var store = AppStore()

    var body: some View {
        TabView {
            Tab("Overview", systemImage: "chart.bar.fill") {
                DashboardView()
            }
            Tab("Wallets", systemImage: "wallet.bifold") {
                DebitView()
            }
            Tab("Credit", systemImage: "creditcard.fill") {
                CreditCardListView()
            }
            Tab("Piutang", systemImage: "person.2.fill") {
                DebtListView()
            }
        }
        .environment(store)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
