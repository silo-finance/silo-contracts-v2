// SPDX-License-Identifier: GD
pragma solidity >=0.5.0;

import "silo-amm-core/contracts/external/interfaces/ISiloOracle.sol";
import "silo-amm-core/contracts/interfaces/IAmmPriceModel.sol";

import "../external/interfaces/IUniswapV2Router02.sol";
import "./ISiloAmmRouterEvents.sol";

interface ISiloAmmRouter is ISiloAmmRouterEvents, IUniswapV2Router02 {
    /// @dev It creates pool for pair of tokens. It creates 1:1 bond with Silo
    /// @notice Only SiloFactory can call this method.
    /// @param _silo address of silo with which pool will be paired up
    /// @param _token0 address, assuming addresses are sorted, so `token0 < token1`
    /// @param _token1 address, assuming addresses are sorted, so `token0 < token1`
    /// @param _oracle0 oracle address
    /// @param _oracle1 oracle address
    /// @param _bridge token address required when both oracle are provided
    /// @param _config AmmPriceConfig pool config
    function createPair(
        address _silo,
        address _token0,
        address _token1,
        ISiloOracle _oracle0,
        ISiloOracle _oracle1,
        address _bridge,
        IAmmPriceModel.AmmPriceConfig memory _config
    ) external returns (ISiloAmmPair pair);

    function getPair(address tokenA, address tokenB, uint256 id) external view returns (IUniswapV2Pair pair);
    function getPairs(address tokenA, address tokenB) external view returns (IUniswapV2Pair[] memory pairs);

    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);
}
