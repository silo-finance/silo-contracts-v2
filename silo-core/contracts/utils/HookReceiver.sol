// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";

import {IShareToken} from "../interface/IShareToken.sol";
import {IHookReceiver} from "../interface/IHookReceiver.sol";
import {IGauge} from "../interface/IGauge.sol";

contract HookReceiver is IHookReceiver, OwnableUpgradeable {
    IGauge public gauge;
    IShareToken public shareToken;

    error Unauthorized();

    function initialize() external initializer {
        __Ownable_init();
    }

    function setup(IGauge _gauge, IShareToken _shareToken) external onlyOwner {
        gauge = _gauge;
        shareToken = _shareToken;
    }

    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256
    ) external {
        if (msg.sender != address(shareToken)) revert Unauthorized();

        if (address(gauge) != address(0)) {
            gauge.afterTokenTransfer(_sender, _senderBalance, _recipient, _recipientBalance, _totalSupply);
        }
    }

    function totalSupply() external view virtual returns (uint256) {
        return shareToken.totalSupply();
    }

    function balanceOf(address _account) external view virtual returns (uint256) {
        return shareToken.balanceOf(_account);
    }

    function balanceOfAndTotalSupply(address _account) external view virtual returns (uint256, uint256) {
        return shareToken.balanceOfAndTotalSupply(_account);
    }
}
