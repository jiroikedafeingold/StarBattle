import SwiftUI
import StoreKit

/// The Full Access paywall. Shown when a free player hits the daily new-puzzle limit,
/// and from Settings. Presents the localized product price straight from the App Store
/// (so regional pricing is automatic), a Buy button, and — as Apple requires for a
/// non-consumable — a Restore Purchase button.
struct PaywallView: View {
    @Environment(PurchaseManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    Text("Cherry Battle Full Access")
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text("Free play gives you one new puzzle a day in each of Easy, Medium, Hard and Expert. Unlock Full Access to play as many as you like.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    features

                    buyButton
                    restoreButton

                    Text("A one-time purchase for this Apple Account. Beginner mode is always free.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Full Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            // Owning it (via purchase, restore, or an update from another device) closes
            // the paywall automatically.
            .onChange(of: store.hasFullAccess) { _, owned in
                if owned { dismiss() }
            }
            .alert("Purchase", isPresented: errorPresented) {
                Button("OK", role: .cancel) { store.lastError = nil }
            } message: {
                Text(store.lastError ?? "")
            }
            // Ensure the product is (re)loaded whenever the paywall opens, so a transient
            // failure at launch doesn't leave the Buy button stuck.
            .task { await store.loadProduct() }
        }
    }

    // MARK: Pieces

    private var hero: some View {
        Image("SplashArt")
            .resizable()
            .scaledToFill()
            .frame(height: 170)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.12)))
            .shadow(color: Color(hex: 0xF2B01E, alpha: 0.40), radius: 16, y: 6)
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 12) {
            feature("infinity", "Unlimited new puzzles in Easy, Medium, Hard & Expert")
            feature("calendar", "No daily limit — play whenever you want")
            feature("checkmark.seal.fill", "One-time purchase, yours forever")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func feature(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color(hex: 0xF2B01E))
                .frame(width: 26)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    /// The purchase area. Never a silently-disabled button: it shows a real Buy button
    /// once the product loads, a spinner while loading, or a Try Again if the store
    /// couldn't be reached — so App Review (and users) always have a working control.
    @ViewBuilder private var buyButton: some View {
        if let product = store.product {
            Button {
                Task { if await store.purchase() { dismiss() } }
            } label: {
                Group {
                    if store.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text("Unlock — \(product.displayPrice)")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(hex: 0x2E6BE5))
            .disabled(store.isPurchasing || store.isRestoring)
        } else if store.isLoadingProduct {
            HStack(spacing: 10) {
                ProgressView()
                Text("Loading…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        } else {
            VStack(spacing: 10) {
                Text("The store is unavailable right now. Please check your connection and try again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    Task { await store.loadProduct() }
                } label: {
                    Text("Try Again")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: 0x2E6BE5))
            }
        }
    }

    private var restoreButton: some View {
        Button {
            Task { await store.restore() }
        } label: {
            if store.isRestoring {
                ProgressView()
            } else {
                Text("Restore Purchase")
            }
        }
        .font(.subheadline)
        .disabled(store.isPurchasing || store.isRestoring)
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { store.lastError != nil },
                set: { if !$0 { store.lastError = nil } })
    }
}

#Preview {
    PaywallView()
        .environment(PurchaseManager())
}
