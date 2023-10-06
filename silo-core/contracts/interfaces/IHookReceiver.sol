// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IGauge} from "./IGauge.sol";
import {IShareToken} from "./IShareToken.sol";

interface IHookReceiver {
    error WrongShareToken();

    /// @param _owner address that can setup gauge
    /// @param _shareToken address for which hook is deployed
    function initialize(address _owner, IShareToken _shareToken) external;

    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    ) external;

    function setup(IGauge _gauge) external;
}
