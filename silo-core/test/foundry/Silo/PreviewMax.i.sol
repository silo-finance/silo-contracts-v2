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

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxWithdrawRedeem_noDebt_fuzz
    /// forge-config: core.fuzz.runs = 10000
    function test_maxWithdrawRedeem_noDebt_fuzz( // solhint-disable-line func-name-mixedcase
        uint128 _assetsToDepositForBorrow,
        uint256 _assetsToBorrow
    ) public {
        vm.assume(_assetsToDepositForBorrow > 1);
        vm.assume(_assetsToBorrow > 1 && _assetsToBorrow < _assetsToDepositForBorrow / 2);

        _depositForBorrow(_assetsToDepositForBorrow, _DEPOSITOR);
        _deposit(_assetsToBorrow * 2, _BORROWER);
        _borrow(_assetsToBorrow, _BORROWER);

        uint256 maxAssets = silo1.maxWithdraw(_DEPOSITOR);
        uint256 maxShare = silo1.maxRedeem(_DEPOSITOR);

        vm.prank(_DEPOSITOR);
        uint256 sharesWithdraw = silo1.withdraw(maxAssets, _DEPOSITOR, _DEPOSITOR);

        assertEq(sharesWithdraw, maxShare, "sharesWithdraw == maxShare");

        uint256 balance = IERC20(address(token1)).balanceOf(_DEPOSITOR);
        assertEq(balance, maxAssets, "balance == maxAssets");
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxWithdrawRedeem_withDebt_fuzz
    /// forge-config: core.fuzz.runs = 10000
    function test_maxWithdrawRedeem_withDebt_fuzz( // solhint-disable-line func-name-mixedcase
        uint128 _assetsToDepositForBorrow,
        uint256 _assetsToBorrow
    ) public {
        vm.assume(_assetsToDepositForBorrow > 1);
        vm.assume(_assetsToBorrow > 1 && _assetsToBorrow < _assetsToDepositForBorrow / 2);

        _depositForBorrow(_assetsToDepositForBorrow, _DEPOSITOR);
        _deposit(_assetsToBorrow * 2, _BORROWER);
        _borrow(_assetsToBorrow, _BORROWER);

        uint256 maxAssets = silo0.maxWithdraw(_BORROWER);
        uint256 maxShare = silo0.maxRedeem(_BORROWER);

        vm.prank(_BORROWER);
        uint256 sharesWithdraw = silo0.withdraw(maxAssets, _BORROWER, _BORROWER);

        assertEq(sharesWithdraw, maxShare, "sharesWithdraw == maxShare");

        uint256 balance = IERC20(address(token0)).balanceOf(_BORROWER);
        assertEq(balance, maxAssets, "balance == maxAssets");
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

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxBorrow_noDebt_fuzz
    /// forge-config: core.fuzz.runs = 10000
    // solhint-disable-next-line func-name-mixedcase
    function test_maxBorrow_noDebt_fuzz(uint128 _assets, uint128 _collateral, bool _useShares) public {
        vm.assume(_assets < _collateral);
        vm.assume(_assets > 3); // only for this test as we have `_assets / 2` for `_BORROWER2`

        _depositForBorrow(_assets, _DEPOSITOR);
        _deposit(_collateral, _BORROWER);
        _deposit(_collateral, _BORROWER2);

        uint256 amountToBorrowFor2 = _assets / 2;

        _borrow(amountToBorrowFor2, _BORROWER2);

        uint256 max = _useShares ? silo1.maxBorrowShares(_BORROWER) : silo1.maxBorrow(_BORROWER);

        uint256 result = _useShares
            ? _borrowShares(max, _BORROWER)
            : _borrow(max, _BORROWER);

        assertEq(max, result, "max == result");

        uint256 balance = IERC20(address(token1)).balanceOf(_BORROWER);

        assertEq(balance, max, "balance == max");
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxBorrow_withDebt_fuzz
    /// forge-config: core.fuzz.runs = 10000
    // solhint-disable-next-line func-name-mixedcase
    function test_maxBorrow_withDebt_fuzz(uint128 _assets, uint128 _collateral, bool _useShares) public {
        vm.assume(_assets < _collateral);
        vm.assume(_assets > 3); // only for this test as we have `_assets / 2` for `_BORROWER2`

        _depositForBorrow(_assets, _DEPOSITOR);
        _deposit(_collateral, _BORROWER);
        _deposit(_collateral, _BORROWER2);

        uint256 amountToBorrowFor = _assets / 3;

        _borrow(amountToBorrowFor, _BORROWER);

        uint256 borrowedBefore = _borrow(amountToBorrowFor, _BORROWER2);

        uint256 max = _useShares ? silo1.maxBorrowShares(_BORROWER2) : silo1.maxBorrow(_BORROWER2);

        uint256 result = _useShares
            ? _borrowShares(max, _BORROWER2)
            : _borrow(max, _BORROWER2);

        assertEq(max, result, "max == result");

        uint256 balance = IERC20(address(token1)).balanceOf(_BORROWER2);

        assertEq(balance - borrowedBefore, max, "balance == max");
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxReepay_fuzz
    /// forge-config: core.fuzz.runs = 10000
    function test_maxReepay_fuzz( // solhint-disable-line func-name-mixedcase
        uint128 _assetsToDepositForBorrow,
        uint256 _assetsToBorrow,
        bool _useShares
    ) public {
        vm.assume(_assetsToDepositForBorrow > 1);
        vm.assume(_assetsToBorrow > 1 && _assetsToBorrow < _assetsToDepositForBorrow / 2);

        _depositForBorrow(_assetsToDepositForBorrow, _DEPOSITOR);
        _deposit(_assetsToBorrow * 2, _BORROWER);
        _borrow(_assetsToBorrow, _BORROWER);

        uint256 maxRepay = _useShares ? silo1.maxRepayShares(_BORROWER) : silo1.maxRepay(_BORROWER);

        uint256 result = _useShares
            ? _repay(maxRepay, _BORROWER)
            : _repayShares(maxRepay, maxRepay, _BORROWER);

        assertEq(maxRepay, result, "maxRepay == result");
        assertEq(maxRepay, _assetsToBorrow, "maxRepay == _assetsToBorrow");

        (,,address debtToken) = _siloConfig.getShareTokens(address(silo1));

        assertTrue(
            silo1.isSolvent(_BORROWER),
            string.concat(
                "User is not solved. Debt share token balance: ",
                vm.toString(IERC20(debtToken).balanceOf(_BORROWER))
            )
        );
    }


    // DEBUGGING


    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxBorrow_debug
    // solhint-disable-next-line func-name-mixedcase
    function test_maxBorrow_debug() public {
        bool _useShares = false;
        uint256 _assets = 2516;
        uint256 _collateral = 3000;

        _depositForBorrow(_assets, _DEPOSITOR);
        _deposit(_collateral, _BORROWER);
        _deposit(_collateral, _BORROWER2);

        uint256 amountToBorrowFor2 = _assets / 2;

        _borrow(amountToBorrowFor2, _BORROWER2);

        uint256 max = _useShares ? silo1.maxBorrowShares(_BORROWER) : silo1.maxBorrow(_BORROWER);
        uint256 result = _useShares ? _borrowShares(max, _BORROWER) : _borrow(max, _BORROWER);

        assertEq(max, result, "max == result");

        uint256 balance = IERC20(address(token1)).balanceOf(_BORROWER);

        assertEq(balance, max, "balance == max");
    }


    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxFlashLoan_debug
    // solhint-disable-next-line func-name-mixedcase
    function test_maxFlashLoan_debug() public {
        uint256 _assetsToDepositForBorrow = 28812946819072445023350786;
        uint256 _assetsToDepositAsCollateral = 28812946819072445023350786;
        uint256 _assetsToBorrow = 2;

        FlasLoanTakerMock flasLoanTakerMock = new FlasLoanTakerMock();

        _depositForBorrow(_assetsToDepositForBorrow, _DEPOSITOR);
        _deposit(_assetsToDepositAsCollateral, _BORROWER);
        _borrow(_assetsToBorrow, _BORROWER);

        uint256 maxFlashLoan = silo1.maxFlashLoan(address(token1));

        uint256 fee = silo1.flashFee(address(token1), maxFlashLoan);

        _mintTokens(token1, fee, address(flasLoanTakerMock));

        flasLoanTakerMock.takeFlashLoan(silo1, address(token1), maxFlashLoan);
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxWithdrawRedeem_for_debug
    // solhint-disable-next-line func-name-mixedcase
    function test_maxWithdrawRedeem_for_debug() public {
        uint256 _assetsToDepositForBorrow = 28812946819072445023350786;
        uint256 _assetsToDepositAsCollateral = 28812946819072445023350786;
        uint256 _assetsToBorrow = 2;

        _depositForBorrow(_assetsToDepositForBorrow, _DEPOSITOR);
        _deposit(_assetsToDepositAsCollateral, _BORROWER);
        _borrow(_assetsToBorrow, _BORROWER);

        uint256 maxAssets = silo1.maxWithdraw(_DEPOSITOR);
        uint256 maxShare = silo1.maxRedeem(_DEPOSITOR);

        vm.prank(_DEPOSITOR);
        uint256 sharesWithdraw = silo1.withdraw(maxAssets, _DEPOSITOR, _DEPOSITOR);

        assertEq(sharesWithdraw, maxShare, "sharesWithdraw == maxShare");
    }
}
