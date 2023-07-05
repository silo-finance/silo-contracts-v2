// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface ILiquidityGaugeFactory {
    /// @notice Deploys a new gauge for a Silo shares token.
    /// It is possible to deploy multiple gauges for a single Silo shares token.
    /// @param relativeWeightCap The relative weight cap for the created gauge
    /// @param erc20BalancesHandler The address of the Silo shares token for which to deploy a gauge
    /// @return gauge The address of the deployed gauge
    function create(uint256 relativeWeightCap, address erc20BalancesHandler) external returns (address gauge);

    /// @return the address of the implementation used for the gauge deployments.
    function getGaugeImplementation() external view returns (address);
}
