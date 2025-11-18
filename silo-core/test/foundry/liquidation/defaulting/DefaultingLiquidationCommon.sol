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
    /// forge-config: core_test.fuzz.runs = 10000
    function test_defaulting_neverReverts_fuzz(uint32 _collateral, uint32 _protected) public {
        _defaulting_neverReverts_badDebtScenario(borrower, _collateral, _protected);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_neverReverts_withOtherBorrowers_fuzz -vv
    */
    /// forge-config: core_test.fuzz.runs = 10000
    function test_defaulting_neverReverts_withOtherBorrowers_fuzz(uint32 _collateral, uint32 _protected) public {
        bool success = _createPosition({
            _borrower: makeAddr("otherBorrower"),
            _collateral: _collateral,
            _protected: _protected,
            _maxOut: true
        });

        vm.assume(success);

        _defaulting_neverReverts_badDebtScenario(borrower, _collateral, _protected);
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

        assertGe(silo0.getLtv(_borrower), 1e18, "position should be in bad debt state");

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
    if _defaultingPossible() we never revert otherwise we do revert

    FOUNDRY_PROFILE=core_test forge test --ffi --mt test__defaultingPossible_fuzz -vv --mc DefaultingLiquidationTwo1Test
    */
    function test__defaultingPossible_fuzz(
        uint64 _initialPrice,
        uint64 _changePrice,
        uint32 _warp,
        uint96 _collateral,
        uint96 _protected
    ) public {
        _setCollateralPrice(_initialPrice);
        bool success =
            _createPosition({_borrower: borrower, _collateral: _collateral, _protected: _protected, _maxOut: true});
        vm.assume(success);

        assertGt(silo0.getLtv(borrower), 0, "double check that user does have position");

        // this will help with interest
        _removeLiquidity();

        _setCollateralPrice(_changePrice);

        vm.warp(block.timestamp + _warp);

        _printLtv(borrower);

        _createIncentiveController();

        if (!_defaultingPossible(borrower)) vm.expectRevert(IPartialLiquidation.UserIsSolvent.selector);

        defaulting.liquidationCallByDefaulting(borrower);

        _printLtv(borrower);

        assertTrue(silo0.isSolvent(borrower), "whatever happen user must be solvent");
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
    bad debt scenario: everybody can exit with the same loss
    */

    /*
    if no bad debt, both liquidations are the same
    */

    /*
    fee is corectly splitted 
    */
}
