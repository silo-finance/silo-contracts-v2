// SPDX-License-Identifier: GD
pragma solidity >=0.8.0;

import "silo-amm-core/contracts/interfaces/ISiloAmmPair.sol";

import "./UniswapV2Library.sol";

/// @dev this is based on UniswapV2Library
/// differences in interface are mentioned in `notice` section of each method
///
/// library containing some math for dealing with the liquidity shares of a pair, e.g. computing their exact value
/// in terms of the underlying tokens
library UniswapV2LiquidityMathLibrary {
    /// @notice differences from original UniswapV2Library:
    /// - first argument is changed from factory address to pair address
    /// **note this is subject to manipulation, e.g. sandwich attacks**. prefer passing a manipulation resistant price
    /// to #getLiquidityValueAfterArbitrageToPrice
    /// @dev get all current parameters from the pair and compute value of a liquidity amount
    function getLiquidityValue(
        IUniswapV2Pair _pair,
        address _tokenA,
        address _tokenB,
        uint256
    ) internal view returns (uint256 tokenAAmount, uint256 tokenBAmount) {
        return UniswapV2Library.getReserves(_pair, _tokenA, _tokenB);
    }

    /// @dev computes liquidity value given all the parameters of the pair
    function computeLiquidityValue(
        uint256 _reservesA,
        uint256 _reservesB,
        uint256,
        uint256,
        bool,
        uint
    ) internal pure returns (uint256 tokenAAmount, uint256 tokenBAmount) {
        return (_reservesA, _reservesB);
    }
}
