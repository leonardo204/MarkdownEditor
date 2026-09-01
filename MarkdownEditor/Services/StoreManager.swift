import Foundation
import StoreKit

@MainActor
class StoreManager: ObservableObject {
    static let shared = StoreManager()

    // Product ID for Quick Look Premium
    static let quickLookPremiumID = "com.zerolive.MarkdownEditor.premium.quicklook"

    @Published private(set) var isPremium: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseInProgress: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoadingProducts: Bool = false

    private var transactionListener: Task<Void, Error>?
    private var retryTask: Task<Void, Never>?
    private static let maxRetries = 5

    // App Group suite name for sharing with extensions
    static let appGroupID = "group.com.zerolive.MarkdownEditor"

    private init() {
        transactionListener = listenForTransactions()
        Task {
            await checkEntitlements()
            await loadProductsWithRetry()
        }
    }

    deinit {
        transactionListener?.cancel()
        retryTask?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        isLoadingProducts = true
        errorMessage = nil

        do {
            let fetchedProducts = try await Product.products(for: [Self.quickLookPremiumID])
            products = fetchedProducts
            if fetchedProducts.isEmpty {
                errorMessage = L("store.error.not_found")
                print("[StoreManager] No products found for ID: \(Self.quickLookPremiumID)")
            } else {
                errorMessage = nil
                print("[StoreManager] Loaded \(fetchedProducts.count) product(s): \(fetchedProducts.map { $0.id })")
            }
        } catch {
            errorMessage = L("store.error.load_failed", error.localizedDescription)
            print("[StoreManager] Failed to load products: \(error)")
        }

        isLoadingProducts = false
    }

    private func loadProductsWithRetry() async {
        for attempt in 1...Self.maxRetries {
            await loadProducts()

            if !products.isEmpty { return }

            let delay = min(30, attempt * 10) // 10s, 20s, 30s, 30s, 30s
            print("[StoreManager] Retry \(attempt)/\(Self.maxRetries) in \(delay)s...")
            try? await Task.sleep(for: .seconds(delay))

            if Task.isCancelled { return }
        }
        print("[StoreManager] All retries exhausted")
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        purchaseInProgress = true
        errorMessage = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchaseState(transaction)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                errorMessage = L("store.error.pending")
            @unknown default:
                break
            }
        } catch {
            errorMessage = L("store.error.purchase_failed", error.localizedDescription)
        }

        purchaseInProgress = false
    }

    // MARK: - Restore Purchases

    func restorePurchases() async {
        try? await AppStore.sync()
        await checkEntitlements()
    }

    // MARK: - Check Entitlements

    func checkEntitlements() async {
        var hasPremium = false

        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if transaction.productID == Self.quickLookPremiumID {
                    hasPremium = true
                }
            }
        }

        isPremium = hasPremium
        syncPurchaseStateToAppGroup()
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    await self?.updatePurchaseState(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - Helpers

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func updatePurchaseState(_ transaction: Transaction) async {
        if transaction.productID == Self.quickLookPremiumID {
            isPremium = transaction.revocationDate == nil
            syncPurchaseStateToAppGroup()
        }
    }

    // MARK: - App Group Sync

    private func syncPurchaseStateToAppGroup() {
        if let defaults = UserDefaults(suiteName: Self.appGroupID) {
            defaults.set(isPremium, forKey: "isPremium")
        }
    }
}

// MARK: - Errors

enum StoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return L("store.error.verification_failed")
        }
    }
}
