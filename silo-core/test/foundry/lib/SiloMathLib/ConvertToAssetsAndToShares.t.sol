// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "silo-core/contracts/lib/SiloMathLib.sol";

// forge test -vv --mc ConvertToAssetsAndToSharesTest
contract ConvertToAssetsAndToSharesTest is Test {
    /*
    forge test -vv --mt test_convertToAssetsOrToShares
    */
    function test_convertToAssetsOrToShares() public pure {
        uint256 _assetsOrShares = 10000;
        uint256 _totalAssets = 250000;
        uint256 _totalShares = 250000;
        Math.Rounding roundingToAssets = Rounding.UP;
        Math.Rounding roundingToShares = Rounding.DOWN;

        uint256 assets;
        uint256 shares;

        (assets, shares) = SiloMathLib.convertToAssetsOrToShares(
            0, _assetsOrShares, _totalAssets, _totalShares, roundingToAssets, roundingToShares, ISilo.AssetType.Debt
        );

        assertEq(
            assets,
            SiloMathLib.convertToAssets(
                _assetsOrShares, _totalAssets, _totalShares, roundingToAssets, ISilo.AssetType.Debt
            )
        );
        assertEq(shares, _assetsOrShares);

        (assets, shares) = SiloMathLib.convertToAssetsOrToShares(
            _assetsOrShares,
            0,
            _totalAssets,
            _totalShares,
            roundingToAssets,
            roundingToShares,
            ISilo.AssetType.Collateral
        );

        assertEq(assets, _assetsOrShares);
        assertEq(
            shares + 1, // losing 1 wei due to rounding
            SiloMathLib.convertToShares(
                _assetsOrShares, _totalAssets, _totalShares, roundingToAssets, ISilo.AssetType.Collateral
            )
        );
    }
}
