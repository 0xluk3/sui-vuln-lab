module vuln_lab::hot_potato_vault {
    use sui::tx_context::{Self as tx_context, TxContext};
    use sui::object::{Self as object, UID};
    use sui::transfer;

    /// Denominator for basis points math: 10_000 = 100.00%
    const BPS_DENOM: u64 = 10_000;
    /// Require at least 98.00% of the saved reserves to be present at the end.
    const MIN_RETURN_BPS: u64 = 9_800;

    const ENotAdmin: u64 = 0;
    const ENotInOperation: u64 = 1;
    const ENotEnoughReserves: u64 = 2;
    const EInsufficientReturn: u64 = 3;


    public struct Vault has key {
        id: UID,
        /// Admin address that is allowed to run harvest operations.
        admin: address,
        /// Mock reserves of SUI held by the vault.
        reserves: u64,
        /// Flag used to "guard" strategy-only functions.
        operation_in_progress: bool,
        /// Snapshot of reserves at the beginning of the *last* start_harvest call.
        saved_reserves: u64,
    }

    /// Hot potato representing an in-progress harvest operation.
    /// No abilities => must be consumed before the PTB ends.
    public struct HarvestOp {
    }

    /// Create a new vault and fund it with some initial reserves.
    public fun create_vault(
        initial_reserves: u64,
        ctx: &mut TxContext,
    ) {
        let admin = tx_context::sender(ctx);

        let vault = Vault {
            id: object::new(ctx),
            admin,
            reserves: initial_reserves,
            operation_in_progress: false,
            saved_reserves: 0,
        };

        // Vault is address-owned by the creator.
        transfer::transfer(vault, admin);
    }

    /// Start a harvest / “flash-loan-like” operation.
    ///
    /// Returns a hot potato that must be consumed by `finish_harvest`
    /// within the same PTB.
    public fun start_harvest(
        vault: &mut Vault,
        ctx: &TxContext,
    ): HarvestOp {
        // Only the admin can start harvests.
        assert!(tx_context::sender(ctx) == vault.admin, ENotAdmin);

        // Take a snapshot of the current reserves.
        vault.saved_reserves = vault.reserves;
        vault.operation_in_progress = true;

        HarvestOp {} //🥔
    }

    /// Withdraw funds from the vault into the admin's “strategy”.
    public fun withdraw_for_strategy(
        vault: &mut Vault,
        _op: &mut HarvestOp,
        amount: u64,
        ctx: &TxContext,
    ) {
        let sender = tx_context::sender(ctx);

        // Only admin is allowed to pull funds out.
        assert!(sender == vault.admin, ENotAdmin);

        // Require that a harvest operation is in progress.
        assert!(vault.operation_in_progress, ENotInOperation);

        let current = vault.reserves;
        assert!(amount <= current, ENotEnoughReserves);

        // Mock transfer: just reduce reserves.
        vault.reserves = current - amount;

    }

    /// Finish the harvest operation.
    /// Enforces that the vault holds at least 98% of `saved_reserves`.
    public fun finish_harvest(
        vault: &mut Vault,
        op: HarvestOp,
        returned_amount: u64,
        ctx: &TxContext,
    ) {
        // Still only admin should be finalizing operations.
        assert!(tx_context::sender(ctx) == vault.admin, ENotAdmin);
        assert!(vault.operation_in_progress, ENotInOperation);
        
        //let current = vault.reserves;
        let required = vault.saved_reserves * MIN_RETURN_BPS / BPS_DENOM;
        assert!(returned_amount >= required, EInsufficientReturn);
        //transfer returned_amount from admin

        // Clear the flag and snapshot.
        vault.operation_in_progress = false;

        // Consume the hot potato (unpack), otherwise it would be a non-drop value.
        let HarvestOp {} = op; 
    }

    
}
