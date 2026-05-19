// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// begin edit
import {Script, console2} from "forge-std/Script.sol";

import {IHooks} from "../src/interfaces/IHooks.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {TickMath} from "../src/libraries/TickMath.sol";
import {MovaExactInputFeeHook} from "../src/testnet/MovaExactInputFeeHook.sol";
import {MovaHookDeployer} from "../src/testnet/MovaHookDeployer.sol";
import {MovaNamedTestToken} from "../src/testnet/MovaNamedTestToken.sol";
import {MovaTestRouter} from "../src/testnet/MovaTestRouter.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "../src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "../src/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from "../src/types/PoolOperation.sol";
import {PoolKey} from "../src/types/PoolKey.sol";

contract MovaTestnetExactInputFeeHook is Script {
    using BalanceDeltaLibrary for BalanceDelta;

    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    uint24 internal constant FEE = 3000;
    int24 internal constant TICK_SPACING = 60;
    int24 internal constant TICK_LOWER = -120;
    int24 internal constant TICK_UPPER = 120;
    int256 internal constant LIQUIDITY = 1e18;
    uint256 internal constant TOKEN_SUPPLY = 1_000_000 ether;
    uint256 internal constant NATIVE_LIQUIDITY_VALUE = 0.02 ether;
    uint256 internal constant SWAP_AMOUNT_ABS = 1_000_000_000_000;
    int256 internal constant SWAP_AMOUNT = -1_000_000_000_000;
    uint160 internal constant HOOK_FLAGS = 0x00c4;
    uint160 internal constant HOOK_MASK = (1 << 14) - 1;

    function run() external {
        require(block.chainid == 10323, "wrong chain");

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        IPoolManager manager = IPoolManager(vm.envAddress("POOL_MANAGER"));
        MovaTestRouter router = MovaTestRouter(payable(vm.envAddress("ROUTER")));

        vm.startBroadcast(privateKey);

        MovaHookDeployer hookDeployer = new MovaHookDeployer();
        bytes32 salt = _findHookSalt(address(hookDeployer), manager);
        MovaExactInputFeeHook hook = hookDeployer.deployExactInputFeeHook(manager, salt);
        hook.validateHookAddress();

        MovaNamedTestToken token =
            new MovaNamedTestToken("MOVA Hook Fee Test Token 20260514", "MOVA-HOOK-0514", 18, TOKEN_SUPPLY);
        token.approve(address(router), type(uint256).max);

        PoolKey memory key = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(address(token)),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(hook))
        });

        manager.initialize(key, SQRT_PRICE_1_1);

        ModifyLiquidityParams memory addLiquidity =
            ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: LIQUIDITY, salt: 0});

        BalanceDelta addDelta = router.modifyLiquidity{value: NATIVE_LIQUIDITY_VALUE}(key, addLiquidity, "");

        uint256 hookTokenBefore = token.balanceOf(address(hook));
        BalanceDelta nativeToToken = router.swap{value: SWAP_AMOUNT_ABS}(
            key,
            SwapParams({zeroForOne: true, amountSpecified: SWAP_AMOUNT, sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1}),
            ""
        );
        uint256 hookTokenFee = token.balanceOf(address(hook)) - hookTokenBefore;

        uint256 hookNativeBefore = address(hook).balance;
        BalanceDelta tokenToNative = router.swap(
            key,
            SwapParams({zeroForOne: false, amountSpecified: SWAP_AMOUNT, sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1}),
            ""
        );
        uint256 hookNativeFee = address(hook).balance - hookNativeBefore;

        vm.stopBroadcast();

        console2.log("poolManager", address(manager));
        console2.log("router", address(router));
        console2.log("hookDeployer", address(hookDeployer));
        console2.log("hookSalt");
        console2.logBytes32(salt);
        console2.log("hook", address(hook));
        console2.log("token", address(token));
        console2.log("addLiquidityDelta0");
        console2.logInt(addDelta.amount0());
        console2.log("addLiquidityDelta1");
        console2.logInt(addDelta.amount1());
        console2.log("nativeToTokenDelta0");
        console2.logInt(nativeToToken.amount0());
        console2.log("nativeToTokenDelta1");
        console2.logInt(nativeToToken.amount1());
        console2.log("hookTokenFee", hookTokenFee);
        console2.log("tokenToNativeDelta0");
        console2.logInt(tokenToNative.amount0());
        console2.log("tokenToNativeDelta1");
        console2.logInt(tokenToNative.amount1());
        console2.log("hookNativeFee", hookNativeFee);
        console2.log("lastFeeAmount", hook.lastFeeAmount());
        console2.log("lastInputAmount", hook.lastInputAmount());
        console2.log("lastBeforeSwapEpoch", hook.lastBeforeSwapEpoch());
        console2.log("lastAfterSwapEpoch", hook.lastAfterSwapEpoch());
        console2.log("transientActive", hook.transientActive());
        console2.log("transientInputAmount", hook.transientInputAmount());
    }

    function _findHookSalt(address hookDeployer, IPoolManager manager) internal pure returns (bytes32 salt) {
        bytes memory initCode = abi.encodePacked(type(MovaExactInputFeeHook).creationCode, abi.encode(manager));
        bytes32 initCodeHash = keccak256(initCode);

        for (uint256 i = 0; i < 1_000_000; i++) {
            salt = bytes32(i);
            bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), hookDeployer, salt, initCodeHash));
            address hook = address(uint160(uint256(hash)));
            if (uint160(hook) & HOOK_MASK == HOOK_FLAGS) return salt;
        }

        revert("salt not found");
    }
}
// end edit
