//
//  Store.kt
//
//  In-app purchases: optional tips now, and the full game (every city after
//  Portland) once the other cities are ready. This file is the part the game
//  talks to and has no Android in it, so the tests can stand a pretend store
//  in its place. PlayStore.kt is the real one. Ported from skate/UI/Store.swift,
//  in the same shape as Sevens' Android store.
//

package com.tuesdaygames.skate.store

/** Something that can be bought, as Google Play describes it. `price` is already formatted, such as "$2.99". */
data class StoreProduct(val id: String, val name: String, val price: String)

enum class PurchaseOutcome {
    Success,

    /** Waiting on something outside the app, such as a parent's approval or a cash payment. */
    Pending,
    Cancelled,
    Failed,
}

/** Everything the screens need to know about the store at one moment. */
data class StoreState(
    /** The full game, once the store has answered and it's on sale. */
    val fullGame: StoreProduct? = null,
    /** Tip products, cheapest first. */
    val tips: List<StoreProduct> = emptyList(),
    /** True once the product list has been requested, whether or not anything came back. */
    val hasLoaded: Boolean = false,
    /** Whether Google Play says the full game is owned. */
    val isUnlocked: Boolean = false,
    /** One line describing what the store currently knows, for when the tips don't appear. */
    val diagnostics: String = "",
)

interface Store {
    val state: StoreState

    /** Called whenever products or the unlock change, so the screen can redraw. */
    var onChange: () -> Unit

    /** Connects to the store, then loads products and what is owned. */
    fun start()

    /** Asks the store again: a purchase can be made or refunded while the app is in the background. */
    fun refresh()

    /**
     * Buys a product. `host` is whatever the store needs to show its payment sheet
     * on top of; on Android that is the Activity. `done` is called once.
     */
    fun buy(product: StoreProduct, host: Any?, done: (PurchaseOutcome) -> Unit)

    companion object {
        /** Product identifiers. These must match the products set up in the Google Play
         *  Console, and are the same as on the App Store. */
        const val fullGameID = "skate.fullgame"
        val tipIDs = listOf("skate.tip.small", "skate.tip.medium", "skate.tip.large")

        /** Off until the other cities are ready. While off, the full game is never loaded or sold. */
        const val fullGameOnSale = false

        /** What the full game will cost, for the coming-soon screen. */
        const val fullGamePrice = "$4.99"

        /** The products to ask Google Play for right now. */
        val productIDs: List<String> get() = (if (fullGameOnSale) listOf(fullGameID) else emptyList()) + tipIDs
    }
}

/** A store with nothing for sale. Used by tests, and as the stand-in before Google Play answers. */
class NoStore(unlocked: Boolean = false) : Store {
    override val state = StoreState(hasLoaded = true, isUnlocked = unlocked)
    override var onChange: () -> Unit = {}
    override fun start() {}
    override fun refresh() {}
    override fun buy(product: StoreProduct, host: Any?, done: (PurchaseOutcome) -> Unit) = done(PurchaseOutcome.Failed)
}
