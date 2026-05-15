// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {EpochState} from "./EpochState.sol";

/// @notice Lock state backed by epoch-scoped storage for chains without TSTORE/TLOAD support.
library Lock {
    // The slot holding the unlocked state, transiently. bytes32(uint256(keccak256("Unlocked")) - 1)
    bytes32 internal constant IS_UNLOCKED_SLOT = 0xc090fc4683624cfc3884e9d8de5eca132f2d0ec062aff75d43c0465d5ceeab23;

    function unlock() internal {
        if (EpochState.isUnlocked()) revert();
        EpochState.bumpEpoch();
        EpochState.setUnlocked(true);
    }

    function lock() internal {
        EpochState.setUnlocked(false);
    }

    function isUnlocked() internal view returns (bool unlocked) {
        unlocked = EpochState.isUnlocked();
    }
}
