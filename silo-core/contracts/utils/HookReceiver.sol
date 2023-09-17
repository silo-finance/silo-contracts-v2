// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IShareToken} from "../interfaces/IShareToken.sol";
import {IHookReceiver} from "../interfaces/IHookReceiver.sol";
import {IGauge} from "../interfaces/IGauge.sol";

contract HookReceiver is IHookReceiver, OwnableUpgradeable {
    IGauge public gauge;
    IShareToken public shareToken;

    error Unauthorized();

    function initialize(address _owner, IShareToken _shareToken) external virtual initializer {
        _transferOwnership(_owner);

        shareToken = _shareToken;
    }

    function setup(IGauge _gauge) external virtual onlyOwner {
        gauge = _gauge;

        if (gauge.shareToken() != address(shareToken)) revert WrongShareToken();
    }

    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256
    ) external virtual {
        if (msg.sender != address(shareToken)) revert Unauthorized();

        if (address(gauge) != address(0)) {
            gauge.afterTokenTransfer(_sender, _senderBalance, _recipient, _recipientBalance, _totalSupply);
        }
    }
}
