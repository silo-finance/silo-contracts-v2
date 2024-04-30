// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {IHookReceiver} from "silo-core/contracts/utils/hook-receivers/interfaces/IHookReceiver.sol";

contract HookReceiverMock is CommonBase, StdCheats {
    address public immutable ADDRESS;

    uint24 public hooksBefore;
    uint24 public hooksAfter;

    constructor(address _hook) {
        ADDRESS = _hook == address(0) ? makeAddr("HookReceiverMock") : _hook;
    }

    function hookReceiverConfigMock(uint24 _hooksBefore, uint24 _hooksAfter) public {
        hooksBefore = _hooksBefore;
        hooksAfter = _hooksAfter;
        // vm.mockCall(
        //     ADDRESS,
        //     abi.encodeWithSelector(IHookReceiver.hookReceiverConfig.selector),
        //     abi.encode(hooksBefore, hooksAfter)
        // );
    }

    function hookReceiverConfig() public view returns (uint24, uint24) {
        return (hooksBefore, hooksAfter);
    }

    // TODO
//    function afterTokenTransferMock(
//        address _sender,
//        uint256 _senderBalance,
//        address _recipient,
//        uint256 _recipientBalance,
//        uint256 _totalSupply,
//        uint256 _amount
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
//        vm.mockCall(ADDRESS, data);
//        vm.expectCall(ADDRESS, data);
//    }
}
