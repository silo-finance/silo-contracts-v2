// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc PreviewDepositTest
*/
contract PreviewDepositTest is SiloLittleHelper, Test {
    address immutable depositor;
    address immutable borrower;

    constructor() {
        depositor = makeAddr("Depositor");
        borrower = makeAddr("Borrower");
    }

    function setUp() public {
        _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_NO_LTV_SILO);
    }

    /*
    forge test -vv --ffi --mt test_previewDepositType_beforeInterest_fuzz
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewDeposit_beforeInterest_fuzz(uint256 _assets, bool _defaultType, uint8 _type) public {
        vm.assume(_assets > 0);
        vm.assume(_type == 0 || _type == 1);

        uint256 previewShares = _defaultType
            ? silo0.previewDeposit(_assets)
            : silo0.previewDeposit(_assets, ISilo.AssetType(_type));

        uint256 shares = _defaultType
            ? _deposit(_assets, depositor)
            : _deposit(_assets, depositor, ISilo.AssetType(_type));

        assertEq(previewShares, shares, "previewDeposit must return as close but NOT more");
    }

    /*
    forge test -vv --ffi --mt test_previewDeposit_afterNoInterest
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewDeposit_afterNoInterest_fuzz(uint128 _assets, bool _defaultType, uint8 _type) public {
        vm.assume(_assets > 0);
        vm.assume(_type == 0 || _type == 1);

        uint256 sharesBefore = _defaultType
            ? _deposit(_assets, depositor)
            : _deposit(_assets, depositor, ISilo.AssetType(_type));

        vm.warp(block.timestamp + 365 days);
        silo0.accrueInterest();

        uint256 previewShares = _defaultType
            ? silo0.previewDeposit(_assets)
            : silo0.previewDeposit(_assets, ISilo.AssetType(_type));

        uint256 gotShares = _defaultType
            ? _deposit(_assets, depositor)
            : _deposit(_assets, depositor, ISilo.AssetType(_type));

        assertEq(previewShares, gotShares, "previewDeposit must return as close but NOT more");
        assertEq(previewShares, sharesBefore, "without interest shares must be the same");
    }

    /*
    forge test -vv --ffi --mt test_previewDeposit_withInterest
    */
    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewDeposit_withInterest_1token_fuzz(uint256 _assets, bool _protected) public {
        _previewDeposit_withInterest(_assets, _protected, true);
    }

    /// forge-config: core-test.fuzz.runs = 10000
    function test_previewDeposit_withInterest_2tokens_fuzz(uint256 _assets, bool _protected) public {
        _previewDeposit_withInterest(_assets, _protected, false);
    }

    function _previewDeposit_withInterest(uint256 _assets, bool _protected, bool _sameAsset) private {
        vm.assume(_assets < type(uint128).max);
        vm.assume(_assets > 0);

        ISilo.AssetType assetType = _protected ? ISilo.AssetType.Protected : ISilo.AssetType.Collateral;

        uint256 sharesBefore = _deposit(_assets, depositor, assetType);
        _depositForBorrow(_assets, depositor);

        if (_protected) {
            _makeDeposit(silo1, token1, _assets, depositor, ISilo.AssetType.Protected);
        }

        _depositCollateral(_assets / 10 == 0 ? 2 : _assets, borrower, _sameAsset);
        _borrow(_assets / 10 + 1, borrower, _sameAsset); // +1 ensure we not borrowing 0

        vm.warp(block.timestamp + 365 days);

        uint256 previewShares0 = silo0.previewDeposit(_assets, assetType);
        uint256 previewShares1 = silo1.previewDeposit(_assets, assetType);

        assertLe(
            previewShares1,
            previewShares0,
            "you can get less shares on silo1 than on silo0, because we have interests here"
        );

        if (previewShares1 == 0) {
            // if preview is zero for `_assets`, then deposit should also reverts
            _depositForBorrowRevert(_assets, depositor, assetType, ISilo.ZeroShares.selector);
        } else {
            assertEq(
                previewShares1,
                _makeDeposit(silo1, token1, _assets, depositor, assetType),
                "previewDeposit with interest on the fly - must be as close but NOT more"
            );
        }

        silo0.accrueInterest();
        silo1.accrueInterest();

        assertEq(silo0.previewDeposit(_assets, assetType), sharesBefore, "no interest in silo0, so preview should be the same");

        previewShares1 = silo1.previewDeposit(_assets, assetType);

        assertLe(previewShares1, _assets, "with interests, we can receive less shares than assets amount");

        emit log_named_uint("previewShares1", previewShares1);

        if (previewShares1 == 0) {
            _depositForBorrowRevert(_assets, depositor, assetType, ISilo.ZeroShares.selector);
        } else {
            assertEq(
                previewShares1,
                _makeDeposit(silo1, token1, _assets, depositor, assetType),
                "previewDeposit after accrueInterest() - as close, but NOT more"
            );
        }
    }
}
