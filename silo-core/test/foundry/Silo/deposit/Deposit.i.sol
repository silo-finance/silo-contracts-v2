// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloERC4626Lib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {MintableToken} from "../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

import {console} from "forge-std/console.sol";

/*
    forge test -vv --ffi --mc DepositTest
*/
contract DepositTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    MintableToken weth;
    MintableToken usdc;

    event Deposit(address indexed sender, address indexed owner, uint256 assets, uint256 shares);
    event DepositProtected(address indexed sender, address indexed owner, uint256 assets, uint256 shares);

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        weth = token0;
        usdc = token1;
    }

    /*
    forge test -vv --ffi --mt test_deposit_revertsZeroAssets
    */
    function test_deposit_revertsZeroAssets() public {
        uint256 _assets;
        ISilo.CollateralType _type;
        address depositor = makeAddr("Depositor");

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.deposit(_assets, depositor);

        vm.expectRevert(ISilo.ZeroAssets.selector);
        silo0.deposit(_assets, depositor, _type);
    }

    /*
    forge test -vv --ffi --mt test_deposit_reverts_WrongAssetType
    */
    function test_deposit_reverts_WrongAssetType() public {
        uint256 _assets = 1;
        address depositor = makeAddr("Depositor");

        vm.expectRevert();
        silo0.deposit(_assets, depositor, ISilo.CollateralType(uint8(ISilo.AssetType.Debt)));
    }

    /*
    forge test -vv --ffi --mt test_vault_attack
    */
    function test_vault_attack() public {
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");
        ISiloConfig.ConfigData memory collateral = silo0.config().getConfig(address(silo0));

        _prepareForTheAttack(depositor, borrower);

        console.log("*** Borrow, repay interest and withdraw to break 1:1 share-to-asset ratio for donation attack preparation ***");
        console.log("collateralShareToken.totalSupply(): ", IShareToken(collateral.collateralShareToken).totalSupply());
        console.log("silo0.getCollateralAssets(): ", silo0.getCollateralAssets());

        console.log("*************");
        console.log("*** Main attack starts now: ***");
        
        uint256 depositedForAttack = _doAttack(depositor, 10);
        console.log("*** After 10 steps of deposit silo0.getCollateralAssets() -> withdraw 1 wei ***");
        console.log("collateralShareToken.totalSupply(): ", IShareToken(collateral.collateralShareToken).totalSupply());
        console.log("silo0.getCollateralAssets(): ", silo0.getCollateralAssets());

        depositedForAttack =  depositedForAttack + _doAttack(depositor, 10);
        console.log("*** After +10 steps of deposit silo0.getCollateralAssets() -> withdraw 1 wei ***");
        console.log("collateralShareToken.totalSupply(): ", IShareToken(collateral.collateralShareToken).totalSupply());
        console.log("silo0.getCollateralAssets(): ", silo0.getCollateralAssets());

        depositedForAttack = depositedForAttack + _doAttack(depositor, 40);
        console.log("*** After +40 (log2(10^18) < 60) steps of deposit silo0.getCollateralAssets() -> withdraw 1 wei ***");
        console.log("collateralShareToken.totalSupply(): ", IShareToken(collateral.collateralShareToken).totalSupply());
        console.log("silo0.getCollateralAssets(): ", silo0.getCollateralAssets());
    }

    function _prepareForTheAttack(address _depositor, address _borrower) internal {
        ISiloConfig.ConfigData memory collateral = silo0.config().getConfig(address(silo0));
        (,, address debtShareToken) = siloConfig.getShareTokens(address(silo0));


        console.log("*** Vault is empty initially ***");
        console.log("collateralShareToken.totalSupply(): ", IShareToken(collateral.collateralShareToken).totalSupply());
        console.log("silo0.getCollateralAssets(): ", silo0.getCollateralAssets());
        assertEq(IShareToken(collateral.collateralShareToken).totalSupply(), 0, "shares supply is zero");
        assertEq(silo0.getCollateralAssets(), 0, "no assets deposited");
        uint256 one = 1;

        _makeDeposit(silo0, token0, one, _depositor, ISilo.CollateralType.Collateral);

        console.log("*** 1 share 1 asset ***");
        console.log("collateralShareToken.totalSupply(): ", IShareToken(collateral.collateralShareToken).totalSupply());
        console.log("silo0.getCollateralAssets(): ", silo0.getCollateralAssets());
        assertEq(IShareToken(collateral.collateralShareToken).totalSupply(), one);
        assertEq(silo0.getCollateralAssets(), one);

        _repayLoan(_borrower, 200*one);
        (uint256 borrowerAssets) = silo0.maxWithdraw(_borrower);
        vm.prank(_borrower);
        silo0.withdraw(borrowerAssets, _borrower, _borrower);
        silo0.accrueInterest();
    }

    function _doAttack(address _depositor, uint _steps) internal returns (uint256 deposited) {
        ISiloConfig.ConfigData memory collateral = silo0.config().getConfig(address(silo0));

        for (uint i = 0; i < _steps; i++) {
            uint toDeposit = silo0.getCollateralAssets();
            _makeDeposit(silo0, token0, toDeposit, _depositor, ISilo.CollateralType.Collateral);
            vm.prank(_depositor);
            silo0.withdraw(1, _depositor, _depositor);

            deposited = deposited + toDeposit - 1;
        }
    }

    function _repayLoan(address _borrower, uint _toBorrow) internal {
        uint256 depositAmount = _toBorrow * 12 / 8;
        
        _makeDeposit(silo0, token0, depositAmount, _borrower, ISilo.CollateralType.Collateral);
        vm.prank(_borrower);
        uint shares = silo0.borrowSameAsset(_toBorrow, _borrower, _borrower);

        vm.warp(block.timestamp + 70 days);

        uint256 toRepay = silo0.maxRepay(_borrower);
        // assertTrue(toRepay > _toBorrow);

        vm.prank(_borrower);
        token0.approve(address(silo0), toRepay);

        _mintTokens(token0, toRepay, _borrower);

        vm.prank(_borrower);
        shares = silo0.repay(toRepay, _borrower);
    }

    /*
    forge test -vv --ffi --mt test_deposit_everywhere
    */
    function test_deposit_everywhere() public {
        uint256 assets = 1;
        address depositor = makeAddr("Depositor");

        _makeDeposit(silo0, token0, assets, depositor, ISilo.CollateralType.Collateral);
        _makeDeposit(silo0, token0, assets, depositor, ISilo.CollateralType.Protected);
        _makeDeposit(silo1, token1, assets, depositor, ISilo.CollateralType.Collateral);
        _makeDeposit(silo1, token1, assets, depositor, ISilo.CollateralType.Protected);

        ISiloConfig.ConfigData memory collateral = silo0.config().getConfig(address(silo0));
        ISiloConfig.ConfigData memory debt = silo0.config().getConfig(address(silo1));

        assertEq(token0.balanceOf(address(silo0)), assets * 2);
        assertEq(silo0.getCollateralAssets(), assets);
        assertEq(silo0.getTotalAssetsStorage(AssetTypes.PROTECTED), assets);
        assertEq(silo0.getDebtAssets(), 0);

        assertEq(IShareToken(collateral.collateralShareToken).balanceOf(depositor), assets, "collateral shares");
        assertEq(IShareToken(collateral.protectedShareToken).balanceOf(depositor), assets, "protected shares");

        assertEq(token1.balanceOf(address(silo1)), assets * 2);
        assertEq(silo1.getCollateralAssets(), assets);
        assertEq(silo1.getTotalAssetsStorage(AssetTypes.PROTECTED), assets);
        assertEq(silo1.getDebtAssets(), 0);

        assertEq(IShareToken(debt.collateralShareToken).balanceOf(depositor), assets, "collateral shares (on other silo)");
        assertEq(IShareToken(debt.protectedShareToken).balanceOf(depositor), assets, "protected shares (on other silo)");
    }

    /*
    forge test -vv --ffi --mt test_deposit_withDebt_1token
    */
    function test_deposit_withDebt_1token() public {
        _deposit_withDebt();
    }

    function _deposit_withDebt() internal {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");

        _makeDeposit(silo0, token0, assets, depositor, ISilo.CollateralType.Collateral);
        _makeDeposit(silo0, token0, assets, depositor, ISilo.CollateralType.Protected);
        _makeDeposit(silo1, token1, assets, depositor, ISilo.CollateralType.Collateral);
        _makeDeposit(silo1, token1, assets, depositor, ISilo.CollateralType.Protected);

        uint256 maxBorrow = silo1.maxBorrow(depositor);
        _borrow(maxBorrow, depositor);

        _makeDeposit(silo0, token0, assets, depositor, ISilo.CollateralType.Collateral);
        _makeDeposit(silo0, token0, assets, depositor, ISilo.CollateralType.Protected);
        _makeDeposit(silo1, token1, assets, depositor, ISilo.CollateralType.Collateral);
        _makeDeposit(silo1, token1, assets, depositor, ISilo.CollateralType.Protected);
    }

    /*
    forge test -vv --ffi --mt test_deposit_toWrongSilo
    */
    function test_deposit_toWrongSilo() public {
        uint256 assets = 1;
        address depositor = makeAddr("Depositor");

        vm.prank(depositor);
        token1.approve(address(silo0), assets);

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, silo0, 0, assets)
        );
        vm.prank(depositor);
        silo0.deposit(assets, depositor, ISilo.CollateralType.Collateral);
    }

    /*
    forge test -vv --ffi --mt test_deposit_emitEvents
    */
    function test_deposit_emitEvents() public {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");

        token0.mint(depositor, assets * 2);
        vm.prank(depositor);
        token0.approve(address(silo0), assets * 2);

        vm.expectEmit(true, true, true, true);
        emit Deposit(depositor, depositor, assets, assets);

        vm.prank(depositor);
        silo0.deposit(assets, depositor, ISilo.CollateralType.Collateral);

        vm.expectEmit(true, true, true, true);
        emit DepositProtected(depositor, depositor, assets, assets);

        vm.prank(depositor);
        silo0.deposit(assets, depositor, ISilo.CollateralType.Protected);
    }

    /*
    forge test -vv --ffi --mt test_deposit_withWrongAssetType
    */
    function test_deposit_withWrongAssetType() public {
        uint256 assets = 1e18;
        address depositor = makeAddr("Depositor");

        token0.mint(depositor, assets * 2);
        vm.prank(depositor);
        token0.approve(address(silo0), assets * 2);

        uint8 invalidCollateralType = 3;

        vm.prank(depositor);

        (bool success,) = address(silo0).call(
            abi.encodeWithSelector(
                ISilo.deposit.selector,
                assets,
                depositor,
                invalidCollateralType
            )
        );

        assertFalse(success, "Expect deposit to fail");

        // deposit with correct type

        uint8 collateralType = 1;

        vm.expectEmit(true, true, true, true);
        emit Deposit(depositor, depositor, assets, assets);

        vm.prank(depositor);
        
        (success,) = address(silo0).call(
            abi.encodeWithSelector(
                ISilo.deposit.selector,
                assets,
                depositor,
                collateralType
            )
        );

        assertTrue(success, "Expect deposit to succeed");
    }

    /*
    forge test -vv --ffi --mt test_deposit_totalAssets
    */
    function test_deposit_totalAssets() public {
        _deposit(123, makeAddr("Depositor"));

        assertEq(silo0.totalAssets(), 123, "totalAssets 0");
        assertEq(silo1.totalAssets(), 0, "totalAssets 1");
    }

    /*
    forge test -vv --ffi --mt test_deposit_revert_zeroShares
    */
    function test_deposit_revert_zeroShares_1token() public {
        _deposit_revert_zeroShares();
    }

    function _deposit_revert_zeroShares() private {
        address borrower = makeAddr("borrower");

        _deposit(2 ** 128, borrower);
        _depositForBorrow(2 ** 128, address(2));

        _borrow(2 ** 128 / 2, borrower);

        address anyAddress = makeAddr("any");
        // no interest, so shares are 1:1
        _depositForBorrow(1, anyAddress);

        vm.warp(block.timestamp + 365 days);

        // with interest assets > shares, so we can get zero

        _mintTokens(token1, 1, anyAddress);

        vm.startPrank(anyAddress);
        token1.approve(address(silo1), 1);
        vm.expectRevert(ISilo.ZeroShares.selector);
        silo1.deposit(1, anyAddress);
        vm.stopPrank();
    }
}
