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

    private var transactionListener: Task<Void, Error>?

    // App Group suite name for sharing with extensions
    static let appGroupID = "group.com.zerolive.MarkdownEditor"

    private init() {
        transactionListener = listenForTransactions()
        Task {
            await checkEntitlements()
            await loadProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            products = try await Product.products(for: [Self.quickLookPremiumID])
        } catch {
            errorMessage = "상품을 불러올 수 없습니다: \(error.localizedDescription)"
        }
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
                errorMessage = "구매가 승인 대기 중입니다."
            @unknown default:
                break
            }
        } catch {
            errorMessage = "구매 실패: \(error.localizedDescription)"
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
            return "거래 검증에 실패했습니다."
        }
    }
}
