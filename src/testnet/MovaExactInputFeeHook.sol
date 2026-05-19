// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// begin edit
import {MovaTransientCompat} from "mova-transient-compat-library/src/MovaTransientCompat.sol";

import {IHooks} from "../interfaces/IHooks.sol";
import {IPoolManager} from "../interfaces/IPoolManager.sol";
import {Hooks} from "../libraries/Hooks.sol";
import {SafeCast} from "../libraries/SafeCast.sol";
import {BaseTestHooks} from "../test/BaseTestHooks.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "../types/BeforeSwapDelta.sol";
import {BalanceDelta} from "../types/BalanceDelta.sol";
import {Currency} from "../types/Currency.sol";
import {PoolKey} from "../types/PoolKey.sol";
import {SwapParams} from "../types/PoolOperation.sol";

/// @notice Testnet hook that charges a 5% fee from exact-input swap output.
contract MovaExactInputFeeHook is BaseTestHooks {
    using Hooks for IHooks;
    using SafeCast for uint256;

    error OnlyPoolManager();
    error ExactOutputNotSupported();

    uint256 public constant FEE_BIPS = 500;
    uint256 public constant TOTAL_BIPS = 10_000;

    bytes32 internal constant INPUT_AMOUNT_SLOT = bytes32(uint256(keccak256("mova.fee-hook.input-amount")) - 1);
    bytes32 internal constant ZERO_FOR_ONE_SLOT = bytes32(uint256(keccak256("mova.fee-hook.zero-for-one")) - 1);

    IPoolManager public immutable manager;

    uint256 public lastBeforeSwapEpoch;
    uint256 public lastAfterSwapEpoch;
    uint256 public lastInputAmount;
    uint256 public lastFeeAmount;
    Currency public lastFeeCurrency;
    bool public lastZeroForOne;

    constructor(IPoolManager _manager) {
        manager = _manager;
    }

    receive() external payable {}

    modifier onlyPoolManager() {
        if (msg.sender != address(manager)) revert OnlyPoolManager();
        _;
    }

    function beforeSwap(address, PoolKey calldata, SwapParams calldata params, bytes calldata)
        external
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (params.amountSpecified >= 0) revert ExactOutputNotSupported();

        uint256 epoch = MovaTransientCompat.enter();
        uint256 inputAmount = uint256(-params.amountSpecified);

        MovaTransientCompat.tstoreUint256(INPUT_AMOUNT_SLOT, inputAmount);
        MovaTransientCompat.tstoreUint256(ZERO_FOR_ONE_SLOT, params.zeroForOne ? 1 : 0);

        lastBeforeSwapEpoch = epoch;
        lastInputAmount = inputAmount;
        lastZeroForOne = params.zeroForOne;

        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(address, PoolKey calldata key, SwapParams calldata params, BalanceDelta delta, bytes calldata)
        external
        override
        onlyPoolManager
        returns (bytes4, int128)
    {
        uint256 inputAmount = MovaTransientCompat.tloadUint256(INPUT_AMOUNT_SLOT);
        bool zeroForOne = MovaTransientCompat.tloadUint256(ZERO_FOR_ONE_SLOT) == 1;

        assert(inputAmount == uint256(-params.amountSpecified));
        assert(zeroForOne == params.zeroForOne);

        int128 outputDelta = params.zeroForOne ? delta.amount1() : delta.amount0();
        if (outputDelta < 0) outputDelta = -outputDelta;

        uint256 feeAmount = uint128(outputDelta) * FEE_BIPS / TOTAL_BIPS;
        Currency feeCurrency = params.zeroForOne ? key.currency1 : key.currency0;

        if (feeAmount != 0) manager.take(feeCurrency, address(this), feeAmount);

        lastAfterSwapEpoch = MovaTransientCompat.currentEpoch();
        lastFeeAmount = feeAmount;
        lastFeeCurrency = feeCurrency;

        MovaTransientCompat.exit();

        return (IHooks.afterSwap.selector, feeAmount.toInt128());
    }

    function transientActive() external view returns (bool) {
        return MovaTransientCompat.isActive();
    }

    function transientInputAmount() external view returns (uint256) {
        return MovaTransientCompat.tloadUint256(INPUT_AMOUNT_SLOT);
    }

    function validateHookAddress() external view {
        IHooks(address(this)).validateHookPermissions(
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: true,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            })
        );
    }
}
// end edit
