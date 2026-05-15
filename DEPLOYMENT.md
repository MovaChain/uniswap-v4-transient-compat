# Deployment and Testing Guide

This document explains how to deploy and test the current version. This build replaces Uniswap v4's original `TSTORE/TLOAD` transient storage usage with storage + epoch-scoped storage, making it compatible with chains that do not support transient storage.

## Chain Configuration

Deployment scripts and commands use environment variables to configure the target chain. Set the target chain first:

```bash
export RPC_URL=<target-rpc-url>
export CHAIN_ID=<target-chain-id>
export CHAIN_NAME=<target-chain-name>
```

Confirm that the RPC chain id matches the configured value:

```bash
cast chain-id --rpc-url "$RPC_URL"
test "$(cast chain-id --rpc-url "$RPC_URL")" = "$CHAIN_ID"
```

Verified example: Mova testnet.

```bash
export RPC_URL=https://mars.rpc.movachain.com
export CHAIN_ID=10323
export CHAIN_NAME=mova-testnet
```

The EVM version must match the target chain's capabilities. This compatibility build targets chains without transient storage support, and `foundry.toml` uses the following by default:

```toml
evm_version = "paris"
```

If the target chain requires a different EVM version, update `foundry.toml` or add a Foundry profile before building and deploying.

All subsequent `forge create`, `cast send`, and `cast call` commands use `$RPC_URL` and `$PRIVATE_KEY`, so the same flow can be switched to any target chain. Make sure the target chain supports the EVM instructions used by the current contract bytecode.

## Environment Setup

Install Foundry and fetch dependencies:

```bash
forge --version
cast --version
forge install
```

Set environment variables:

```bash
export PRIVATE_KEY=0x...
export DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")
```

The deployer account needs enough native currency on the target chain to pay gas and to run native-token pool liquidity and swap tests.

## Local Build and Tests

Build:

```bash
forge build
```

It is recommended to first run the test slices most relevant to the storage + epoch changes:

```bash
forge test --match-path 'test/PoolManager.t.sol' --match-test 'test_(sync|settle|unlock|swap|addLiquidity|removeLiquidity|take|collectProtocolFees)'
forge test --match-path 'test/Sync.t.sol'
forge test --match-path 'test/libraries/Lock.t.sol'
forge test --match-path 'test/libraries/NonzeroDeltaCount.t.sol'
forge test --match-path 'test/CurrencyReserves.t.sol'
```

Note: the current version may have a full `forge test` failure in a `TickMath` fuzz boundary case unrelated to this change. The storage, lock, sync, settle, swap, and liquidity-related test slices should pass.

## Option A: Verified Script Smoke Test

Script:

```text
script/MovaTestnetDeployAndSwap.s.sol
```

Note: this script is a Mova testnet verification script and internally checks `block.chainid == 10323`. It is suitable as a quick smoke test on the verified chain. To reuse it on another chain, first change the chain id check in the script or copy it into a target-chain-specific script.

The script deploys:

- `PoolManager`
- `MovaTestRouter`
- Two test ERC20 tokens

It then automatically executes:

- approve router
- initialize a native-token pool
- initialize a token-token pool
- add liquidity
- swap in both directions
- remove liquidity

Dry run first:

```bash
forge script script/MovaTestnetDeployAndSwap.s.sol:MovaTestnetDeployAndSwap \
  --rpc-url "$RPC_URL"
```

Broadcast:

```bash
forge script script/MovaTestnetDeployAndSwap.s.sol:MovaTestnetDeployAndSwap \
  --rpc-url "$RPC_URL" \
  --broadcast
```

Broadcast records are written under the actual chain id:

```text
broadcast/MovaTestnetDeployAndSwap.s.sol/<chain-id>/
```

## Option B: Generic Manual Deployment and Step-by-Step Testing

This is the recommended generic flow. It does not depend on a specific chain id. Use this option as well if you need to reproduce the named-token flow in `MARS_TEST_REPORT.md`.

### 1. Deploy PoolManager

```bash
forge create src/PoolManager.sol:PoolManager \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --constructor-args "$DEPLOYER"
```

Save the returned address:

```bash
export POOL_MANAGER=0x...
```

### 2. Deploy the Test Router

```bash
forge create src/testnet/MovaTestRouter.sol:MovaTestRouter \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --constructor-args "$POOL_MANAGER"
```

Save the returned address:

```bash
export ROUTER=0x...
```

### 3. Deploy Named Test Tokens

