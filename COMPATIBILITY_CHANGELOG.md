# Compatibility Changelog

Updated: 2026-05-19

## Goal

The current version targets EVM chains that do not support EIP-1153 `TLOAD/TSTORE`. The project no longer assumes native transient storage support. Instead, it provides simulated transient load/store entry points inside the contracts.

Core requirements:

- `EpochState` is responsible only for the simulated transient session and raw `bytes32` key reads/writes.
- Business semantics remain in the original business libraries, for example `CurrencyDelta.getDelta/applyDelta` and `CurrencyReserves.getSyncedCurrency`.
- `EpochState` must not implement business-level APIs.
- Solidity edits are wrapped with `// begin edit` / `// end edit` comments, using the historical code from `46c6834698c48bc4a463a86d8420f4eb1d7f3b75` as the reference.
- New code blocks are wrapped only with `begin edit` / `end edit`; no `New file` or `No historical` fields are used.

## Design

### EpochState

`src/libraries/EpochState.sol` is now the only low-level entry point for simulated transient storage.

It provides:

- `enter()` / `exit()`: enter and exit one simulated transient session.
- `isActive()` / `currentEpoch()`: query the session state and epoch.
- `scopedSlot(bytes32)`: map a raw key to the storage slot scoped to the current epoch.
- `load/store/clear`: read, write, and clear by raw `bytes32` key.
- `loadUint256/storeUint256`, `loadInt256/storeInt256`, and `loadAddress/storeAddress`: thin typed wrappers.

### Lock

`src/libraries/Lock.sol` no longer calls `tstore/tload`.

Current behavior:

- `unlock()` calls `EpochState.enter()` and writes `IS_UNLOCKED_SLOT = 1`.
- `lock()` writes `IS_UNLOCKED_SLOT = 0` and calls `EpochState.exit()`.
- `isUnlocked()` checks `EpochState.load(IS_UNLOCKED_SLOT)`.

The historical `tstore/tload` code is preserved inside begin/end comment blocks.

### CurrencyDelta

`src/libraries/CurrencyDelta.sol` keeps the business APIs:

- `getDelta(Currency,address)`
- `applyDelta(Currency,address,int128)`

The slot computation function keeps the Uniswap v4 original name:

- `_computeSlot(address,Currency)`

In the current implementation, the business library computes the raw slot first, then calls `EpochState.loadInt256/storeInt256`.

### CurrencyReserves

`src/libraries/CurrencyReserves.sol` keeps the business APIs:

- `getSyncedCurrency()`
- `resetCurrency()`
- `syncCurrencyAndReserves(Currency,uint256)`
- `getSyncedReserves()`

These functions pass the original transient slots as raw keys to `EpochState`.

### NonzeroDeltaCount

`src/libraries/NonzeroDeltaCount.sol` uses `EpochState.loadUint256/storeUint256` instead of `tload/tstore`.

`increment()` / `decrement()` use `unchecked`, preserving semantics consistent with the Uniswap v4 original `tload/tstore` implementation.

### Exttload / PoolManager

`src/Exttload.sol` changes the public `exttload` behavior to call an internal virtual function:

- `exttload(bytes32)` -> `_exttload(slot)`
- `exttload(bytes32[])` -> loops over `_exttload`

`src/PoolManager.sol` implements `_exttload(bytes32)`:

- If the slot is `EpochState.EPOCH_SLOT`, it returns the current epoch.
- Other slots return `EpochState.load(slot)`.

This keeps simulated transient state observable externally through `exttload`.

### PoolManager.sync

`PoolManager.sync(Currency)` now has `onlyWhenUnlocked`.

This ensures the synchronized state in `CurrencyReserves` is only used inside the unlock lifecycle and prevents simulated transient state from being polluted while locked.

### TransientStateLibrary

`src/libraries/TransientStateLibrary.sol` adds `currentEpoch(IPoolManager)`, which reads the current epoch through `EpochState.EPOCH_SLOT` and `exttload`.

## Test Helper Contracts

### MovaTestRouter

`src/testnet/MovaTestRouter.sol` is used for manual testnet calls:

- `modifyLiquidity`
- `swap`

The router calls `PoolManager.unlock()`, executes the operation in `unlockCallback`, and completes `settle` or `take` in the same unlock lifecycle, ensuring deltas are settled before the manager locks again.

### MovaNamedTestToken

`src/testnet/MovaNamedTestToken.sol` is the ERC20 used on testnets.

### MovaExactInputFeeHook

`src/testnet/MovaExactInputFeeHook.sol` is the testnet hook:

- It charges a 5% fee from the output asset of exact-input swaps.
- The hook uses the simulated transient session from `mova-transient-compat-library`.
- `beforeSwap()` writes the input amount and direction.
- `afterSwap()` reads and validates the input amount and direction, charges the fee, then exits the session.

### MovaHookDeployer

`src/testnet/MovaHookDeployer.sol` deploys the hook with CREATE2 so the hook address low 14 bits satisfy the Uniswap v4 hook permission flags.

## Comment Convention

Solidity edits are wrapped in this format:

```solidity
// begin edit
// historical code or note
new implementation
// end edit
```

For new files or new code blocks, only this wrapper is used:

```solidity
// begin edit
new implementation
// end edit
```

## Local Verification

The current version has been verified locally with:

```bash
forge test --match-path 'test/PoolManager.t.sol' --match-test 'test_(sync|settle|unlock|swap|addLiquidity|removeLiquidity|take|collectProtocolFees)'
forge test --match-path 'test/Sync.t.sol'
forge test --match-path 'test/libraries/Lock.t.sol'
forge test --match-path 'test/libraries/NonzeroDeltaCount.t.sol'
forge test --match-path 'test/CurrencyReserves.t.sol'
forge test --match-path 'test/MovaExactInputFeeHook.t.sol'
forge build
git diff --check
```

Results:

- PoolManager-related tests: 63 passed.
- Sync tests: 12 passed.
- Lock tests: 2 passed.
- NonzeroDeltaCount tests: 3 passed.
- CurrencyReserves tests: 4 passed.
- MovaExactInputFeeHook tests: 3 passed.
- `forge build` passed.
- `git diff --check` passed.
