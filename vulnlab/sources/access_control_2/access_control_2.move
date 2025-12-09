module vuln_lab::access_control_2 {
    use sui::tx_context::{Self as tx_context, TxContext};
    use sui::object::{Self as object, UID};
    use sui::transfer;

    /// Simple shared vault with an admin and stored balance.
    public struct Vault has key {
        id: UID,
        admin: address,
        balance: u64,
    }

    /// Module initializer — creates and shares a new Vault on publish.
    fun init(ctx: &mut TxContext) {
        transfer::share_object(Vault {
            id: object::new(ctx),
            admin: tx_context::sender(ctx),
            balance: 100, // give it some balance for testing
        });
    }


    public fun withdraw_all_admin_argument(
        v: &mut Vault,
        caller: address
    ) {
        assert!(v.balance > 0, 0);
        // if (caller != v.admin) { abort E_NOT_ADMIN; }
        v.balance = 0;
    }

    // --------------------------------------------------------------------------
    // ⚠️ 2. PRIVATE helper (visible ONLY inside this module)
    // --------------------------------------------------------------------------

    fun withdraw_all_private(
        v: &mut Vault,
        caller: address,
    ) {
        assert!(v.balance > 0, 0);
        v.balance = 0;
        // if (caller != v.admin) { abort E_NOT_ADMIN; }
    }

    // --------------------------------------------------------------------------
    // ⚠️ 3. PACKAGE-visible withdraw (public(package))
    //    - Only callable by modules in THIS package

    public(package) fun withdraw_all_package(
        v: &mut Vault,
        ctx: &TxContext,
    ) {
        let caller = tx_context::sender(ctx);
        withdraw_all_private(v, caller);
    }


    public entry fun withdraw_all_entry(
        v: &mut Vault,
        ctx: &TxContext,
    ) {
        let caller = tx_context::sender(ctx);
        withdraw_all_private(v, caller);
    }
}
