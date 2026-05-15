// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Currency} from "../types/Currency.sol";

/// @notice Shared helpers for epoch-scoped storage used to emulate transient state.
library EpochState {
    bytes32 internal constant STORAGE_NAMESPACE = keccak256("uniswap.v4.transient.compat.storage");

    // bytes32(uint256(keccak256("Epoch")) - 1)
    bytes32 internal constant EPOCH_SLOT = 0x668146ca85848777f0ddc67c485ba93c0c4482231149dce151713c1a85ef76fa;
    // The logical slot holding the unlocked state. bytes32(uint256(keccak256("Unlocked")) - 1)
    bytes32 internal constant UNLOCKED_SLOT = 0xc090fc4683624cfc3884e9d8de5eca132f2d0ec062aff75d43c0465d5ceeab23;
    bytes32 internal constant RESERVES_SLOT = 0x1e0745a7db1623981f0b2a5d4232364c00787266eb75ad546f190e6cebe9bd95;
    bytes32 internal constant CURRENCY_SLOT = 0x27e098c505d44ec3574004bca052aabf76bd35004c182099d8c575fb238593b9;
    bytes32 internal constant NONZERO_DELTA_COUNT_SLOT =
        0x7d4b3164c6e45b97e7d87b7125a44c5828d005af88f9d751cfd78729c5d99a0b;

    function currentEpoch() internal view returns (uint256 epoch) {
        assembly ("memory-safe") {
            epoch := sload(EPOCH_SLOT)
        }
    }

    function bumpEpoch() internal returns (uint256 epoch) {
        assembly ("memory-safe") {
            epoch := add(sload(EPOCH_SLOT), 1)
            sstore(EPOCH_SLOT, epoch)
        }
    }

    function scopedSlot(bytes32 slot) internal view returns (bytes32 scopedKey) {
        scopedKey = keccak256(abi.encode(STORAGE_NAMESPACE, address(this), currentEpoch(), slot));
    }

    function exttload(bytes32 slot) internal view returns (bytes32 value) {
        if (!isUnlocked()) return bytes32(0);
        bytes32 scopedKey = scopedSlot(slot);
        assembly ("memory-safe") {
            value := sload(scopedKey)
        }
    }

    function setUnlocked(bool unlocked) internal {
        bytes32 slot = scopedSlot(UNLOCKED_SLOT);
        assembly ("memory-safe") {
            sstore(slot, unlocked)
        }
    }

    function isUnlocked() internal view returns (bool unlocked) {
        bytes32 slot = scopedSlot(UNLOCKED_SLOT);
        assembly ("memory-safe") {
            unlocked := sload(slot)
        }
    }

    function getSyncedCurrency() internal view returns (Currency currency) {
        if (!isUnlocked()) return Currency.wrap(address(0));
        bytes32 slot = scopedSlot(CURRENCY_SLOT);
        assembly ("memory-safe") {
            currency := sload(slot)
        }
    }

    function getSyncedReserves() internal view returns (uint256 value) {
        if (!isUnlocked()) return 0;
        bytes32 slot = scopedSlot(RESERVES_SLOT);
        assembly ("memory-safe") {
            value := sload(slot)
        }
    }

    function resetCurrency() internal {
        bytes32 slot = scopedSlot(CURRENCY_SLOT);
        assembly ("memory-safe") {
            sstore(slot, 0)
        }
    }

    function syncCurrencyAndReserves(Currency currency, uint256 value) internal {
        bytes32 currencySlot = scopedSlot(CURRENCY_SLOT);
        bytes32 reservesSlot = scopedSlot(RESERVES_SLOT);
        assembly ("memory-safe") {
            sstore(currencySlot, and(currency, 0xffffffffffffffffffffffffffffffffffffffff))
            sstore(reservesSlot, value)
        }
    }

    function readNonzeroDeltaCount() internal view returns (uint256 count) {
        if (!isUnlocked()) return 0;
        bytes32 slot = scopedSlot(NONZERO_DELTA_COUNT_SLOT);
        assembly ("memory-safe") {
            count := sload(slot)
        }
    }

    function incrementNonzeroDeltaCount() internal {
        bytes32 slot = scopedSlot(NONZERO_DELTA_COUNT_SLOT);
        assembly ("memory-safe") {
            sstore(slot, add(sload(slot), 1))
        }
    }

    function decrementNonzeroDeltaCount() internal {
        bytes32 slot = scopedSlot(NONZERO_DELTA_COUNT_SLOT);
        assembly ("memory-safe") {
            sstore(slot, sub(sload(slot), 1))
        }
    }

    function deltaSlot(address target, Currency currency) internal pure returns (bytes32 slot) {
        slot = keccak256(abi.encode(target, currency));
    }

    function getDelta(address target, Currency currency) internal view returns (int256 delta) {
        if (!isUnlocked()) return 0;
        bytes32 slot = scopedSlot(deltaSlot(target, currency));
        assembly ("memory-safe") {
            delta := sload(slot)
        }
    }

    function applyDelta(address target, Currency currency, int128 amount)
        internal
        returns (int256 previous, int256 next)
    {
        bytes32 slot = scopedSlot(deltaSlot(target, currency));
        assembly ("memory-safe") {
            previous := sload(slot)
        }
        next = previous + amount;
        assembly ("memory-safe") {
            sstore(slot, next)
        }
    }
}
