// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

/// @dev Balancer V2 VeBoostV2 interface
/// As Balancer VeBoostV2 is implemented with Vyper programming language and we don't use
/// all the methods present in the Balancer VeBoostV2. We'll have a solidity version
/// of the interface that includes only methods required for Silo.
interface IVeBoost {
    // solhint-disable func-name-mixedcase
    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (bool);

    function boost(address _to, uint256 _amount, uint256 _endtime) external;
    function adjusted_balance_of(address _user) external view returns (uint256);
    function delegated_balance(address _user) external view returns (uint256);
    function received_balance(address _user) external view returns (uint256);
    function VE() external view returns (address);
    function BOOST_V1() external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function version() external view returns (string memory);
    function nonces(address _user) external view returns (uint256);
    function allowance(address _owner, address _spender) external view returns (uint256);
    // solhint-enable func-name-mixedcase
}
