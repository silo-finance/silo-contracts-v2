// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Math} from "openzeppelin5/utils/math/Math.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {SiloConfigOverride, SiloFixture} from "../../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {DefaultingSiloLogic} from "silo-core/contracts/hooks/defaulting/DefaultingSiloLogic.sol";

import {DummyOracle} from "silo-core/test/foundry/_common/DummyOracle.sol";
import {DefaultingLiquidationAsserts} from "./common/DefaultingLiquidationAsserts.sol";

/*

- anything todo with decimals?


- defaulting should not change protected collateral ratio (rule candidate)


incentive distribution: 
- does everyone can claim? its shares so even 1 wei should be claimable


- fes should be able to withdraw

- if there is no bad debt, asset/share ratio should never go < 1.0

TODO make sure we added EXIT when we can

TODO test with many borrowers

TODO double check same assets with protected - does it increase LTV?

TODO test with setOnDemand(false)

TODO test if tehre is diff when we configure gauge

TODO reentrancy test

*/

/*
FOUNDRY_PROFILE=core_test forge test --ffi --mc DefaultingLiquidationBorrowable -vv

input is often limited to uint48 because of `WithdrawSharesForLendersTooHighForDistribution`
*/
abstract contract DefaultingLiquidationCommon is DefaultingLiquidationAsserts {
    using SiloLensLib for ISilo;

    function setUp() public virtual {
        token0 = new MintableToken(18);
        token1 = new MintableToken(18);

        oracle0 = new DummyOracle(1e18, address(token1)); // 1:1 price

        token0.setOnDemand(true);
        token1.setOnDemand(true);

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        overrides.solvencyOracle0 = address(oracle0);
        overrides.maxLtvOracle0 = address(oracle0);
        overrides.configName = _useConfigName();

        SiloFixture siloFixture = new SiloFixture();

        address hook;
        (siloConfig, silo0, silo1,,, hook) = siloFixture.deploy_local(overrides);

        partialLiquidation = IPartialLiquidation(hook);
        defaulting = IPartialLiquidationByDefaulting(hook);

        (address collateralAsset, address debtAsset) = _getTokens();
        (ISilo collateralSilo, ISilo debtSilo) = _getSilos();

        assertEq(collateralSilo.asset(), collateralAsset, "[crosscheck] asset must much silo asset");
        assertEq(debtSilo.asset(), debtAsset, "[crosscheck] asset must much silo asset");

        vm.label(address(this), "TESTER");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_setup -vv
    */
    function test_defaulting_setup() public {
        _addLiquidity(2);

        // minimal collateral to create position is 2
        assertTrue(
            _createPosition({_borrower: borrower, _collateral: 0, _protected: 2, _maxOut: true}),
            "create position failed"
        );
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_happyPath -vv
    */
    function test_defaulting_happyPath() public virtual;

    /*
    - borrower deposit 1e18 assets, 50% collateral, 50% protected
    - price is 1.02e18 at begin and the drop to 1e18, so at the moment of liquidation is 1:1 so we can easily use collateral/debt
    */
    function _defaulting_happyPath()
        internal
        returns (
            UserState memory collateralState,
            UserState memory debtState,
            SiloState memory collateralSiloState,
            SiloState memory debtSiloState,
            uint256 collateralToLiquidate,
            uint256 debtToRepay
        )
    {
        (ISilo collateralSilo, ISilo debtSilo) = _getSilos();

        _createIncentiveController();

        uint256 assets = 1e18;
        _addLiquidity(assets);

        _setCollateralPrice(1.02e18);

        address protectedUser = makeAddr("protectedUser");
        vm.prank(protectedUser);
        debtSilo.deposit(assets, protectedUser, ISilo.CollateralType.Protected);
        depositors.push(protectedUser);

        // TODO do it with other borrower
        // bool success = _createPosition({_borrower: makeAddr("randomBorrower"), _collateral: assets / 2, _protected: assets / 2, _maxOut: false});
        // assertTrue(success, "create position 1 failed");
        // _addLiquidity(assets);

        bool success =
            _createPosition({_borrower: borrower, _collateral: assets / 2, _protected: assets / 2, _maxOut: true});
        assertTrue(success, "create position failed");

        // DO NOT REMOVE LIQUIDITY, we need to check how much provider loose§

        _setCollateralPrice(1e18); // 2% down

        do {
            vm.warp(block.timestamp + 2 hours);
        } while (!_defaultingPossible(borrower));

        _printLtv(borrower);

        debtSilo.accrueInterest();
        assertGt(_printRevenue(debtSilo), 0, "we need case with fees");

        // _createIncentiveController();

        collateralState = _getUserState(collateralSilo, borrower);
        debtState = _getUserState(debtSilo, borrower);
        collateralSiloState = _getSiloState(collateralSilo);
        debtSiloState = _getSiloState(debtSilo);

        (collateralToLiquidate, debtToRepay,) = partialLiquidation.maxLiquidation(borrower);

        defaulting.liquidationCallByDefaulting(borrower);
        console2.log("AFTER DEFAULTING what happened?");

        token0.setOnDemand(false);
        token1.setOnDemand(false);

        assertTrue(silo0.isSolvent(borrower), "borrower is solvent");

        // // TODO exit
        // _assertEveryoneCanExit();

        // TODO fees should be zero in this case, because we didnt accrue in a middle, do test with accrue interest
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_neverReverts_badDebt_fuzz -vv --fuzz-runs 3333
    */
    /// forge-config: core_test.fuzz.runs=3333
    function test_defaulting_neverReverts_badDebt_fuzz(uint32 _collateral, uint32 _protected, uint32 _warp) public {
        _defaulting_neverReverts_badDebt({
            _borrower: borrower,
            _collateral: _collateral,
            _protected: _protected,
            _warp: _warp
        });
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_neverReverts_badDebt_withOtherBorrowers_fuzz -vv --fuzz-runs 3333
    */
    /// forge-config: core_test.fuzz.runs=3333
    function test_defaulting_neverReverts_badDebt_withOtherBorrowers_fuzz(
        uint32 _collateral,
        uint32 _protected,
        uint32 _warp
    ) public {
        _addLiquidity(Math.max(_collateral, _protected));

        address otherBorrower = makeAddr("otherBorrower");

        bool success = _createPosition({
            _borrower: otherBorrower,
            _collateral: _collateral,
            _protected: _protected,
            _maxOut: false
        });

        vm.assume(success);

        (,, IShareToken debtShareToken) = _getBorrowerShareTokens(otherBorrower);
        (, ISilo debtSilo) = _getSilos();

        uint256 debtBalanceBefore = debtShareToken.balanceOf(otherBorrower);

        _defaulting_neverReverts_badDebt({
            _borrower: borrower,
            _collateral: _collateral,
            _protected: _protected,
            _warp: _warp
        });

        assertEq(
            debtBalanceBefore,
            debtShareToken.balanceOf(otherBorrower),
            "other borrower debt should be the same before and after defaulting"
        );

        debtSilo.repayShares(debtBalanceBefore, otherBorrower);
        assertEq(debtShareToken.balanceOf(otherBorrower), 0, "other borrower should be able fully repay");

        // TODO exit should covver that
        // collateralSilo.redeem(collateralShareToken.balanceOf(otherBorrower), otherBorrower, otherBorrower, ISilo.CollateralType.Collateral);
        // collateralSilo.redeem(protectedShareToken.balanceOf(otherBorrower), otherBorrower, otherBorrower, ISilo.CollateralType.Protected);
    }

    function _defaulting_neverReverts_badDebt(
        address _borrower,
        uint256 _collateral,
        uint256 _protected,
        uint32 _warp
    ) internal {
        _addLiquidity(Math.max(_collateral, _protected));

        bool success =
            _createPosition({_borrower: _borrower, _collateral: _collateral, _protected: _protected, _maxOut: true});

        vm.assume(success);

        // this will help with high interest
        _removeLiquidity();

        uint256 price = 1e18;

        do {
            price -= 0.01e18; // drop price by 1%
            _setCollateralPrice(price);
            vm.warp(block.timestamp + 1 days);
        } while (silo0.getLtv(_borrower) < 1e18);

        vm.warp(block.timestamp + _warp);

        _printLtv(_borrower);
        assertTrue(_defaultingPossible(_borrower), "it should be possible always when bad debt");

        _createIncentiveController();

        _printBalances(silo0, _borrower);
        _printBalances(silo1, _borrower);

        console2.log("\tdefaulting.liquidationCallByDefaulting(_borrower)");

        _printMaxLiquidation(_borrower);

        vm.assume(silo0.getLtv(_borrower) >= 1e18); // position should be in bad debt state

        defaulting.liquidationCallByDefaulting(_borrower);

        _printBalances(silo0, _borrower);
        _printBalances(silo1, _borrower);

        _printLtv(_borrower);

        assertEq(silo0.getLtv(_borrower), 0, "position should be removed");

        _assertNoShareTokens({
            _silo: silo0,
            _user: _borrower,
            _allowForDust: false,
            _msg: "position should be removed on silo0"
        });
        _assertNoShareTokens({
            _silo: silo1,
            _user: _borrower,
            _allowForDust: false,
            _msg: "position should be removed on silo1"
        });

        // we can not assert for silo exit, because defaulting will make share value lower,
        // so there might be users who can not withdraw because convertion to assets will give 0
        // _exitSilo();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_neverReverts_insolvency_fuzz -vv
    */
    function test_defaulting_neverReverts_insolvency_fuzz(uint32 _collateral, uint32 _protected) public {
        _defaulting_neverReverts_insolvency({_borrower: borrower, _collateral: _collateral, _protected: _protected});
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_neverReverts_insolvency_withOtherBorrowers_fuzz -vv
    */
    function test_defaulting_neverReverts_insolvency_withOtherBorrowers_fuzz(uint32 _collateral, uint32 _protected)
        public
    {
        _addLiquidity(Math.max(_collateral, _protected));
        address otherBorrower = makeAddr("otherBorrower");

        bool success = _createPosition({
            _borrower: otherBorrower,
            _collateral: _collateral,
            _protected: _protected,
            _maxOut: false
        });

        vm.assume(success);

        (,, IShareToken debtShareToken) = _getBorrowerShareTokens(otherBorrower);
        (, ISilo debtSilo) = _getSilos();

        uint256 debtBalanceBefore = debtShareToken.balanceOf(otherBorrower);

        _defaulting_neverReverts_insolvency({_borrower: borrower, _collateral: _collateral, _protected: _protected});

        assertEq(
            debtBalanceBefore,
            debtShareToken.balanceOf(otherBorrower),
            "other borrower debt should be the same before and after defaulting"
        );
        debtSilo.repayShares(debtBalanceBefore, otherBorrower);
        assertEq(debtShareToken.balanceOf(otherBorrower), 0, "other borrower should be able fully repay");

        // TODO exit should covver that
        // collateralSilo.redeem(collateralShareToken.balanceOf(otherBorrower), otherBorrower, otherBorrower, ISilo.CollateralType.Collateral);
        // collateralSilo.redeem(protectedShareToken.balanceOf(otherBorrower), otherBorrower, otherBorrower, ISilo.CollateralType.Protected);
    }

    function _defaulting_neverReverts_insolvency(address _borrower, uint256 _collateral, uint256 _protected)
        internal
    {
        _addLiquidity(Math.max(_collateral, _protected));

        bool success =
            _createPosition({_borrower: _borrower, _collateral: _collateral, _protected: _protected, _maxOut: true});

        vm.assume(success);

        // this will help with high interest
        _removeLiquidity();

        _printLtv(_borrower);

        uint256 price = 1e18;

        do {
            price -= 0.001e18; // drop price litle by little, to not create bad debt instantly
            _setCollateralPrice(price);
            vm.warp(block.timestamp + 12 hours);
        } while (!_defaultingPossible(_borrower));

        _createIncentiveController();

        _printBalances(silo0, _borrower);
        _printBalances(silo1, _borrower);

        console2.log("\tdefaulting.liquidationCallByDefaulting(_borrower)");

        _printMaxLiquidation(_borrower);

        vm.assume(!silo0.isSolvent(_borrower)); // position should be insolvent
        vm.assume(silo0.getLtv(_borrower) < 1e18); // position should not be in bad debt state

        defaulting.liquidationCallByDefaulting(_borrower);

        _printBalances(silo0, _borrower);
        _printBalances(silo1, _borrower);

        _printLtv(_borrower);

        // we can not assert for silo exit, because defaulting will make share value lower,
        // so there might be users who can not withdraw because convertion to assets will give 0
        //_exitSilo();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_when_0collateral_oneBorrower -vv
    */
    function test_defaulting_when_0collateral_oneBorrower(uint96 _collateral, uint96 _protected) public {
        _setCollateralPrice(1.3e18); // we need high price at begin for this test, because we need to end up wit 1:1
        _addLiquidity(uint256(_collateral) + _protected);

        (ISilo collateralSilo, ISilo debtSilo) = _getSilos();

        bool success =
            _createPosition({_borrower: borrower, _collateral: _collateral, _protected: _protected, _maxOut: true});
        vm.assume(success);

        // this will help with interest
        _removeLiquidity();
        assertLe(debtSilo.getLiquidity(), 1, "liquidity should be ~0");

        console2.log("AFTER REMOVE LIQUIDITY");

        _setCollateralPrice(1e18);

        do {
            vm.warp(block.timestamp + 10 days);
            // 1.01 because when we do normal liquidation it can be no debt after that
        } while (silo0.getLtv(borrower) < 1.01e18);

        // we need case, where we do not oveflow on interest, so we can apply interest
        // vm.assume(debtSilo.maxRepay(borrower) > repayBefore);
        debtSilo.accrueInterest();
        vm.assume(_printRevenue(debtSilo) > 0); // we need case with fees

        // first do normal liquidation with sTokens, to remove whole collateral,
        // price is set 1:1 so we can use collateral as max debt
        (IShareToken collateralShareToken, IShareToken protectedShareToken, IShareToken debtShareToken) =
            _getBorrowerShareTokens(borrower);
        uint256 collateralPreview =
            collateralSilo.previewRedeem(collateralShareToken.balanceOf(borrower), ISilo.CollateralType.Collateral);
        uint256 protectedPreview =
            collateralSilo.previewRedeem(protectedShareToken.balanceOf(borrower), ISilo.CollateralType.Protected);
        (address collateralToken, address debtToken) = _getTokens();

        // we need to create 0 collateral, +2 should cover full collateral and price is 1:1 so we can use as maxDebt
        partialLiquidation.liquidationCall(
            collateralToken, debtToken, borrower, collateralPreview + protectedPreview + 2, true
        );

        depositors.push(address(this)); // liquidator got shares
        console2.log("AFTER NORMAL LIQUIDATION");

        assertEq(collateralShareToken.balanceOf(borrower), 0, "collateral shares must be 0");
        assertEq(protectedShareToken.balanceOf(borrower), 0, "protected shares must be 0");
        vm.assume(debtShareToken.balanceOf(borrower) != 0); //  we need bad debt

        assertTrue(_defaultingPossible(borrower), "defaulting should be possible even without collateral");

        _createIncentiveController();

        defaulting.liquidationCallByDefaulting(borrower);
        console2.log("AFTER DEFAULTING");

        // NOTE: turns out, even with bad debt collateral not neccessarly is reset

        _printLtv(borrower);

        assertEq(silo0.getLtv(borrower), 0, "position should be removed");

        _assertNoWithdrawableFees(collateralSilo);
        _assertWithdrawableFees(debtSilo);

        // borrower is fully liquidated, so we can exit from both silos
        _assertEveryoneCanExitFromSilo(debtSilo, true);
        // we need to allow for dust, because liquidaor got dust after defaulting
        _assertEveryoneCanExitFromSilo(collateralSilo, true);

        _assertTotalSharesZero(collateralSilo);
        _assertTotalSharesZero(debtSilo);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_when_0collateral_otherBorrower -vv
    */
    function test_defaulting_when_0collateral_otherBorrower(uint96 _collateral, uint96 _protected) public {
        _addLiquidity(uint256(_collateral) + _protected);

        _setCollateralPrice(1.3e18); // we need high price at begin for this test, because we need to end up wit 1:1

        bool success = _createPosition({
            _borrower: makeAddr("otherBorrower"),
            _collateral: _collateral / 3,
            _protected: uint96(uint256(_protected) * 2 / 3),
            _maxOut: false
        });
        vm.assume(success);

        (ISilo collateralSilo, ISilo debtSilo) = _getSilos();

        success = _createPosition({
            _borrower: borrower,
            _collateral: uint96(uint256(_collateral) * 2 / 3),
            _protected: _protected / 3,
            _maxOut: true
        });
        vm.assume(success);

        (IShareToken collateralShareToken, IShareToken protectedShareToken, IShareToken debtShareToken) =
            _getBorrowerShareTokens(borrower);

        // this will help with interest
        _removeLiquidity();

        console2.log("AFTER REMOVE LIQUIDITY");

        _setCollateralPrice(1e18);

        do {
            vm.warp(block.timestamp + 10 days);
            // 1.01 because when we do normal liquidation it can be no debt after that
        } while (silo0.getLtv(borrower) < 1.01e18);

        // we need case, where we do not oveflow on interest, so we can apply interest
        // vm.assume(debtSilo.maxRepay(borrower) > repayBefore);
        debtSilo.accrueInterest();
        vm.assume(_printRevenue(debtSilo) > 0); // we need case with fees

        // this repay should make other liquidation not reset total assets, so everyone can exit
        debtSilo.repayShares(debtShareToken.balanceOf(makeAddr("otherBorrower")), makeAddr("otherBorrower"));

        // first do normal liquidation with sTokens, to remove whole collateral,
        // price is set 1:1 so we can use collateral as max debt
        uint256 collateralPreview =
            collateralSilo.previewRedeem(collateralShareToken.balanceOf(borrower), ISilo.CollateralType.Collateral);
        uint256 protectedPreview =
            collateralSilo.previewRedeem(protectedShareToken.balanceOf(borrower), ISilo.CollateralType.Protected);
        (address collateralToken, address debtToken) = _getTokens();
        // we need to create 0 collateral, +1 should cover full collateral and price is 1:1 so we can use as maxDebt
        partialLiquidation.liquidationCall(
            collateralToken, debtToken, borrower, collateralPreview + protectedPreview + 1, true
        );

        depositors.push(address(this)); // liquidator got shares

        assertEq(collateralShareToken.balanceOf(borrower), 0, "collateral shares must be 0");
        assertEq(protectedShareToken.balanceOf(borrower), 0, "protected shares must be 0");
        vm.assume(debtShareToken.balanceOf(borrower) != 0); // we need bad debt

        console2.log("AFTER NORMAL LIQUIDATION");

        assertTrue(_defaultingPossible(borrower), "defaulting should be possible even without collateral");

        _createIncentiveController();

        defaulting.liquidationCallByDefaulting(borrower);
        console2.log("AFTER DEFAULTING");

        _assertNoWithdrawableFees(collateralSilo);
        _assertWithdrawableFees(debtSilo);

        // borrower is fully liquidated
        _assertEveryoneCanExitFromSilo(debtSilo, true);
        _assertEveryoneCanExitFromSilo(collateralSilo, true);

        _assertTotalSharesZero(collateralSilo);
        _assertTotalSharesZero(debtSilo);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_twice_0collateral -vv
    */
    function test_defaulting_twice_0collateral()
        // uint48 _collateral, uint48 _protected
        public
    {
        (uint48 _collateral, uint48 _protected) = (10, 10);
        _createIncentiveController();

        _setCollateralPrice(1.3e18); // we need high price at begin for this test, because we need to end up wit 1:1
        _addLiquidity(uint256(_collateral) + _protected);

        (ISilo collateralSilo, ISilo debtSilo) = _getSilos();

        bool success =
            _createPosition({_borrower: borrower, _collateral: _collateral, _protected: _protected, _maxOut: true});
        vm.assume(success);

        // this will help with interest
        _removeLiquidity();
        assertLe(debtSilo.getLiquidity(), 1, "liquidity should be ~0");

        console2.log("AFTER REMOVE LIQUIDITY");

        _setCollateralPrice(1e18);

        do {
            vm.warp(block.timestamp + 10 days);
            // 1.01 because when we do normal liquidation it can be no debt after that
        } while (silo0.getLtv(borrower) < 1.5e18);

        // we need case, where we do not oveflow on interest, so we can apply interest
        // vm.assume(debtSilo.maxRepay(borrower) > repayBefore);
        debtSilo.accrueInterest();
        vm.assume(_printRevenue(debtSilo) > 0); // we need case with fees

        // first do normal liquidation with sTokens, to remove whole collateral,
        // price is set 1:1 so we can use collateral as max debt
        (IShareToken collateralShareToken, IShareToken protectedShareToken, IShareToken debtShareToken) =
            _getBorrowerShareTokens(borrower);
        uint256 collateralPreview =
            collateralSilo.previewRedeem(collateralShareToken.balanceOf(borrower), ISilo.CollateralType.Collateral);
        uint256 protectedPreview =
            collateralSilo.previewRedeem(protectedShareToken.balanceOf(borrower), ISilo.CollateralType.Protected);
        // we need to create 0 collateral, +1 should cover full collateral and price is 1:1 so we can use as maxDebt
        defaulting.liquidationCallByDefaulting(borrower, collateralPreview + protectedPreview + 1);

        depositors.push(address(this)); // liquidator got shares

        assertEq(collateralShareToken.balanceOf(borrower), 0, "collateral shares must be 0");
        assertEq(protectedShareToken.balanceOf(borrower), 0, "protected shares must be 0");
        vm.assume(debtShareToken.balanceOf(borrower) != 0); // we need bad debt

        console2.log("AFTER DEFAULTING #1");

        assertTrue(_defaultingPossible(borrower), "defaulting should be possible even without collateral");

        defaulting.liquidationCallByDefaulting(borrower);
        console2.log("AFTER DEFAULTING #2");

        _printLtv(borrower);

        _printBalances(silo0, borrower);
        _printBalances(silo1, makeAddr("lpProvider"));

        assertEq(silo0.getLtv(borrower), 0, "position should be removed");

        _assertNoShareTokens(silo0, borrower, false, "position should be removed on silo0");
        _assertNoShareTokens(silo1, borrower, false, "position should be removed on silo1");

        _assertNoWithdrawableFees(collateralSilo);
        _assertWithdrawableFees(debtSilo);

        collateralSilo.deposit(1e18, makeAddr("anyUser"));
        debtSilo.deposit(2, makeAddr("anyUser2"));
        depositors.push(makeAddr("anyUser"));
        depositors.push(makeAddr("anyUser2"));
        depositors.push(address(this));

        // borrower is fully liquidated
        _assertEveryoneCanExitFromSilo(debtSilo, true);
        _assertEveryoneCanExitFromSilo(collateralSilo, true);

        // we can not assert zero shares ath the end, because
        // few defaulting can cause non-withdawable share dust
        // _assertTotalSharesZero(collateralSilo);
        // _assertTotalSharesZero(debtSilo);
    }

    /*
    everyone should be able to withdraw protected after defaulting liquidation
    TODO echidna candidate

    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_protectedCanBeFullyWithdrawn_fuzz -vv
    */
    /// forge-config: core_test.fuzz.runs = 8888
    function test_defaulting_protectedCanBeFullyWithdrawn_fuzz(
        uint24[] memory _protectedDeposits,
        uint64 _initialPrice,
        uint64 _changePrice,
        uint32 _warp,
        uint96 _collateral,
        uint96 _protected
    ) public {
        (, ISilo debtSilo) = _getSilos();

        for (uint256 i; i < _protectedDeposits.length; i++) {
            address user = makeAddr(string.concat("user", vm.toString(i + 1)));
            vm.prank(user);
            debtSilo.deposit(Math.max(_protectedDeposits[i], 1), user, ISilo.CollateralType.Protected);
        }

        _setCollateralPrice(_initialPrice);
        _addLiquidity(Math.max(_collateral, _protected));

        bool success =
            _createPosition({_borrower: borrower, _collateral: _collateral, _protected: _protected, _maxOut: true});
        vm.assume(success);

        assertGt(silo0.getLtv(borrower), 0, "double check that user does have position");

        _removeLiquidity();

        _setCollateralPrice(_changePrice);

        vm.warp(block.timestamp + _warp);

        _createIncentiveController();

        try defaulting.liquidationCallByDefaulting(borrower) {
            // nothing to do
        } catch {
            // does not matter what happened, user should be able to withdraw protected
        }

        for (uint256 i; i < _protectedDeposits.length; i++) {
            address user = makeAddr(string.concat("user", vm.toString(i + 1)));
            vm.prank(user);
            debtSilo.withdraw(Math.max(_protectedDeposits[i], 1), user, user, ISilo.CollateralType.Protected);
        }
    }

    /*
    if _defaultingPossible() we never revert otherwise we do revert

    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_whenDefaultingPossibleTxDoesNotRevert_badDebt_fuzz -vv
    */
    /// forge-config: core_test.fuzz.runs = 2222
    function test_whenDefaultingPossibleTxDoesNotRevert_badDebt_fuzz(
        uint64 _dropPricePercentage,
        uint32 _warp,
        uint48 _collateral,
        uint48 _protected
    ) public {
        _whenDefaultingPossibleTxDoesNotRevert({
            _dropPricePercentage: _dropPricePercentage,
            _warp: _warp,
            _collateral: _collateral,
            _protected: _protected,
            _badDebtCasesOnly: true
        });
    }

    /*
    if _defaultingPossible() we never revert otherwise we do revert

    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_whenDefaultingPossibleTxDoesNotRevert_notBadDebt_fuzz -vv
    */
    /// forge-config: core_test.fuzz.runs = 8888
    function test_whenDefaultingPossibleTxDoesNotRevert_notBadDebt_fuzz(
        uint64 _dropPricePercentage,
        uint32 _warp,
        uint48 _collateral,
        uint48 _protected
    ) public {
        _addLiquidity(Math.max(_collateral, _protected));

        bool success = _createPosition({
            _borrower: makeAddr("borrower2"),
            _collateral: uint256(_collateral) * 10,
            _protected: uint256(_protected) * 10,
            _maxOut: false
        });

        vm.assume(success);

        _whenDefaultingPossibleTxDoesNotRevert({
            _dropPricePercentage: _dropPricePercentage,
            _warp: _warp,
            _collateral: _collateral,
            _protected: _protected,
            _badDebtCasesOnly: false
        });
    }

    function _whenDefaultingPossibleTxDoesNotRevert(
        uint64 _dropPricePercentage,
        uint32 _warp,
        uint48 _collateral,
        uint48 _protected,
        bool _badDebtCasesOnly
    ) internal {
        uint64 initialPrice = 1e18;
        uint256 changePrice = _calculateNewPrice(initialPrice, -int64(0.001e18 + (_dropPricePercentage % 0.1e18)));

        changePrice = 0.2e18;

        _addLiquidity(Math.max(_collateral, _protected));

        bool success = _createPosition({
            _borrower: borrower,
            _collateral: _collateral,
            _protected: _protected,
            _maxOut: _badDebtCasesOnly
        });

        vm.assume(success);

        if (_badDebtCasesOnly) {
            _removeLiquidity();
            _setCollateralPrice(changePrice);
            vm.assume(!_isOracleThrowing(borrower));
            vm.warp(block.timestamp + _warp);
        } else {
            vm.assume(_printLtv(borrower) < 1e18);
        }

        console2.log("AFTER WARP AND PRICE CHANGE");

        _makeDefaultingPossible(borrower, 0.001e18, 1 hours);

        // if oracle is throwing, we can not test anything
        vm.assume(!_isOracleThrowing(borrower));

        _createIncentiveController();

        if (_badDebtCasesOnly) {
            vm.assume(_printLtv(borrower) >= 1e18);
        } else {
            vm.assume(_printLtv(borrower) < 1e18);
        }

        defaulting.liquidationCallByDefaulting(borrower);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_bothLiquidationsResultsMatch_insolvent_fuzz -vv --fuzz-runs 2345

    use uint64 for collateral and protected because fuzzing was trouble to find cases, 
    reason is incentive uint104 cap

    use only 500 runs because fuzzing for this one is demanding
    */
    /// forge-config: core_test.fuzz.runs = 500
    function test_bothLiquidationsResultsMatch_insolvent_fuzz(
        uint64 _priceDropPercentage,
        uint32 _warp,
        uint48 _collateral,
        uint48 _protected
    ) public virtual {
        vm.assume(_priceDropPercentage > 0.0005e18);

        // 0.5% to 15.5% price drop cap
        int256 dropPercentage = int256(uint256(_priceDropPercentage) % 0.15e18);

        uint256 targetPrice = _calculateNewPrice(uint64(oracle0.price()), -int64(dropPercentage));

        _addLiquidity(Math.max(_collateral, _protected));
        bool success =
            _createPosition({_borrower: borrower, _collateral: _collateral, _protected: _protected, _maxOut: false});

        vm.assume(success);

        // this will help with interest
        _removeLiquidity();
        _setCollateralPrice(targetPrice);
        vm.warp(block.timestamp + _warp);

        // if oracle is throwing, we can not test anything
        vm.assume(!_isOracleThrowing(borrower));

        console2.log("AFTER WARP AND PRICE CHANGE");

        uint256 ltv = _printLtv(borrower);
        vm.assume(ltv < 1e18); // we dont want back debt, in bad debt we reset position

        _createIncentiveController();

        _printLtv(borrower);

        vm.assume(_defaultingPossible(borrower));

        uint256 snapshot = vm.snapshotState();
        console2.log("snapshot taken", snapshot);

        _executeMaxLiquidation(borrower);
        console2.log("regular liquidation done");
        UserState memory userState0 = _getUserState(silo0, borrower);
        UserState memory userState1 = _getUserState(silo1, borrower);

        vm.revertToState(snapshot);
        console2.log("snapshot reverted");

        _executeDefaulting(borrower);
        console2.log("defaulting liquidation done");
        UserState memory userStateAfter0 = _getUserState(silo0, borrower);
        UserState memory userStateAfter1 = _getUserState(silo1, borrower);

        assertEq(userState0.debtShares, userStateAfter0.debtShares, "debt0 shares should be the same");
        assertEq(userState0.protectedShares, userStateAfter0.protectedShares, "protected0 shares should be the same");
        assertEq(
            userState0.colalteralShares, userStateAfter0.colalteralShares, "collateral0 shares should be the same"
        );

        assertEq(userState1.debtShares, userStateAfter1.debtShares, "debt1 shares should be the same");
        assertEq(userState1.protectedShares, userStateAfter1.protectedShares, "protected1 shares should be the same");
        assertEq(
            userState1.colalteralShares, userStateAfter1.colalteralShares, "collateral1 shares should be the same"
        );

        _printLtv(borrower);

        assertTrue(silo0.isSolvent(borrower), "whatever happen user must be solvent");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_delegatecall_whenRepayReverts -vv
    */
    function test_defaulting_delegatecall_whenRepayReverts() public {
        _addLiquidity(1e18);
        bool success = _createPosition({_borrower: borrower, _collateral: 1e18, _protected: 10, _maxOut: true});
        vm.assume(success);

        _makeDefaultingPossible(borrower, 0.001e18, 1 days);

        uint256 ltv = _printLtv(borrower);

        assertTrue(_defaultingPossible(borrower), "explect not solvent ready for defaulting");

        _createIncentiveController();

        (, ISilo debtSilo) = _getSilos();
        (,, IShareToken debtShareToken) = _getBorrowerShareTokens(borrower);
        uint256 debtBalanceBefore = debtShareToken.balanceOf(borrower);

        // mock revert inside repay process to test if whole tx reverts
        vm.mockCallRevert(
            address(siloConfig),
            abi.encodeWithSelector(ISiloConfig.getDebtShareTokenAndAsset.selector, address(debtSilo)),
            abi.encode("repayDidNotWork")
        );

        vm.expectRevert("repayDidNotWork");
        defaulting.liquidationCallByDefaulting(borrower);

        assertEq(ltv, silo0.getLtv(borrower), "ltv should be unchanged because no liquidation happened");
        assertEq(debtBalanceBefore, debtShareToken.balanceOf(borrower), "debt balance should be the same");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_delegatecall_whenDecuctReverts -vv
    */
    function test_defaulting_delegatecall_whenDecuctReverts() public {
        _addLiquidity(1e18);
        bool success = _createPosition({_borrower: borrower, _collateral: 1e18, _protected: 1e18, _maxOut: true});
        vm.assume(success);

        _setCollateralPrice(0.01e18);

        uint256 ltv = _printLtv(borrower);

        assertTrue(ltv > 1e18, "we need bad debt so we can use max repay for mocking call");

        _createIncentiveController();

        (, ISilo debtSilo) = _getSilos();
        (,, IShareToken debtShareToken) = _getBorrowerShareTokens(borrower);
        uint256 debtBalanceBefore = debtShareToken.balanceOf(borrower);

        uint256 maxRepay = debtSilo.maxRepay(borrower);
        console2.log("debtSilo.maxRepay(borrower)", maxRepay);

        // mock revert inside collateral reduction process to test if whole tx reverts
        bytes memory deductDefaultedDebtFromCollateralCalldata =
            abi.encodeWithSelector(DefaultingSiloLogic.deductDefaultedDebtFromCollateral.selector, maxRepay);

        bytes memory callOnBehalfOfSiloCalldata = abi.encodeWithSelector(
            ISilo.callOnBehalfOfSilo.selector,
            address(defaulting.LIQUIDATION_LOGIC()),
            0,
            ISilo.CallType.Delegatecall,
            deductDefaultedDebtFromCollateralCalldata
        );

        vm.mockCallRevert(address(debtSilo), callOnBehalfOfSiloCalldata, abi.encode("deductDidNotWork"));

        vm.expectRevert("deductDidNotWork");
        defaulting.liquidationCallByDefaulting(borrower);

        assertEq(ltv, silo0.getLtv(borrower), "ltv should be unchanged because no liquidation happened");
        assertEq(debtBalanceBefore, debtShareToken.balanceOf(borrower), "debt balance should be the same");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_getKeeperAndLenderSharesSplit_fuzz -vv --fuzz-runs 2345

    we should never generate more shares then borrower has, rounding check
    */
    /// forge-config: core_test.fuzz.runs = 2345
    function test_defaulting_getKeeperAndLenderSharesSplit_fuzz(uint32 _collateral, uint32 _protected, uint32 _warp)
        public
    {
        _setCollateralPrice(1.05e18);

        _addLiquidity(Math.max(_collateral, _protected));

        bool success =
            _createPosition({_borrower: borrower, _collateral: _collateral, _protected: _protected, _maxOut: false});

        vm.assume(success);

        _removeLiquidity();

        vm.warp(block.timestamp + _warp);

        uint256 price = 1e18;
        _setCollateralPrice(price);

        _makeDefaultingPossible(borrower, 0.001e18, 1 hours);

        (IShareToken collateralShareToken, IShareToken protectedShareToken,) = _getBorrowerShareTokens(borrower);

        uint256 collateralSharesBefore = collateralShareToken.balanceOf(borrower);
        uint256 protectedSharesBefore = protectedShareToken.balanceOf(borrower);

        address lpProvider = makeAddr("lpProvider");

        assertEq(
            collateralShareToken.balanceOf(lpProvider),
            0,
            "lpProvider should have 0 collateral shares before liquidation"
        );
        assertEq(
            protectedShareToken.balanceOf(lpProvider),
            0,
            "lpProvider should have 0 protected shares before liquidation"
        );

        _printBalances(silo0, borrower);
        _printBalances(silo1, borrower);

        _printBalances(silo0, lpProvider);
        _printBalances(silo1, lpProvider);

        _createIncentiveController();
        defaulting.liquidationCallByDefaulting(borrower);

        console2.log("AFTER LIQUIDATION");

        vm.prank(lpProvider);
        gauge.claimRewards(lpProvider);

        uint256 collateralRewards = collateralShareToken.balanceOf(lpProvider);
        uint256 protectedRewards = protectedShareToken.balanceOf(lpProvider);

        assertLe(collateralShareToken.balanceOf(address(gauge)), 1, "gauge should have ~0 collateral shares");
        assertLe(protectedShareToken.balanceOf(address(gauge)), 1, "gauge should have ~0 protected shares");

        if (_protected == 0) {
            assertEq(protectedRewards, 0, "no protected rewards if no protected deposit");
            assertEq(protectedShareToken.balanceOf(address(this)), 0, "keeper should have 0 protected shares");
        } else {
            assertGt(protectedRewards, 0, "protected rewards are always somethig after liquidation");
            assertLt(protectedRewards, protectedSharesBefore, "protected rewards are always less, because of fee");
            // keeprs can have 0 or more
        }

        if (_collateral == 0) {
            assertEq(collateralRewards, 0, "no collateral rewards if no collateral deposit");
            assertEq(collateralShareToken.balanceOf(address(this)), 0, "keeper should have 0 collateral shares");
        } else {
            if (_protected == 0) {
                assertGt(collateralRewards, 0, "collateral rewards are always somethig");
            } else {
                // collaterar rewards depends if protected were enough or not
            }

            assertLt(collateralRewards, collateralSharesBefore, "rewards are always less, because of fee");
            // keeprs can have 0 or more
        }
    }

    /*
    bad debt scenario: everybody can exit with the same loss
    */

    /*
    if no bad debt, both liquidations are the same
    */

    /*
    fee is corectly splitted 
    */
}
