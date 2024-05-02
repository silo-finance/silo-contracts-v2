// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "silo-core/contracts/lib/SiloMathLib.sol";

// forge test -vv --mc ConversionsTest
contract ConversionsTest is Test {
    /*
    forge test -vv --mt test_SiloMathLib_conversions
    */
    function test_SiloMathLib_conversions() public {
        uint256 _assets = 1;
        uint256 _totalAssets;
        uint256 _totalShares;
        Math.Rounding _rounding = Rounding.DOWN;

        uint256 shares = SiloMathLib.convertToShares(_assets, _totalAssets, _totalShares, _rounding, ISilo.CollateralType.Collateral);
        assertEq(shares, 1 * SiloMathLib._DECIMALS_OFFSET_POW);

        _totalAssets += _assets;
        _totalShares += shares;

        _assets = 1000;
        shares = SiloMathLib.convertToShares(_assets, _totalAssets, _totalShares, _rounding, ISilo.CollateralType.Collateral);
        assertEq(shares, 1000 * SiloMathLib._DECIMALS_OFFSET_POW);

        _totalAssets += _assets;
        _totalShares += shares;

        shares = 1 * SiloMathLib._DECIMALS_OFFSET_POW;
        _assets = SiloMathLib.convertToAssets(shares, _totalAssets, _totalShares, _rounding, ISilo.CollateralType.Collateral);
        assertEq(_assets, 1);

        shares = 1000 * SiloMathLib._DECIMALS_OFFSET_POW;
        _assets = SiloMathLib.convertToAssets(shares, _totalAssets, _totalShares, _rounding, ISilo.CollateralType.Collateral);
        assertEq(_assets, 1000);
    }
}
