// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";

import {MaxLiquidationCommon} from "./MaxLiquidationCommon.sol";

/*
    forge test -vv --ffi --mc MaxLiquidationDustTest

    cases where when user become insolvent, we do full liquidation because of "dust"
*/
contract MaxLiquidationDustTest is MaxLiquidationCommon {
    using SiloLensLib for ISilo;

    /*
    forge test -vv --ffi --mt test_maxLiquidation_dust_1token_sTokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_dust_1token_sTokens_fuzz(uint8 _collateral) public {
        _maxLiquidation_dust_1token_fuzz(_collateral, _RECEIVE_STOKENS);
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_dust_1token_tokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_dust_1token_tokens_fuzz(uint8 _collateral) public {
        _maxLiquidation_dust_1token_fuzz(_collateral, !_RECEIVE_STOKENS);
    }

    function _maxLiquidation_dust_1token_fuzz(uint8 _collateral, bool _receiveSToken) internal {
        bool _sameAsset = true;

        // this value found by fuzzing tests, is high enough to have partial liquidation possible for this test setup
        vm.assume(
            _collateral == 12
            || (_collateral >= 29 && _collateral <= 38)
            || (_collateral >= 52 && _collateral <= 57)
        );

        uint256 toBorrow = uint256(_collateral) * 85 / 100; // maxLT is 85%
        _createDebt(_collateral, toBorrow, _sameAsset);

        vm.warp(block.timestamp + 1050 days); // initial time movement to speed up _moveTimeUntilInsolvent
        _moveTimeUntilInsolvent();

        _assertBorrowerIsNotSolvent({_hasBadDebt: false}); // TODO make tests for bad debt as well

        _executeLiquidationAndChecks(_sameAsset, _receiveSToken);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasNoDebt();
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_dust_2tokens_sTokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_dust_2tokens_sTokens_fuzz(uint8 _collateral) public {
        _maxLiquidation_dust_2tokens_fuzz(_collateral, _RECEIVE_STOKENS);
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_dust_2tokens_tokens_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 100
    function test_maxLiquidation_dust_2tokens_tokens_fuzz(uint8 _collateral) public {
        _maxLiquidation_dust_2tokens_fuzz(_collateral, !_RECEIVE_STOKENS);
    }

    function _maxLiquidation_dust_2tokens_fuzz(uint8 _collateral, bool _receiveSToken) internal {
        bool _sameAsset = false;

        vm.assume(_collateral == 12 || _collateral == 19 || _collateral == 33);

        uint256 toBorrow = uint256(_collateral) * 75 / 100; // maxLT is 75%

        _createDebt(_collateral, toBorrow, _sameAsset);

        _moveTimeUntilInsolvent();

        _assertBorrowerIsNotSolvent({_hasBadDebt: false});

        _executeLiquidationAndChecks(_sameAsset, _receiveSToken);

        _assertBorrowerIsSolvent();
        _ensureBorrowerHasNoDebt();
    }

    function _executeLiquidation(bool _sameToken, bool _receiveSToken)
        internal
        virtual
        override
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        (
            uint256 collateralToLiquidate, uint256 debtToRepay
        ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        emit log_named_decimal_uint("[_executeMaxPartialDustLiquidation] ltv before", silo0.getLtv(borrower), 16);
        emit log_named_uint("[_executeMaxPartialDustLiquidation] debtToRepay", debtToRepay);

        // to test max, we want to provide higher `_debtToCover` and we expect not higher results
        // also to make sure we can execute with exact `debtToRepay` we will pick exact amount conditionally
        uint256 debtToCover = debtToRepay % 2 == 0 ? type(uint256).max : debtToRepay;

        (withdrawCollateral, repayDebtAssets) = partialLiquidation.liquidationCall(
            address(silo1),
            address(_sameToken ? token1 : token0),
            address(token1),
            borrower,
            debtToCover,
            _receiveSToken
        );

        assertEq(silo0.getLtv(borrower), 0, "[_executeMaxPartialDustLiquidation] expect full liquidation with dust");
        assertEq(debtToRepay, repayDebtAssets, "[_executeMaxPartialDustLiquidation] debt: maxLiquidation == result");

        _assertEqDiff(
            withdrawCollateral,
            collateralToLiquidate,
            "[_executeMaxPartialDustLiquidation] collateral: max == result"
        );
    }
}
