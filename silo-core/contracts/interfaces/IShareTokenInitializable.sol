// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {ISilo} from "./ISilo.sol";

interface IShareTokenInitializable {
    /// @param _target target address to call
    /// @param _value value to send
    /// @param _callType call type
    /// @param _input input data
    /// @return success true if the call was successful, false otherwise
    /// @return result bytes returned by the call
    function callOnBehalfOfShareToken(address _target, uint256 _value, ISilo.CallType _callType, bytes calldata _input)
        external
        payable
        returns (bool success, bytes memory result);

    /// @param _silo Silo address for which tokens was deployed
    /// @param _hookReceiver address that will get a callback on mint, burn and transfer of the token
    /// @param _tokenType must be one of this hooks values: COLLATERAL_TOKEN, PROTECTED_TOKEN, DEBT_TOKEN
    function initialize(ISilo _silo, address _hookReceiver, uint24 _tokenType) external;
}
