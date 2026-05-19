# Mars On-Chain Test Report

Test date: 2026-05-19

## Network

| Field | Value |
| --- | --- |
| Network | Mova testnet |
| RPC | `https://mars.rpc.movachain.com` |
| Chain ID | `10323` |
| EVM profile | `mova` |
| Transaction type | legacy |
| Test account | `0xA38620A48424a61964184A8422F7a7f3dF5FC766` |

## Local Tests

Local verification was completed before on-chain testing:

| Command | Result |
| --- | --- |
| `forge test --match-path 'test/PoolManager.t.sol' --match-test 'test_(sync\|settle\|unlock\|swap\|addLiquidity\|removeLiquidity\|take\|collectProtocolFees)'` | 63 passed |
| `forge test --match-path 'test/Sync.t.sol'` | 12 passed |
| `forge test --match-path 'test/libraries/Lock.t.sol'` | 2 passed |
| `forge test --match-path 'test/libraries/NonzeroDeltaCount.t.sol'` | 3 passed |
| `forge test --match-path 'test/CurrencyReserves.t.sol'` | 4 passed |
| `forge test --match-path 'test/MovaExactInputFeeHook.t.sol'` | 3 passed |
| `forge build` | passed |
| `git diff --check` | passed |

## Deployed Addresses

### No-Hook Test

| Contract | Address |
| --- | --- |
| PoolManager | `0xdeb857505756b4c7c602d4957d440b2eb9142b3d` |
| MovaTestRouter | `0x66a327ab10f7348bc89e71ab42b3e243c75e7689` |
| Alpha token | `0xecd035a10687e6c1508e9a8c701e672d3aca7328` |
| Beta token | `0xa33dfdf0a8cd4a16bf8b2799e949ac1078b71bcb` |
| token0 | `0xa33dfdf0a8cd4a16bf8b2799e949ac1078b71bcb` |
| token1 | `0xecd035a10687e6c1508e9a8c701e672d3aca7328` |

### Hook Test

| Contract | Address |
| --- | --- |
| MovaHookDeployer | `0x825ce9cf118c4923292b58411e2f55d425081da8` |
| MovaExactInputFeeHook | `0xa86D96259934430647B427623323A5974D3a00C4` |
| Hook token | `0x711db61620d9072f12249ed3515123770f938154` |
| Hook salt | `0xce0f9507e0759943f17a9d52a664fbf024d1c313129bfed01d3ef5d36becb4af` |

The hook address low 14 bits are `0x00c4`, matching the `beforeSwap + afterSwap + afterSwapReturnDelta` permission flags.

## On-Chain Transactions

All business transactions waited for confirmation before the next transaction was sent. Every receipt returned `status=0x1`.

### Deployment and No-Hook Flow

| Step | Tx |
| --- | --- |
| Deploy PoolManager | `0xe7765358a706a6c693baeb4c237b741fdb4141bb01484f17d6e40af6fb003b0a` |
| Deploy Router | `0x77081b509d92ab5d4f469615aedb2f49eb518961e41b431a7c73f18136da656e` |
| Deploy Alpha token | `0x5a42102de66c3f2f0b26e199002dc5782103ce25ee8605a90bd96429ec146aea` |
| Deploy Beta token | `0xdda73d8f703b7bab12fea00011fa67ae03fe2f23547928d2c9586763638a7adf` |
| Alpha approve Router | `0x539adc29806531f787ba092bb32c8bdf6be6fff61bb68925562d4ad6bd82e6ee` |
| Beta approve Router | `0x7395b6d759ceb93cbdd9ef17d3d5a3cee1fb08648c790e80f8715f4168c84fc9` |
| initialize native-Alpha | `0xfd28284987398d2fdfbc8ac69338d1a13e932bda1f5da07a4772725af04e0704` |
| initialize Beta-Alpha | `0xdff4534e6b27287b53ec4859b9ea8216e2400531ab2d0c1712de4c4f88eaf5a6` |
| add liquidity native-Alpha | `0x7b3d6c5315b530024fc7794c96fa18fc8fb047e41b072811ce56eb99212914dc` |
| add liquidity Beta-Alpha | `0xc2cfa74463a1b18d88b8ae7e07fc2df196d9326fc292b6607457385075743f35` |
| swap native -> Alpha | `0x4f303e1c302724a5cff41d7e1aa8cb29fe6629eae66a1d7f90a983f6d3248e43` |
| swap Alpha -> native | `0x14ab4b43f19fa748db2b977ef88200e6b3cad7f20f29cb3f9709c757005925a9` |
| swap Beta -> Alpha | `0xb20e8a41df860f9ce5fdc81c28b18a76c2d4124b2437427618fb9ac1d1e19a67` |
| swap Alpha -> Beta | `0x87216f635e1a5329ea1dea075467fe8147ebe3ecece82698c5c985f7a4e7c196` |
| remove liquidity native-Alpha | `0xf1692c478bc3573f90ede0e8ba1f54e6c101094735c503271b94a4172099ca3c` |
| remove liquidity Beta-Alpha | `0xe60cf93db219c652b311215e543138199b4a4202ee95d3b449e257f43feea362` |

