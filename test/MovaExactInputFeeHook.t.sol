// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Deployers} from "./utils/Deployers.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {IHooks} from "../src/interfaces/IHooks.sol";
import {Hooks} from "../src/libraries/Hooks.sol";
import {MovaExactInputFeeHook} from "../src/testnet/MovaExactInputFeeHook.sol";
import {PoolSwapTest} from "../src/test/PoolSwapTest.sol";
import {Currency, CurrencyLibrary} from "../src/types/Currency.sol";
import {PoolKey} from "../src/types/PoolKey.sol";
import {SwapParams} from "../src/types/PoolOperation.sol";
import {BalanceDelta} from "../src/types/BalanceDelta.sol";

contract MovaExactInputFeeHookTest is Deployers {
    MovaExactInputFeeHook hook;
    MockERC20 token;

    function setUp() public {
        deployFreshManagerAndRouters();

        token = new MockERC20("Mova Hook Token", "MHT", 18);
        token.mint(address(this), 1_000_000 ether);
        token.approve(address(modifyLiquidityRouter), type(uint256).max);
        token.approve(address(swapRouter), type(uint256).max);

        address hookAddr = address(uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG));
        address impl = address(new MovaExactInputFeeHook(manager));
        vm.etch(hookAddr, impl.code);
        hook = MovaExactInputFeeHook(payable(hookAddr));

        nativeKey = PoolKey({
            currency0: CurrencyLibrary.ADDRESS_ZERO,
            currency1: Currency.wrap(address(token)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hookAddr)
        });

        manager.initialize(nativeKey, SQRT_PRICE_1_1);
        modifyLiquidityRouter.modifyLiquidity{value: 1 ether}(nativeKey, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_nativeToToken_exactInput_chargesFivePercentOutputFee() public {
        uint256 amountIn = 0.01 ether;
        uint256 tokenBefore = token.balanceOf(address(this));
        uint256 hookTokenBefore = token.balanceOf(address(hook));

        BalanceDelta delta = swapNativeInput(nativeKey, true, -int256(amountIn), ZERO_BYTES, amountIn);

        uint256 tokenOutAfterFee = token.balanceOf(address(this)) - tokenBefore;
        uint256 hookFee = token.balanceOf(address(hook)) - hookTokenBefore;
        uint256 grossTokenOut = tokenOutAfterFee + hookFee;

        assertEq(uint256(uint128(delta.amount1())), tokenOutAfterFee, "caller output includes hook fee deduction");
        assertEq(hookFee, grossTokenOut * hook.FEE_BIPS() / hook.TOTAL_BIPS(), "5% token output fee");
        assertEq(Currency.unwrap(hook.lastFeeCurrency()), address(token), "fee currency");
        assertEq(hook.lastFeeAmount(), hookFee, "recorded fee");
        assertEq(hook.lastInputAmount(), amountIn, "transient input was read");
        assertEq(hook.lastBeforeSwapEpoch(), hook.lastAfterSwapEpoch(), "same compat epoch");
        assertFalse(hook.transientActive(), "compat session exited");
        assertEq(hook.transientInputAmount(), 0, "transient state hidden after swap");
    }

    function test_tokenToNative_exactInput_chargesFivePercentOutputFee() public {
        uint256 amountIn = 0.01 ether;
        uint256 nativeBefore = address(this).balance;
        uint256 hookNativeBefore = address(hook).balance;

        BalanceDelta delta = swapNativeInput(nativeKey, false, -int256(amountIn), ZERO_BYTES, 0);

        uint256 nativeOutAfterFee = address(this).balance - nativeBefore;
        uint256 hookFee = address(hook).balance - hookNativeBefore;
        uint256 grossNativeOut = nativeOutAfterFee + hookFee;

        assertEq(uint256(uint128(delta.amount0())), nativeOutAfterFee, "caller output includes hook fee deduction");
        assertEq(hookFee, grossNativeOut * hook.FEE_BIPS() / hook.TOTAL_BIPS(), "5% native output fee");
        assertEq(Currency.unwrap(hook.lastFeeCurrency()), address(0), "fee currency");
        assertEq(hook.lastFeeAmount(), hookFee, "recorded fee");
        assertEq(hook.lastInputAmount(), amountIn, "transient input was read");
        assertEq(hook.lastBeforeSwapEpoch(), hook.lastAfterSwapEpoch(), "same compat epoch");
        assertFalse(hook.transientActive(), "compat session exited");
        assertEq(hook.transientInputAmount(), 0, "transient state hidden after swap");
    }

    function test_exactOutput_reverts() public {
        SwapParams memory params =
            SwapParams({zeroForOne: true, amountSpecified: int256(1e15), sqrtPriceLimitX96: MIN_PRICE_LIMIT});

        vm.expectRevert();
        swapRouter.swap{value: 1 ether}(
            nativeKey,
            params,
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ZERO_BYTES
        );
    }
}
