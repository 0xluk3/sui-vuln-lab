module vuln_lab::access_control_visibility_confusion {
    use sui::tx_context::{Self as tx_context, TxContext};
    use sui::object::{Self as object, UID};
    use sui::transfer;

    /// A vault controlled by an admin.
    public struct Vault has key {
        id: UID,
        admin: address,
        withdrawals: u64,
    }

    /// Module initializer – called on publish.
    fun init(ctx: &mut TxContext) {
        transfer::share_object(Vault {
            id: object::new(ctx),
            admin: tx_context::sender(ctx),
            withdrawals: 0,
        });
    }

    /// The vulnerable entry.
    public(package) entry fun emergency_withdraw(
        v: &mut Vault,
        ctx: &TxContext
    ) {
        let caller = tx_context::sender(ctx);
        v.withdrawals = v.withdrawals + 1;
        v.admin = caller;
    }

    public(package) fun emergency_withdraw_secure(
        v: &mut Vault,
        ctx: &TxContext
    ) {
        let caller = tx_context::sender(ctx);
        v.withdrawals = v.withdrawals + 1;
        v.admin = caller;
    }
  
}