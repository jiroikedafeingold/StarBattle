import Foundation
import StoreKit

/// Owns the app's single in-app purchase — "Star Battle Nova Full Access", a one-time
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

    /// The App Store product identifier (must match App Store Connect exactly, and is
    /// case-sensitive). This is the *Product ID*, not the reference name.
    static let productID = "cherrybattleaccess"

    /// The loaded product, or nil until `refresh()` succeeds (offline / not yet ready).
    private(set) var product: Product?
    /// True while the product metadata is being fetched, so the paywall can show a spinner
    /// instead of a dead button.
    private(set) var isLoadingProduct = false
    /// True when the last load attempt finished without a product, so the paywall can
    /// offer a Try Again button rather than leaving Buy silently disabled.
    private(set) var productLoadFailed = false
    /// Whether the player owns Full Access. Drives every gate in the app.
    private(set) var hasFullAccess = false
    /// True while a purchase is in flight, so the paywall can show progress.
    private(set) var isPurchasing = false
    /// True while a restore is in flight.
    private(set) var isRestoring = false
    /// A user-facing message from the last failed purchase/restore; the paywall shows it
    /// then clears it.
    var lastError: String?

    /// A hidden, persisted comp unlock (set by a secret gesture). It grants the same
    /// board access as a purchase but is deliberately kept out of the entitlement shown
    /// in Settings, so it never reveals itself.
    private static let secretKey = "fullAccessSecretUnlock"
    private(set) var secretUnlocked = UserDefaults.standard.bool(forKey: "fullAccessSecretUnlock")

    /// The real entitlement used to *display* purchase state (Settings, paywall).
    /// `isUnlocked` is what actually gates the boards — either a purchase or the secret.
    var isUnlocked: Bool { hasFullAccess || secretUnlocked }

    /// Silently grants full board access and remembers it across launches. No UI feedback.
    func unlockSecretly() {
        guard !secretUnlocked else { return }
        secretUnlocked = true
        UserDefaults.standard.set(true, forKey: Self.secretKey)
    }

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

    /// Fetches the product's localized metadata (title, price) from the App Store, with a
    /// few retries — the request can fail or return empty transiently (cold StoreKit, slow
    /// network, product still propagating). Sets `productLoadFailed` if it never arrives so
    /// the paywall can show a Try Again affordance rather than a permanently disabled Buy
    /// button. Safe to call again to retry.
    func loadProduct() async {
        if product != nil { return }
        isLoadingProduct = true
        productLoadFailed = false
        defer { isLoadingProduct = false }

        for attempt in 0..<3 {
            do {
                if let loaded = try await Product.products(for: [Self.productID]).first {
                    product = loaded
                    return
                }
            } catch {
                // Fall through to a backoff and retry.
            }
            if attempt < 2 {
                try? await Task.sleep(for: .seconds(Double(attempt + 1)))
            }
        }
        productLoadFailed = (product == nil)
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
            lastError = String(localized: "The purchase isn’t available right now. Please try again in a moment.")
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
                lastError = String(localized: "Your purchase is pending approval and will unlock once it’s approved.")
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = String(localized: "The purchase couldn’t be completed. Please try again.")
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
            lastError = String(localized: "No previous purchase was found for this Apple Account.")
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
