//
//  CreditCardListView.swift
//  Budget Expense
//

import SwiftUI

struct CreditCardListView: View {
    @Environment(AppStore.self) private var store
    @State private var showAdd = false
    @State private var editTarget: CreditCard?

    var body: some View {
        NavigationStack {
            ZStack {
                // ✅ background full
                Color.appBg
                    .ignoresSafeArea()

                if store.creditCards.isEmpty {
                    emptyState
                } else {
                    cardList
                }
            }
            .navigationTitle("Credit Cards")
            .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
                fab
            }
            .sheet(isPresented: $showAdd) {
                AddEditCreditCardView(editTarget: nil)
                    .environment(store)
            }
            .sheet(item: $editTarget) { card in
                AddEditCreditCardView(editTarget: card)
                    .environment(store)
            }
            
            
        }
    }

    // MARK: - List

    private var cardList: some View {
        List {
            ForEach(store.creditCards) { card in
                NavigationLink {
                    CreditCardDetailView(cardId: card.id)
                        .environment(store)
                } label: {
                    CreditCardListRow(card: card, store: store)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                // ✅ Context Menu untuk Edit via Long Press
                .contextMenu {
                    Button {
                        editTarget = card
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        store.deleteCreditCard(card.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        store.deleteCreditCard(card.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        editTarget = card
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                
            }

            // spacer biar gak ketiban FAB
            Color.clear
                .frame(height: 80)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - FAB

    private var fab: some View {
        Button {
            showAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color(red: 0.95, green: 0.4, blue: 0.2)) // Orange FAB
                .clipShape(Circle())
                .shadow(color: Color(red: 0.95, green: 0.4, blue: 0.2).opacity(0.4), radius: 8, x: 0, y: 4)
                .glassEffect(
                    .regular.tint(Color(white: 0.7)),
                    in: Circle()
                )
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(white: 0.07))
                    .frame(width: 96, height: 96)

                Image(systemName: "creditcard")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(white: 0.28))
            }

            VStack(spacing: 6) {
                Text("No Credit Cards Yet")
                    .font(.title3.bold())
                    .foregroundStyle(.white)

                Text("Tap + to add a credit card")
                    .font(.subheadline)
                    .foregroundStyle(.glassText)
            }

            Spacer()
        }
    }
}

// MARK: - Row

struct CreditCardListRow: View {
    let card: CreditCard
    let store: AppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Section: Bank Name and Icon
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.bank)
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.8))
                    Text(card.name)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
                
                Spacer()
                
                // Chip-like icon
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(colors: [Color(white: 0.8), Color(white: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 24)
                    .overlay(
                        VStack(spacing: 4) {
                            ForEach(0..<3) { _ in
                                Rectangle().fill(Color.black.opacity(0.1)).frame(height: 1)
                            }
                        }
                    )
            }
            .padding(.bottom, 20)
            
            // Middle Section: Outstanding / Bill
            VStack(alignment: .leading, spacing: 4) {
                Text("CURRENT BILL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .kerning(1)
                
                Text(formatCurrency(store.totalDueThisMonth(for: card), currency: card.currency))
                    .font(.title3.bold())
                    .foregroundStyle(.white)
            }
            
            Spacer(minLength: 16)
            
            // Bottom Section: Progress and Remaining Limit
            VStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.black.opacity(0.2))
                            .frame(height: 6)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [.white, .white.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * card.usedPercent, height: 6)
                    }
                }
                .frame(height: 6)
                
                HStack {
                    Text("Limit: \(formatCurrency(card.limit, currency: card.currency))")
                    Spacer()
                    Text("Left: \(formatCurrency(card.remainingLimit, currency: card.currency))")
                        .foregroundStyle(card.usedPercent > 0.8 ? .neonRed : .white.opacity(0.8))
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(20)
        .background(
            ZStack {
                // Card Color Gradient
                LinearGradient(
                    colors: [card.cardColor, card.cardColor.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Subtle Pattern Overlay
                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 150, height: 150)
                    .offset(x: 120, y: -40)
                
                Circle()
                    .fill(Color.black.opacity(0.05))
                    .frame(width: 100, height: 100)
                    .offset(x: -60, y: 60)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: card.cardColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}
