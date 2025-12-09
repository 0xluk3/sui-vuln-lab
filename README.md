# sui-vuln-lab

A small Sui Move “vuln lab” with intentionally broken patterns around access control, time units, tables, reentrancy, and phantom roles. Each subdirectory under `vulnlab/sources` contains a standalone example you can publish and attack on Sui testnet.

## Layout

```text
vulnlab/
  Move.toml
  sources/
    access_control_1/
    access_control_2/
    access_control_3/
    tables_1/
    tables_2/
    time_units/
    hot_potato/
```

## Getting started on Sui testnet

Check your CLI and switch to testnet:

```bash
sui --version
sui client envs
sui client switch --env testnet
```

Publish the package (from the vulnlab directory):

```bash
cd vulnlab
sui client publish --gas-budget 100000000
```

Inspect created objects:

```bash
sui client objects
sui client object <OBJECT_ID>
```

### Example PTB-style call: access_control_1 emergency withdraw

After publishing, note:

*   **PACKAGE_ID** – from the publish output
*   **VAULT_ID** – the shared Vault object created by init in access_control_1

You can trigger the vulnerable `emergency_withdraw` like this (this builds a PTB with a single MoveCall under the hood):

```bash
PACKAGE_ID=0x...       # from publish output
VAULT_ID=0x...         # shared Vault object id

sui client call \
  --package  "$PACKAGE_ID" \
  --module   access_control_visibility_confusion \
  --function emergency_withdraw \
  --args     "$VAULT_ID" \
  --gas-budget 100000000
```

Because the function is `public(package) entry`, it is still callable as a transaction entry point even though its visibility might look “internal”. That’s the whole point of the lab.

## Labs

### access_control_1 – public(package) entry confusion

This lab shows how `public(package) entry` can be misleading: even though the function is only package-visible at the Move level, marking it as `entry` makes it directly callable as a transaction entry point. The vulnerable function lets any caller escalate privileges on a shared Vault object by calling an “emergency” function that was assumed to be internal.

**Key takeaways:** don’t rely on `public(package)` alone for access control. Treat any entry function as externally callable and explicitly check the sender, capabilities, or object ownership.

### access_control_2 – visibility vs real authorization

This is kind of playground for the access-control-1 theme with several variants of a `withdraw_all_*` function. One version takes an untrusted `caller: address` argument and never checks it, another is `public(package)` and forwards through a private helper, and the entry function again forgets to enforce `caller == admin`. 

**Key takeaways:** visibility controls who can syntactically call a function, not who is authorized to perform a state change. Always gate sensitive logic with checks on `tx_context::sender` and/or capabilities instead of trusting where the call comes from.

### access_control_3 – phantom role cap privilege escalation

This module uses phantom generic parameters to model roles: `RoleCap<UserRole>`, `RoleCap<ModRole>`, and `RoleCap<AdminRole>`. The `moderator_checkout_admin` function is generic over `R` and accepts `&RoleCap<R>`, so any role (even a plain user) can pass their capability and receive a one-shot `RoleCap<AdminRole>`, then call `sudo_execute`. The type system appears to enforce roles, but the overly-generic function signature opens a privilege-escalation path.

**Key takeaways:** be very careful with generics over phantom-role types. For access control, functions should require concrete types like `&RoleCap<ModRole>` instead of generic `R` so that only the intended capabilities type-check.

### tables_1 – table key collision / duplicate deposit

This lab implements a simple Bank using `Table<address, u64>` and a buggy `deposit_buggy` that always calls `table::add` even if the key already exists. The second deposit for the same user aborts due to a duplicate key, blocking further deposits instead of incrementing the balance. A fixed version uses `table::contains` and `borrow_mut` to implement insert-or-increase semantics.

**Key takeaways:** when using Table, decide explicitly whether you want “insert-only” or “upsert” semantics. Blindly calling `add` on a key that might already exist creates denial-of-service conditions and brittle APIs.

### tables_2 – unbounded iteration on user-controlled data

`tables_2` defines a Leaderboard that stores scores in a vector and exposes a loop that walks through all entries with no upper bound beyond the current vector length. The accompanying test shows how an attacker can create a large vector of scores and force very large iterations, making the function effectively uncallable or extremely expensive.

**Key takeaways:** never trust user-controlled structure sizes when iterating. Always enforce sane upper bounds, cap collection sizes, or use pagination / amortized updates for large collections.

### time_units – broken timelock from seconds/ms confusion

The `vuln_stake` module tries to implement a simple 10-day staking lock. The `stake` function records a timestamp into a field conceptually named `seconds`, but the value is derived from milliseconds and then misused. The `unstake` function later compares “now in seconds” against `state.seconds + STAKE_LOCK_TIME_SECONDS`, which completely breaks the intended timelock and can allow users to unlock stake far earlier than expected.

**Key takeaways:** be extremely explicit about units when working with time. Name fields by unit, use a single unit consistently, and double-check every conversion. Mixing milliseconds and seconds silently invalidates security assumptions around lock periods.

### hot_potato – nested hot-potato / reentrancy-like bug

The `hot_potato_vault` module is a flash-loan / harvest-like pattern with a Vault, a `HarvestOp` “hot potato” object, and `start_harvest` / `withdraw_for_strategy` / `finish_harvest`. In a normal flow, if a yield farm is deployed, its admin could use the capital for a flash swap arbitrage opportunities. The farm requires the admin to return at least 98% of borrowed capital to minimize losses. The admin can only withdraw the reserves during harvest and they are saved on harvest start, which is checked on return. The bug is that `start_harvest` can be called repeatedly in a nested manner during an ongoing operation, resetting `saved_reserves` and `operation_in_progress`. This lets the admin wrap sensitive operations, refresh the snapshot, and dodge the final `MIN_RETURN_BPS` check.

**Key takeaways:** when designing PTB-based flash loans or similar operations, make sure that “operation in progress” flags cannot be reset mid-operation and that you cannot re-enter `start_*` while a previous operation is live. If nesting is intentionally supported, the logic needs to be designed and tested specifically for that case.
