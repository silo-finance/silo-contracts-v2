// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import {ILiquidityGaugeFactory} from "./ILiquidityGaugeFactory.sol";

interface ISiloChildChainGauge {
    function initialize(address _hookReceiver, string memory _version) external;
    // solhint-disable func-name-mixedcase
    // solhint-disable func-param-name-mixedcase
    // solhint-disable var-name-mixedcase
    function afterTokenTransfer(
        address _user1,
        uint256 _user1_new_balancer,
        address _user2,
        uint256 _user2_new_balancer,
        uint256 _total_supply,
        uint256 _amount
    )
        external
        returns (bool);

    function user_checkpoint(address _addr) external returns (bool);
    function claimable_tokens(address _user) external returns (uint256);

    function claimable_tokens_with_fees(
        address _user
    )
        external
        returns (
            uint256 claimable_tokens,
            uint256 fee_dao,
            uint256 fee_deployer
        );

    function add_reward(address _reward_token, address _distributor) external;
    function deposit_reward_token(address _reward_token, uint256 _amount) external;

    /// @notice Returns a silo hook receiver
    function hook_receiver() external view returns (address);
    /// @notice Returns a silo share token
    function share_token() external view returns (address);
    /// @notice Returns a silo
    function silo() external view returns (address);
        /// @notice Returns a silo factory
    function silo_factory() external view returns (address);
    /// @notice Returns a silo and a silo factory
    function getFeeReceivers() external view returns (address, address);
    /// @notice Get the timestamp of the last checkpoint
    function integrate_checkpoint() external view returns (uint256);
    /// @notice ∫(balance * rate(t) / totalSupply(t) dt) from 0 till checkpoint
    function integrate_fraction(address _user) external view returns (uint256);

    function working_supply() external view returns (uint256);
    function working_balances(address _user) external view returns (uint256);

    function period() external view returns (int128);
    function period_timestamp(int128 _period) external view returns (uint256);
    function integrate_inv_supply(int128 _period) external view returns (uint256);
    function integrate_inv_supply_of(address _user) external view returns (uint256);
    function inflation_rate(uint256 _week) external view returns (uint256);
    function version() external view returns (string memory);
    function factory() external view returns (ILiquidityGaugeFactory);
    function authorizer_adaptor() external view returns (address);
    function integrate_checkpoint_of(address _user) external view returns (uint256);
    function lp_token() external view returns (address);
    function bal_pseudo_minter() external view returns (address);
    function voting_escrow_delegation_proxy() external view returns (address);

    // solhint-enable func-name-mixedcase
    // solhint-enable func-param-name-mixedcase
    // solhint-enable var-name-mixedcase
}
