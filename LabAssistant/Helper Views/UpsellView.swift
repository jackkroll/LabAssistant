//
//  UpsellView.swift
//  LabAssistant
//
//  Created by Jack Kroll on 5/29/26.
//

import SwiftUI
import UIKit
import StoreKit

struct UpsellView: View {
    let context: UpsellContext
    var onPurchaseComplete: ((UpsellContext) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                header
                features
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollIndicators(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    purchaseSection
                    purchaseSupportActions
                }
                .padding(.horizontal, 16)
            }
            .toolbar {
                Button(role: .cancel) {
                    dismiss()
                }
            }
            .task {
                await purchaseManager.refreshStoreState()
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
            Text(context.navigationTitle)
                .font(.title2.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text(context.heroText)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var features: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(context.orderedFeatures.enumerated()), id: \.element.id) { index, feature in
                    if index > 0 {
                        Divider()
                    }
                    UpsellFeatureRow(
                        iconName: feature.iconName,
                        title: feature.title,
                        description: feature.description,
                        emphasized: index == 0
                    )
                }
            }
            .padding(.vertical, 4)
        } label: {
            Label("Included with Pro", systemImage: "checkmark.seal")
        }
    }

    @ViewBuilder
    private var purchaseSection: some View {
        if purchaseManager.hasPro {
            VStack(alignment: .leading, spacing: 12) {
                Label("Pro is active", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(context.continueButtonTitle) {
                    completePurchase()
                }
                .buttonStyle(.borderedProminent)
                .buttonSizing(.flexible)
                .padding(.top, 4)
            }
        } else if purchaseManager.isLoadingProducts {
            HStack {
                ProgressView()
                Text("Loading purchase options")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical)
        } else if let product = purchaseManager.proProduct {
            VStack(spacing: 8) {
                Button {
                    Task {
                        await purchase()
                    }
                } label: {
                    HStack {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "flask.fill")
                        }

                        Text(context.purchaseButtonTitle)
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

                Text(context.reassuranceText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
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

            Text(context.supportIndieText)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    @MainActor
    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            try await purchaseManager.purchasePro()
            if purchaseManager.hasPro {
                completePurchase()
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
            try await purchaseManager.restorePurchases()
            if purchaseManager.hasPro {
                completePurchase()
            } else {
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
            try await purchaseManager.redeemOfferCode(in: scene)
            if purchaseManager.hasPro {
                completePurchase()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func completePurchase() {
        onPurchaseComplete?(context)
        if context.dismissesPaywallAfterPurchase {
            dismiss()
        }
    }

    @MainActor
    private var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
}

private enum UpsellError: LocalizedError {
    case sceneUnavailable

    var errorDescription: String? {
        switch self {
        case .sceneUnavailable:
            "Promo code redemption is unavailable right now."
        }
    }
}

private struct UpsellFeatureRow: View {
    let iconName: String
    let title: String
    let description: String
    var emphasized: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .font(emphasized ? .title2 : .title3)
                .foregroundStyle(.red)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(emphasized ? .title3.weight(.semibold) : .headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview("Process Limit") {
    UpsellView(context: .processLimit(current: 2, max: 2))
        .environmentObject(PurchaseManager())
}

#Preview("Auto Time") {
    UpsellView(context: .autoTime)
        .environmentObject(PurchaseManager())
}

#Preview("Presets") {
    UpsellView(context: .presets)
        .environmentObject(PurchaseManager())
}
