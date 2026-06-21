//
//  PurchaseManager.swift
//  LabAssistant
//
//  Created by Codex on 6/16/26.
//

import Foundation
import StoreKit
import UIKit
import Combine

@MainActor
final class PurchaseManager: ObservableObject {
    static let proProductID = "pro"

    @Published private(set) var proProduct: Product?
    @Published private(set) var hasPro = false
    @Published private(set) var isLoadingProducts = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = observeTransactionUpdates()

        Task {
            await refreshStoreState()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func refreshStoreState() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            proProduct = try await Product.products(for: [Self.proProductID]).first
        } catch {
            proProduct = nil
        }

        await refreshEntitlements()
    }

    func purchasePro() async throws {
        guard let proProduct else {
            throw PurchaseError.productUnavailable
        }

        let result = try await proProduct.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
        case .pending:
            throw PurchaseError.pendingApproval
        case .userCancelled:
            return
        @unknown default:
            throw PurchaseError.unknown
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    func redeemOfferCode(in scene: UIWindowScene) async throws {
        try await AppStore.presentOfferCodeRedeemSheet(in: scene)
        await refreshEntitlements()
    }

    private func refreshEntitlements() async {
        hasPro = await fetchHasProEntitlement()
    }

    private func fetchHasProEntitlement() async -> Bool {
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(entitlement) else { continue }
            guard transaction.productID == Self.proProductID else { continue }
            if transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }

            for await update in Transaction.updates {
                guard let transaction = try? self.checkVerified(update) else { continue }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    nonisolated
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PurchaseError.failedVerification
        case .verified(let signedType):
            return signedType
        }
    }
}

enum PurchaseError: LocalizedError {
    case failedVerification
    case productUnavailable
    case pendingApproval
    case unknown

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "The App Store could not verify this purchase."
        case .productUnavailable:
            return "The Pro purchase is unavailable right now."
        case .pendingApproval:
            return "The purchase is pending approval."
        case .unknown:
            return "The purchase could not be completed."
        }
    }
}
