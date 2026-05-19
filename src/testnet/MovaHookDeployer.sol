// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

// begin edit
import {IPoolManager} from "../interfaces/IPoolManager.sol";
import {MovaExactInputFeeHook} from "./MovaExactInputFeeHook.sol";

contract MovaHookDeployer {
    event HookDeployed(address hook, bytes32 salt);

    function deployExactInputFeeHook(IPoolManager manager, bytes32 salt) external returns (MovaExactInputFeeHook hook) {
        hook = new MovaExactInputFeeHook{salt: salt}(manager);
        emit HookDeployed(address(hook), salt);
    }

    function computeExactInputFeeHookAddress(IPoolManager manager, bytes32 salt) external view returns (address) {
        bytes memory initCode = abi.encodePacked(type(MovaExactInputFeeHook).creationCode, abi.encode(manager));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(initCode)));
        return address(uint160(uint256(hash)));
    }
}
// end edit
