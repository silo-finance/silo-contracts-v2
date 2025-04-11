// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {SiloMathLib} from "silo-core/contracts/lib/SiloMathLib.sol";

/*
   FOUNDRY_PROFILE=core-test forge test -vv --mc ApplyFraction
*/
contract ApplyFraction is Test {

    function setUp() public {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        $.interestRateTimestamp = 1000;
        $.daoAndDeployerRevenue = 333;

        $.totalAssets[ISilo.AssetType.Collateral] = type(uint256).max - 100e18;
        $.totalAssets[ISilo.AssetType.Debt] = type(uint256).max - 200e18;
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vv --mt test_applyFractions_
    */
    function test_applyFractions_shouldNeverRevert(
        uint256 _rcomp, uint256 _daoFee, uint256 _deployerFee
    ) public {
//        (uint256 _rcomp, uint256 _daoFee, uint256 _deployerFee) = (1, 115792089237316195423570985008687907853269984665640564039457584007913129639934, 115792089237316195423570985008687907853269984665640564039457584007913129639935);

        vm.assume(_rcomp > 0 && _rcomp < 1e18);
        vm.assume(_daoFee > 0 && _daoFee < 1e18);
        vm.assume(_deployerFee > 0 && _deployerFee < 1e18);
        vm.assume(_daoFee + _deployerFee < 1e18);

        vm.warp(block.timestamp + 10);

        uint256 accruedInterest;

        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        uint64 lastTimestamp = $.interestRateTimestamp;

        // Interest has already been accrued this block
        if (lastTimestamp == block.timestamp) {
            revert("we need test with time");
        }

        // This is the first time, so we can return early and save some gas
        if (lastTimestamp == 0) {
            $.interestRateTimestamp = uint64(block.timestamp);
            revert("we need test with lastTimestamp");
        }

        uint256 totalFees;
        uint256 totalCollateralAssets = $.totalAssets[ISilo.AssetType.Collateral];
        uint256 totalDebtAssets = $.totalAssets[ISilo.AssetType.Debt];

        if (_rcomp == 0) {
            $.interestRateTimestamp = uint64(block.timestamp);
            revert("we need test with interest");
        }

        (
            $.totalAssets[ISilo.AssetType.Collateral], $.totalAssets[ISilo.AssetType.Debt], totalFees, accruedInterest
        ) = SiloMathLib.getCollateralAmountsWithInterest({
            _collateralAssets: totalCollateralAssets,
            _debtAssets: totalDebtAssets,
            _rcomp: _rcomp,
            _daoFee: _daoFee,
            _deployerFee: _deployerFee
        });

        (accruedInterest, totalFees) = SiloLendingLib.applyFractions({
            _totalDebtAssets: totalDebtAssets,
            _rcomp: _rcomp,
            _accruedInterest: accruedInterest,
            _fees: _daoFee + _deployerFee,
            _totalFees: totalFees
        });

        // update remaining contract state
        $.interestRateTimestamp = uint64(block.timestamp);

        // we operating on chunks (fees) of real tokens, so overflow should not happen
        // fee is simply too small to overflow on cast to uint192, even if, we will get lower fee
        unchecked { $.daoAndDeployerRevenue += uint192(totalFees); }
    }
}
