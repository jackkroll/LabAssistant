//
//  UpsellView.swift
//  LabAssistant
//
//  Created by Jack Kroll on 5/29/26.
//

import SwiftUI
import StoreKit
import UIKit

struct UpsellView: View {
    private let productID = "pro"
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var product: Product?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var isPurchased = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
                ScrollView {
                    header
                    features
                    Spacer()
                        .frame(maxWidth: 200)
                    purchaseSection
                    purchaseSupportActions
            }
                .padding()
            .navigationTitle("Unlock Pro")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                Button(role: .cancel) {
                    dismiss()
                }
            }
            .task {
                await refreshStoreState()
            }
            .alert("StoreKit Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Create as many development processes as you need, then save temperature and time presets for repeatable sessions.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private var features: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                UpsellFeatureRow(
                    iconName: "infinity",
                    title: "Unlimited Processes",
                    description: "Build and keep every workflow you use without limits"
                )
                
                Divider()
                
                UpsellFeatureRow(
                    iconName: "thermometer.medium",
                    title: "Temperature/Time Presets",
                    description: "Save development times for different temperatures and switch between them while editing or developing."
                )
                UpsellFeatureRow(iconName: "bolt.badge.clock.fill", title: "Auto Time", description: "Automatically calculate adjusted development time based on the current temperature")
                Divider()
                
                UpsellFeatureRow(
                    iconName: "heart.fill",
                    title: "Support an Indie App",
                    description: "Your purchase directly supports development and keeps Lab Assistant free for everyone"
                )
            }
            .padding(.vertical, 4)
        } label: {
            Label("Included with Pro", systemImage: "checkmark.seal")
        }
    }
    
    @ViewBuilder
    private var purchaseSection: some View {
        if isPurchased {
            VStack(alignment: .leading, spacing: 12) {
                Label("Pro is active", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button("Continue") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .buttonSizing(.flexible)
                .padding(.top, 4)
            }
        } else if isLoading {
            HStack {
                ProgressView()
                Text("Loading purchase options")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical)
        } else if let product {
            VStack(spacing: 8) {
                Spacer()
                Button {
                    Task {
                        await purchase(product)
                    }
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "flask.fill")
                        }
                        
                        Text("Purchase")
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text(product.displayPrice)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .buttonSizing(.flexible)
                .buttonBorderShape(.roundedRectangle)
                .disabled(isPurchasing)
                
                
            }
        } else {
            ContentUnavailableView(
                "Pro is unavailable",
                systemImage: "cart.badge.questionmark",
                description: Text("Check your StoreKit configuration or try again later.")
            )
        }
    }
    
    private var purchaseSupportActions: some View {
        VStack(spacing: 8) {
            Divider()
                .padding(.vertical, 4)
            
            Button("Restore Purchases") {
                Task {
                    await restorePurchases()
                }
            }
            .buttonStyle(.bordered)
            .buttonSizing(.flexible)
            .buttonBorderShape(.roundedRectangle)
            .disabled(isPurchasing)
            
            Button {
                Task {
                    await redeemPromoCode()
                }
            } label: {
                Text("Redeem Offer Code")
            }
            .buttonStyle(.borderless)
            .buttonSizing(.flexible)
            .disabled(isPurchasing)
            .padding(.top, 4)
        }
    }
    
    @MainActor
    private func refreshStoreState() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            product = try await Product.products(for: [productID]).first
            isPurchased = await hasPurchasedPro()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    private func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isPurchased = await hasPurchasedPro()
                
                if isPurchased {
                    dismiss()
                }
            case .pending:
                errorMessage = "The purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                errorMessage = "The purchase could not be completed."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    private func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            try await AppStore.sync()
            isPurchased = await hasPurchasedPro()
            
            if !isPurchased {
                errorMessage = "No Pro purchase was found for this Apple ID."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    private func redeemPromoCode() async {
        guard let scene = activeWindowScene else {
            errorMessage = UpsellError.sceneUnavailable.localizedDescription
            return
        }
        
        do {
            try await AppStore.presentOfferCodeRedeemSheet(in: scene)
            isPurchased = await hasPurchasedPro()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
    
    private func hasPurchasedPro() async -> Bool {
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(entitlement) else { continue }
            
            if transaction.productID == productID {
                return true
            }
        }
        
        return false
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw UpsellError.failedVerification
        case .verified(let signedType):
            return signedType
        }
    }
}

private enum UpsellError: LocalizedError {
    case failedVerification
    case sceneUnavailable
    
    var errorDescription: String? {
        switch self {
        case .failedVerification:
            "The App Store could not verify this purchase."
        case .sceneUnavailable:
            "Promo code redemption is unavailable right now."
        }
    }
}

private struct UpsellFeatureRow: View {
    let iconName: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.red)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    UpsellView()
}
