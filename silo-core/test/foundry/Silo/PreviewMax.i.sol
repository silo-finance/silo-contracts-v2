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

import {console} from "forge-std/console.sol";

// FOUNDRY_PROFILE=core forge test -vv --ffi --mc PreviewMaxTest
contract PreviewMaxTest is SiloLittleHelper, Test {
    ISiloConfig internal _siloConfig;

    // solhint-disable var-name-mixedcase
    address immutable internal _DEPOSITOR;
    address immutable internal _BORROWER;
    // solhint-disable-enable var-name-mixedcase

    constructor() {
        _DEPOSITOR = makeAddr("Depositor");
        _BORROWER = makeAddr("Borrower");
    }

    function setUp() public {
        _siloConfig = _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_NO_LTV_SILO);
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxWithdrawRedeem_fuzz
    // solhint-disable-next-line func-name-mixedcase
    function test_maxWithdrawRedeem_fuzz(
        uint256 _assetsToDepositForBorrow,
        uint256 _assetsToDepositAsCollateral,
        uint256 _assetsToBorrow
    ) public {
        vm.assume(_assetsToDepositForBorrow > 1);
        vm.assume(_assetsToBorrow > 1 && _assetsToBorrow < _assetsToDepositForBorrow);
        vm.assume(_assetsToDepositAsCollateral > 1 && _assetsToDepositAsCollateral > _assetsToBorrow);

        _depositForBorrow(_assetsToDepositForBorrow, _DEPOSITOR);
        _deposit(_assetsToDepositAsCollateral, _BORROWER);
        _borrow(_assetsToBorrow, _BORROWER);

        uint256 maxAssets = silo1.maxWithdraw(_DEPOSITOR);
        uint256 maxShare = silo1.maxRedeem(_DEPOSITOR);

        vm.prank(_DEPOSITOR);
        uint256 sharesWithdraw = silo1.withdraw(maxAssets, _DEPOSITOR, _DEPOSITOR);

        assertEq(sharesWithdraw, maxShare, "sharesWithdraw == maxShare");
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxFlashLoan_fuzz
    // solhint-disable-next-line func-name-mixedcase
    function test_maxFlashLoan_fuzz(
        uint256 _assetsToDepositForBorrow,
        uint256 _assetsToDepositAsCollateral,
        uint256 _assetsToBorrow
    ) public {
        vm.assume(_assetsToDepositForBorrow < type(uint128).max);
        vm.assume(_assetsToDepositForBorrow > 1);
        vm.assume(_assetsToBorrow > 1 && _assetsToBorrow < _assetsToDepositForBorrow);
        vm.assume(_assetsToDepositAsCollateral > 1 && _assetsToDepositAsCollateral > _assetsToBorrow);

        _depositForBorrow(_assetsToDepositForBorrow, _DEPOSITOR);
        _deposit(_assetsToDepositAsCollateral, _BORROWER);
        _borrow(_assetsToBorrow, _BORROWER);

        uint256 maxFlashLoan = silo1.maxFlashLoan(address(token1));

        FlasLoanTakerMock flasLoanTakerMock = new FlasLoanTakerMock();

        uint256 fee = silo1.flashFee(address(token1), maxFlashLoan);

        _mintTokens(token1, fee, address(flasLoanTakerMock));

        flasLoanTakerMock.takeFlashLoan(silo1, address(token1), maxFlashLoan);
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxBorrow_fuzz
    // solhint-disable-next-line func-name-mixedcase
    function test_maxBorrow_fuzz(uint128 _assets, bool _useShares) public {
        uint256 assetsOrSharesToBorrow = _assets / 10 + (_assets % 2); // keep even/odd
        vm.assume(assetsOrSharesToBorrow < _assets);

        // can be 0 if _assets < 10
        if (assetsOrSharesToBorrow == 0) {
            _assets = 3;
            assetsOrSharesToBorrow = 1;
        }

        _depositForBorrow(_assets, _DEPOSITOR);
        _deposit(_assets, _BORROWER);

        uint256 max = _useShares ? silo1.maxBorrowShares(_BORROWER) : silo1.maxBorrow(_BORROWER);

        uint256 result = _useShares
            ? _borrow(assetsOrSharesToBorrow, _BORROWER)
            : _borrowShares(assetsOrSharesToBorrow, _BORROWER);

        assertEq(assetsOrSharesToBorrow, result, "assetsOrSharesToBorrow == result");
        assertEq(max, _assets, "max == _assets");
    }

    // FOUNDRY_PROFILE=core forge test -vvv --ffi --mt test_maxReepay_fuzz
    // solhint-disable-next-line func-name-mixedcase
    function test_maxReepay_fuzz(
        uint256 _assetsToDepositForBorrow,
        uint256 _assetsToDepositAsCollateral,
        uint256 _assetsToBorrow,
        bool _useShares
    ) public {
        vm.assume(_assetsToDepositForBorrow > 1);
        vm.assume(_assetsToBorrow > 1 && _assetsToBorrow < _assetsToDepositForBorrow);
        vm.assume(_assetsToDepositAsCollateral > 1 && _assetsToDepositAsCollateral > _assetsToBorrow);
        vm.assume(_assetsToBorrow < type(uint128).max);

        _depositForBorrow(_assetsToDepositForBorrow, _DEPOSITOR);
        _deposit(_assetsToDepositAsCollateral, _BORROWER);
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
        uint256 assetsOrSharesToBorrow = 251;
        uint256 _assets = 2516;

        _depositForBorrow(_assets, _DEPOSITOR);
        _deposit(_assets, _BORROWER);

        uint256 max = _useShares ? silo1.maxBorrowShares(_BORROWER) : silo1.maxBorrow(_BORROWER);
        uint256 result = _useShares ? _borrow(assetsOrSharesToBorrow, _BORROWER) : _borrowShares(assetsOrSharesToBorrow, _BORROWER);

        assertEq(max, _assets, "max == _assets");
        assertEq(assetsOrSharesToBorrow, result, "assetsOrSharesToBorrow == result");
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

        console.log("maxAssets", maxAssets);
        console.log("maxShare", maxShare);
        console.log("liquidity", token1.balanceOf(address(silo1)));

        vm.prank(_DEPOSITOR);
        uint256 sharesWithdraw = silo1.withdraw(maxAssets, _DEPOSITOR, _DEPOSITOR);

        assertEq(sharesWithdraw, maxShare, "sharesWithdraw == maxShare");
    }
}
