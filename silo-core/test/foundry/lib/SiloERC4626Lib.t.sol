// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../../../contracts/lib/SiloERC4626Lib.sol";


// forge test -vv --mc SiloERC4626LibTest
contract SiloERC4626LibTest is Test {

    /*
    forge test -vv --mt test_SiloERC4626Lib_conversions
    */
    function test_SiloERC4626Lib_conversions() public {
        uint256 _assets = 1;
        uint256 _totalAssets;
        uint256 _totalShares;
        MathUpgradeable.Rounding _rounding = MathUpgradeable.Rounding.Down;

        uint256 shares = SiloERC4626Lib.convertToShares(_assets, _totalAssets, _totalShares, _rounding);
        assertEq(shares, 1 * SiloERC4626Lib._DECIMALS_OFFSET_POW);

        _totalAssets += _assets;
        _totalShares += shares;

        _assets = 1000;
        shares = SiloERC4626Lib.convertToShares(_assets,  _totalAssets, _totalShares, _rounding);
        assertEq(shares, 1000 * SiloERC4626Lib._DECIMALS_OFFSET_POW);

        _totalAssets += _assets;
        _totalShares += shares;

        shares = 1 * SiloERC4626Lib._DECIMALS_OFFSET_POW;
        _assets = SiloERC4626Lib.convertToAssets(shares, _totalAssets, _totalShares, _rounding);
        assertEq(_assets, 1);

        shares = 1000 * SiloERC4626Lib._DECIMALS_OFFSET_POW;
        _assets = SiloERC4626Lib.convertToAssets(shares, _totalAssets, _totalShares, _rounding);
        assertEq(_assets, 1000);
    }

}
