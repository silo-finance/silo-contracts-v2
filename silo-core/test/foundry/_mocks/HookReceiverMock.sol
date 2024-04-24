// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {IHookReceiver} from "silo-core/contracts/utils/hook-receivers/interfaces/IHookReceiver.sol";
import {CommonBase} from "forge-std/Base.sol";

contract HookReceiverMock is CommonBase {
    address public immutable ADDRESS;

    constructor(address _hook) {
        ADDRESS = _hook == address(0) ? address(0x191919191919191919191) : _hook;
    }

    // TODO
//    function afterTokenTransferMock(
//        address _sender,
//        uint256 _senderBalance,
//        address _recipient,
//        uint256 _recipientBalance,
//        uint256 _totalSupply,
//        uint256 _amount,
//        uint256 _hookReturnCode
//    ) public {
//        bytes memory data = abi.encodeWithSelector(
//            IHookReceiver.afterTokenTransfer.selector,
//            _sender,
//            _senderBalance,
//            _recipient,
//            _recipientBalance,
//            _totalSupply,
//            _amount
//        );
//
//        vm.mockCall(ADDRESS, data, abi.encode(_hookReturnCode));
//        vm.expectCall(ADDRESS, data);
//    }
}
