// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";

contract InterestRateModelMock is Test {
    address public immutable ADDRESS;

    constructor () {
        ADDRESS = makeAddr("InterestRateModelMock");
    }

    function getCompoundInterestRateMock(address _silo, uint256 _blockTimestamp, uint256 _rcomp) external {
        vm.mockCall(
            ADDRESS,
            abi.encodeWithSelector(
                bytes4(keccak256(abi.encodePacked("getCompoundInterestRate(address,uint256)"))), _silo, _blockTimestamp
            ),
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
