// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {VaultsLittleHelper} from "../../_common/VaultsLittleHelper.sol";

/*
    forge test -vv --ffi --mc PreviewDepositTest
*/
contract PreviewDepositTest is VaultsLittleHelper {
    address immutable depositor;

    constructor() {
        depositor = makeAddr("Depositor");
    }

    /*
    forge test -vv --ffi --mt test_previewDeposit_beforeInterest_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewDeposit_beforeInterest_fuzz(uint128 _assets) public {
        vm.assume(_assets > 0);

        uint256 previewShares =vault.previewDeposit(_assets);
        uint256 shares = _deposit(_assets, depositor);

        assertEq(previewShares, shares, "previewDeposit must return as close but NOT more");
        assertEq(previewShares, vault.convertToShares(_assets), "previewDeposit == convertToShares");
    }

    /*
    forge test -vv --ffi --mt test_previewDeposit_afterNoInterest
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewDeposit_afterNoInterest_fuzz(uint128 _assets) public {
        vm.assume(_assets > 0);

        uint256 sharesBefore = _deposit(_assets, depositor);

        vm.warp(block.timestamp + 365 days);
        silo0.accrueInterest();
        silo1.accrueInterest();

        uint256 previewShares = vault.previewDeposit(_assets);
        uint256 gotShares = _deposit(_assets, depositor);

        assertEq(previewShares, gotShares, "previewDeposit must return as close but NOT more");
        assertEq(previewShares, sharesBefore, "without interest shares must be the same");
        assertEq(previewShares, silo0.convertToShares(_assets), "previewDeposit == convertToShares");
    }

    /*
    forge test -vv --ffi --mt test_previewDeposit_withInterest
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewDeposit_withInterest_1token_fuzz(uint256 _assets) public {
        _previewDeposit_withInterest(_assets);
    }

    function _previewDeposit_withInterest(uint256 _assets) private {
        vm.assume(_assets < type(uint128).max);
        vm.assume(_assets > 0);

        uint256 sharesBefore = _deposit(_assets, depositor);
        _depositForBorrow(_assets, depositor);

        address borrower = makeAddr("Borrower");
        _deposit(_assets / 10 == 0 ? 2 : _assets, borrower);
        _borrow(_assets / 10 + 1, borrower); // +1 ensure we not borrowing 0

        vm.warp(block.timestamp + 365 days);

        uint256 previewShares0 = vault.previewDeposit(_assets);
        uint256 previewShares1 = vault.previewDeposit(_assets);

        assertLe(
            previewShares1,
            previewShares0,
            "you can get less shares on silo1 than on silo0, because we have interests here"
        );

        if (previewShares1 == 0) {
            // if preview is zero for `_assets`, then deposit should also reverts
            _depositForBorrowRevert(_assets, depositor, ISilo.InputZeroShares.selector);
        } else {
            assertEq(
                previewShares1,
                _makeDeposit(silo1, token1, _assets, depositor, cType),
                "previewDeposit with interest on the fly - must be as close but NOT more"
            );
        }

        silo0.accrueInterest();
        silo1.accrueInterest();

        assertEq(silo0.previewDeposit(_assets, cType), sharesBefore, "no interest in silo0, so preview should be the same");
        assertEq(silo0.previewDeposit(_assets, cType), silo0.convertToShares(_assets, aType), "previewDeposit0 == convertToShares");

        previewShares1 = silo1.previewDeposit(_assets, cType);
        assertEq(previewShares1, silo1.convertToShares(_assets, aType), "previewDeposit1 == convertToShares");

        // we have different rounding direction for general conversion method nad preview deposit
        // so it can produce slight different result on precision level, that's why we divide by precision
        assertLe(
            previewShares1 / SiloMathLib._DECIMALS_OFFSET_POW,
            _assets,
            "with interests, we can receive less shares than assets amount"
        );

        emit log_named_uint("previewShares1", previewShares1);

        if (previewShares1 == 0) {
            _depositForBorrowRevert(_assets, depositor, cType, ISilo.InputZeroShares.selector);
        } else {
            assertEq(
                previewShares1,
                _makeDeposit(silo1, token1, _assets, depositor, cType),
                "previewDeposit after accrueInterest() - as close, but NOT more"
            );
        }
    }
    
    function _castToTypes(bool _defaultType, uint8 _type)
        private
        pure
        returns (ISilo.CollateralType collateralType, ISilo.AssetType assetType)
    {
        collateralType = _defaultType ? ISilo.CollateralType.Collateral : ISilo.CollateralType(_type);
        assetType = _defaultType ? ISilo.AssetType.Collateral : ISilo.AssetType(_type);
    }
}
