# Deployment and Test Flow

Updated: 2026-05-19

This document records the recommended deployment and test flow for the current version. The target chain does not support native `TLOAD/TSTORE`, so the contracts simulate transient storage through `EpochState` and the hook compatibility library.

## Environment

Mova testnet:

```bash
export RPC_URL=https://mars.rpc.movachain.com
export CHAIN_ID=10323
export CHAIN_NAME=mova-testnet
export FOUNDRY_PROFILE=mova
```

Pass the private key through an environment variable. Do not write it into documentation or commit it to the repository:

```bash
export PRIVATE_KEY=<private-key>
export DEPLOYER=$(cast wallet address --private-key "$PRIVATE_KEY")
```

Confirm the chain ID:

```bash
cast chain-id --rpc-url "$RPC_URL"
test "$(cast chain-id --rpc-url "$RPC_URL")" = "$CHAIN_ID"
```

Mars RPC does not support `eth_feeHistory`, so broadcast transactions with legacy gas:

```bash
--legacy
```

## Local Build and Tests

```bash
forge build

forge test --match-path 'test/PoolManager.t.sol' --match-test 'test_(sync|settle|unlock|swap|addLiquidity|removeLiquidity|take|collectProtocolFees)'
forge test --match-path 'test/Sync.t.sol'
forge test --match-path 'test/libraries/Lock.t.sol'
forge test --match-path 'test/libraries/NonzeroDeltaCount.t.sol'
forge test --match-path 'test/CurrencyReserves.t.sol'
forge test --match-path 'test/MovaExactInputFeeHook.t.sol'
git diff --check
```

## Per-Transaction Confirmation Rule

On-chain tests must wait for each transaction to be confirmed before sending the next one. Use `cast send --json` and check the receipt each time:

```bash
status=$(printf '%s\n' "$receipt_json" | jq -r '.status')
test "$status" = "0x1" -o "$status" = "1"
```

Some Mars RPC receipts are missing the `type` field, so Foundry / cast may print a deserialization error. In that case, use the `status` field in the raw receipt JSON as the source of truth.

## Deploy PoolManager

The recommended flow is to compile initcode with the `mova` profile and deploy it with `cast send --create`.

```bash
BYTECODE=$(FOUNDRY_PROFILE=mova forge inspect src/PoolManager.sol:PoolManager bytecode)
ARGS=$(cast abi-encode 'constructor(address)' "$DEPLOYER")
INITCODE="$BYTECODE${ARGS#0x}"

cast send --create "$INITCODE" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --legacy \
  --gas-limit 10000000 \
  --json
```

Save the returned `contractAddress`:

```bash
export POOL_MANAGER=0x...
```

Verify:

```bash
cast code "$POOL_MANAGER" --rpc-url "$RPC_URL" | wc -c
cast call "$POOL_MANAGER" 'owner()(address)' --rpc-url "$RPC_URL"
```

## Deploy Router and Tokens

Router:

```bash
BYTECODE=$(FOUNDRY_PROFILE=mova forge inspect src/testnet/MovaTestRouter.sol:MovaTestRouter bytecode)
ARGS=$(cast abi-encode 'constructor(address)' "$POOL_MANAGER")
INITCODE="$BYTECODE${ARGS#0x}"

cast send --create "$INITCODE" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --legacy \
  --gas-limit 12000000 \
  --json

export ROUTER=0x...
```

Test tokens:

```bash
export TOKEN_SUPPLY=1000000000000000000000000

BYTECODE=$(FOUNDRY_PROFILE=mova forge inspect src/testnet/MovaNamedTestToken.sol:MovaNamedTestToken bytecode)
ARGS=$(cast abi-encode 'constructor(string,string,uint8,uint256)' "MOVA Alpha Compat" "MOVA-A" 18 "$TOKEN_SUPPLY")
INITCODE="$BYTECODE${ARGS#0x}"
cast send --create "$INITCODE" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --gas-limit 12000000 --json
export ALPHA=0x...

ARGS=$(cast abi-encode 'constructor(string,string,uint8,uint256)' "MOVA Beta Compat" "MOVA-B" 18 "$TOKEN_SUPPLY")
INITCODE="$BYTECODE${ARGS#0x}"
cast send --create "$INITCODE" --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --gas-limit 12000000 --json
export BETA=0x...
```

Approve:

```bash
export MAX_UINT=0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff

cast send "$ALPHA" 'approve(address,uint256)' "$ROUTER" "$MAX_UINT" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --gas-limit 200000 --json

cast send "$BETA" 'approve(address,uint256)' "$ROUTER" "$MAX_UINT" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --gas-limit 200000 --json
```

## No-Hook Pool Tests

Common parameters:

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
export SWAP_AMOUNT=-1000000000000
export MIN_SQRT_PRICE_PLUS_ONE=4295128740
export MAX_SQRT_PRICE_MINUS_ONE=1461446703485210103287273052203988822378723970341
```

The token-token pool requires address sorting:

```bash
export TOKEN0=<smaller-token-address>
export TOKEN1=<larger-token-address>
```

Initialize:

```bash
cast send "$POOL_MANAGER" \
  'initialize((address,address,uint24,int24,address),uint160)' \
  "($NATIVE,$ALPHA,$FEE,$TICK_SPACING,$HOOKS)" \
  "$SQRT_PRICE_1_1" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --gas-limit 2000000 --json

