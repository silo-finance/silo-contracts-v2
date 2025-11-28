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

*/

/*
FOUNDRY_PROFILE=core_test forge test --ffi --mc DefaultingLiquidationBorrowable -vv
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

        (,, IShareToken debtShareToken) = _getShareTokens(otherBorrower);
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

        _assertNoShareTokens({_silo: silo0, _user: _borrower, _allowForDust: false});
        _assertNoShareTokens({_silo: silo1, _user: _borrower, _allowForDust: false});

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

        (,, IShareToken debtShareToken) = _getShareTokens(otherBorrower);
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
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_neverReverts_0collateral -vv
    */
    function test_defaulting_neverReverts_0collateral(uint96 _collateral, uint96 _protected) public {
        _setCollateralPrice(1.3e18); // we need high price at begin for this test, because we need to end up wit 1:1
        _addLiquidity(uint256(_collateral) + _protected);

        bool success =
            _createPosition({_borrower: borrower, _collateral: _collateral, _protected: _protected, _maxOut: true});
        vm.assume(success);

        (ISilo collateralSilo, ISilo debtSilo) = _getSilos();

        // this will help with interest
        _removeLiquidity();
        assertLe(debtSilo.getLiquidity(), 1, "liquidity should be ~0");

        // uint256 repayBefore = debtSilo.maxRepay(borrower);

        _setCollateralPrice(1e18);

        do {
            vm.warp(block.timestamp + 10 days);
        } while (silo0.getLtv(borrower) < 1.01e18); // 1.01 because when we do normla liquidation +2 it can be no debt after that

        _printLtv(borrower);
        // we need case, where we do not oveflow on interest, so we can apply interest
        // vm.assume(debtSilo.maxRepay(borrower) > repayBefore);
        debtSilo.accrueInterest();
        vm.assume(_printRevenue(debtSilo) > 0); // we need case with fees

        // first do normal liquidation with sTokens, to remove whole collateral,
        // price is set 1:1 so we can use collateral as max debt
        (uint256 collateralToLiquidate,,) = partialLiquidation.maxLiquidation(borrower);
        (address collateralAsset, address debtAsset) = _getTokens();
        // +2 to make sure we will get all the shares
        partialLiquidation.liquidationCall(collateralAsset, debtAsset, borrower, collateralToLiquidate + 2, true);

        console2.log("AFTER NORMAL LIQUIDATION");
        assertEq(silo0.getLtv(borrower), type(uint256).max, "ltv must be max if we liquidate all collateral");

        (IShareToken collateralShareToken, IShareToken protectedShareToken,) = _getShareTokens(borrower);
        assertEq(collateralShareToken.balanceOf(borrower), 0, "collateral shares must be 0");
        assertEq(protectedShareToken.balanceOf(borrower), 0, "protected shares must be 0");

        assertTrue(_defaultingPossible(borrower), "defaulting should be possible even without collateral");

        _createIncentiveController();

        defaulting.liquidationCallByDefaulting(borrower);
        console2.log("AFTER DEFAULTING");

        _printLtv(borrower);

        assertEq(silo0.getLtv(borrower), 0, "position should be removed");

        _assertNoShareTokens(silo0, borrower);
        _assertNoShareTokens(silo1, borrower);

        _assertNoWithdrawableFees(collateralSilo);
        _assertWithdrawableFees(debtSilo);

        // TODO exit
        _assertEveryoneCanExit();

        // TODO fees should be zero in this case, because we didnt accrue in a middle, do test with accrue interest
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
    TODO found a case when maxBorrow > 0 but borrow fails, because borrow value is 0.

    if _defaultingPossible() we never revert otherwise we do revert

    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_whenDefaultingPossibleTxDoesNotRevert_badDebt_fuzz -vv
    */
    /// forge-config: core_test.fuzz.runs = 8888
    function test_whenDefaultingPossibleTxDoesNotRevert_badDebt_fuzz(
        uint64 _initialPrice,
        uint64 _changePrice,
        uint32 _warp,
        uint96 _collateral,
        uint96 _protected
    ) public {
        _whenDefaultingPossibleTxDoesNotRevert(_initialPrice, _changePrice, _warp, _collateral, _protected, true);
    }

    /*
    TODO found a case when maxBorrow > 0 but borrow fails, because borrow value is 0.

    if _defaultingPossible() we never revert otherwise we do revert

    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_whenDefaultingPossibleTxDoesNotRevert_notBadDebt_fuzz -vv
    */
    /// forge-config: core_test.fuzz.runs = 8888
    function test_whenDefaultingPossibleTxDoesNotRevert_notBadDebt_fuzz()
        // uint64 _initialPrice,
        // uint64 _changePrice,
        // uint32 _warp,
        // uint96 _collateral,
        // uint96 _protected
        public
    {
        (uint64 _initialPrice, uint64 _changePrice, uint32 _warp, uint96 _collateral, uint96 _protected) =
            (1220675810644933940, 12095630249335940, 3116951, 2963863702, 763645);

        _addLiquidity(Math.max(_collateral, _protected));

        bool success = _createPosition({
            _borrower: makeAddr("borrower2"),
            _collateral: _collateral * 10,
            _protected: _protected * 10,
            _maxOut: false
        });

        vm.assume(success);

        _whenDefaultingPossibleTxDoesNotRevert(_initialPrice, _changePrice, _warp, _collateral, _protected, false);
    }

    function _whenDefaultingPossibleTxDoesNotRevert(
        uint64 _initialPrice,
        uint64 _changePrice,
        uint32 _warp,
        uint96 _collateral,
        uint96 _protected,
        bool _badDebtCasesOnly
    ) internal {
        // 1000x for price movement is more than enough
        vm.assume(_initialPrice > 1e15 && _initialPrice < 1000e18);
        vm.assume(_changePrice > 1e15 && _changePrice < 1000e18);

        //debug use higher numbers
        // TODO we have a lot of issues with small numbers
        // vm.assume(_collateral > 100);
        // vm.assume(_protected > 100);

        _setCollateralPrice(_initialPrice);

        bool success =
            _createPosition({_borrower: borrower, _collateral: _collateral, _protected: _protected, _maxOut: false});

        vm.assume(success);

        _printBalances(silo0, borrower);
        _printBalances(silo1, borrower);

        assertGt(silo0.getLtv(borrower), 0, "double check that user does have position");

        // this will help with interest
        _removeLiquidity();

        _setCollateralPrice(_changePrice);

        vm.warp(block.timestamp + _warp);

        // if oracle is throwing, we can not test anything
        vm.assume(!_isOracleThrowing(borrower));

        console2.log("AFTER WARP AND PRICE CHANGE");

        uint256 ltv = _printLtv(borrower);

        if (_badDebtCasesOnly) vm.assume(ltv >= 1e18);
        else vm.assume(ltv < 1e18);

        _createIncentiveController();

        bool defaultingPossible = _defaultingPossible(borrower);

        _printLtv(makeAddr("borrower2"));

        if (!defaultingPossible) vm.expectRevert(IPartialLiquidation.UserIsSolvent.selector);
        defaulting.liquidationCallByDefaulting(borrower);
        // _executeMaxLiquidation(borrower); // DEBUG TODO

        console2.log("AFTER DEFAULTING");

        _printLtv(makeAddr("borrower2"));

        _printBalances(silo0, borrower);
        _printBalances(silo1, borrower);

        _printLtv(borrower);

        if (defaultingPossible && _badDebtCasesOnly) {
            assertTrue(silo0.isSolvent(borrower), "whatever happen user must be solvent");
        }

        if (defaultingPossible && !_badDebtCasesOnly) {
            assertTrue(silo0.isSolvent(borrower), "whatever happen user must be solvent ???");

            // for tiny numbers, we can find case where user is still insolvent.
            // for such case we allow for 150% LTV (exact value) because

            if (!silo0.isSolvent(borrower)) {
                ltv = _printLtv(borrower);
                // eg 3 collatera land 3 debt will give us 150% LTV
                // TODO not sure why this is happening
                assertLt(ltv, 2.5e18, "because of rounding error we allow for such cases");
            }

            // assertTrue(silo0.isSolvent(borrower), "whatever happen user must be solvent");
        }
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_bothLiquidationsResultsMatch_insolvent_fuzz -vv

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
        // vm.assume(_collateral == 0); // DEBUG
        // _protected += _collateral;
        _protected = 0;

        // (uint64 _priceDropPercentage,
        // uint32 _warp,
        // uint48 _collateral,
        // uint48 _protected) = (899657688608099926, 43909, 0, 29);
        uint64 initialPrice = 1e18;
        vm.assume(_priceDropPercentage > 0.0005e18);

        // 0.5% to 15.5% price drop cap
        int256 dropPercentage = int256(uint256(_priceDropPercentage) % 0.15e18);
        // emit log_named_decimal_int("dropPercentage [%]", dropPercentage, 16);
        // emit log_named_decimal_uint("calculateNewPrice", _calculateNewPrice(initialPrice, -int64(dropPercentage)), 18);

        uint256 targetPrice = _calculateNewPrice(initialPrice, -int64(dropPercentage));

        _setCollateralPrice(initialPrice);

        bool success =
            _createPosition({_borrower: borrower, _collateral: _collateral, _protected: _protected, _maxOut: false});

        vm.assume(success);

        // _printBalances(silo0, borrower);
        // _printBalances(silo1, borrower);

        assertGt(silo0.getLtv(borrower), 0, "double check that user does have position");

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

        // TODO make separate test just to see, if whatever happen user will be solvent?
        // assertTrue(silo0.isSolvent(borrower), "whatever happen user must be solvent");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_delegatecall_whenRepayReverts -vv --mc DefaultingLiquidationTwo0Test
    */
    function test_defaulting_delegatecall_whenRepayReverts() public {
        _setCollateralPrice(100e18);
        bool success = _createPosition({_borrower: borrower, _collateral: 10, _protected: 10, _maxOut: true});
        vm.assume(success);

        _setCollateralPrice(1e18);
        _removeLiquidity();

        vm.warp(block.timestamp + 10 days);

        uint256 ltv = _printLtv(borrower);

        assertTrue(_defaultingPossible(borrower), "explect not solvent ready for defaulting");

        _createIncentiveController();

        (, ISilo debtSilo) = _getSilos();

        // mock revert inside repay process to test if whole tx reverts
        vm.mockCallRevert(
            address(siloConfig),
            abi.encodeWithSelector(ISiloConfig.getDebtShareTokenAndAsset.selector, address(debtSilo)),
            abi.encode("repayDidNotWork")
        );

        vm.expectRevert("repayDidNotWork");
        defaulting.liquidationCallByDefaulting(borrower);

        assertEq(ltv, silo0.getLtv(borrower), "ltv should be unchanged because no liquidation happened");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_delegatecall_whenDecuctReverts -vv
    */
    function test_defaulting_delegatecall_whenDecuctReverts() public {
        _setCollateralPrice(100e18);
        bool success = _createPosition({_borrower: borrower, _collateral: 10, _protected: 10, _maxOut: true});
        vm.assume(success);

        _setCollateralPrice(1e18);
        _removeLiquidity();

        vm.warp(block.timestamp + 10 days);

        uint256 ltv = _printLtv(borrower);

        assertTrue(_defaultingPossible(borrower), "explect not solvent ready for defaulting");

        _createIncentiveController();

        (ISilo collateralSilo, ISilo debtSilo) = _getSilos();

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

        vm.mockCallRevert(address(collateralSilo), callOnBehalfOfSiloCalldata, abi.encode("deductDidNotWork"));

        vm.expectRevert("deductDidNotWork");
        defaulting.liquidationCallByDefaulting(borrower);

        assertEq(ltv, silo0.getLtv(borrower), "ltv should be unchanged because no liquidation happened");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_getKeeperAndLenderSharesSplit_withdrawable_fuzz -vv

    we should never generate more shares then borrower has, rounding check
    */
    /// forge-config: core_test.fuzz.runs = 8888
    function test_getKeeperAndLenderSharesSplit_withdrawable_fuzz(uint32 _collateral, uint32 _protected) public {
        _setCollateralPrice(2e18);

        bool success =
            _createPosition({_borrower: borrower, _collateral: _collateral, _protected: _protected, _maxOut: false});

        vm.assume(success);

        _removeLiquidity();

        uint256 warp = 1 days;
        vm.warp(block.timestamp + warp);
        _setCollateralPrice(1e18);

        vm.assume(_defaultingPossible(borrower));

        (IShareToken collateralShareToken, IShareToken protectedShareToken,) = _getShareTokens(borrower);

        uint256 collateralSharesBefore = collateralShareToken.balanceOf(borrower);
        uint256 protectedSharesBefore = protectedShareToken.balanceOf(borrower);

        (ISilo collateralSilo,) = _getSilos();

        uint256 collateralPreview =
            collateralSilo.previewRedeem(collateralSharesBefore, ISilo.CollateralType.Collateral);

        uint256 protectedPreview = collateralSilo.previewRedeem(protectedSharesBefore, ISilo.CollateralType.Protected);

        // if any of collateral is withdrawable, tx can not revert
        // at the same time we are sure, rounding can not generate more shares then borrower has initially
        vm.assume(collateralPreview > 0 || protectedPreview > 0);

        _createIncentiveController();
        defaulting.liquidationCallByDefaulting(borrower);
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
