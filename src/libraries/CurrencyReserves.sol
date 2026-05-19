// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Currency} from "../types/Currency.sol";
// begin edit
// Historical import:
// import {CustomRevert} from "./CustomRevert.sol";
import {EpochState} from "./EpochState.sol";
// end edit

library CurrencyReserves {
    // begin edit
    // Historical usage:
    // using CustomRevert for bytes4;
    // end edit

    /// bytes32(uint256(keccak256("ReservesOf")) - 1)
    // begin edit
    // Historical visibility:
    // bytes32 constant RESERVES_OF_SLOT = 0x1e0745a7db1623981f0b2a5d4232364c00787266eb75ad546f190e6cebe9bd95;
    bytes32 internal constant RESERVES_OF_SLOT = 0x1e0745a7db1623981f0b2a5d4232364c00787266eb75ad546f190e6cebe9bd95;
    // end edit
    /// bytes32(uint256(keccak256("Currency")) - 1)
    // begin edit
    // Historical visibility:
    // bytes32 constant CURRENCY_SLOT = 0x27e098c505d44ec3574004bca052aabf76bd35004c182099d8c575fb238593b9;
    bytes32 internal constant CURRENCY_SLOT = 0x27e098c505d44ec3574004bca052aabf76bd35004c182099d8c575fb238593b9;
    // end edit

    function getSyncedCurrency() internal view returns (Currency currency) {
        // begin edit
        // Historical implementation:
        // assembly ("memory-safe") {
        //     currency := tload(CURRENCY_SLOT)
        // }
        currency = Currency.wrap(EpochState.loadAddress(CURRENCY_SLOT));
        // end edit
    }

    function resetCurrency() internal {
        // begin edit
        // Historical implementation:
        // assembly ("memory-safe") {
        //     tstore(CURRENCY_SLOT, 0)
        // }
        EpochState.clear(CURRENCY_SLOT);
        // end edit
    }

    function syncCurrencyAndReserves(Currency currency, uint256 value) internal {
        // begin edit
        // Historical implementation:
        // assembly ("memory-safe") {
        //     tstore(CURRENCY_SLOT, and(currency, 0xffffffffffffffffffffffffffffffffffffffff))
        //     tstore(RESERVES_OF_SLOT, value)
        // }
        EpochState.storeAddress(CURRENCY_SLOT, Currency.unwrap(currency));
        EpochState.storeUint256(RESERVES_OF_SLOT, value);
        // end edit
    }

    function getSyncedReserves() internal view returns (uint256 value) {
        // begin edit
        // Historical implementation:
        // assembly ("memory-safe") {
        //     value := tload(RESERVES_OF_SLOT)
        // }
        value = EpochState.loadUint256(RESERVES_OF_SLOT);
        // end edit
    }
}
