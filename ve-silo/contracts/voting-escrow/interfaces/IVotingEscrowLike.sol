// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

/// @dev Balancer V2 Voting Escrow interface
/// As Balancer VotingEscrow is implemented with Vyper programming language and we don't use
/// all the methods present in the Balancer VotingEscrow. We'll have a solidity version
/// of the interface that includes only methods required for Silo.
interface IVotingEscrowLike {
    //  solhint-disable-next-line func-name-mixedcase
    function create_lock(uint256 _value, uint256 _timestamp) external;
    //  solhint-disable-next-line func-name-mixedcase
    function commit_smart_wallet_checker(address _addr) external;
    //  solhint-disable-next-line func-name-mixedcase
    function apply_smart_wallet_checker() external;

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint256);
    function admin() external view returns (address);
    function token() external view returns (address);
    function balanceOf(address _user) external view returns (uint256);
    function balanceOf(address _user, uint256 _timestamp) external view returns (uint256);
}
