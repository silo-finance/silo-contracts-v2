// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";

contract SiloFactoryMock is Test {
    address public immutable ADDRESS;

    constructor(address _siloConfig) {
        ADDRESS = _siloConfig == address(0) ? makeAddr("SiloFactoryMock") : _siloConfig;
    }

    function getFeeReceiversMock(address _silo, address _dao, address _deployer) external {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(ISiloFactory.getFeeReceivers.selector, _silo),
            abi.encode(_dao, _deployer)
        );
    }
}
