// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Math} from "openzeppelin5/utils/math/Math.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {SiloHookV2} from "silo-core/contracts/hooks/SiloHookV2.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";
import {Rounding} from "silo-core/contracts/lib/Rounding.sol";

import {CloneHookV2} from "./common/CloneHookV2.sol";

/*
FOUNDRY_PROFILE=core_test forge test --ffi --mc DefaultingLiquidationSplitMathTest -vv
*/
contract DefaultingLiquidationSplitMathTest is CloneHookV2 {
    function setUp() public {
        ISiloConfig.ConfigData memory config0;
        ISiloConfig.ConfigData memory config1;

        config0.lt = 1;
        config0.silo = silo0;
        config0.collateralShareToken = collateralShareToken;
        config0.protectedShareToken = protectedShareToken;
        config0.debtShareToken = debtShareToken;

        defaulting = _cloneHook(config0, config1);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_getKeeperAndLenderSharesSplit_zeros -vv
    */
    function test_getKeeperAndLenderSharesSplit_zeros() public view {
        // _singleCheck({_id: 0, _collateralToSplit: 0, _liquidationFee: 0, _expectedKeepers: 0, _expectedLenders: 0});
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_getKeeperAndLenderSharesSplit_pass -vv
    */
    function test_getKeeperAndLenderSharesSplit_pass() public view {
        assertEq(defaulting.KEEPER_FEE(), 0.2e18, "this math expect 20% keeper fee, so 1/5 of liquidation fee");

        // _singleCheck({
        //     _id: 1,
        //     _collateralToSplit: 1,
        //     _liquidationFee: 0.1e18,
        //     _expectedKeepers: 0,
        //     _expectedLenders: 1
        // });

        // _singleCheck({
        //     _id: 2,
        //     _collateralToSplit: 2,
        //     _liquidationFee: 0.1e18,
        //     _expectedKeepers: 0,
        //     _expectedLenders: 2
        // });

        // _singleCheck({
        //     _id: 3,
        //     _collateralToSplit: 3,
        //     _liquidationFee: 0.1e18,
        //     _expectedKeepers: 0,
        //     _expectedLenders: 3
        // });

        // _singleCheck({
        //     _id: 4,
        //     _collateralToSplit: 54,
        //     _liquidationFee: 0.1e18,
        //     _expectedKeepers: 0,
        //     _expectedLenders: 54
        // });

        // _singleCheck({
        //     _id: 5,
        //     _collateralToSplit: 55,
        //     _liquidationFee: 0.1e18,
        //     _expectedKeepers: 1,
        //     _expectedLenders: 54
        // });

        // _singleCheck({
        //     _id: 6,
        //     _collateralToSplit: 100,
        //     _liquidationFee: 0.1e18,
        //     _expectedKeepers: 1,
        //     _expectedLenders: 99
        // });

        // _singleCheck({
        //     _id: 7,
        //     _collateralToSplit: 1e18,
        //     _liquidationFee: 0.1e18,
        //     _expectedKeepers: 0.018181818181818181e18, // almost 2%
        //     _expectedLenders: 1e18 - 0.018181818181818181e18
        // });
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_getKeeperAndLenderSharesSplit_sumUp_fuzz -vv
    */
    function test_getKeeperAndLenderSharesSplit_sumUp_fuzz(uint256 _collateralToSplit, uint64 _liquidationFee)
        public
        view
    {
        // only in this case we can revert if `_collateralToSplit` is huge
        // vm.assume(uint256(_liquidationFee) * defaulting.KEEPER_FEE() <= 1e18);

        // (uint256 forKeeper, uint256 forLenders) =
        //     defaulting.getKeeperAndLenderSharesSplit(_collateralToSplit, _liquidationFee);

        // if (forLenders == 0) assertEq(forKeeper, 0, "if lenders are 0, keeper should be 0");
        // else assertLt(forKeeper, forLenders, "keeper part is always less lenders part");

        // assertEq(forKeeper + forLenders, _collateralToSplit, "we should split 100%");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_getKeeperAndLenderSharesSplit_neverReverts -vv
    */
    /// forge-config: core_test.fuzz.runs = 10000
    function test_getKeeperAndLenderSharesSplit_neverReverts_fuzz(
        uint64 _liquidationFee,
        uint256 _assetsToLiquidate,
        bool _useProtected,
        uint256 _totalAssets,
        uint256 _totalShares
    ) public {
        // (uint64 _liquidationFee,
        // uint256 _assetsToLiquidate,
        // bool _useProtected,
        // uint256 _totalAssets,
        // uint256 _totalShares) = (236168283117, 115792089237316195423570985008687907853269984665640564039457584007913129639935, false, 3684588539, 3);
        ISilo.CollateralType collateralType =
            _useProtected ? ISilo.CollateralType.Protected : ISilo.CollateralType.Collateral;

        ///////////// prevent overflows START /////////////
        
        // we can revert in few places here actually eg when muldiv reverts, so when result will be oner 256 bits
        // but we do not want to cover extreamly high assets/shares in code, we care more about common cases and edge cases

        // in `_commonConverTo` we have: _totalAssets + 1
        vm.assume(_totalAssets <= type(uint256).max - 1);
        // in _commonConverTo: _totalShares + _DECIMALS_OFFSET_POW
        vm.assume(_totalShares <= type(uint256).max - SiloMathLib._DECIMALS_OFFSET_POW);

        uint256 totalAssetsCap = _totalShares == 0 ? 1 :_totalAssets + 1;
        uint256 totalSharesCap = _totalShares + SiloMathLib._DECIMALS_OFFSET_POW;

        // in convertToShares: _assets.mulDiv(totalShares, totalAssets, _rounding);
        vm.assume(_assetsToLiquidate / totalAssetsCap < type(uint256).max / totalSharesCap);
        
        // precalculate totalSharesToLiquidate
        uint256 totalSharesToLiquidate = SiloMathLib.convertToShares({
            _assets: _assetsToLiquidate,
            _totalAssets: _totalAssets,
            _totalShares: _totalShares,
            _rounding: Rounding.UP,
            _assetType: ISilo.AssetType(uint8(collateralType))
        });

        //  muldiv in `_getKeeperAndLenderSharesSplit`
        if (totalSharesToLiquidate != 0) vm.assume(uint256(_liquidationFee) * defaulting.KEEPER_FEE() < type(uint256).max / totalSharesToLiquidate);

        ///////////// prevent overflows END /////////////    

        address shareToken = _useProtected ? protectedShareToken : collateralShareToken;

        vm.mockCall(silo0, abi.encodeWithSelector(ISilo.getTotalAssetsStorage.selector, collateralType), abi.encode(_totalAssets));
        vm.mockCall(address(shareToken), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(_totalShares));
    
        defaulting.getKeeperAndLenderSharesSplit({
            _liquidationFee: _liquidationFee,
            _assetsToLiquidate: _assetsToLiquidate,
            _collateralType: collateralType
        });
    }

    function _singleCheck(
        uint8 _id,
        uint256 _liquidationFee,
        uint256 _assetsToLiquidate,
        ISilo.CollateralType _collateralType,
        uint256 _expectedTotalShares,
        uint256 _expectedKeeperShares,
        uint256 _expectedLendersShares
    ) public view {
        (uint256 totalShares, uint256 keeperShares, uint256 lendersShares) = defaulting.getKeeperAndLenderSharesSplit({
            _liquidationFee: _liquidationFee,
            _assetsToLiquidate: _assetsToLiquidate,
            _collateralType: _collateralType
        });

        string memory id = vm.toString(_id);

        assertEq(keeperShares, _expectedKeeperShares, string.concat("keeper shares failed for id: ", id));
        assertEq(lendersShares, _expectedLendersShares, string.concat("lenders shares failed for id: ", id));
        assertEq(totalShares, _expectedTotalShares, string.concat("total shares failed for id: ", id));
        assertEq(keeperShares + lendersShares, totalShares, string.concat("sum failed for id: ", id));
    }
}
