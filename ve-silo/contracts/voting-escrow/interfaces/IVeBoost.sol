// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

/// @dev Balancer V2 VeBoostV2 interface
/// As Balancer VeBoostV2 is implemented with Vyper programming language and we don't use
/// all the methods present in the Balancer VeBoostV2. We'll have a solidity version
/// of the interface that includes only methods required for Silo.
interface IVeBoost {
    // solhint-disable func-name-mixedcase
    function boost(address _to, uint256 _amount, uint256 _endtime) external;
    function adjusted_balance_of(address _user) external view returns (uint256);
    function delegated_balance(address _user) external view returns (uint256);
    function received_balance(address _user) external view returns (uint256);
    function VE() external view returns (address);
    function BOOST_V1() external view returns (address);
    // solhint-enable func-name-mixedcase
}
