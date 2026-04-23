//
//  CategoryManager.swift
//  Budget Expense
//

import SwiftUI

// MARK: - Category Model

struct ExpenseCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var type: TransactionType
    var isDefault: Bool // Default categories cannot be deleted
    var order: Int // For custom ordering
    
    init(id: UUID = UUID(), name: String, icon: String, type: TransactionType, isDefault: Bool = false, order: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.type = type
        self.isDefault = isDefault
        self.order = order
    }
}

// MARK: - Category Manager

@MainActor
@Observable
class CategoryManager {
    var categories: [ExpenseCategory] = []
    
    private let categoriesKey = "budget_expense_categories"
    
    init() {
        loadCategories()
    }
    
    // MARK: - Default Categories (Seeding Data)
    
    private var defaultInflowCategories: [ExpenseCategory] {
        [
            ExpenseCategory(name: "Salary", icon: "banknote.fill", type: .inflow, isDefault: true, order: 0),
            ExpenseCategory(name: "Transfer In", icon: "arrow.down.circle.fill", type: .inflow, isDefault: true, order: 1),
            ExpenseCategory(name: "Sales", icon: "cart.fill", type: .inflow, isDefault: true, order: 2),
            ExpenseCategory(name: "Refund", icon: "arrow.uturn.backward.circle.fill", type: .inflow, isDefault: true, order: 3),
            ExpenseCategory(name: "Gift", icon: "gift.fill", type: .inflow, isDefault: true, order: 4),
            ExpenseCategory(name: "Other", icon: "ellipsis.circle.fill", type: .inflow, isDefault: true, order: 5)
        ]
    }
    
    private var defaultOutflowCategories: [ExpenseCategory] {
        [
            ExpenseCategory(name: "Food", icon: "fork.knife", type: .outflow, isDefault: true, order: 0),
            ExpenseCategory(name: "Transport", icon: "car.fill", type: .outflow, isDefault: true, order: 1),
            ExpenseCategory(name: "Shopping", icon: "bag.fill", type: .outflow, isDefault: true, order: 2),
            ExpenseCategory(name: "Bills", icon: "doc.text.fill", type: .outflow, isDefault: true, order: 3),
            ExpenseCategory(name: "Entertainment", icon: "ticket.fill", type: .outflow, isDefault: true, order: 4),
            ExpenseCategory(name: "Health", icon: "cross.case.fill", type: .outflow, isDefault: true, order: 5),
            ExpenseCategory(name: "Education", icon: "book.fill", type: .outflow, isDefault: true, order: 6),
            ExpenseCategory(name: "Other", icon: "ellipsis.circle.fill", type: .outflow, isDefault: true, order: 7)
        ]
    }
    
    // MARK: - Load & Save
    
    func loadCategories() {
        if let data = UserDefaults.standard.data(forKey: categoriesKey),
           let decoded = try? JSONDecoder().decode([ExpenseCategory].self, from: data) {
            categories = decoded
        } else {
            // First time - seed with default categories
            seedDefaultCategories()
        }
    }
    
    func saveCategories() {
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
        }
    }
    
    private func seedDefaultCategories() {
        categories = defaultInflowCategories + defaultOutflowCategories
        saveCategories()
    }
    
    // MARK: - CRUD Operations
    
    func addCategory(name: String, icon: String, type: TransactionType) {
        let maxOrder = categories.filter { $0.type == type }.map(\.order).max() ?? -1
        let newCategory = ExpenseCategory(
            name: name,
            icon: icon,
            type: type,
            isDefault: false,
            order: maxOrder + 1
        )
        categories.append(newCategory)
        saveCategories()
    }
    
    func updateCategory(_ category: ExpenseCategory, name: String, icon: String) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index].name = name
        categories[index].icon = icon
        saveCategories()
    }
    
    func deleteCategory(_ category: ExpenseCategory) {
        // Cannot delete default categories
        guard !category.isDefault else { return }
        categories.removeAll { $0.id == category.id }
        saveCategories()
    }
    
    func reorderCategories(_ categories: [ExpenseCategory], type: TransactionType) {
        // Update order for the given type
        for (index, category) in categories.enumerated() {
            if let idx = self.categories.firstIndex(where: { $0.id == category.id }) {
                self.categories[idx].order = index
            }
        }
        saveCategories()
    }
    
    // MARK: - Query Methods
    
    func categoriesForType(_ type: TransactionType) -> [ExpenseCategory] {
        categories
            .filter { $0.type == type }
            .sorted { $0.order < $1.order }
    }
    
    func categoryNames(for type: TransactionType) -> [String] {
        categoriesForType(type).map(\.name)
    }
    
    func resetToDefaults() {
        // Remove all non-default categories and reset defaults
        categories.removeAll()
        seedDefaultCategories()
    }
}

// MARK: - Environment Key

struct CategoryManagerKey: EnvironmentKey {
    static let defaultValue = CategoryManager()
}

extension EnvironmentValues {
    var categoryManager: CategoryManager {
        get { self[CategoryManagerKey.self] }
        set { self[CategoryManagerKey.self] = newValue }
    }
}
