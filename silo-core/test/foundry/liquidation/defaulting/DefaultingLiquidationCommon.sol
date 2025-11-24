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

- should work exactly the same for same asset positions, that's why we have 4 cases

- anything todo with decimals?


defaulting should not change protected collateral ratio

delay should be tested

should work for both collaterals (collateral and protected) in same way




incentive distribution: 
- does everyone can claim? its shares so even 1 wei should be claimable


- fes should be able to withdraw

- if there is no bad debt, asset/share ratio should never go < 1.0

add test taht are checking numbers: how much we repay, how mych debt reduced, collatera reduced

TODO make sure we added EXIT when we can

TODO test with many borrowers

TODO double check same assets with protected - does it increase LTV?

TODO test with setOnDemand(false)

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
        _setCollateralPrice(3e18);
        // minimal collateral to create position is 2
        assertTrue(_createPosition({_borrower: borrower, _collateral: 0, _protected: 2, _maxOut: true}));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_neverReverts_fuzz -vv
    */
    /// forge-config: core_test.fuzz.runs = 8888
    function test_defaulting_neverReverts_fuzz(uint32 _collateral, uint32 _protected) public {
        _defaulting_neverReverts_badDebtScenario(borrower, _collateral, _protected);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_neverReverts_withOtherBorrowers_fuzz -vv
    */
    /// forge-config: core_test.fuzz.runs = 8888
    function test_defaulting_neverReverts_withOtherBorrowers_fuzz(uint32 _collateral, uint32 _protected) public {
        bool success = _createPosition({
            _borrower: makeAddr("otherBorrower"),
            _collateral: _collateral,
            _protected: _protected,
            _maxOut: true
        });

        vm.assume(success);

        _defaulting_neverReverts_badDebtScenario(borrower, _collateral, _protected);

        // other borrower should be able to repay and withdraw TODO
    }

    function _defaulting_neverReverts_badDebtScenario(address _borrower, uint256 _collateral, uint256 _protected)
        internal
    {
        _setCollateralPrice(1000e18);
        bool success =
            _createPosition({_borrower: _borrower, _collateral: _collateral, _protected: _protected, _maxOut: true});
        vm.assume(success);

        // this will help with high interest
        _removeLiquidity();

        _setCollateralPrice(1e18); // drop price 1000x

        vm.warp(block.timestamp + 10000 days);

        _printLtv(_borrower);
        vm.assume(_defaultingPossible(_borrower));

        _createIncentiveController();

        _printBalances(silo0, _borrower);
        _printBalances(silo1, _borrower);

        console2.log("\tdefaulting.liquidationCallByDefaulting(_borrower)");

        _printMaxLiquidation(_borrower);

        // assertGe(silo0.getLtv(_borrower), 1e18, "position should be in bad debt state");
        vm.assume(silo0.getLtv(_borrower) >= 1e18); // position should be in bad debt state

        defaulting.liquidationCallByDefaulting(_borrower);

        _printBalances(silo0, _borrower);
        _printBalances(silo1, _borrower);

        _printLtv(_borrower);

        assertEq(silo0.getLtv(_borrower), 0, "position should be removed");

        _assertNoShareTokens({_silo: silo0, _user: _borrower, _allowForDust: _useSameAssetPosition()});
        _assertNoShareTokens({_silo: silo1, _user: _borrower, _allowForDust: _useSameAssetPosition()});

        // we can not assert for silo exit, because defaulting will make share value lower,
        // so there might be users who can not withdraw because convertion to assets will give 0
        //_exitSilo();
    }

// todo
    function _defaulting_neverReverts_insolvencyScenario(address _borrower, uint256 _collateral, uint256 _protected)
        internal
    {
        _setCollateralPrice(2e18);
        bool success =
            _createPosition({_borrower: _borrower, _collateral: _collateral, _protected: _protected, _maxOut: true});
        vm.assume(success);

        // this will help with high interest
        _removeLiquidity();

        _setCollateralPrice(1e18); // drop price 1000x

        vm.warp(block.timestamp + 10000 days);

        _printLtv(_borrower);
        vm.assume(_defaultingPossible(_borrower));

        _createIncentiveController();

        _printBalances(silo0, _borrower);
        _printBalances(silo1, _borrower);

        console2.log("\tdefaulting.liquidationCallByDefaulting(_borrower)");

        _printMaxLiquidation(_borrower);

        vm.assume(!silo0.isSolvent(_borrower)); // position should be insolvent
        vm.assume(silo0.getLtv(_borrower) < 1e18); // position should NOT be in bad debt state

        defaulting.liquidationCallByDefaulting(_borrower);

        _printBalances(silo0, _borrower);
        _printBalances(silo1, _borrower);

        _printLtv(_borrower);

        assertEq(silo0.getLtv(_borrower), 0, "position should be removed");

        _assertNoShareTokens({_silo: silo0, _user: _borrower, _allowForDust: _useSameAssetPosition()});
        _assertNoShareTokens({_silo: silo1, _user: _borrower, _allowForDust: _useSameAssetPosition()});

        // we can not assert for silo exit, because defaulting will make share value lower,
        // so there might be users who can not withdraw because convertion to assets will give 0
        //_exitSilo();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_neverReverts_0collateral -vv
    */
    function test_defaulting_neverReverts_0collateral() public {
        _setCollateralPrice(1000e18);
        bool success = _createPosition({_borrower: borrower, _collateral: 1e18, _protected: 1, _maxOut: true});
        vm.assume(success);

        // this will help with interest
        _removeLiquidity();

        _setCollateralPrice(1e18); // drop price 1000x

        vm.warp(block.timestamp + 10000 days);

        _printLtv(borrower);

        // first do normal liquidation with sTokens, to remove whole collateral,
        // price is set 1:1 so we can use collateral as max debt
        (uint256 collateralToLiquidate,,) = partialLiquidation.maxLiquidation(borrower);
        (address collateralAsset, address debtAsset) = _getTokens();
        partialLiquidation.liquidationCall(collateralAsset, debtAsset, borrower, collateralToLiquidate, true);

        (collateralToLiquidate,,) = partialLiquidation.maxLiquidation(borrower);
        assertEq(collateralToLiquidate, 0, "collateral taken by regular liquidation");

        assertTrue(_defaultingPossible(borrower), "defaulting not possible??");
        assertFalse(silo0.isSolvent(borrower), "borrower should be insolvent");

        _createIncentiveController();

        defaulting.liquidationCallByDefaulting(borrower);

        _printLtv(borrower);

        assertEq(silo0.getLtv(borrower), 0, "position should be removed");
        _assertNoShareTokens(silo0, borrower);
        _assertNoShareTokens(silo1, borrower);
        _assertWithdrawableFees();
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

        bool success = _createPosition({
            _borrower: makeAddr("borrower2"),
            _collateral: _collateral * 10,
            _protected: _protected * 10,
            _maxOut: _useSameAssetPosition()
        });

        vm.assume(success);

        _whenDefaultingPossibleTxDoesNotRevert(_initialPrice, _changePrice, _warp, _collateral, _protected, false);
    }

    /* 
    TODO defaulting will not bring LTV to the target LT because total collaterla decrease
    impact on other positions eg with position is 10x bigger then position we are liquidating 
    other position that is 10x bigger: position 92.7% -> 100.2
    liquidated position by defaulting: 92.7% -> 82.7%, normal liquidation result: 76%
    */
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

        bool success = _createPosition({
            _borrower: borrower,
            _collateral: _collateral,
            _protected: _protected,
            _maxOut: _useSameAssetPosition()
        });

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

        bool success = _createPosition({
            _borrower: borrower,
            _collateral: _collateral,
            _protected: _protected,
            _maxOut: _useSameAssetPosition()
        });

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
        UserState memory userState = _getUserState(borrower);

        vm.revertToState(snapshot);
        console2.log("snapshot reverted");

        _executeDefaulting(borrower);
        console2.log("defaulting liquidation done");
        UserState memory userState2 = _getUserState(borrower);

        assertEq(userState.debtShares, userState2.debtShares, "debt shares should be the same");
        assertEq(userState.protectedShares, userState2.protectedShares, "protected shares should be the same");
        assertEq(userState.colalteralShares, userState2.colalteralShares, "collateral shares should be the same");

        if (_useSameAssetPosition()) {
            // for same position, LTV depends on type of collateral.
            // if user has protected - LTV drops, if collateral LTV grows
            // if (userState.ltv != 0) assertFalse(silo0.isSolvent(borrower), "same borrow position will grow LTV");
            assertTrue(silo0.isSolvent(borrower), "CHECK PROTECTED - DEBUG");
        } else {
            // TODO make separate test just to see, if whatever happen user will be solvent?
            // assertTrue(silo0.isSolvent(borrower), "whatever happen user must be solvent");
        }
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

        if (_useSameAssetPosition() && address(collateralSilo) == address(silo0)) {
            // maxRepay does not give us precise data for this case, that's why hardcoding
            // TODO looks like another bug for max method?
            maxRepay = 14;
        }

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

        bool success = _createPosition({
            _borrower: borrower,
            _collateral: _collateral,
            _protected: _protected,
            _maxOut: _useSameAssetPosition()
        });

        vm.assume(success);

        _removeLiquidity();

        uint256 warp = _useSameAssetPosition() ? 1000 days : 1 days;
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
