// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

// begin edit
// Historical notice:
// /// @notice This is a temporary library that allows us to use transient storage (tstore/tload)
// /// for the nonzero delta count.
// /// TODO: This library can be deleted when we have the transient keyword support in solidity.
import {EpochState} from "./EpochState.sol";

/// @notice Nonzero delta count backed by epoch-scoped storage for chains without transient storage support.
// end edit
library NonzeroDeltaCount {
    // The logical slot holding the number of nonzero deltas. bytes32(uint256(keccak256("NonzeroDeltaCount")) - 1)
    bytes32 internal constant NONZERO_DELTA_COUNT_SLOT =
        0x7d4b3164c6e45b97e7d87b7125a44c5828d005af88f9d751cfd78729c5d99a0b;

    function read() internal view returns (uint256 count) {
        // begin edit
        // Historical implementation:
        // assembly ("memory-safe") {
        //     count := tload(NONZERO_DELTA_COUNT_SLOT)
        // }
        count = EpochState.loadUint256(NONZERO_DELTA_COUNT_SLOT);
        // end edit
    }

    function increment() internal {
        // begin edit
        // Historical implementation:
        // assembly ("memory-safe") {
        //     let count := tload(NONZERO_DELTA_COUNT_SLOT)
        //     count := add(count, 1)
        //     tstore(NONZERO_DELTA_COUNT_SLOT, count)
        // }
        uint256 count = EpochState.loadUint256(NONZERO_DELTA_COUNT_SLOT);
        unchecked {
            EpochState.storeUint256(NONZERO_DELTA_COUNT_SLOT, count + 1);
        }
        // end edit
    }

    /// @notice Potential to underflow. Ensure checks are performed by integrating contracts to ensure this does not happen.
    /// Current usage ensures this will not happen because we call decrement with known boundaries (only up to the number of times we call increment).
    function decrement() internal {
        // begin edit
        // Historical implementation:
        // assembly ("memory-safe") {
        //     let count := tload(NONZERO_DELTA_COUNT_SLOT)
        //     count := sub(count, 1)
        //     tstore(NONZERO_DELTA_COUNT_SLOT, count)
        // }
        uint256 count = EpochState.loadUint256(NONZERO_DELTA_COUNT_SLOT);
        unchecked {
            EpochState.storeUint256(NONZERO_DELTA_COUNT_SLOT, count - 1);
        }
        // end edit
    }
}
