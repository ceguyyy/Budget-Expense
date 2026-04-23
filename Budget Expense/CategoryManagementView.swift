//
//  CategoryManagementView.swift
//  Budget Expense
//

import SwiftUI

struct CategoryManagementView: View {
    @Environment(\.categoryManager) private var categoryManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedType: TransactionType = .outflow
    @State private var showAddCategory = false
    @State private var showEditCategory: ExpenseCategory?
    @State private var showDeleteAlert = false
    @State private var categoryToDelete: ExpenseCategory?
    @State private var showResetAlert = false
    
    private var currentCategories: [ExpenseCategory] {
        categoryManager.categoriesForType(selectedType)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Type Selector
                    typeSelector
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                    
                    // Category List
                    if currentCategories.isEmpty {
                        emptyState
                    } else {
                        categoryList
                    }
                }
            }
            .navigationTitle("Manage Categories")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.neonGreen)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showAddCategory = true }) {
                            Label("Add Category", systemImage: "plus.circle")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: { showResetAlert = true }) {
                            Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.neonGreen)
                    }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                AddEditCategoryView(type: selectedType)
            }
            .sheet(item: $showEditCategory) { category in
                AddEditCategoryView(category: category)
            }
            .alert("Delete Category", isPresented: $showDeleteAlert, presenting: categoryToDelete) { category in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    categoryManager.deleteCategory(category)
                }
            } message: { category in
                Text("Are you sure you want to delete '\(category.name)'?")
            }
            .alert("Reset Categories", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    categoryManager.resetToDefaults()
                }
            } message: {
                Text("This will remove all custom categories and restore defaults. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Type Selector
    
    private var typeSelector: some View {
        HStack(spacing: 10) {
            typeButton(.inflow, "Inflow", "arrow.down.circle.fill", .neonGreen)
            typeButton(.outflow, "Outflow", "arrow.up.circle.fill", .neonRed)
        }
    }
    
    @ViewBuilder
    private func typeButton(_ type: TransactionType, _ label: String, _ icon: String, _ color: Color) -> some View {
        Button {
            withAnimation(.spring(duration: 0.2)) {
                selectedType = type
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(selectedType == type ? color : Color(white: 0.3))
                Text(label)
                    .font(.subheadline.weight(selectedType == type ? .semibold : .regular))
                    .foregroundStyle(selectedType == type ? .white : Color(white: 0.38))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassEffect(selectedType == type ? .regular.tint(color) : .regular, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Category List
    
    private var categoryList: some View {
        List {
            ForEach(currentCategories) { category in
                CategoryRow(category: category)
                    .listRowBackground(Color(white: 0.12))
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !category.isDefault {
                            Button(role: .destructive) {
                                categoryToDelete = category
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        
                        Button {
                            showEditCategory = category
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.orange)
                    }
                    .onTapGesture {
                        showEditCategory = category
                    }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundStyle(.glassText)
            
            Text("No Categories")
                .font(.title3.bold())
                .foregroundStyle(.white)
            
            Text("Add your first category using the + button")
                .font(.subheadline)
                .foregroundStyle(.glassText)
                .multilineTextAlignment(.center)
            
            Button {
                showAddCategory = true
            } label: {
                Label("Add Category", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glassProminent)
            .padding(.top, 8)
            
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: ExpenseCategory
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(white: 0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: category.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(category.type == .inflow ? .neonGreen : .neonRed)
            }
            
            // Name
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                
                if category.isDefault {
                    Text("Default")
                        .font(.caption)
                        .foregroundStyle(.glassText)
                }
            }
            
            Spacer()
            
            // Edit indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.glassText)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add/Edit Category View

struct AddEditCategoryView: View {
    @Environment(\.categoryManager) private var categoryManager
    @Environment(\.dismiss) private var dismiss
    
    let editingCategory: ExpenseCategory?
    let transactionType: TransactionType
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "circle.fill"
    @State private var showIconPicker = false
    
    private var isEditing: Bool {
        editingCategory != nil
    }
    
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // Predefined icon options
    private let iconOptions = [
        "circle.fill", "star.fill", "heart.fill", "tag.fill",
        "folder.fill", "doc.fill", "book.fill", "cart.fill",
        "bag.fill", "gift.fill", "house.fill", "building.2.fill",
        "car.fill", "airplane", "bicycle", "tram.fill",
        "fork.knife", "cup.and.saucer.fill", "mug.fill", "wineglass.fill",
        "cross.case.fill", "pills.fill", "stethoscope", "heart.text.square.fill",
        "gamecontroller.fill", "tv.fill", "music.note", "headphones",
        "cart.fill.badge.plus", "creditcard.fill", "banknote.fill", "dollarsign.circle.fill",
        "graduationcap.fill", "backpack.fill", "pencil", "book.closed.fill",
        "pawprint.fill", "leaf.fill", "flame.fill", "drop.fill"
    ]
    
    init(category: ExpenseCategory? = nil, type: TransactionType = .outflow) {
        self.editingCategory = category
        self.transactionType = category?.type ?? type
        _name = State(initialValue: category?.name ?? "")
        _selectedIcon = State(initialValue: category?.icon ?? "circle.fill")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Icon Preview
                        iconPreview
                        
                        // Name Field
                        nameField
                        
                        // Icon Grid
                        iconGrid
                        
                        // Save Button
                        saveButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle(isEditing ? "Edit Category" : "New Category")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.glassText)
                }
            }
        }
    }
    
    // MARK: - Icon Preview
    
    private var iconPreview: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(white: 0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: selectedIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(transactionType == .inflow ? .neonGreen : .neonRed)
            }
            
            Text(transactionType == .inflow ? "Inflow Category" : "Outflow Category")
                .font(.caption)
                .foregroundStyle(.glassText)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Name Field
    
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("CATEGORY NAME", systemImage: "tag")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.glassText)
                .kerning(0.8)
            
            TextField("e.g. Groceries, Salary...", text: $name)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(.white)
                .padding(14)
                .glassEffect(in: .rect(cornerRadius: 14))
        }
    }
    
    // MARK: - Icon Grid
    
    private var iconGrid: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("SELECT ICON", systemImage: "photo.on.rectangle.angled")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.glassText)
                .kerning(0.8)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(iconOptions, id: \.self) { icon in
                    iconButton(icon)
                }
            }
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 14))
        }
    }
    
    @ViewBuilder
    private func iconButton(_ icon: String) -> some View {
        Button {
            withAnimation(.spring(duration: 0.2)) {
                selectedIcon = icon
            }
        } label: {
            ZStack {
                Circle()
                    .fill(selectedIcon == icon ? (transactionType == .inflow ? Color.neonGreen.opacity(0.2) : Color.neonRed.opacity(0.2)) : Color(white: 0.12))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(selectedIcon == icon ? (transactionType == .inflow ? .neonGreen : .neonRed) : .glassText)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text(isEditing ? "Save Changes" : "Add Category")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
        }
        .buttonStyle(.glassProminent)
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.38)
    }
    
    // MARK: - Actions
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        if let category = editingCategory {
            categoryManager.updateCategory(category, name: trimmedName, icon: selectedIcon)
        } else {
            categoryManager.addCategory(name: trimmedName, icon: selectedIcon, type: transactionType)
        }
        
        dismiss()
    }
}

// MARK: - Preview

#Preview("Category Management") {
    let categoryManager = CategoryManager()
    CategoryManagementView()
        .environment(\.categoryManager, categoryManager)
}

#Preview("Add Category") {
    let categoryManager = CategoryManager()
    AddEditCategoryView(type: .outflow)
        .environment(\.categoryManager, categoryManager)
}
