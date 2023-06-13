// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "../external/interfaces/IUniswapV2Pair.sol";
import "../external/interfaces/ISiloOracle.sol";
import "./IAmmPriceModel.sol";

/// @dev open method for creating a pair, however if it will be created by anyone else, except router,
/// there will be no events and it will not be registered in router.
/// @notice ONLY PAIRS CREATED BY ROUTER CAN BE TRUSTED
interface ISiloAmmPairFactory {
    function createPair(
        address _silo,
        address _token0,
        address _token1,
        address _feeTo,
        ISiloOracle _oracle0,
        ISiloOracle _oracle1,
        IAmmPriceModel.AmmPriceConfig memory _config
    ) external returns (IUniswapV2Pair pair);
}
