# Mova Testnet Uniswap v4 Compatibility Test Report

## Basic Information

| Item | Value |
| --- | --- |
| Network | Mova testnet |
| RPC | `https://mars.rpc.movachain.com` |
| Chain ID | `10323` |
| EVM version | Paris |
| Test account | `0xA38620A48424a61964184A8422F7a7f3dF5FC766` |
| PoolManager | `0x37f04396b3Aa193EED40dD2b8c0f4056D182EEB2` |
| Router | `0x7Be3613Dced5Afb5059Bc99a401aF4CdD4d109f2` |

This report covers two categories of verification:

- Basic native-token and token-token pool flows for the non-transient-storage-compatible Uniswap v4 build.
- A 5% exactInput fee hook flow using `mova-transient-compat-library`.

Only final valid results are recorded. Intermediate failed debugging attempts are not included as test conclusions.

## Test Code

| File | Description |
| --- | --- |
| `src/testnet/MovaTestRouter.sol` | Testnet unlock callback router |
| `src/testnet/MovaNamedTestToken.sol` | Test ERC20 token |
| `src/testnet/MovaExactInputFeeHook.sol` | 5% exactInput output-fee hook |
| `src/testnet/MovaHookDeployer.sol` | CREATE2 hook deployer for deploying to a permission-matching address |
| `script/MovaTestnetExactInputFeeHook.s.sol` | Mars hook test script |
| `test/MovaExactInputFeeHook.t.sol` | Local native-token hook tests |

## Contract Addresses

### Core Contracts

| Contract | Address | txHash | Description |
| --- | --- | --- | --- |
| `PoolManager` | `0x37f04396b3Aa193EED40dD2b8c0f4056D182EEB2` | `0xb035951702aa3cc3d2d978ae1829d33804cb8489207f0665ba404b1435f70332` | Adapted for non-transient storage |
| `MovaTestRouter` | `0x7Be3613Dced5Afb5059Bc99a401aF4CdD4d109f2` | `0xa0303a834360bd101e586c7cb00a09cd0b43fcaa012d23e432cdef45052f78f3` | Test unlock callback router |

### Test Tokens

| Token | Address | txHash | Name | Symbol | Decimals |
| --- | --- | --- | --- | --- | --- |
| Alpha | `0x63c42C3133c899320154918Cb1537c8278cC94F8` | `0x315cdf50c41b29aa4a480a947efcb776b988210c510258d0b02e486371a753a3` | `MOVA Alpha Test Token 20260513` | `MOVA-ALPHA-0513` | `18` |
| Beta | `0x1BE60C6EB94a1017f84e5d08C7FD5a6832538076` | `0x8e624a97466454831460c41870a5fbdf3e6342d9cfd030fb6d0c6630811e16a5` | `MOVA Beta Test Token 20260513` | `MOVA-BETA-0513` | `18` |
| Hook B | `0x64e9f73599945C332BacCFe07798FE4Bd3A9257f` | `0xb4454cfa1d2721273fa7f44cd50331ea2a01408b3acee3c3adbbca082f69a929` | `MOVA Hook Fee Test Token 20260514 B` | `MOVA-HOOK-B-0514` | `18` |

### Hook Contracts

| Contract | Address | txHash / salt | Description |
| --- | --- | --- | --- |
| `MovaHookDeployer` | `0x234729c6EE75af593e592AD1D7170bF9C9354F4C` | `0x911f3210da8e266097c63362c3c5255782eb7b0281efcc942c7015861e4e3d75` | CREATE2 hook deployer |
| `MovaExactInputFeeHook` | `0x0114156011Ae6Ec104EEFF8f8B7c3AcB253100c4` | deploy tx `0x709c1f7663c4d41696e8ab987c10a27038f50f6abe04aa7bf8811b2acedde06c`; salt `0xd883f10e78fdb6183686cd5195fc8d1737b1d63487b1efc329f91c7c43c35b27` | Low 14 bits are `0x00c4`, matching `beforeSwap + afterSwap + afterSwapReturnDelta` |

## PoolKey Configuration

### native / Alpha

| Field | Value |
| --- | --- |
| `currency0` | native token, `0x0000000000000000000000000000000000000000` |
| `currency1` | Alpha, `0x63c42C3133c899320154918Cb1537c8278cC94F8` |
| `fee` | `3000` |
| `tickSpacing` | `60` |
| `hooks` | `0x0000000000000000000000000000000000000000` |

### Beta / Alpha