Token names and symbols can be adjusted for the target chain:

```bash
export TOKEN_A_NAME="${CHAIN_NAME} Alpha Test Token"
export TOKEN_A_SYMBOL="ALPHA"
export TOKEN_B_NAME="${CHAIN_NAME} Beta Test Token"
export TOKEN_B_SYMBOL="BETA"
export TOKEN_SUPPLY=1000000000000000000000000
```

```bash
forge create src/testnet/MovaNamedTestToken.sol:MovaNamedTestToken \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --constructor-args "$TOKEN_A_NAME" "$TOKEN_A_SYMBOL" 18 "$TOKEN_SUPPLY"

forge create src/testnet/MovaNamedTestToken.sol:MovaNamedTestToken \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --constructor-args "$TOKEN_B_NAME" "$TOKEN_B_SYMBOL" 18 "$TOKEN_SUPPLY"
```

Save the returned addresses:

```bash
export ALPHA=0x...
export BETA=0x...
```

Set common parameters:

```bash
export NATIVE=0x0000000000000000000000000000000000000000
export HOOKS=0x0000000000000000000000000000000000000000
export FEE=3000
export TICK_SPACING=60
export SQRT_PRICE_1_1=79228162514264337593543950336
export TICK_LOWER=-120
export TICK_UPPER=120
export LIQUIDITY=1000000000000000000
export SALT=0x0000000000000000000000000000000000000000000000000000000000000000
```

Uniswap v4 requires `currency0 < currency1`. For native-token pools, native is always `currency0`. For token-token pools, sort the token addresses and set:

```bash
# Example: set these manually according to the address order of ALPHA and BETA
export TOKEN0=$BETA
export TOKEN1=$ALPHA
```

### 4. Approve the Router

```bash
export MAX_UINT=0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff

cast send "$ALPHA" 'approve(address,uint256)' "$ROUTER" "$MAX_UINT" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"

cast send "$BETA" 'approve(address,uint256)' "$ROUTER" "$MAX_UINT" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
```

### 5. Initialize Pools

native / Alpha:

```bash
cast send "$POOL_MANAGER" \
  'initialize((address,address,uint24,int24,address),uint160)' \
  "($NATIVE,$ALPHA,$FEE,$TICK_SPACING,$HOOKS)" \
  "$SQRT_PRICE_1_1" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
```

token-token:

```bash
cast send "$POOL_MANAGER" \
  'initialize((address,address,uint24,int24,address),uint160)' \
  "($TOKEN0,$TOKEN1,$FEE,$TICK_SPACING,$HOOKS)" \
  "$SQRT_PRICE_1_1" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
```

## Step-by-Step Functional Tests

`modifyLiquidity` and `swap` must be called through `MovaTestRouter`. The router calls `PoolManager.unlock()`, performs the operation inside `unlockCallback`, settles or takes both currency deltas, and then lets `PoolManager` lock successfully.

### Add Liquidity

native / Alpha:

```bash
cast send "$ROUTER" \
  'modifyLiquidity((address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)' \
  "($NATIVE,$ALPHA,$FEE,$TICK_SPACING,$HOOKS)" \
  "($TICK_LOWER,$TICK_UPPER,$LIQUIDITY,$SALT)" \
  0x \
  --value 20000000000000000 \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
```

token-token:

```bash
cast send "$ROUTER" \
  'modifyLiquidity((address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)' \
  "($TOKEN0,$TOKEN1,$FEE,$TICK_SPACING,$HOOKS)" \
  "($TICK_LOWER,$TICK_UPPER,$LIQUIDITY,$SALT)" \
  0x \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
```

### Swap

Set swap parameters:

```bash
export SWAP_AMOUNT=-1000000000000
export MIN_SQRT_PRICE_PLUS_ONE=4295128740
export MAX_SQRT_PRICE_MINUS_ONE=1461446703485210103287273052203988822378723970341
```

native -> Alpha:

```bash
cast send "$ROUTER" \
  'swap((address,address,uint24,int24,address),(bool,int256,uint160),bytes)' \
  "($NATIVE,$ALPHA,$FEE,$TICK_SPACING,$HOOKS)" \
  "(true,$SWAP_AMOUNT,$MIN_SQRT_PRICE_PLUS_ONE)" \
  0x \
  --value 1000000000000 \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
```

Alpha -> native:

