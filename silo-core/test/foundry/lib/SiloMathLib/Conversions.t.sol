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
        uint256 _totalAssets, uint256 _totalShares, uint256 _assets
    ) public {
//        (uint256 _totalAssets, uint256 _totalShares, uint256 _assets) = (1,0,1);

        vm.assume(_totalAssets >= _totalShares); // we allow for dust and/or interest

        if (_totalShares > 0) {
            vm.assume(_totalAssets / _totalShares < 10); // max 10x
        }

        vm.assume(_totalAssets < 2 ** 128);
        vm.assume(_assets < 2 ** 64);

        bool withDust = _totalShares == 0 && _totalAssets > 0;

        uint256 shares = SiloMathLib.convertToShares(_assets, _totalAssets, _totalShares, Rounding.DEPOSIT_TO_SHARES, ISilo.AssetType.Collateral);
        vm.assume(shares > 0);

        _totalShares += shares;
        _totalAssets += _assets;

        uint256 assets = SiloMathLib.convertToAssets(shares, _totalAssets, _totalShares, Rounding.DEPOSIT_TO_ASSETS, ISilo.AssetType.Collateral);
        vm.assume(assets > 0);

        emit log_named_uint("_totalShares", _totalShares);
        emit log_named_uint("_totalAssets", _totalAssets);
        emit log_named_uint("shares", shares);
        emit log_named_uint("assets", assets);
        emit log_named_uint("_assets", _assets);

        if (withDust) {
            // this is where silo is empty and we have dust
            assertLe(assets - _assets, 1 + _totalAssets, "dust: allow for 1 wei diff (rounding) + dust distribution");
        } else {
            assertLe(_assets - assets, 10, "assets: allow for 1 wei diff for rounding"); // TODO
        }
    }
}
