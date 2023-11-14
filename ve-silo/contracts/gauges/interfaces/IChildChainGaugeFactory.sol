// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

interface IChildChainGaugeFactory {
    /// @notice Deploys a new gauge for a ERC-20 balances handler (Silo shares token)
    /// It is possible to deploy multiple gauges for a single pool.
    /// @param hookReceiver The address of the Silo hook receiver
    /// @return The address of the deployed gauge
    function create(address hookReceiver) external returns (address);

    /// @return the address of the implementation used for the gauge deployments.
    function getGaugeImplementation() external view returns (address);

    /// @return the version of the product
    function getProductVersion() external view returns (string memory);
}
