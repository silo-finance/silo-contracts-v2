// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

import "silo-core/contracts/interfaces/ISiloOracle.sol";

contract OracleMock {
    address public immutable ADDRESS;
    Vm private immutable vm;

    constructor(Vm _vm, address _address) {
        vm = _vm;
        ADDRESS = _address == address(0) ? address(0x0740137777777777777777777777) : _address;
    }

    function quoteMock(uint256 _baseAmount, address _baseToken, uint256 _quoteAmount) external {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(ISiloOracle.quote.selector, _baseAmount, _baseToken),
            abi.encode(_quoteAmount)
        );
    }
}
