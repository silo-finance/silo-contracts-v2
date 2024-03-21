// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

/// @dev Balancer V2 Voting Escrow interface
/// As Balancer VotingEscrow is implemented with Vyper programming language and we don't use
/// all the methods present in the Balancer VotingEscrow. We'll have a solidity version
/// of the interface that includes only methods required for Silo.
interface IVeSilo {
    struct Point {
        int128 bias;
        int128 slope; // - dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    // solhint-disable func-name-mixedcase
    function checkpoint() external;
    function create_lock(uint256 _value, uint256 _timestamp) external;
    function increase_unlock_time(uint256 _timestamp) external;
    function commit_smart_wallet_checker(address _addr) external;
    function apply_smart_wallet_checker() external;
    function point_history(uint _epoch) external view returns (Point memory);
    function user_point_history(address _user, uint _epoch) external view returns (Point memory);
    function user_point_epoch(address _user) external view returns (uint);
    function future_smart_wallet_checker() external view returns(address);
    function smart_wallet_checker() external view returns(address);
    function locked__end(address _user) external view returns (uint256);
    // solhint-enable func-name-mixedcase

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint256);
    function admin() external view returns (address);
    function token() external view returns (address);
    function balanceOf(address _user) external view returns (uint256);
    function balanceOf(address _user, uint256 _timestamp) external view returns (uint256);
    function balanceOfAt(address _addr, uint256 _block) external view returns(uint256);
    function totalSupply() external view returns(uint256);
    function totalSupply(uint256 _time) external view returns(uint256);
    function epoch() external view returns (uint);
}
