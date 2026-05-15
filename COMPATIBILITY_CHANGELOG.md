# Uniswap v4 Non-Transient Storage Compatibility Changelog

## Background

This version targets EVM chains that do not support the `TLOAD/TSTORE` transient storage opcodes. Uniswap v4 originally relies on transient storage to keep temporary state during a single `unlock()` lifecycle, including lock state, currency deltas, synced reserves, nonzero delta count, and related session data.

This change migrates that session-scoped data to regular storage and isolates each `unlock()` lifecycle by epoch, preventing stale state from being read across transactions or across sessions.

## Final Implementation

### 1. Epoch-Scoped Storage

Added `src/libraries/EpochState.sol` to centralize the session-state data that used to be backed by transient storage.

The scoped key is derived as:

```solidity
bytes32 scopedKey = keccak256(
    abi.encode(
        STORAGE_NAMESPACE,
        address(this),
        currentEpoch(),
        slot
    )
);
```

Where:

- `STORAGE_NAMESPACE` isolates this compatibility layer's storage namespace.
- `address(this)` isolates different manager instances.
- `currentEpoch()` represents the current `unlock()` lifecycle.
- `slot` is the logical slot originally used by Uniswap v4 transient storage.

Storage written under historical epochs is not actively cleared, but each new epoch uses different scoped keys, so old state cannot pollute later sessions.

### 2. Unlock Lifecycle

`PoolManager.unlock()` now follows this lifecycle:

1. Check whether the manager is already unlocked.
2. Advance the epoch through `Lock.unlock()`.
3. Mark the current epoch as unlocked.
4. Execute `IUnlockCallback(msg.sender).unlockCallback(data)`.
5. Check `NonzeroDeltaCount.read() == 0`.
6. Mark the current epoch as locked.

The settlement constraints of `unlock()` keep the original Uniswap v4 business semantics. This change only replaces the underlying storage mechanism for related session state.

### 3. Lock / Delta / Reserves / Count Storage Replacement

The following libraries no longer use `tload/tstore` directly and now read/write epoch-scoped storage through `EpochState`:

- `src/libraries/Lock.sol`
- `src/libraries/CurrencyDelta.sol`
- `src/libraries/CurrencyReserves.sol`
- `src/libraries/NonzeroDeltaCount.sol`

The covered state includes:

- unlocked state
- per `(target, currency)` currency deltas
- currency and reserve snapshots written by `sync()`
- nonzero delta count within the current unlock lifecycle

When the manager is locked, reads of session-scoped state return empty values. Semantically, this is equivalent to transient storage being cleared at the end of the transaction.

### 4. `exttload` Compatibility Layer

`src/Exttload.sol` keeps the original external `IExttload` interface:

```solidity
function exttload(bytes32 slot) external view returns (bytes32);
function exttload(bytes32[] calldata slots) external view returns (bytes32[] memory);
```

The actual read logic is implemented by `PoolManager._exttload()` and `ProxyPoolManager._exttload()`:

- Reading `EpochState.EPOCH_SLOT` returns the current epoch.
- Reading any other logical slot maps it to the current epoch's scoped storage.
- When the manager is locked, session-state reads other than the epoch return `0`.

Third-party integrations can still use `TransientStateLibrary`:

```solidity
manager.isUnlocked();
manager.currencyDelta(target, currency);
manager.getSyncedCurrency();
manager.getSyncedReserves();
manager.getNonzeroDeltaCount();
manager.currentEpoch();
```

These helpers still go through `manager.exttload(logicalSlot)`, preserving the original v4 transient-state read pattern.

### 5. `sync()` Lock-State Protection

Both `PoolManager.sync()` and `ProxyPoolManager.sync()` are now protected by `onlyWhenUnlocked`.

This is required for the storage-backed compatibility implementation: original transient storage is automatically cleared at transaction end, while regular storage is not. If `sync()` were allowed while locked, it could write state that should only exist inside an unlock lifecycle.

Current behavior:

- Calling `sync()` while locked reverts with `ManagerLocked`.
- While unlocked, `sync()`, ERC20 transfer, and `settle()` must all happen within the same `unlockCallback`.

### 6. Test Helper Adjustments

The following test helper contracts and test cases were updated for epoch-scoped storage behavior:

- `src/test/ActionsRouter.sol`
- `src/test/ProxyPoolManager.sol`
- `src/test/SkipCallsTestHook.sol`
- `test/PoolManager.t.sol`
- `test/Sync.t.sol`
- `test/CurrencyReserves.t.sol`
- `test/libraries/NonzeroDeltaCount.t.sol`

Key adjustments include:

- Reading manager session state through `TransientStateLibrary`.
- Moving `sync()`-related tests into an unlocked lifecycle.
- Adding coverage that verifies `sync()` reverts with `ManagerLocked` when called while locked.

### 7. Testnet Helper Contracts

Added the following testnet helper contracts:

- `src/testnet/MovaTestRouter.sol`
- `src/testnet/MovaNamedTestToken.sol`

`MovaTestRouter` is used on testnets to call `modifyLiquidity()` and `swap()` step by step:

1. An external user calls the router.
2. The router calls `PoolManager.unlock()`.
3. The router calls `modifyLiquidity()` or `swap()` inside `unlockCallback()`.
4. Based on the returned `BalanceDelta`, the router performs `settle()` or `take()` for both currencies.
5. `PoolManager.unlock()` completes the current unlock lifecycle.

This flow covers adding liquidity, swapping, and removing liquidity for both native-token and token-token pools.

## Behavioral Results

The current compatibility version behaves as follows:

- It no longer depends on the `TLOAD/TSTORE` opcodes.
- Each `unlock()` uses a fresh epoch to isolate session state.
- Session-state reads return empty values while the manager is locked.
- `sync()` requires the manager to be unlocked, preventing writes to state that should only exist during an unlock lifecycle.
- Third-party reads still work through `TransientStateLibrary` + `exttload`; no new external `PoolManager` getters are required.

## Verification

The following key test slices were run and passed:

```bash
forge test --match-path 'test/PoolManager.t.sol' --match-test 'test_(sync|settle|unlock|swap|addLiquidity|removeLiquidity|take|collectProtocolFees)'
forge test --match-path 'test/Sync.t.sol'
forge test --match-path 'test/libraries/Lock.t.sol'
forge test --match-path 'test/libraries/NonzeroDeltaCount.t.sol'
forge test --match-path 'test/CurrencyReserves.t.sol'
```

The following testnet flow was verified:

- Deploy `PoolManager`
- Deploy the test router
- Deploy test tokens
- Approve the router
- Initialize a native-token pool
- Initialize a token-token pool
- Add liquidity
- Swap in both directions
- Remove partial liquidity
- Swap in the reverse direction
- Remove the remaining liquidity

All on-chain transactions succeeded. Liquidity, swap deltas, fees, final balances, and epoch increments in the key events matched expectations.
