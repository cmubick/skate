//
//  Store.swift
//  skate
//
//  In-app purchases: the full game (every city after Portland) and optional tips.
//  Apple handles the payment; the app only learns whether the full game is owned.
//
//  The full game isn't on sale yet: it goes on sale when the other cities are ready.
//  Until then the store only sells tips, and the locked cities say so.
//

import Foundation
import StoreKit
import UIKit

final class Store {
    static let shared = Store()

    /// Product identifiers. These must match the products set up in App Store Connect
    /// exactly (the tips there are com.tuesdaygames.*tip, unlike the other apps' <app>.tip.*).
    static let fullGameID = "skate.fullgame"
    static let tipIDs = ["com.tuesdaygames.smalltip", "com.tuesdaygames.mediumtip", "com.tuesdaygames.largetip"]

    /// Off until the other cities are ready. While off, the full game is never loaded or sold.
    static let fullGameOnSale = false
    /// What the full game will cost, for the coming-soon screen.
    static let fullGamePrice = "$4.99"

    enum Outcome: Equatable {
        case success
        /// Waiting on something outside the app, such as Ask to Buy approval.
        case pending
        case cancelled
        case failed
    }

    private static let unlockedKey = "fullGameUnlocked"

    private let defaults: UserDefaults
    private var updates: Task<Void, Never>?

    /// The full game, once the App Store has answered and it's on sale.
    private(set) var fullGame: Product?
    /// Tip products, cheapest first.
    private(set) var tips: [Product] = []
    /// True once the product list has been requested, whether or not anything came back.
    private(set) var hasLoaded = false
    /// Whether the App Store says the full game is owned. Cached so menus are right
    /// before the store answers.
    private var owned: Bool

    var isUnlocked: Bool {
        #if DEBUG
        if let debugOverride { return debugOverride }
        #endif
        return owned
    }

    #if DEBUG
    /// For screenshots and manual testing: pretend the full game is or is not owned.
    var debugOverride: Bool?
    #endif

    /// Detail of the most recent failure.
    private(set) var lastProblem: String?

    /// Called whenever products or the unlock change, so the screen can redraw.
    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        owned = defaults.bool(forKey: Store.unlockedKey)
    }

    deinit {
        updates?.cancel()
    }

    /// The products to ask the App Store for right now.
    static var productIDs: [String] { (fullGameOnSale ? [fullGameID] : []) + tipIDs }

    /// Starts watching for purchases made elsewhere, then loads products and ownership.
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        if let products = try? await Product.products(for: Store.productIDs) {
            fullGame = products.first { $0.id == Store.fullGameID }
            tips = products.filter { Store.tipIDs.contains($0.id) }.sorted { $0.price < $1.price }
        }
        hasLoaded = true
        await refreshOwnership()
        onChange?()
    }

    /// Reads what the App Store says is owned. This is the source of truth for the unlock.
    private func refreshOwnership() async {
        var found = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement,
               transaction.productID == Store.fullGameID, transaction.revocationDate == nil {
                found = true
            }
        }
        setUnlocked(found)
    }

    /// Buys a product. Pass the window's scene so the App Store knows where to
    /// show its payment sheet; without it the sheet can fail to appear.
    func buy(_ product: Product, in scene: UIScene? = nil) async -> Outcome {
        lastProblem = nil
        do {
            let result: Product.PurchaseResult
            if #available(iOS 17.0, *), let scene {
                result = try await product.purchase(confirmIn: scene)
            } else {
                result = try await product.purchase()
            }
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    if transaction.productID == Store.fullGameID { setUnlocked(true) }
                    await transaction.finish()
                    onChange?()
                    return .success
                case .unverified(_, let error):
                    lastProblem = "unverified: \(error)"
                    onChange?()
                    return .failed
                }
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .failed
            }
        } catch {
            lastProblem = "error: \(error)"
            return .failed
        }
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = update else { return }
        if transaction.productID == Store.fullGameID {
            setUnlocked(transaction.revocationDate == nil)
        }
        await transaction.finish()
        onChange?()
    }

    private func setUnlocked(_ value: Bool) {
        owned = value
        defaults.set(value, forKey: Store.unlockedKey)
    }
}
