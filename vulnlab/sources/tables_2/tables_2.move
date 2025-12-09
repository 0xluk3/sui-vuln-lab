module vuln_lab::tables_2 {
    use sui::tx_context::{Self as tx_context, TxContext};
    use sui::object::{Self as object, UID};
    use sui::transfer;

    public struct Leaderboard has key {
        id: UID,
        scores: vector<u64>,
    }

    public fun new_leaderboard(ctx: &mut TxContext, scores: vector<u64>): Leaderboard {
        Leaderboard { id: object::new(ctx), scores }
    }

    /// BUG: trusts user-provided `n`, ignores `scores` length.
 public fun reward_top_n_buggy(lb: &mut Leaderboard) {
        let len = vector::length(&lb.scores);
        let mut i = 0;

        while (i < len) {
            // Placeholder “mutate entry”
            let s_ref = vector::borrow_mut(&mut lb.scores, i);
            *s_ref = *s_ref + 1;

            i = i + 1;
        }
    }

     #[test]
    fun reward_top_n_buggy_unbounded_iteration() {
        let mut ctx = tx_context::dummy();

        // Build a scores vector of length 10_000, all zeros.
        let mut scores = vector::empty<u64>();
        let mut i = 0;
        while (i < 10_000) { //100_000_000 fails
            vector::push_back(&mut scores, 0);
            i = i + 1;
        };

        let mut lb = new_leaderboard(&mut ctx, scores);

        // Call with an attacker-controlled n that is *much* larger than scores.len().
        // The loop condition uses `n`, not the actual length, so this is logically unsafe.
        reward_top_n_buggy(&mut lb);
        transfer::transfer(lb, tx_context::sender(&ctx));
    }
}
