module vuln_lab::phantom_role_bug {
    use sui::event;
    use sui::tx_context::{Self as tx_context, TxContext};
    use sui::object::{Self as object, UID};
    use sui::transfer;

    //
    // --- ROLE MARKERS ---
    //

    /// Marker types for phantom roles.
    public struct UserRole has drop {}
    public struct ModRole has drop {}
    public struct AdminRole has drop {}

    //
    // --- CAPABILITY OBJECT ---
    //

    /// Generic role capability.
    /// RoleCap<UserRole>, RoleCap<ModRole>, RoleCap<AdminRole>
    /// are the three concrete caps in this system.
    public struct RoleCap<phantom R> has key {
        id: UID,
        // Redundant with Sui's ownership model, but handy for demos/logging.
        owner: address,
    }

    //
    // --- EVENTS ---
    //

    public struct UserCapMinted has copy, drop {
        user: address,
    }

    public struct AdminCapCheckedOut has copy, drop {
        to: address,
    }

    public struct SudoExecuted has copy, drop {
        by: address,
    }

    //
    // --- SIGN UP: MINT USER CAP ---
    //

    /// Anyone can sign up and get a RoleCap<UserRole>.
    public entry fun sign_up(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        let cap = RoleCap<UserRole> {
            id: object::new(ctx),
            owner: sender,
        };

        // Non-transferable capability pattern:
        // `RoleCap` has only `key`, so we use `transfer::transfer`
        // from inside this defining module.
        transfer::transfer(cap, sender);

        event::emit(UserCapMinted { user: sender });
    }

    //
       // --- VULNERABLE MODERATOR CHECKOUT ---
       //
       // Intended: only a moderator holding RoleCap<ModRole> can call this.
       // BUG: it's generic in `R`, so ANY RoleCap<R> works, including
       //      RoleCap<UserRole> from `sign_up`.
       //
    /// 
    /// BUGGY:
    /// Accepts ANY RoleCap<R>, not just RoleCap<ModRole>.
    ///
    /// A normal user who only has RoleCap<UserRole> can pass it here,
    /// and still receive a RoleCap<AdminRole>.
    public fun moderator_checkout_admin<R>(
        _cap: & RoleCap<R>,          // ❌ should have been &RoleCap<ModRole>
        ctx: &mut TxContext,
    ) {
        let caller = tx_context::sender(ctx);

        let admin_cap = RoleCap<AdminRole> {
            id: object::new(ctx),
            owner: caller,
        };

        // One-shot admin capability is minted to the caller.
        transfer::transfer(admin_cap, caller);

        event::emit(AdminCapCheckedOut { to: caller });
    }

    //
    // --- SUDO EXECUTION (ONE-SHOT ADMIN) ---
    //

    /// Requires a RoleCap<AdminRole> and burns it after use.
    public entry fun sudo_execute(
        admin: RoleCap<AdminRole>,  // must be the AdminRole specialization
        ctx: &mut TxContext,
    ) {
        let caller = tx_context::sender(ctx);

        // Whatever privileged thing you want to model goes here.
        event::emit(SudoExecuted { by: caller });

        // One-shot semantics: destroy the Admin cap object.
        let RoleCap { id, owner: _ } = admin;
        object::delete(id);
    }
}