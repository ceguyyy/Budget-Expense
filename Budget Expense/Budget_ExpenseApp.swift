//
//  Budget_ExpenseApp.swift
//  Budget Expense
//
//  Created by Christian Gunawan on 23/04/26.
//

import SwiftUI

@main
struct Budget_ExpenseApp: App {
    @State private var authManager = AuthenticationManager()
    @State private var categoryManager = CategoryManager()
    
    var body: some Scene {
        WindowGroup {
            AuthenticationWrapper()
                .environment(\.authenticationManager, authManager)
                .environment(\.categoryManager, categoryManager)
                .ignoresSafeArea()
        }
    }
}
