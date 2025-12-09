module vuln_lab::tables_1 {
    use sui::table::{Self as table, Table};
    use sui::tx_context::{Self as tx_context, TxContext};
    use sui::object::{Self as object, UID};
    use sui::transfer;


    /// Bank of balances per address.
    public struct Bank has key {
        id: UID,
        balances: Table<address, u64>,
    }

    public fun new_bank(ctx: &mut TxContext): Bank {
        Bank {
            id: object::new(ctx),
            balances: table::new(ctx),
        }
    }

    /// BUGGY: uses `add` blindly, aborts on second deposit for the same user.
    public fun deposit_buggy(
        bank: &mut Bank,
        user: address,
        amount: u64,
    ) {
        table::add(&mut bank.balances, user, amount);
    }

    /// Correct: insert-or-increase.
    public fun deposit_fixed(
        bank: &mut Bank,
        user: address,
        amount: u64,
    ) {
        if (!table::contains(&bank.balances, user)) {
            table::add(&mut bank.balances, user, amount);
        } else {
            let bal_ref = table::borrow_mut(&mut bank.balances, user);
            *bal_ref = *bal_ref + amount;
        }
    }

 #[test]
    #[expected_failure]    // ✔️ This test EXPECTS an abort. That's the whole point.
    fun test_duplicate_deposit_buggy() {
        let mut ctx = tx_context::dummy();

        let mut bank = new_bank(&mut ctx);
        let user = @0xC0FFEE;

        // First deposit — OK
        deposit_buggy(&mut bank, user, 100);

        // Second deposit — ❌ aborts due to duplicate key
        deposit_buggy(&mut bank, user, 200);

        // We NEVER reach here because the second call aborts.
        // But if Move required consuming bank, we'd transfer it:
        transfer::transfer(bank, user);
    }

}