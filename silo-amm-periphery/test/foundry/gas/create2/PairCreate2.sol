// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.19;

contract PairCreate2 {
    address token0 = address(1);
    address token1 = address(2);
    address silo = address(3);

    function get() public view returns (bytes32) {
        // reading 3 slots
        return keccak256(abi.encode(token0, token1, silo));
    }
}