Uniswap v4 requires `currency0 < currency1`, so after sorting by address the token-token pool is `Beta / Alpha`.

| Field | Value |
| --- | --- |
| `currency0` | Beta, `0x1BE60C6EB94a1017f84e5d08C7FD5a6832538076` |
| `currency1` | Alpha, `0x63c42C3133c899320154918Cb1537c8278cC94F8` |
| `fee` | `3000` |
| `tickSpacing` | `60` |
| `hooks` | `0x0000000000000000000000000000000000000000` |

### native / Hook B + 5% exactInput hook

| Field | Value |
| --- | --- |
| `currency0` | native token, `0x0000000000000000000000000000000000000000` |
| `currency1` | Hook B, `0x64e9f73599945C332BacCFe07798FE4Bd3A9257f` |
| `fee` | `3000` |
| `tickSpacing` | `60` |
| `hooks` | `0x0114156011Ae6Ec104EEFF8f8B7c3AcB253100c4` |

## Deployment and Initialization Verification

All transactions were confirmed with `status = 0x1`.

### Core Contracts and Test Assets

| Action | txHash |
| --- | --- |
| Deploy `PoolManager` | `0xb035951702aa3cc3d2d978ae1829d33804cb8489207f0665ba404b1435f70332` |
| Deploy `MovaTestRouter` | `0xa0303a834360bd101e586c7cb00a09cd0b43fcaa012d23e432cdef45052f78f3` |
| Deploy Alpha token | `0x315cdf50c41b29aa4a480a947efcb776b988210c510258d0b02e486371a753a3` |
| Deploy Beta token | `0x8e624a97466454831460c41870a5fbdf3e6342d9cfd030fb6d0c6630811e16a5` |
| Deploy Hook B token | `0xb4454cfa1d2721273fa7f44cd50331ea2a01408b3acee3c3adbbca082f69a929` |
| Alpha approve `MovaTestRouter` | `0xc2ea942940eb9f0c8ca585d5ecec12abddbdb79517a737e50b09143705fc498b` |
| Beta approve `MovaTestRouter` | `0x4704d81372828ea467e422fd58ea774def66024e3bc6f51f97fbe3b585f2563a` |
| Hook B approve `MovaTestRouter` | `0x82f43c873f564afc98b0d3f3824be13b8c31d93c479b1b6634f923448feac6d5` |

### Hook Deployment

| Action | txHash |
| --- | --- |
| Deploy `MovaHookDeployer` | `0x911f3210da8e266097c63362c3c5255782eb7b0281efcc942c7015861e4e3d75` |
| CREATE2 deploy `MovaExactInputFeeHook` | `0x709c1f7663c4d41696e8ab987c10a27038f50f6abe04aa7bf8811b2acedde06c` |

### Pool Initialization

| Pool | txHash |
| --- | --- |
| Initialize `native / Alpha` at initial price 1:1 | `0x7efc6a757741f44ed5fff38200997fa29aad35c867ab6e255e476cdf83d4760a` |
| Initialize `Beta / Alpha` at initial price 1:1 | `0x0b3870da00ff5d8727dca94a2dc590521df0572820a14c5ab204ed6aa9df2464` |
| Initialize `native / Hook B` at initial price 1:1 | `0x7ba8dbd5522e4d5c2c101e0bf4941d8c876afd4ba16f8316ab7e666460cda404` |

## Functional Verification

All swap and modifyLiquidity operations were executed through `MovaTestRouter`, which calls `PoolManager.unlock()` and settles currency deltas within the same unlock lifecycle.

### Basic Liquidity and Bidirectional Swaps

| Pool | Action | txHash |
| --- | --- | --- |
| `native / Alpha` | Add liquidity `+1e18` | `0x98c832e2ad77c83408612c832e28b211965294d1f431a15e180d27e128a1f22e` |
| `native / Alpha` | `native -> Alpha` swap | `0xdc553cef86ff72c6f3eba74f2b7c0b5b96774dced916fb24561bab32df222750` |
| `native / Alpha` | `Alpha -> native` swap | `0xdd8c5a5d5d701a49f76b94a0d6ed483a875a27505a27ce4e355b81dc8d4b8796` |
| `native / Alpha` | Remove liquidity `-1e18` | `0x23cc5872b847fb4dc61ca13e5be8061c0db901fdb875e1a3d0fced557187c95e` |
| `Beta / Alpha` | Add liquidity `+1e18` | `0x9e6487edd885d79ce1af1b4243082689ef870ac2790cc87201b4c265f8a86173` |
| `Beta / Alpha` | `Beta -> Alpha` swap | `0x5d971cb038ca5f1e469ec9b5bdeedc025b781607606aeb9dbc3d0c4d1a5b774f` |
| `Beta / Alpha` | `Alpha -> Beta` swap | `0x4c83d397d430224c5f2595f2b6a094be3d67160dc13f785488814b82a1a63dd2` |
| `Beta / Alpha` | Remove liquidity `-1e18` | `0x3aa415ad004e9accc779bdd0d0313882682834fd470e468095651ebbe2217100` |

