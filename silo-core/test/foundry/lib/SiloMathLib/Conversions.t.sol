// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {Rounding} from "silo-core/contracts/lib/Rounding.sol";
import {SiloMathLib, Math} from "silo-core/contracts/lib/SiloMathLib.sol";

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

        uint256 shares = SiloMathLib.convertToShares(_assets, _totalAssets, _totalShares, _rounding, ISilo.AssetType.Collateral);
        assertEq(shares, 1 * SiloMathLib._DECIMALS_OFFSET_POW, "#1");

        _totalAssets += _assets;
        _totalShares += shares;

        _assets = 1000;
        shares = SiloMathLib.convertToShares(_assets, _totalAssets, _totalShares, _rounding, ISilo.AssetType.Collateral);
        assertEq(shares, 1000 * SiloMathLib._DECIMALS_OFFSET_POW, "#2");

        _totalAssets += _assets;
        _totalShares += shares;

        shares = 1 * SiloMathLib._DECIMALS_OFFSET_POW;
        _assets = SiloMathLib.convertToAssets(shares, _totalAssets, _totalShares, _rounding, ISilo.AssetType.Collateral);
        assertEq(_assets, 1, "#3");

        shares = 1000 * SiloMathLib._DECIMALS_OFFSET_POW;
        _assets = SiloMathLib.convertToAssets(shares, _totalAssets, _totalShares, _rounding, ISilo.AssetType.Collateral);
        assertEq(_assets, 1000, "#4");
    }

    /*
    forge test -vv --mt test_SiloMathLib_conversions
    */
    function test_SiloMathLib_conversions_fuzz(
//        uint256 _assets, uint64 _dust
    ) public {
        (uint256 _assets, uint64 _dust) = (0, 18446744073709550616);
        vm.assume(_assets < 2 ** 128);

        uint256 _totalAssets = _dust;
        uint256 _totalShares;
        Math.Rounding _rounding = Rounding.DOWN;

        uint256 shares = SiloMathLib.convertToShares(_assets, _totalAssets, _totalShares, _rounding, ISilo.AssetType.Collateral);
        assertEq(shares, _assets * SiloMathLib._DECIMALS_OFFSET_POW, "#1");

        _totalAssets += _assets;
        _totalShares += shares;

        _assets = 1000;
        shares = SiloMathLib.convertToShares(_assets, _totalAssets, _totalShares, _rounding, ISilo.AssetType.Collateral);
        assertEq(shares, 1000 * SiloMathLib._DECIMALS_OFFSET_POW, "#2");

        _totalAssets += _assets;
        _totalShares += shares;

        shares = 1 * SiloMathLib._DECIMALS_OFFSET_POW;
        _assets = SiloMathLib.convertToAssets(shares, _totalAssets, _totalShares, _rounding, ISilo.AssetType.Collateral);
        assertGe(_assets, 1, "#3, with dust, we can get more");
        assertLe(_assets, 1 + uint256(_dust), "#3, with dust, we can not get more than dust");

        shares = 1000 * SiloMathLib._DECIMALS_OFFSET_POW;
        _assets = SiloMathLib.convertToAssets(shares, _totalAssets, _totalShares, _rounding, ISilo.AssetType.Collateral);
        assertGe(_assets, 1000, "#4, with dust, we can get more");
        assertLe(_assets, 1000 + uint256(_dust), "#4, with dust, we can not get more than dust");
    }
}