```bash
cast send "$ROUTER" \
  'swap((address,address,uint24,int24,address),(bool,int256,uint160),bytes)' \
  "($NATIVE,$ALPHA,$FEE,$TICK_SPACING,$HOOKS)" \
  "(false,$SWAP_AMOUNT,$MAX_SQRT_PRICE_MINUS_ONE)" \
  0x \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
```

Token0 -> Token1:

```bash
cast send "$ROUTER" \
  'swap((address,address,uint24,int24,address),(bool,int256,uint160),bytes)' \
  "($TOKEN0,$TOKEN1,$FEE,$TICK_SPACING,$HOOKS)" \
  "(true,$SWAP_AMOUNT,$MIN_SQRT_PRICE_PLUS_ONE)" \
  0x \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
```

Token1 -> Token0:

```bash
cast send "$ROUTER" \
  'swap((address,address,uint24,int24,address),(bool,int256,uint160),bytes)' \
  "($TOKEN0,$TOKEN1,$FEE,$TICK_SPACING,$HOOKS)" \
  "(false,$SWAP_AMOUNT,$MAX_SQRT_PRICE_MINUS_ONE)" \
  0x \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
```

### Remove Liquidity

```bash
export REMOVE_LIQUIDITY=-1000000000000000000
```

native / Alpha:

```bash
cast send "$ROUTER" \
  'modifyLiquidity((address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)' \
  "($NATIVE,$ALPHA,$FEE,$TICK_SPACING,$HOOKS)" \
  "($TICK_LOWER,$TICK_UPPER,$REMOVE_LIQUIDITY,$SALT)" \
  0x \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
```

token-token:

```bash
cast send "$ROUTER" \
  'modifyLiquidity((address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)' \
  "($TOKEN0,$TOKEN1,$FEE,$TICK_SPACING,$HOOKS)" \
  "($TICK_LOWER,$TICK_UPPER,$REMOVE_LIQUIDITY,$SALT)" \
  0x \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY"
```

Complex sequence tests can repeat the following flow:

1. Add liquidity
2. Add liquidity again
3. Swap
4. Remove partial liquidity
5. Reverse swap
6. Remove remaining liquidity

## Transaction Result Checks

Some test-chain RPCs may return receipts without the `type` field, causing some versions of `cast send` / `cast receipt` to print a receipt deserialization error even after the transaction has landed on-chain. In this case, rely on the raw RPC receipt `status`.

```bash
export TX_HASH=0x...

curl -s "$RPC_URL" \
  -H 'content-type: application/json' \
  --data '{"jsonrpc":"2.0","id":1,"method":"eth_getTransactionReceipt","params":["'"$TX_HASH"'"]}' \
  | jq '.result | {status, blockNumber, gasUsed, logs: (.logs | length)}'
```

A successful transaction should return:

```json
{
  "status": "0x1"
}
```

Check balances:

```bash
cast balance "$DEPLOYER" --rpc-url "$RPC_URL"
cast balance "$POOL_MANAGER" --rpc-url "$RPC_URL"

cast call "$ALPHA" 'balanceOf(address)(uint256)' "$DEPLOYER" --rpc-url "$RPC_URL"
cast call "$BETA" 'balanceOf(address)(uint256)' "$DEPLOYER" --rpc-url "$RPC_URL"
cast call "$ALPHA" 'balanceOf(address)(uint256)' "$POOL_MANAGER" --rpc-url "$RPC_URL"
cast call "$BETA" 'balanceOf(address)(uint256)' "$POOL_MANAGER" --rpc-url "$RPC_URL"
```

Read the current epoch:

```bash
export EPOCH_SLOT=0x668146ca85848777f0ddc67c485ba93c0c4482231149dce151713c1a85ef76fa

cast call "$POOL_MANAGER" 'exttload(bytes32)(bytes32)' "$EPOCH_SLOT" --rpc-url "$RPC_URL"
```

`epoch` increments by 1 after each successful `PoolManager.unlock()` lifecycle.

## Expected Behavior

- `initialize()` can be called directly on `PoolManager`.
- `modifyLiquidity()`, `swap()`, `donate()`, `take()`, `settle()`, `settleFor()`, `clear()`, `mint()`, and `burn()` all require the manager to be unlocked.
- In the current compatibility version, `sync()` also requires the manager to be unlocked. This is intentional: if the storage-backed version allowed writes to sync state while locked, it would leave pseudo-transient state that should have disappeared automatically at transaction end.
- A successful router operation means all currency deltas were settled within the same `unlock()` lifecycle. Otherwise, `PoolManager.unlock()` reverts with `CurrencyNotSettled` at the end.
