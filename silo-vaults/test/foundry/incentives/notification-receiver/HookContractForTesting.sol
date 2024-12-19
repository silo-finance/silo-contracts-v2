//// SPDX-License-Identifier: UNLICENSED
//pragma solidity ^0.8.10;
//
//
//contract HookContractForTesting {
//    SiloIncentivesController controller;
//    MintableToken notifierToken;
//
//    function setup(
//        SiloIncentivesController _controller,
//        MintableToken _notifierToken
//    ) public {
//        controller = _controller;
//        notifierToken = _notifierToken;
//    }
//
//    // notifier has to sum up total from all external contracts
//    function totalSupply() external view returns (uint256) {
//        return notifierToken.totalSupply();
//    }
//
//    // notifier has to sum up balances from all external contracts
//    function balanceOf(address _user) external view returns (uint256) {
//        return notifierToken.balanceOf(_user);
//    }
//
//    function hookReceiverConfig(address) external view returns (uint24 hooksBefore, uint24 hooksAfter) {
//        hooksAfter = uint24(Hook.SHARE_TOKEN_TRANSFER | Hook.COLLATERAL_TOKEN);
//    }
//
//    function afterAction(address /* _silo */, uint256 /* _action */, bytes calldata _inputAndOutput) external {
//        Hook.AfterTokenTransfer memory input = Hook.afterTokenTransferDecode(_inputAndOutput);
//
//        controller.afterTokenTransfer(
//            input.sender, input.senderBalance, input.recipient, input.recipientBalance, input.totalSupply, input.amount
//        );
//    }
//}
