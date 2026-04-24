//
//  AddEditWalletView.swift
//  Budget Expense
//

import SwiftUI
import PhotosUI // ✅ Import PhotosUI for image picking

struct AddEditWalletView: View {
    let editTarget: Wallet?
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name        = ""
    @State private var balanceText = ""
    @State private var currency    = Currency.idr
    @State private var isPositive  = true
    
    // ✅ State for Image Picking
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var imageData: Data?

    private var isEditMode: Bool { editTarget != nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        Double(balanceText.replacingOccurrences(of: ",", with: ".")) != nil
    }
    private var parsedBalance: Double {
        Double(balanceText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    private var previewWallet: Wallet {
        Wallet(name: name.isEmpty ? "Wallet Name" : name,
               balance: parsedBalance, currency: currency, isPositive: isPositive, imageData: imageData) // ✅ Pass imageData to preview
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        previewCard
                        imagePicker // ✅ Added image picker UI
                        fields
                        saveBtn
                    }
                    .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 40)
                }
            }
            .navigationTitle(isEditMode ? "Edit Wallet" : "New Wallet")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.glassText)
                }
            }
            .onAppear { prefill() }
            // ✅ Load the image data when a photo is selected
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
        }
    }

    // MARK: Live Preview

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PREVIEW").font(.caption2.weight(.semibold)).foregroundStyle(.dimText).kerning(1.5)
                .padding(.leading, 4)
            WalletListRow(wallet: previewWallet)
        }
    }

    // MARK: Image Picker
    
    private var imagePicker: some View {
        field(title: "WALLET IMAGE", icon: "photo") {
            HStack(spacing: 12) {
                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(white: 0.12))
                        .frame(width: 50, height: 50)
                        .overlay(Image(systemName: "photo").foregroundStyle(.glassText))
                }
                
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Text(imageData == nil ? "Select Image" : "Change Image")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(white: 0.15), in: Capsule())
                }
                
                if imageData != nil {
                    Button(role: .destructive) {
                        imageData = nil
                        selectedPhotoItem = nil
                    } label: {
                        Image(systemName: "trash.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.neonRed)
                    }
                }
                
                Spacer()
            }
            .padding(14).glassEffect(in: .rect(cornerRadius: 14))
        }
    }

    // MARK: Fields

    private var fields: some View {
        VStack(spacing: 20) {
            // Name
            field(title: "WALLET NAME", icon: "wallet.bifold") {
                TextField("e.g. BCA, GoPay, Dana…", text: $name)
                    .textFieldStyle(.plain).font(.body).foregroundStyle(.white)
                    .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            }

            // Currency - Horizontal Selector
            field(title: "CURRENCY", icon: "globe") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Currency.allCases, id: \.self) { c in
                            Button { 
                                withAnimation(.spring(duration: 0.2)) { 
                                    currency = c 
                                } 
                            } label: {
                                VStack(spacing: 6) {
                                    Text(c.flag)
                                        .font(.title2)
                                    Text(c.symbol)
                                        .font(.headline.bold())
                                    Text(c.rawValue)
                                        .font(.caption2.weight(.semibold))
                                }
                                .frame(width: 70)
                                .padding(.vertical, 12)
                                .glassEffect(
                                    currency == c ? .regular.tint(Color(white: 0.6)) : .regular,
                                    in: .rect(cornerRadius: 12)
                                )
                                .foregroundStyle(currency == c ? .white : Color(white: 0.38))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 2)
                }
            }

            // Balance
            field(title: "BALANCE", icon: "banknote") {
                HStack(spacing: 10) {
                    Text(currency.symbol).font(.headline).foregroundStyle(.glassText).frame(minWidth: 24)
                    TextField("0", text: $balanceText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .textFieldStyle(.plain).font(.headline).foregroundStyle(.white)
                }
                .padding(14).glassEffect(in: .rect(cornerRadius: 14))
            }

            // Type
            field(title: "TYPE", icon: "plusminus") {
                HStack(spacing: 10) {
                    typeBtn("Asset / Inflow", "arrow.up.circle.fill", true,  .neonGreen)
                    typeBtn("Liability",      "arrow.down.circle.fill", false, .neonRed)
                }
            }
        }
    }

    private var saveBtn: some View {
        Button(action: save) {
            HStack(spacing: 8) {
                Image(systemName: isEditMode ? "checkmark.circle.fill" : "plus.circle.fill")
                Text(isEditMode ? "Save Changes" : "Add Wallet").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 17)
        }
        .buttonStyle(.glassProminent)
        .disabled(!canSave).opacity(canSave ? 1 : 0.38)
    }

    // MARK: Helpers

    @ViewBuilder
    private func field<C: View>(title: String, icon: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold)).foregroundStyle(.glassText).kerning(0.8)
            content()
        }
    }

    @ViewBuilder
    private func typeBtn(_ title: String, _ icon: String, _ value: Bool, _ color: Color) -> some View {
        Button { withAnimation(.spring(duration: 0.2)) { isPositive = value } } label: {
            VStack(spacing: 5) {
                Image(systemName: icon).font(.title3)
                    .foregroundStyle(isPositive == value ? color : Color(white: 0.28))
                Text(title).font(.caption2.weight(isPositive == value ? .semibold : .regular))
                    .foregroundStyle(isPositive == value ? .white : Color(white: 0.38))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .glassEffect(isPositive == value ? .regular.tint(color) : .regular, in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func prefill() {
        guard let w = editTarget else { return }
        name        = w.name
        balanceText = "\(Int(w.balance))"
        currency    = w.currency
        isPositive  = w.isPositive
        imageData   = w.imageData // ✅ Prefill the image data if it exists
    }

    private func save() {
        let w = Wallet(id: editTarget?.id ?? UUID(),
                       name: name.trimmingCharacters(in: .whitespaces),
                       balance: parsedBalance, 
                       currency: currency, 
                       isPositive: isPositive,
                       imageData: imageData) // ✅ Include the chosen image data here
        if isEditMode { store.updateWallet(w) } else { store.addWallet(w) }
        dismiss()
    }
}
