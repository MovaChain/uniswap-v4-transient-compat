// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IHooks} from "../src/interfaces/IHooks.sol";
import {IPoolManager} from "../src/interfaces/IPoolManager.sol";
import {PoolManager} from "../src/PoolManager.sol";
import {TickMath} from "../src/libraries/TickMath.sol";
import {MovaTestRouter} from "../src/testnet/MovaTestRouter.sol";
import {TestERC20} from "../src/test/TestERC20.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "../src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "../src/types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from "../src/types/PoolOperation.sol";
import {PoolKey} from "../src/types/PoolKey.sol";

contract MovaTestnetDeployAndSwap is Script {
    using BalanceDeltaLibrary for BalanceDelta;

    uint160 internal constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    uint256 internal constant TOKEN_SUPPLY = 1_000_000 ether;
    uint24 internal constant FEE = 3000;
    int24 internal constant TICK_SPACING = 60;
    int24 internal constant TICK_LOWER = -120;
    int24 internal constant TICK_UPPER = 120;
    int256 internal constant LIQUIDITY = 1e18;
    uint256 internal constant NATIVE_LIQUIDITY_VALUE = 0.02 ether;
    int256 internal constant SWAP_AMOUNT = -1e12;

    function run() external {
        require(block.chainid == 10323, "wrong chain");

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(privateKey);

        vm.startBroadcast(privateKey);

        PoolManager manager = new PoolManager(deployer);
        MovaTestRouter router = new MovaTestRouter(IPoolManager(address(manager)));

        TestERC20 tokenA = new TestERC20(TOKEN_SUPPLY);
        TestERC20 tokenB = new TestERC20(TOKEN_SUPPLY);

        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);

        (Currency token0, Currency token1) = _sortTokens(address(tokenA), address(tokenB));

        PoolKey memory nativeTokenKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: token0,
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0))
        });

        PoolKey memory tokenTokenKey =
            PoolKey({currency0: token0, currency1: token1, fee: FEE, tickSpacing: TICK_SPACING, hooks: IHooks(address(0))});

        manager.initialize(nativeTokenKey, SQRT_PRICE_1_1);
        manager.initialize(tokenTokenKey, SQRT_PRICE_1_1);

        ModifyLiquidityParams memory addLiquidity =
            ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: LIQUIDITY, salt: 0});
        ModifyLiquidityParams memory removeLiquidity =
            ModifyLiquidityParams({tickLower: TICK_LOWER, tickUpper: TICK_UPPER, liquidityDelta: -LIQUIDITY, salt: 0});

        _logDelta(
            "native-token add liquidity",
            router.modifyLiquidity{value: NATIVE_LIQUIDITY_VALUE}(nativeTokenKey, addLiquidity, "")
        );
        _logDelta("token-token add liquidity", router.modifyLiquidity(tokenTokenKey, addLiquidity, ""));

        _logDelta(
            "native-token swap native -> token",
            router.swap{value: uint256(-SWAP_AMOUNT)}(
                nativeTokenKey,
                SwapParams({zeroForOne: true, amountSpecified: SWAP_AMOUNT, sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1}),
                ""
            )
        );
        _logDelta(
            "native-token swap token -> native",
            router.swap(
                nativeTokenKey,
                SwapParams({zeroForOne: false, amountSpecified: SWAP_AMOUNT, sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1}),
                ""
            )
        );

        _logDelta(
            "token-token swap token0 -> token1",
            router.swap(
                tokenTokenKey,
                SwapParams({zeroForOne: true, amountSpecified: SWAP_AMOUNT, sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1}),
                ""
            )
        );
        _logDelta(
            "token-token swap token1 -> token0",
            router.swap(
                tokenTokenKey,
                SwapParams({zeroForOne: false, amountSpecified: SWAP_AMOUNT, sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1}),
                ""
            )
        );

        _logDelta("native-token remove liquidity", router.modifyLiquidity(nativeTokenKey, removeLiquidity, ""));
        _logDelta("token-token remove liquidity", router.modifyLiquidity(tokenTokenKey, removeLiquidity, ""));

        vm.stopBroadcast();

        console2.log("deployer", deployer);
        console2.log("poolManager", address(manager));
        console2.log("router", address(router));
        console2.log("tokenA", address(tokenA));
        console2.log("tokenB", address(tokenB));
        console2.log("nativePoolToken", Currency.unwrap(token0));
        console2.log("tokenTokenCurrency0", Currency.unwrap(token0));
        console2.log("tokenTokenCurrency1", Currency.unwrap(token1));
    }

    function _sortTokens(address tokenA, address tokenB) internal pure returns (Currency token0, Currency token1) {
        return tokenA < tokenB
            ? (Currency.wrap(tokenA), Currency.wrap(tokenB))
            : (Currency.wrap(tokenB), Currency.wrap(tokenA));
    }

    function _logDelta(string memory label, BalanceDelta delta) internal view {
        console2.log(label);
        console2.logInt(delta.amount0());
        console2.logInt(delta.amount1());
    }
}
