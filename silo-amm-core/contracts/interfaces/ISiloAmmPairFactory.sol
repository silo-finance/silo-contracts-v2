// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "silo-core/contracts/interface/ISiloOracle.sol";
import "./IAmmPriceModel.sol";
import "./ISiloAmmPair.sol";


/// @dev this is based on IUniswapV2Factory, unfortunately we are not able to replicate factory interface entirely
/// and methods that are relevant to developers will be integrated into router. So basically in Silo AMM
/// router will handle both.
interface ISiloAmmPairFactory {

    /// @dev open method for creating a pair, however if it will be created by anyone else, except router,
    /// there will be no events and it will not be registered inside protocol.
    /// @notice ONLY PAIRS CREATED BY ROUTER CAN BE TRUSTED
    /// this method does not emit any events and it should not be used directly
    /// @param _silo address
    /// @param _token0 address, assuming addresses are sorted, so `token0 < token1`
    /// @param _token1 address, assuming addresses are sorted, so `token0 < token1`
    /// @param _oracle0 oracle address
    /// @param _oracle1 oracle address
    /// @param _bridge token address required when both oracle are provided
    /// @param _config AmmPriceConfig pool config
    /// @return pair ISiloAmmPair address of new created pool
    function createPair(
        address _silo,
        address _token0,
        address _token1,
        ISiloOracle _oracle0,
        ISiloOracle _oracle1,
        address _bridge,
        IAmmPriceModel.AmmPriceConfig memory _config
    ) external returns (ISiloAmmPair pair);

    function siloAmmPairFactoryPing() external pure returns (bytes4);
}
