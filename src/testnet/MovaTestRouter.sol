// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {IUnlockCallback} from "../interfaces/callback/IUnlockCallback.sol";
import {IERC20Minimal} from "../interfaces/external/IERC20Minimal.sol";
import {IPoolManager} from "../interfaces/IPoolManager.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "../types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "../types/Currency.sol";
import {ModifyLiquidityParams, SwapParams} from "../types/PoolOperation.sol";
import {PoolKey} from "../types/PoolKey.sol";

/// @notice Minimal router for testnet PoolManager unlock flows.
contract MovaTestRouter is IUnlockCallback {
    using BalanceDeltaLibrary for BalanceDelta;
    using CurrencyLibrary for Currency;

    enum Action {
        ModifyLiquidity,
        Swap
    }

    struct CallbackData {
        address payer;
        PoolKey key;
        ModifyLiquidityParams modifyParams;
        SwapParams swapParams;
        bytes hookData;
    }

    error OnlyPoolManager();
    error InsufficientNativeValue();
    error UnknownAction();

    IPoolManager public immutable manager;

    constructor(IPoolManager _manager) {
        manager = _manager;
    }

    receive() external payable {}

    function modifyLiquidity(PoolKey calldata key, ModifyLiquidityParams calldata params, bytes calldata hookData)
        external
        payable
        returns (BalanceDelta delta)
    {
        CallbackData memory data = CallbackData({
            payer: msg.sender,
            key: key,
            modifyParams: params,
            swapParams: SwapParams({zeroForOne: false, amountSpecified: 0, sqrtPriceLimitX96: 0}),
            hookData: hookData
        });

        delta = abi.decode(manager.unlock(abi.encode(Action.ModifyLiquidity, data)), (BalanceDelta));
        _refundNative(msg.sender);
    }

    function swap(PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        external
        payable
        returns (BalanceDelta delta)
    {
        CallbackData memory data = CallbackData({
            payer: msg.sender,
            key: key,
            modifyParams: ModifyLiquidityParams({tickLower: 0, tickUpper: 0, liquidityDelta: 0, salt: bytes32(0)}),
            swapParams: params,
            hookData: hookData
        });

        delta = abi.decode(manager.unlock(abi.encode(Action.Swap, data)), (BalanceDelta));
        _refundNative(msg.sender);
    }

    function unlockCallback(bytes calldata rawData) external returns (bytes memory) {
        if (msg.sender != address(manager)) revert OnlyPoolManager();

        (Action action, CallbackData memory data) = abi.decode(rawData, (Action, CallbackData));

        if (action == Action.ModifyLiquidity) {
            (BalanceDelta delta,) = manager.modifyLiquidity(data.key, data.modifyParams, data.hookData);
            _settleOrTake(data.key, data.payer, delta);
            return abi.encode(delta);
        }

        if (action == Action.Swap) {
            BalanceDelta delta = manager.swap(data.key, data.swapParams, data.hookData);
            _settleOrTake(data.key, data.payer, delta);
            return abi.encode(delta);
        }

        revert UnknownAction();
    }

    function _settleOrTake(PoolKey memory key, address payer, BalanceDelta delta) internal {
        _settleOrTakeCurrency(key.currency0, payer, delta.amount0());
        _settleOrTakeCurrency(key.currency1, payer, delta.amount1());
    }

    function _settleOrTakeCurrency(Currency currency, address payer, int128 amount) internal {
        if (amount < 0) {
            _settle(currency, payer, uint128(-amount));
        } else if (amount > 0) {
            manager.take(currency, payer, uint128(amount));
        }
    }

    function _settle(Currency currency, address payer, uint256 amount) internal {
        if (currency.isAddressZero()) {
            if (address(this).balance < amount) revert InsufficientNativeValue();
            manager.settle{value: amount}();
        } else {
            manager.sync(currency);
            IERC20Minimal(Currency.unwrap(currency)).transferFrom(payer, address(manager), amount);
            manager.settle();
        }
    }

    function _refundNative(address recipient) internal {
        uint256 balance = address(this).balance;
        if (balance != 0) CurrencyLibrary.ADDRESS_ZERO.transfer(recipient, balance);
    }
}