### Hook Flow

| Step | Tx |
| --- | --- |
| Deploy MovaHookDeployer | `0x31fc09190730bc77d07d96fc90c8592769346e32891c7e5f7865843ed931bbd7` |
| CREATE2 deploy MovaExactInputFeeHook | `0x0762378563d4e6bb9b668d6e8d75e7799e3e32a433698f3ad7d43a26d5bf0ae1` |
| Deploy Hook token | `0xa11ed0f1a94cde941e4f00374fadb73542bdabe08500abf88854e82ee6597f0b` |
| Hook token approve Router | `0x0f093160de6fa8570ee2a1efe344783f4e3b2e8505f4fbf636f74bc957e4f8c7` |
| initialize hook native-token | `0x8a28ad6094ba1462339b08c0e332c4120b72b196fdb82ebedc7ec3123ec19448` |
| add liquidity hook native-token | `0xba083754247111e89e2cc2851dbc2ede8c00409398a0656e5559ac728fdbaf5b` |
| hook swap native -> token | `0x10810ddb378da70ad7312f855f5b63c50aaa62f5741dc2b3efb137daac354db4` |
| hook swap token -> native | `0x7f1b1ba642b9ade0bb250b59245071e72d9feb61ff3b56f4ce3c1fe48f4f5e00` |

## On-Chain Read-Only Checks

### PoolManager

| Check | Result |
| --- | --- |
| `owner()` | `0xA38620A48424a61964184A8422F7a7f3dF5FC766` |
| `exttload(EPOCH_SLOT)` | `0x0000000000000000000000000000000000000000000000000000000000000008` |
| `exttload(IS_UNLOCKED_SLOT)` | `0x0000000000000000000000000000000000000000000000000000000000000000` |
| Test account final native balance | `99.873734404390434634` |

`EPOCH_SLOT = 8` corresponds to the 8 router unlock flows in the no-hook test. `IS_UNLOCKED_SLOT = 0` means the manager is locked at the end.

### Token Balances

| Token | Test account balance |
| --- | --- |
| Alpha | `999999999999999999999994` |
| Beta | `999999999999999999999998` |

### Hook State

| Check | Result |
| --- | --- |
| `lastFeeAmount()` | `49850049700` |
| `lastInputAmount()` | `1000000000000` |
| `lastBeforeSwapEpoch()` | `2` |
| `lastAfterSwapEpoch()` | `2` |
| `transientActive()` | `false` |
| `transientInputAmount()` | `0` |
| hook token fee balance | `49849950299` |
| hook native fee balance | `0.000000049850049700` |

The hook `beforeSwap` and `afterSwap` ran in the same hook transient epoch. After the swap, `transientActive=false` and `transientInputAmount=0`, confirming the hook's simulated transient state exited cleanly.

## Tool Compatibility Notes

Two Mars RPC / Foundry compatibility points were encountered during this session:

- `forge create` performs only a dry run unless `--broadcast` is provided.
- Deploying PoolManager with the default profile or with `forge create` hit gas estimation and deployment failures. The successful path was to generate initcode with `FOUNDRY_PROFILE=mova forge inspect ... bytecode` and deploy it with `cast send --create`.
- When Mars receipts are missing the `type` field, `cast` may print a deserialization error, but the raw receipt JSON still includes `status`, `transactionHash`, and `contractAddress`.

## Conclusion

This session verified:

- The PoolManager compatibility implementation without native `TLOAD/TSTORE` can be deployed and run on Mars testnet.
- No-hook native-token and token-token pools can initialize, add liquidity, swap in both directions, and remove liquidity.
- `exttload` can read simulated transient state, and the final unlock state is cleared correctly.
- The exact-input fee hook can be deployed with CREATE2 to an address matching the permission flags.
- The hook's simulated transient session based on `mova-transient-compat-library` can write and read during swap execution, then exit after the swap.
