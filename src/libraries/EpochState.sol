// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

// begin edit
/// @notice Shared helpers for epoch-scoped storage used to simulate transient load/store.
library EpochState {
    error TransientSessionAlreadyActive();
    error TransientSessionNotActive();

    bytes32 internal constant STORAGE_NAMESPACE = keccak256("uniswap.v4.transient.compat.storage");

    // bytes32(uint256(keccak256("Epoch")) - 1)
    bytes32 internal constant EPOCH_SLOT = 0x668146ca85848777f0ddc67c485ba93c0c4482231149dce151713c1a85ef76fa;
    // bytes32(uint256(keccak256("uniswap.v4.transient.compat.active")) - 1)
    bytes32 internal constant ACTIVE_SLOT = 0x5468d5acedcc45633e17a53197e8a2663430492be775034dae2d7590c6d21bd5;

    function currentEpoch() internal view returns (uint256 epoch) {
        // begin edit
        assembly ("memory-safe") {
            epoch := sload(EPOCH_SLOT)
        }
        // end edit
    }

    function isActive() internal view returns (bool active) {
        // begin edit
        bytes32 slot = scopedSlot(ACTIVE_SLOT);
        assembly ("memory-safe") {
            active := sload(slot)
        }
        // end edit
    }

    function enter() internal returns (uint256 epoch) {
        // begin edit
        if (isActive()) revert TransientSessionAlreadyActive();

        assembly ("memory-safe") {
            epoch := add(sload(EPOCH_SLOT), 1)
            sstore(EPOCH_SLOT, epoch)
        }

        bytes32 slot = scopedSlot(ACTIVE_SLOT);
        assembly ("memory-safe") {
            sstore(slot, 1)
        }
        // end edit
    }

    function exit() internal {
        // begin edit
        if (!isActive()) revert TransientSessionNotActive();

        bytes32 slot = scopedSlot(ACTIVE_SLOT);
        assembly ("memory-safe") {
            sstore(slot, 0)
        }
        // end edit
    }

    function scopedSlot(bytes32 logicalSlot) internal view returns (bytes32 scopedKey) {
        // begin edit
        scopedKey = keccak256(abi.encode(STORAGE_NAMESPACE, address(this), currentEpoch(), logicalSlot));
        // end edit
    }

    function load(bytes32 logicalSlot) internal view returns (bytes32 value) {
        // begin edit
        if (!isActive()) return bytes32(0);

        bytes32 slot = scopedSlot(logicalSlot);
        assembly ("memory-safe") {
            value := sload(slot)
        }
        // end edit
    }

    function store(bytes32 logicalSlot, bytes32 value) internal {
        // begin edit
        if (!isActive()) revert TransientSessionNotActive();

        bytes32 slot = scopedSlot(logicalSlot);
        assembly ("memory-safe") {
            sstore(slot, value)
        }
        // end edit
    }

    function clear(bytes32 logicalSlot) internal {
        // begin edit
        store(logicalSlot, bytes32(0));
        // end edit
    }

    function loadUint256(bytes32 logicalSlot) internal view returns (uint256 value) {
        // begin edit
        value = uint256(load(logicalSlot));
        // end edit
    }

    function storeUint256(bytes32 logicalSlot, uint256 value) internal {
        // begin edit
        store(logicalSlot, bytes32(value));
        // end edit
    }

    function loadInt256(bytes32 logicalSlot) internal view returns (int256 value) {
        // begin edit
        value = int256(uint256(load(logicalSlot)));
        // end edit
    }

    function storeInt256(bytes32 logicalSlot, int256 value) internal {
        // begin edit
        store(logicalSlot, bytes32(uint256(value)));
        // end edit
    }

    function loadAddress(bytes32 logicalSlot) internal view returns (address value) {
        // begin edit
        value = address(uint160(uint256(load(logicalSlot))));
        // end edit
    }

    function storeAddress(bytes32 logicalSlot, address value) internal {
        // begin edit
        store(logicalSlot, bytes32(uint256(uint160(value))));
        // end edit
    }
}
// end edit
