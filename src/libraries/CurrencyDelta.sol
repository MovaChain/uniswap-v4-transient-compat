// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Currency} from "../types/Currency.sol";
// begin edit
import {EpochState} from "./EpochState.sol";
// end edit

/// @title a library to store callers' currency deltas in transient storage
/// @dev this library implements the equivalent of a mapping, as transient storage can only be accessed in assembly
library CurrencyDelta {
    // begin edit
    /// @notice calculates which storage slot a delta should be stored in for a given account and currency
    function _computeSlot(address target, Currency currency) internal pure returns (bytes32 hashSlot) {
        assembly ("memory-safe") {
            mstore(0, and(target, 0xffffffffffffffffffffffffffffffffffffffff))
            mstore(32, and(currency, 0xffffffffffffffffffffffffffffffffffffffff))
            hashSlot := keccak256(0, 64)
        }
    }
    // end edit

    function getDelta(Currency currency, address target) internal view returns (int256 delta) {
        // begin edit
        // Historical implementation:
        // bytes32 hashSlot = _computeSlot(target, currency);
        // assembly ("memory-safe") {
        //     delta := tload(hashSlot)
        // }
        bytes32 hashSlot = _computeSlot(target, currency);
        delta = EpochState.loadInt256(hashSlot);
        // end edit
    }

    /// @notice applies a new currency delta for a given account and currency
    /// @return previous The prior value
    /// @return next The modified result
    function applyDelta(Currency currency, address target, int128 delta)
        internal
        returns (int256 previous, int256 next)
    {
        // begin edit
        // Historical implementation:
        // bytes32 hashSlot = _computeSlot(target, currency);
        //
        // assembly ("memory-safe") {
        //     previous := tload(hashSlot)
        // }
        // next = previous + delta;
        // assembly ("memory-safe") {
        //     tstore(hashSlot, next)
        // }
        bytes32 hashSlot = _computeSlot(target, currency);
        previous = EpochState.loadInt256(hashSlot);
        next = previous + delta;
        EpochState.storeInt256(hashSlot, next);
        // end edit
    }
}
