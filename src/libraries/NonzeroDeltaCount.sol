// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {EpochState} from "./EpochState.sol";

/// @notice Nonzero delta count backed by epoch-scoped storage for chains without TSTORE/TLOAD support.
library NonzeroDeltaCount {
    // The logical slot holding the number of nonzero deltas. bytes32(uint256(keccak256("NonzeroDeltaCount")) - 1)
    bytes32 internal constant NONZERO_DELTA_COUNT_SLOT =
        0x7d4b3164c6e45b97e7d87b7125a44c5828d005af88f9d751cfd78729c5d99a0b;

    function read() internal view returns (uint256 count) {
        count = EpochState.readNonzeroDeltaCount();
    }

    function increment() internal {
        EpochState.incrementNonzeroDeltaCount();
    }

    /// @notice Potential to underflow. Ensure checks are performed by integrating contracts to ensure this does not happen.
    /// Current usage ensures this will not happen because we call decrement with known boundaries (only up to the number of times we call increment).
    function decrement() internal {
        EpochState.decrementNonzeroDeltaCount();
    }
}
