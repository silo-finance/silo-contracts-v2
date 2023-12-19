// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

import {FlasLoanTakerMock} from "silo-core/test/foundry/_mocks/FlasLoanTakerMock.sol";

// FOUNDRY_PROFILE=core forge test -vv --ffi --mc PreviewMaxTest
contract PreviewMaxTest is SiloLittleHelper, Test {
    ISiloConfig internal _siloConfig;

    // solhint-disable var-name-mixedcase
    address immutable internal _DEPOSITOR;
    address immutable internal _BORROWER;
    address immutable internal _BORROWER2;
    // solhint-disable-enable var-name-mixedcase

    constructor() {
        _DEPOSITOR = makeAddr("Depositor");
        _BORROWER = makeAddr("Borrower");
        _BORROWER2 = makeAddr("Borrower2");
    }

    function setUp() public {
        _siloConfig = _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_NO_LTV_SILO);
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxWithdrawRedeem_noDebt_noInterest_fuzz
    /// forge-config: core.fuzz.runs = 10000
    function test_maxWithdrawRedeem_noDebt_noInterest_fuzz( // solhint-disable-line func-name-mixedcase
        uint128 _assetsToDepositForBorrow,
        uint256 _assetsToBorrow
    ) public {
        _maxWithdrawRedeem_noDebt(_assetsToDepositForBorrow, _assetsToBorrow, 0);
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxWithdrawRedeem_noDebt_withInterest_fuzz
    /// forge-config: core.fuzz.runs = 10000
    function test_maxWithdrawRedeem_noDebt_withInterest_fuzz( // solhint-disable-line func-name-mixedcase
        uint128 _assetsToDepositForBorrow,
        uint256 _assetsToBorrow
    ) public {
        _maxWithdrawRedeem_noDebt(_assetsToDepositForBorrow, _assetsToBorrow, 30 days);
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxWithdrawRedeem_withDebt_noInterest_fuzz
    /// forge-config: core.fuzz.runs = 10000
    function test_maxWithdrawRedeem_withDebt_noInterest_fuzz( // solhint-disable-line func-name-mixedcase
        uint128 _assetsToDepositForBorrow,
        uint256 _assetsToBorrow
    ) public {
        _maxWithdrawRedeem_withDebt(_assetsToDepositForBorrow, _assetsToBorrow, 0);
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxWithdrawRedeem_withDebt_withInterest_fuzz
    /// forge-config: core.fuzz.runs = 10000
    function test_maxWithdrawRedeem_withDebt_withInterest_fuzz( // solhint-disable-line func-name-mixedcase
        uint128 _assetsToDepositForBorrow,
        uint256 _assetsToBorrow
    ) public {
        _maxWithdrawRedeem_withDebt(_assetsToDepositForBorrow, _assetsToBorrow, 30 days);
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxBorrow_noDebt_noInterest_fuzz
    /// forge-config: core.fuzz.runs = 10000
    // solhint-disable-next-line func-name-mixedcase
    function test_maxBorrow_noDebt_noInterest_fuzz(uint128 _assets, uint128 _collateral, bool _useShares) public {
        _maxBorrow_noDebt(_assets, _collateral, _useShares, 0);
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxBorrow_noDebt_withInterest_fuzz
    /// forge-config: core.fuzz.runs = 10000
    // solhint-disable-next-line func-name-mixedcase
    function test_maxBorrow_noDebt_withInterest_fuzz(
        uint128 _assets,
        uint128 _collateral,
        bool _useShares
    ) public {
        // (uint128 _assets, uint128 _collateral, bool _useShares) = (372, 373, true);
        _maxBorrow_noDebt(_assets, _collateral, _useShares, 30 days);
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxBorrow_withDebt_noInterest_fuzz
    /// forge-config: core.fuzz.runs = 10000
    // solhint-disable-next-line func-name-mixedcase
    function test_maxBorrow_withDebt_noInterest_fuzz(uint128 _assets, uint128 _collateral, bool _useShares) public {
        _maxBorrow_withDebt(_assets, _collateral, _useShares, 0);
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxBorrow_withDebt_withInterest_fuzz
    /// forge-config: core.fuzz.runs = 10000
    // solhint-disable-next-line func-name-mixedcase
    function test_maxBorrow_withDebt_withInterest_fuzz(uint128 _assets, uint128 _collateral, bool _useShares) public {
        _maxBorrow_withDebt(_assets, _collateral, _useShares, 30 days);
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxReepay_noInterest_fuzz
    /// forge-config: core.fuzz.runs = 10000
    function test_maxReepay_noInterest_fuzz( // solhint-disable-line func-name-mixedcase
        uint128 _assetsToDepositForBorrow,
        uint256 _assetsToBorrow,
        bool _useShares
    ) public {
        _maxReepay(_assetsToDepositForBorrow, _assetsToBorrow, _useShares, 0);
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxReepay_withInterest_fuzz
    /// forge-config: core.fuzz.runs = 10000
    function test_maxReepay_withInterest_fuzz( // solhint-disable-line func-name-mixedcase
        uint128 _assetsToDepositForBorrow,
        uint256 _assetsToBorrow,
        bool _useShares
    ) public {
        _maxReepay(_assetsToDepositForBorrow, _assetsToBorrow, _useShares, 30 days);
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxFlashLoan_fuzz
    /// forge-config: core.fuzz.runs = 10000
    function test_maxFlashLoan_fuzz( // solhint-disable-line func-name-mixedcase
        uint128 _assetsToDepositForBorrow,
        uint256 _assetsToBorrow
    ) public {
        vm.assume(_assetsToDepositForBorrow > 1);
        vm.assume(_assetsToBorrow > 1 && _assetsToBorrow < _assetsToDepositForBorrow / 2);

        _depositForBorrow(_assetsToDepositForBorrow, _DEPOSITOR);
        _deposit(_assetsToBorrow * 2, _BORROWER);
        _borrow(_assetsToBorrow, _BORROWER);

        uint256 maxFlashLoan = silo1.maxFlashLoan(address(token1));

        FlasLoanTakerMock flasLoanTakerMock = new FlasLoanTakerMock();

        uint256 fee = silo1.flashFee(address(token1), maxFlashLoan);

        _mintTokens(token1, fee, address(flasLoanTakerMock));

        flasLoanTakerMock.takeFlashLoan(silo1, address(token1), maxFlashLoan);
    }

    function _maxWithdrawRedeem_noDebt( // solhint-disable-line func-name-mixedcase
        uint128 _assetsToDepositForBorrow,
        uint256 _assetsToBorrow,
        uint256 _time
    ) internal {
        vm.assume(_assetsToDepositForBorrow > 1);
        vm.assume(_assetsToBorrow > 1 && _assetsToBorrow < _assetsToDepositForBorrow / 2);

        _depositForBorrow(_assetsToDepositForBorrow, _DEPOSITOR);
        _deposit(_assetsToBorrow * 2, _BORROWER);
        _borrow(_assetsToBorrow, _BORROWER);

        if (_time > 0) {
            vm.warp(block.timestamp + _time);
        }

        uint256 maxAssets = silo1.maxWithdraw(_DEPOSITOR);
        uint256 maxShare = silo1.maxRedeem(_DEPOSITOR);

        vm.prank(_DEPOSITOR);
        uint256 sharesWithdraw = silo1.withdraw(maxAssets, _DEPOSITOR, _DEPOSITOR);

        assertEq(sharesWithdraw, maxShare, "sharesWithdraw == maxShare");

        uint256 balance = IERC20(address(token1)).balanceOf(_DEPOSITOR);
        assertEq(balance, maxAssets, "balance == maxAssets");
    }

    function _maxWithdrawRedeem_withDebt( // solhint-disable-line func-name-mixedcase
        uint128 _assetsToDepositForBorrow,
        uint256 _assetsToBorrow,
        uint256 _time
    ) internal {
        vm.assume(_assetsToDepositForBorrow > 1);
        vm.assume(_assetsToBorrow > 1 && _assetsToBorrow < _assetsToDepositForBorrow / 2);

        _depositForBorrow(_assetsToDepositForBorrow, _DEPOSITOR);
        _deposit(_assetsToBorrow * 2, _BORROWER);
        _borrow(_assetsToBorrow, _BORROWER);

        if (_time > 0) {
            vm.warp(block.timestamp + _time);
        }

        uint256 maxAssets = silo0.maxWithdraw(_BORROWER);
        uint256 maxShare = silo0.maxRedeem(_BORROWER);

        vm.prank(_BORROWER);
        uint256 sharesWithdraw = silo0.withdraw(maxAssets, _BORROWER, _BORROWER);

        assertEq(sharesWithdraw, maxShare, "sharesWithdraw == maxShare");

        uint256 balance = IERC20(address(token0)).balanceOf(_BORROWER);
        assertEq(balance, maxAssets, "balance == maxAssets");
    }

    // solhint-disable-next-line func-name-mixedcase
    function _maxBorrow_noDebt(uint128 _assets, uint128 _collateral, bool _useShares, uint256 _time) internal {
        vm.assume(_assets < _collateral);
        vm.assume(_assets > 3); // only for this test as we have `_assets / 2` for `_BORROWER2`

        _depositForBorrow(_assets, _DEPOSITOR);
        _deposit(_collateral, _BORROWER);
        _deposit(_collateral, _BORROWER2);

        uint256 amountToBorrowFor2 = _assets / 2;

        _borrow(amountToBorrowFor2, _BORROWER2);

        if (_time > 0) {
            vm.warp(block.timestamp + _time);
        }

        uint256 maxBorrowShare = silo1.maxBorrowShares(_BORROWER);
        uint256 maxBorrow = silo1.maxBorrow(_BORROWER);

        vm.assume(maxBorrowShare != 0 && maxBorrow != 0);

        uint256 expectedResult = _useShares ? maxBorrow : maxBorrowShare;

        uint256 result = _useShares
            ? _borrowShares(maxBorrowShare, _BORROWER)
            : _borrow(maxBorrow, _BORROWER);

        assertEq(expectedResult, result, "expectedResult == result");

        uint256 balance = IERC20(address(token1)).balanceOf(_BORROWER);

        assertTrue(balance != 0, "balance != 0");
    }

    // solhint-disable-next-line func-name-mixedcase
    function _maxBorrow_withDebt(uint128 _assets, uint128 _collateral, bool _useShares, uint256 _time) internal {
        vm.assume(_assets < _collateral);
        vm.assume(_assets > 10); // only for this test as we have `_assets / 3` for `_BORROWER2`

        _depositForBorrow(_assets, _DEPOSITOR);
        _deposit(_collateral, _BORROWER);
        _deposit(_collateral, _BORROWER2);

        uint256 amountToBorrowFor = _assets / 3;

        _borrow(amountToBorrowFor, _BORROWER);

        uint256 borrowedBefore = _borrow(amountToBorrowFor, _BORROWER2);

        if (_time > 0) {
            vm.warp(block.timestamp + _time);
        }

        uint256 maxBorrowShare = silo1.maxBorrowShares(_BORROWER2);
        uint256 maxBorrow = silo1.maxBorrow(_BORROWER2);

        vm.assume(maxBorrowShare != 0 && maxBorrow != 0);

        uint256 expectedResult = _useShares ? maxBorrow : maxBorrowShare;

        uint256 result = _useShares
            ? _borrowShares(maxBorrowShare, _BORROWER2)
            : _borrow(maxBorrow, _BORROWER2);

        assertEq(expectedResult, result, "expectedResult == result");

        uint256 balance = IERC20(address(token1)).balanceOf(_BORROWER2);

        assertTrue(balance - borrowedBefore != 0, "balance != 0");
    }

    function _maxReepay( // solhint-disable-line func-name-mixedcase
        uint128 _assetsToDepositForBorrow,
        uint256 _assetsToBorrow,
        bool _useShares,
        uint256 _time
    ) internal {
        vm.assume(_assetsToDepositForBorrow > 1);
        vm.assume(_assetsToBorrow > 1 && _assetsToBorrow < _assetsToDepositForBorrow / 2);

        _depositForBorrow(_assetsToDepositForBorrow, _DEPOSITOR);
        _deposit(_assetsToBorrow * 2, _BORROWER);
        _borrow(_assetsToBorrow, _BORROWER);

        if (_time > 0) {
            vm.warp(block.timestamp + _time);
        }

        uint256 repayShares = silo1.maxRepayShares(_BORROWER);
        uint256 repay = silo1.maxRepay(_BORROWER);

        uint256 epxectedResult = _useShares ? repay: repayShares;

        uint256 result = _useShares
            ? _repayShares(repay, repayShares, _BORROWER)
            : _repay(repay, _BORROWER);

        assertEq(epxectedResult, result, "epxectedResult == result");

        (,,address debtToken) = _siloConfig.getShareTokens(address(silo1));

        assertTrue(
            silo1.isSolvent(_BORROWER),
            string.concat(
                "User is not solved. Debt share token balance: ",
                vm.toString(IERC20(debtToken).balanceOf(_BORROWER))
            )
        );
    }
}
