// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ILiquidityGaugeFactory} from "./ILiquidityGaugeFactory.sol";

interface ISiloChildChainGauge {
    function initialize(address _erc20BalancesHandler, string memory _version) external;
    // solhint-disable func-name-mixedcase
    // solhint-disable func-param-name-mixedcase
    // solhint-disable var-name-mixedcase
    function balance_updated_for_users(
        address _user1,
        uint256 _user1_new_balancer,
        address _user2,
        uint256 _user2_new_balancer,
        uint256 _total_supply
    )
        external
        returns (bool);

    function user_checkpoint(address _addr) external returns (bool);

    /// @notice Returns ERC-20 Balancer handler
    function bal_handler() external view returns (address);
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
    function version() external view returns (string memory);
    function factory() external view returns (ILiquidityGaugeFactory);
    function authorizer_adaptor() external view returns (address);

    // solhint-enable func-name-mixedcase
    // solhint-enable func-param-name-mixedcase
    // solhint-enable var-name-mixedcase
}
