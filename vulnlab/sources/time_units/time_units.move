module vuln_lab::vuln_stake {

    use sui::clock::{Self, Clock};
    use sui::object::{Self as object, UID};
    use sui::event;
    use sui::tx_context::{Self, TxContext};

    /// Very simple global-ish state you pass as &mut object.
    public struct StakeState has key {
        id: UID,
        staked: u64,
        seconds: u64, // supposed to be seconds, but we store ms here
    }

    public struct StakeEvent has copy, drop {
        amount: u64,
        saved_timestamp_ms: u64,
    }

    public struct UnstakeEvent has copy, drop {
        amount: u64,
        unlocked_amount: u64,
    }

    /// 10 days in *seconds* (intended lock time)
    const STAKE_LOCK_TIME_SECONDS: u64 = 10 * 24 * 60 * 60;

    /// Vulnerable stake: saves timestamp in ms into a field called `seconds`.
    /// No real transfers, just tracking and emitting an event.
    public entry fun stake(
        state: &mut StakeState,
        amount: u64,
        clock: &Clock,
        _ctx: &mut TxContext,
    ) {
        let now = clock::timestamp_ms(clock) / 1000;

        // BUG: storing milliseconds in a variable conceptually meant for seconds
        state.seconds = now;
        state.staked = state.staked + amount;

        event::emit(StakeEvent {
            amount,
            saved_timestamp_ms: now,
        });
    }

    /// Vulnerable unstake: compares "now in seconds" to `seconds + lock_time`.
    /// Because `seconds` is really ms, the comparison is nonsense
    /// and the time lock is effectively broken.
    public entry fun unstake(
        state: &mut StakeState,
        clock: &Clock,
        _ctx: &mut TxContext,
    ) {
        // "now in seconds"
        let now_seconds = clock::timestamp_ms(clock);

        // Broken check
        if (now_seconds >= state.seconds + STAKE_LOCK_TIME_SECONDS) {
            let gain = state.staked / 10; // +10%
            let unlocked = state.staked + gain;

            event::emit(UnstakeEvent {
                amount: state.staked,
                unlocked_amount: unlocked, // simulate amount * 1.1
            });

            // Clear state
            state.staked = 0;
            state.seconds = 0;
        };
    }
}
