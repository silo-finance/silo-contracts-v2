// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Math} from "openzeppelin5/utils/math/Math.sol";
import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {SiloHookV2} from "silo-core/contracts/hooks/SiloHookV2.sol";

/*
FOUNDRY_PROFILE=core_test forge test --ffi --mc DefaultingLiquidationSplitMathTest -vv
*/
contract DefaultingLiquidationSplitMathTest is Test {
    IPartialLiquidationByDefaulting defaulting;

    function setUp() public {
        defaulting = IPartialLiquidationByDefaulting(address(new SiloHookV2()));
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
    function test_getKeeperAndLenderSharesSplit_neverReverts(uint256 _collateralToSplit, uint64 _liquidationFee)
        public
        view
    {
        // only in this case we can revert if `_collateralToSplit` is huge
        // vm.assume(uint256(_liquidationFee) * defaulting.KEEPER_FEE() <= 1e18);

        // defaulting.getKeeperAndLenderSharesSplit(_collateralToSplit, _liquidationFee);
    }

    function _singleCheck(
        uint8 _id,
        address _silo,
        address _shareToken,
        uint256 _liquidationFee,
        uint256 _withdrawAssets,
        ISilo.AssetType _assetType,
        uint256 _expectedTotalShares, 
        uint256 _expectedKeeperShares,
        uint256 _expectedLendersShares
    ) public view {
        // (uint256 totalShares, uint256 keeperShares, uint256 lendersShares) =
        //     defaulting.getKeeperAndLenderSharesSplit({
        //         _silo: _silo,
        //         _shareToken: _shareToken,
        //         _liquidationFee: _liquidationFee,
        //         _withdrawAssets: _withdrawAssets,
        //         _assetType: _assetType
        //     });

        // assertEq(keeperShares, _expectedKeeperShares, string.concat("keeper shares failed for id: ", vm.toString(_id)));
        // assertEq(lendersShares, _expectedLendersShares, string.concat("lenders shares failed for id: ", vm.toString(_id)));
        // assertEq(totalShares, _expectedTotalShares, string.concat("total shares failed for id: ", vm.toString(_id)));

        // assertEq(keeperShares + lendersShares, totalShares, string.concat("sum failed for id: ", vm.toString(_id)));
    }
}
