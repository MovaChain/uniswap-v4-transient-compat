// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IExttload} from "./interfaces/IExttload.sol";

// begin edit
/// @notice Historical notice:
/// Enables public transient storage access for efficient state retrieval by external contracts.
/// https://eips.ethereum.org/EIPS/eip-2330#rationale
/// @notice Epoch-aware compatibility layer for reading state that used to live in transient storage.
// end edit
abstract contract Exttload is IExttload {
    /// @inheritdoc IExttload
    function exttload(bytes32 slot) external view returns (bytes32) {
        // begin edit
        // assembly ("memory-safe") {
        //     mstore(0, tload(slot))
        //     return(0, 0x20)
        // }
        return _exttload(slot);
        // end edit
    }

    /// @inheritdoc IExttload
    function exttload(bytes32[] calldata slots) external view returns (bytes32[] memory) {
        // begin edit
        // assembly ("memory-safe") {
        //     let memptr := mload(0x40)
        //     let start := memptr
        //     // for abi encoding the response - the array will be found at 0x20
        //     mstore(memptr, 0x20)
        //     // next we store the length of the return array
        //     mstore(add(memptr, 0x20), slots.length)
        //     // update memptr to the first location to hold an array entry
        //     memptr := add(memptr, 0x40)
        //     // A left bit-shift of 5 is equivalent to multiplying by 32 but costs less gas.
        //     let end := add(memptr, shl(5, slots.length))
        //     let calldataptr := slots.offset
        //     for {} 1 {} {
        //         mstore(memptr, tload(calldataload(calldataptr)))
        //         memptr := add(memptr, 0x20)
        //         calldataptr := add(calldataptr, 0x20)
        //         if iszero(lt(memptr, end)) { break }
        //     }
        //     return(start, sub(end, start))
        // }
        bytes32[] memory values = new bytes32[](slots.length);
        for (uint256 i = 0; i < slots.length; i++) {
            values[i] = _exttload(slots[i]);
        }
        return values;
        // end edit
    }

    // begin edit
    function _exttload(bytes32 slot) internal view virtual returns (bytes32);
    // end edit
}
