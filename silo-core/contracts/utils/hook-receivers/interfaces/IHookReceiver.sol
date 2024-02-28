// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

interface IHookReceiver {
    /// @dev calls to hooks are done using low level call and internal reverts are ignored. In order to have some
    /// communication from hook -> silo, we can use return codes
    enum HookReturnCode {
        SUCCESS,
        REQUEST_TO_REVERT_TX
    }

    /// @notice Initialize a hook receiver
    /// @param _owner Owner of the hook receiver (DAO)
    /// @param _token Silo share token for which hook receiver should be initialized.
    /// It should be a silo collateral token, protected share token, or debt share token.
    /// If any additional data is needed for the hook receiver initialization,
    /// it can be resolved from the silo, which can be resolved from the share token.
    function initialize(address _owner, IShareToken _token) external;

    /// @notice Any time the share token balance updates, the hook receiver receives a notification
    /// @return code code returned by hook receiver to silo, silo can take actions based on this code
    function afterTokenTransfer(
        address _sender,
        uint256 _senderBalance,
        address _recipient,
        uint256 _recipientBalance,
        uint256 _totalSupply,
        uint256 _amount
    ) external returns (HookReturnCode code);
}
