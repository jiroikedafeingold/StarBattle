import Foundation
import StoreKit

/// Owns the app's single in-app purchase — "Cherry Battle Full Access", a one-time
/// non-consumable unlock that removes the free daily puzzle limit. Uses StoreKit 2:
/// it loads the product, tracks the current entitlement, and exposes purchase and
/// restore. A background task also listens for transactions that arrive outside a
/// direct purchase (Ask-to-Buy approvals, purchases made on another device, refunds).
///
/// This is a service, not a screen view-model, so it carries no SwiftUI — views read it
/// from the environment.
@MainActor
@Observable
final class PurchaseManager {

    /// The App Store product identifier (must match App Store Connect).
    static let productID = "CherryBattleFullAccess"

    /// The loaded product, or nil until `refresh()` succeeds (offline / not yet ready).
    private(set) var product: Product?
    /// Whether the player owns Full Access. Drives every gate in the app.
    private(set) var hasFullAccess = false
    /// True while a purchase is in flight, so the paywall can show progress.
    private(set) var isPurchasing = false
    /// True while a restore is in flight.
    private(set) var isRestoring = false
    /// A user-facing message from the last failed purchase/restore; the paywall shows it
    /// then clears it.
    var lastError: String?

    init() {
        // Listen for transaction updates for the app's lifetime.
        Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refresh() }
    }

    /// Loads the product and the current entitlement. Safe to call repeatedly.
    func refresh() async {
        await loadProduct()
        await updateEntitlement()
    }

    /// Fetches the product's localized metadata (title, price) from the App Store.
    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            // Leave `product` as-is; the paywall offers a retry.
        }
    }

    /// Recomputes `hasFullAccess` from StoreKit's current entitlements — the source of
    /// truth even across reinstalls, since the receipt lives with the Apple Account.
    func updateEntitlement() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        hasFullAccess = owned
    }

    /// Starts the purchase flow. Returns true once the unlock is owned.
    @discardableResult
    func purchase() async -> Bool {
        guard let product else {
            lastError = "The purchase isn’t available right now. Please try again in a moment."
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                await handle(verification)
                return hasFullAccess
            case .userCancelled:
                return false
            case .pending:
                lastError = "Your purchase is pending approval and will unlock once it’s approved."
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "The purchase couldn’t be completed. Please try again."
            return false
        }
    }

    /// Restores previous purchases by syncing with the App Store, then re-reads the
    /// entitlement. Required by Apple for non-consumables.
    func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
        } catch {
            // A cancelled or failed sync still falls through to an entitlement re-check.
        }
        await updateEntitlement()
        if !hasFullAccess {
            lastError = "No previous purchase was found for this Apple Account."
        }
    }

    /// Verifies a transaction, updates the entitlement, and finishes it so StoreKit
    /// stops re-delivering it.
    private func handle(_ verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification else { return }
        await updateEntitlement()
        await transaction.finish()
    }
}
