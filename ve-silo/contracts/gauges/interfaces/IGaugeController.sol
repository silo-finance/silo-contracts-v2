// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

/// @dev Balancer V2 GaugesController interface
/// As Balancer GaugesController is implemented with Vyper programming language and we don't use
/// all the methods present in the Balancer GaugesController. We'll have a solidity version
/// of the interface that includes only methods required for Silo.
interface IGaugeController {
    // solhint-disable func-name-mixedcase
    // solhint-disable var-name-mixedcase
    // solhint-disable func-param-name-mixedcase
    function add_type(string memory _name) external;
    function add_type(string memory _name, uint256 _weight) external;
    function change_type_weight(int128 _type_id, uint256 _weight) external;
    function change_gauge_weight(address _gauge, uint256 _weight) external;
    function add_gauge(address _gauge, int128 _gauge_type) external;
    function add_gauge(address _gauge, int128 _gauge_type, uint256 _weight) external;
    function checkpoint() external;
    function checkpoint_gauge(address _gauge) external;
    function vote_for_gauge_weights(address _gauge_addr, uint256 _user_weight) external;
    function vote_for_many_gauge_weights(address[8] memory _gauge_addrs, uint256[8] memory _user_weight) external;
    function set_gauge_adder(address _addr) external;

    function token() external view returns (address);
    function voting_escrow() external view returns (address);
    function admin() external view returns (address);
    function get_total_weight() external view returns (uint256);
    function get_gauge_weight(int128 _type_id) external view returns (uint256);
    function get_weights_sum_per_type(int128 _type_id) external view returns (uint256);
    function gauge_types(address gauge) external view returns (int128);
    function n_gauge_types() external view returns (int128);
    function n_gauges() external view returns (int128);
    function points_total(uint256 _time) external view returns (uint256);
    function gauge_relative_weight(address gauge, uint256 time) external view returns (uint256);
    function gauge_adder() external view returns (address);
    function gauge_exists(address _addr) external view returns (bool);
    function time_weight(address _addr) external view returns (uint256);
    // solhint-enable func-name-mixedcase
    // solhint-enable var-name-mixedcase
    // solhint-enable func-param-name-mixedcase
}