cast send "$POOL_MANAGER" \
  'initialize((address,address,uint24,int24,address),uint160)' \
  "($TOKEN0,$TOKEN1,$FEE,$TICK_SPACING,$HOOKS)" \
  "$SQRT_PRICE_1_1" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --gas-limit 2000000 --json
```

Add liquidity:

```bash
cast send "$ROUTER" \
  'modifyLiquidity((address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)' \
  "($NATIVE,$ALPHA,$FEE,$TICK_SPACING,$HOOKS)" \
  "($TICK_LOWER,$TICK_UPPER,$LIQUIDITY,$SALT)" \
  0x \
  --value 20000000000000000 \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --gas-limit 12000000 --json

cast send "$ROUTER" \
  'modifyLiquidity((address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)' \
  "($TOKEN0,$TOKEN1,$FEE,$TICK_SPACING,$HOOKS)" \
  "($TICK_LOWER,$TICK_UPPER,$LIQUIDITY,$SALT)" \
  0x \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --gas-limit 12000000 --json
```

Swap:

```bash
cast send "$ROUTER" \
  'swap((address,address,uint24,int24,address),(bool,int256,uint160),bytes)' \
  "($NATIVE,$ALPHA,$FEE,$TICK_SPACING,$HOOKS)" \
  "(true,$SWAP_AMOUNT,$MIN_SQRT_PRICE_PLUS_ONE)" \
  0x \
  --value 1000000000000 \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --gas-limit 12000000 --json

cast send "$ROUTER" \
  'swap((address,address,uint24,int24,address),(bool,int256,uint160),bytes)' \
  "($NATIVE,$ALPHA,$FEE,$TICK_SPACING,$HOOKS)" \
  "(false,$SWAP_AMOUNT,$MAX_SQRT_PRICE_MINUS_ONE)" \
  0x \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --gas-limit 12000000 --json
```

For token-token swaps, call `swap` the same way and use the key `($TOKEN0,$TOKEN1,$FEE,$TICK_SPACING,$HOOKS)`.

Remove liquidity:

```bash
export REMOVE_LIQUIDITY=-1000000000000000000
```

```bash
cast send "$ROUTER" \
  'modifyLiquidity((address,address,uint24,int24,address),(int24,int24,int256,bytes32),bytes)' \
  "($NATIVE,$ALPHA,$FEE,$TICK_SPACING,$HOOKS)" \
  "($TICK_LOWER,$TICK_UPPER,$REMOVE_LIQUIDITY,$SALT)" \
  0x \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --gas-limit 12000000 --json
```

## Hook Test

Deploy HookDeployer:

```bash
BYTECODE=$(FOUNDRY_PROFILE=mova forge inspect src/testnet/MovaHookDeployer.sol:MovaHookDeployer bytecode)
ARGS=$(cast abi-encode 'constructor()')
INITCODE="$BYTECODE${ARGS#0x}"

cast send --create "$INITCODE" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --legacy \
  --gas-limit 12000000 \
  --json

export HOOK_DEPLOYER=0x...
```

Compute the hook address and salt that match the permission flags:

```bash
HOOK_INITCODE=$(FOUNDRY_PROFILE=mova forge inspect src/testnet/MovaExactInputFeeHook.sol:MovaExactInputFeeHook bytecode)
HOOK_ARGS=$(cast abi-encode 'constructor(address)' "$POOL_MANAGER")
HOOK_FULL_INITCODE="$HOOK_INITCODE${HOOK_ARGS#0x}"

cast create2 \
  --deployer "$HOOK_DEPLOYER" \
  --init-code "$HOOK_FULL_INITCODE" \
  --ends-with 00c4
```

Deploy the hook:

```bash
export HOOK_SALT=0x...
export HOOK=0x...

cast send "$HOOK_DEPLOYER" 'deployExactInputFeeHook(address,bytes32)' "$POOL_MANAGER" "$HOOK_SALT" \
  --rpc-url "$RPC_URL" --private-key "$PRIVATE_KEY" --legacy --gas-limit 12000000 --json

cast call "$HOOK" 'validateHookAddress()' --rpc-url "$RPC_URL"
```

Deploy the hook token, approve it, initialize the native-token pool with the hook, then execute through the router:

- add liquidity
- native -> token exact-input swap
- token -> native exact-input swap

Query hook state:

```bash
cast call "$HOOK" 'lastFeeAmount()(uint256)' --rpc-url "$RPC_URL"
cast call "$HOOK" 'lastInputAmount()(uint256)' --rpc-url "$RPC_URL"
cast call "$HOOK" 'lastBeforeSwapEpoch()(uint256)' --rpc-url "$RPC_URL"
cast call "$HOOK" 'lastAfterSwapEpoch()(uint256)' --rpc-url "$RPC_URL"
cast call "$HOOK" 'transientActive()(bool)' --rpc-url "$RPC_URL"
cast call "$HOOK" 'transientInputAmount()(uint256)' --rpc-url "$RPC_URL"
```

Success criteria:

- Both swaps return `status=0x1`.
- `lastInputAmount` equals the absolute value of the exact-input amount.
- `lastFeeAmount` is greater than 0.
- `lastBeforeSwapEpoch == lastAfterSwapEpoch`.
- `transientActive == false`.
- `transientInputAmount == 0`.