### Sequential Operation Flow

The sequential flow covers:

1. Add liquidity
2. Add more liquidity
3. Swap
4. Remove partial liquidity
5. Reverse swap
6. Remove remaining liquidity

#### native / Alpha

| Action | txHash |
| --- | --- |
| Add liquidity `+1e18` | `0x78ed7261cb86d678f083488fcb9f6029b6153c52dd463723a375e9ff9b781f5d` |
| Add more liquidity `+1e18` | `0x59a04054e9ddb0c689ff9869b8eb52c100290baca164f22800cf65831f7e53da` |
| `native -> Alpha` swap | `0x0f72ea9db81661e87763ed625cab428d6a2442e7d7e01cdaff9747127794f541` |
| Remove partial liquidity `-1e18` | `0xf185820142a8eef8455400d0dd9eaf2826925338b765c7e49b43631a0f8fc0ed` |
| `Alpha -> native` swap | `0xee19c7dbd320b97d6b29ece57e98f82dc394ba9e36f12d2f2852cf49108a453a` |
| Remove remaining liquidity `-1e18` | `0xf32cacd3d613dfc5540ac638cd03e2f287cf8a468fad8b189e09171040c7683e` |

#### Beta / Alpha

| Action | txHash |
| --- | --- |
| Add liquidity `+1e18` | `0xba4fc579008bd3b0e07bbb260c22390bf7458cd1b83c89dbedb1ea3c10204a03` |
| Add more liquidity `+1e18` | `0x9466b5cd17bcb6ca26c15ec22ba9e5493d7455fe9c2edb73a05f8677bcaebd7a` |
| `Beta -> Alpha` swap | `0x935a35d1bae956af24c91e64b6b639fd780f0fc2bc665b6fdb0769461655f5e2` |
| Remove partial liquidity `-1e18` | `0xceaece955fbb1f5326438e2cb033f02a047cda277cc70afe81351c58356b5069` |
| `Alpha -> Beta` swap | `0xe87c12c1f08dd07be403ae5da095d07bdb4ccde4a29c36402ee05c527b82231e` |
| Remove remaining liquidity `-1e18` | `0xb62485bf5119286b6b167db132cb7ecbd0b40c38634afdcb49754028a44f04e7` |

### 5% exactInput Hook Flow

Hook behavior:

- `beforeSwap()` only allows `params.amountSpecified < 0`, i.e. exactInput.
- `beforeSwap()` calls `MovaTransientCompat.enter()` and writes the current swap input amount and direction.
- `afterSwap()` reads the temporary state from the compatibility library and charges 5% of the actual output asset.
- `afterSwap()` calls `PoolManager.take()` to transfer the fee to the hook.
- `afterSwap()` calls `MovaTransientCompat.exit()`, making the temporary state invisible after the swap.

| Action | txHash |
| --- | --- |
| Add liquidity `+1e18` to `native / Hook B` | `0x53f077decf3c90e40012ddd80785dcde760f8f1f23a0a1ab5a5fbadc6dc8367a` |
| `native -> Hook B` exactInput swap, input `1e12` native | `0xaf6e0df60a8cd1e782370f4b0d09635b5429db3d14555199c88eb31abe079ecd` |
| `Hook B -> native` exactInput swap, input `1e12` Hook B | `0x1dc8fc08941ed3180c4ce905b02d735d63e1fc182e615f46de8a6f1ce2a98441` |

#### Fee Verification

| Direction | Input | User actually received | Hook fee | Gross output | Result |
| --- | --- | --- | --- | --- | --- |
| `native -> Hook B` | `1,000,000,000,000` native | `947,149,055,692` Hook B | `49,849,950,299` Hook B | `996,999,005,991` Hook B | `5%`, rounded down |
| `Hook B -> native` | `1,000,000,000,000` Hook B | `947,150,944,308` native | `49,850,049,700` native | `997,000,994,008` native | `5%`, rounded down |

