// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {ILeverageBorrower} from "silo-core/contracts/interfaces/ILeverageBorrower.sol";

contract LeverageBorrowerMock is Test {
    address public immutable ADDRESS;

    constructor(address _leverage) {
        ADDRESS = _leverage == address(0) ? makeAddr("LeverageBorrowerMock") : _leverage;
    }

    function onLeverageMock(
        address _initiator,
        address _borrower,
        address _asset,
        uint256 _assets,
        bytes calldata _data,
        bytes32 _result
    ) external {
        bytes memory data = abi.encodeWithSelector(
            ILeverageBorrower.onLeverage.selector,
            _initiator,
            _borrower,
            _asset,
            _assets,
            _data
        );
        vm.mockCall(ADDRESS, data, abi.encode(_result));
        vm.expectCall(ADDRESS, data);
    }
}
