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

                    Text("Free play gives you one new puzzle a day in each of Easy, Medium and Hard. Unlock Full Access to play as many as you like.")
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
            .shadow(color: Color(hex: 0xE51937, alpha: 0.35), radius: 16, y: 6)
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 12) {
            feature("infinity", "Unlimited new puzzles in Easy, Medium & Hard")
            feature("calendar", "No daily limit — play whenever you want")
            feature("checkmark.seal.fill", "One-time purchase, yours forever")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func feature(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color(hex: 0xE51937))
                .frame(width: 26)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    private var buyButton: some View {
        Button {
            Task {
                if await store.purchase() { dismiss() }
            }
        } label: {
            Group {
                if store.isPurchasing {
                    ProgressView().tint(.white)
                } else if let product = store.product {
                    Text("Unlock — \(product.displayPrice)")
                } else {
                    Text("Unlock Full Access")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color(hex: 0xE51937))
        .disabled(store.product == nil || store.isPurchasing || store.isRestoring)
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