On-chain balance checks:

- Hook B token balance of the hook: `49,849,950,299`
- Native balance of the hook: `49,850,049,700`

Hook temporary-state checks:

- `lastFeeAmount()`: `49,850,049,700`
- `lastInputAmount()`: `1,000,000,000,000`
- `lastBeforeSwapEpoch()`: `2`
- `lastAfterSwapEpoch()`: `2`
- `transientActive()`: `false`
- `transientInputAmount()`: `0`

Conclusion: after both exactInput swaps, the hook correctly charged a 5% fee on the output asset. The temporary session from `mova-transient-compat-library` was closed after the swap, and the old temporary input amount was no longer visible.

#### exactOutput Negative Verification

An exactOutput-style `eth_call` was executed against the `native / Hook B` pool:

```bash
cast call 0x7Be3613Dced5Afb5059Bc99a401aF4CdD4d109f2 \
  'swap((address,address,uint24,int24,address),(bool,int256,uint160),bytes)' \
  '(0x0000000000000000000000000000000000000000,0x64e9f73599945C332BacCFe07798FE4Bd3A9257f,3000,60,0x0114156011Ae6Ec104EEFF8f8B7c3AcB253100c4)' \
  '(true,100000000000,4295128740)' \
  0x \
  --from 0xA38620A48424a61964184A8422F7a7f3dF5FC766 \
  --value 1000000000000 \
  --rpc-url https://mars.rpc.movachain.com
```

Result: the call reverted with `WrappedError`, which included the hook's `ExactOutputNotSupported()` selector `0x21b865b3`. This confirms that the hook only supports exactInput.

## Local Test Results

### Hook Tests

```bash
forge test --match-path test/MovaExactInputFeeHook.t.sol
```

Result:

- `test_nativeToToken_exactInput_chargesFivePercentOutputFee`: pass
- `test_tokenToNative_exactInput_chargesFivePercentOutputFee`: pass
- `test_exactOutput_reverts`: pass
- Summary: `3 passed; 0 failed`

### Compatibility Regression Tests

```bash
forge test --match-path 'test/PoolManager.t.sol' --match-test 'test_(sync|settle|unlock|swap|addLiquidity|removeLiquidity|take|collectProtocolFees)'
forge test --match-path 'test/Sync.t.sol'
forge test --match-path 'test/libraries/Lock.t.sol'
forge test --match-path 'test/libraries/NonzeroDeltaCount.t.sol'
forge test --match-path 'test/CurrencyReserves.t.sol'
forge build script/MovaTestnetExactInputFeeHook.s.sol
```

Result:

- `PoolManager.t.sol` relevant slice: `63 passed; 0 failed`
- `Sync.t.sol`: `12 passed; 0 failed`
- `Lock.t.sol`: `2 passed; 0 failed`
- `NonzeroDeltaCount.t.sol`: `3 passed; 0 failed`
- `CurrencyReserves.t.sol`: `4 passed; 0 failed`
- Hook test script compilation: passed

## On-Chain State Checks

### State After Basic Pool Tests

- Test account nonce: `52`
- Test account native balance: `99.960815613999999991`
- Alpha balance: `999999999999999999999986`
- Beta balance: `999999999999999999999993`

### State After Hook Tests

- Hook B token balance of `MovaExactInputFeeHook`: `49,849,950,299`
- Native balance of `MovaExactInputFeeHook`: `49,850,049,700`
- `transientActive()`: `false`
- `transientInputAmount()`: `0`

## Node Compatibility Notes

Two tooling compatibility issues were observed with the Mars RPC:

- `eth_feeHistory` is not supported, so transactions need to be broadcast with legacy gas.
- Some receipts are missing the `type` field, so Foundry / cast may report a deserialization error even after the transaction has landed successfully.

Final on-chain results are based on `status = 0x1` from `eth_getTransactionReceipt` and direct on-chain state reads.

## Conclusion

- The non-transient-storage-compatible `PoolManager` can initialize native-token and token-token pools, add liquidity, swap in both directions, remove liquidity, and execute sequential operation flows.
- All core operations are executed through the `unlock()` lifecycle, and currency deltas are settled within the same lifecycle.
- `MovaExactInputFeeHook` can charge a 5% fee on the output asset for exactInput swaps in a native-token pool.
- The hook uses `mova-transient-compat-library` as a transient-storage replacement. After a swap, the temporary session is closed and old temporary state is invisible.
- exactOutput swaps were negatively verified and are rejected by the hook.
