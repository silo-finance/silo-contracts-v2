// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Vm} from "forge-std/Vm.sol";

import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";

contract InterestRateModelMock {
    address public constant ADDRESS = address(0x8365223094333333333333333333);

    Vm private immutable vm;

    constructor (Vm _vm) {
        vm = _vm;
    }

    function getCompoundInterestRateMock(address _silo, uint256 _blockTimestamp, uint256 _rcomp) external {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRate.selector, _silo, _blockTimestamp),
            abi.encode(_rcomp)
        );
    }

    function getCompoundInterestRateAndUpdateMock(uint256 _rcomp) external {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(IInterestRateModel.getCompoundInterestRateAndUpdate.selector),
            abi.encode(_rcomp)
        );
    }
}
