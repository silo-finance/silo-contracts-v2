// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {MaxLiquidationCommon} from "./MaxLiquidationCommon.sol";

/*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mc MaxLiquidationLTV100FullTest

    cases where we go from solvent to 100% and we must do full liquidation
*/
contract MaxLiquidationLTV100FullTest is MaxLiquidationCommon {
    using SiloLensLib for ISilo;

    /*
    forge test -vv --ffi --mt test_maxLiquidation_LTV100_full_1token_sTokens_fuzz
    */
    /// forge-config: core_test.fuzz.runs = 100
    function test_maxLiquidation_LTV100_full_1token_sTokens_fuzz(uint8 _collateral) public {
        _maxLiquidation_LTV100_full_1token(_collateral, _RECEIVE_STOKENS);
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_LTV100_full_1token_tokens_fuzz
    */
    /// forge-config: core_test.fuzz.runs = 100
    function test_maxLiquidation_LTV100_full_1token_tokens_fuzz(uint8 _collateral) public {
        _maxLiquidation_LTV100_full_1token(_collateral, !_RECEIVE_STOKENS);
    }

    /*
    for small numbers we jump from solvent -> 100% LTV, so partial liquidation not possible
    even if 100% is not bad debt, partial liquidation will be full liquidation

    I used `_findLTV100` to find range of numbers for which we jump to 100% for this case setup
    */
    function _maxLiquidation_LTV100_full_1token(uint8 _collateral, bool _receiveSToken) internal virtual {
        bool sameAsset = true;

        vm.assume(_collateral < 20);
        _createDebtForBorrower(_collateral, sameAsset);

        // case for `1` never happen because is is not possible to create debt for 1 collateral
        if (_collateral == 1) _findLTV100();
        else if (_collateral == 2) vm.warp(7229 days);
        else if (_collateral == 3) vm.warp(3172 days);
        else if (_collateral == 4) vm.warp(2001 days);
        else if (_collateral == 5) vm.warp(1455 days);
        else if (_collateral == 6) vm.warp(1141 days);
        else if (_collateral == 7) vm.warp(2457 days);
        else if (_collateral == 8) vm.warp(2001 days);
        else if (_collateral == 9) vm.warp(1685 days);
        else if (_collateral == 10) vm.warp(1455 days);
        else if (_collateral == 11) vm.warp(1279 days);
        else if (_collateral == 12) vm.warp(1141 days);
        else if (_collateral == 13) vm.warp(1030 days);
        else if (_collateral == 14) vm.warp(2059 days);
        else if (_collateral == 15) vm.warp(1876 days);
        else if (_collateral == 16) vm.warp(1722 days);
        else if (_collateral == 17) vm.warp(1592 days);
        else if (_collateral == 18) vm.warp(1480 days);
        else if (_collateral == 19) vm.warp(1382 days);
        else revert("should not happen, because of vm.assume");

        _assertLTV100();

        _executeLiquidationAndRunChecks(sameAsset, _receiveSToken);
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_LTV100_full_2tokens_sToken_fuzz
    */
    /// forge-config: core_test.fuzz.runs = 100
    function test_maxLiquidation_LTV100_full_2tokens_sToken_fuzz(uint8 _collateral) public {
        _maxLiquidation_LTV100_full_2tokens(_collateral, _RECEIVE_STOKENS);
    }

    /*
    forge test -vv --ffi --mt test_maxLiquidation_LTV100_full_2tokens_token_fuzz
    */
    /// forge-config: core_test.fuzz.runs = 100
    function test_maxLiquidation_LTV100_full_2tokens_token_fuzz(uint8 _collateral) public {
        _maxLiquidation_LTV100_full_2tokens(_collateral, !_RECEIVE_STOKENS);
    }

    function _maxLiquidation_LTV100_full_2tokens(uint8 _collateral, bool _receiveSToken) internal {
        bool sameAsset = false;

        vm.assume(_collateral < 7);

        _createDebtForBorrower(_collateral, sameAsset);

        // this case (1) never happen because is is not possible to create debt for 1 collateral
        if (_collateral == 1) _findLTV100();
        else if (_collateral == 2) vm.warp(3615 days);
        else if (_collateral == 3) vm.warp(66 days);
        else if (_collateral == 4) vm.warp(45 days);
        else if (_collateral == 5) vm.warp(95 days);
        else if (_collateral == 6) vm.warp(66 days);
        else revert("should not happen, because of vm.assume");

        _assertLTV100();

        _executeLiquidationAndRunChecks(sameAsset, _receiveSToken);
    }

    function _executeLiquidation(bool _sameToken, bool _receiveSToken)
        internal
        virtual
        override
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        // to test max, we want to provide higher `_maxDebtToCover` and we expect not higher results
        uint256 maxDebtToCover = type(uint256).max;

        (
            uint256 collateralToLiquidate, uint256 debtToRepay, bool sTokenRequired
        ) = partialLiquidation.maxLiquidation(borrower);

        (,,, bool fullLiquidation) = siloLens.maxLiquidation(silo1, partialLiquidation, borrower);
        assertTrue(fullLiquidation, "[100FULL] fullLiquidation flag is UP when LTV is 100%");

        emit log_named_uint("[100FULL] collateralToLiquidate", collateralToLiquidate);
        uint256 ltv = silo0.getLtv(borrower);
        emit log_named_decimal_uint("[100FULL] ltv before", ltv, 16);

        if (collateralToLiquidate == 0) {
            assertGe(ltv, 1e18, "[100FULL] if we don't have collateral we expect bad debt");
            return (0, 0);
        }

        assertTrue(!sTokenRequired, "sTokenRequired NOT required");

        (withdrawCollateral, repayDebtAssets) = partialLiquidation.liquidationCall(
            address(_sameToken ? token1 : token0),
            address(token1),
            borrower,
            maxDebtToCover,
            _receiveSToken
        );

        emit log_named_decimal_uint("[100FULL] ltv after", silo0.getLtv(borrower), 16);
        emit log_named_decimal_uint("[100FULL] collateralToLiquidate", collateralToLiquidate, 18);

        assertEq(debtToRepay, repayDebtAssets, "[100FULL] debt: maxLiquidation == result");

        _assertEqDiff(
            withdrawCollateral,
            collateralToLiquidate,
            "[100FULL] collateral: max == result"
        );
    }

    function _withChunks() internal pure virtual override returns (bool) {
        return false;
    }
}
