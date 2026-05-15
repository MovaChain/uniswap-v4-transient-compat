// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IExttload} from "./interfaces/IExttload.sol";

/// @notice Epoch-aware compatibility layer for reading state that used to live in transient storage.
abstract contract Exttload is IExttload {
    /// @inheritdoc IExttload
    function exttload(bytes32 slot) external view returns (bytes32) {
        return _exttload(slot);
    }

    /// @inheritdoc IExttload
    function exttload(bytes32[] calldata slots) external view returns (bytes32[] memory values) {
        values = new bytes32[](slots.length);
        for (uint256 i = 0; i < slots.length; i++) {
            values[i] = _exttload(slots[i]);
        }
    }

    function _exttload(bytes32 slot) internal view virtual returns (bytes32);
}
