// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Math} from "openzeppelin5/utils/math/Math.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {SiloConfigOverride, SiloFixture} from "../../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {SiloIncentivesController} from "silo-core/contracts/incentives/SiloIncentivesController.sol";

import {DummyOracle} from "silo-core/test/foundry/_common/DummyOracle.sol";

/*

- should work exactly the same for same asset positions, that's why we have 4 cases

- anything todo with decimals?


defaulting should not change protected collateral ratio

delay should be tested

should work for both collaterals (collateral and protected) in same way


TODO test if we revert with TooHigh error on repay because of delegate call


incentive distribution: 
- does everyone can claim? its shares so even 1 wei should be claimable




*/

abstract contract DefaultingLiquidationCommon is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;

    ISiloConfig siloConfig;

    address borrower = makeAddr("borrower");
    address depositor = makeAddr("depositor");

    DummyOracle oracle0;

    IPartialLiquidationByDefaulting defaulting;
    ISiloIncentivesController gauge;

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
        assertTrue(_createPosition({_collateral: 0, _protected: 2, _maxOut: true}));
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_neverReverts_fuzz -vv --mc DefaultingLiquidationTwo1Test
    */
    function test_defaulting_neverReverts_fuzz(uint32 _collateral, uint32 _protected) public {
        _setCollateralPrice(1000e18);
        // minimal collateral to create position is 2
        bool success = _createPosition({_collateral: _collateral, _protected: _protected, _maxOut: true});
        vm.assume(success);

        // this will help with interest
        _removeLiquidity();

        _setCollateralPrice(1e18); // drop price 1000x

        vm.warp(block.timestamp + 10000 days);

        _printLtv(borrower);
        vm.assume(_defaultingPossible(borrower));

        _createIncentiveController();

        defaulting.liquidationCallByDefaulting(borrower);

        _printLtv(borrower);

        assertEq(silo0.getLtv(borrower), 0, "position should be removed");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_neverReverts_0collateral -vv
    */
    function test_defaulting_neverReverts_0collateral() public {
        _setCollateralPrice(1000e18);
        // minimal collateral to create position is 2
        bool success = _createPosition({_collateral: 1e18, _protected: 1, _maxOut: true});
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
            address user = makeAddr(string.concat("user", vm.toString(i+1)));
            vm.prank(user);
            debtSilo.deposit(Math.max(_protectedDeposits[i], 1), user, ISilo.CollateralType.Protected);
        }

        _setCollateralPrice(_initialPrice);
        bool success = _createPosition({_collateral: _collateral, _protected: _protected, _maxOut: true});
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
            address user = makeAddr(string.concat("user", vm.toString(i+1)));
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
        bool success = _createPosition({_collateral: _collateral, _protected: _protected, _maxOut: true});
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
    bad debt scenario: everybody can exit with the same loss
    */

    /*
    if no bad debt, both liquidations are the same
    */

    /*
    fee is corectly splitted 
    */


    function _mockQuote(uint256 _amountIn, uint256 _price) public {
        vm.mockCall(
            address(oracle0),
            abi.encodeWithSelector(ISiloOracle.quote.selector, _amountIn, address(token0)),
            abi.encode(_price)
        );
    }

    // function _depositAndBurn(uint256 _amount, uint256 _burn, ISilo.CollateralType _collateralType) public {
    //     if (_amount == 0) return;

    //     uint256 shares = _deposit(_amount, address(this), _collateralType);
    //     vm.assume(shares >= _burn);

    //     if (_burn != 0) {
    //         (address protectedShareToken, address collateralShareToken,) =
    //             silo0.config().getShareTokens(address(silo0));
    //         address token =
    //             _collateralType == ISilo.CollateralType.Protected ? protectedShareToken : collateralShareToken;

    //         vm.prank(address(silo0));
    //         IShareToken(token).burn(address(this), address(this), _burn);
    //     }
    // }

    function _removeLiquidity() internal {
        vm.startPrank(depositor);
        uint256 amount = silo0.maxWithdraw(depositor);
        if (amount != 0) silo0.withdraw(amount, depositor, depositor);

        amount = silo1.maxWithdraw(depositor);
        if (amount != 0) silo1.withdraw(amount, depositor, depositor);
        vm.stopPrank();
    }

    function _createPosition(uint256 _collateral, uint256 _protected, bool _maxOut) internal returns (bool success) {
        (ISilo collateralSilo, ISilo debtSilo) = _getSilos();

        uint256 forBorrow = Math.max(_collateral, _protected);
        if (forBorrow == 0) return false;

        vm.prank(depositor);
        debtSilo.deposit(forBorrow, depositor);

        vm.startPrank(borrower);
        if (_collateral != 0) collateralSilo.deposit(_collateral, borrower);
        if (_protected != 0) collateralSilo.deposit(_protected, borrower, ISilo.CollateralType.Protected);
        vm.stopPrank();

        _printBalances(silo0, borrower);
        _printBalances(silo1, borrower);

        uint256 maxBorrow = _maxBorrow(borrower);
        console2.log("maxBorrow", maxBorrow);
        console2.log("liquidity0", silo0.getLiquidity());
        console2.log("liquidity1", silo1.getLiquidity());
        success = maxBorrow > 0;

        if (!success) return false;

        _executeBorrow(borrower, maxBorrow);

        _printLtv(borrower);

        if (_maxOut) {
            vm.startPrank(borrower);
            uint256 maxWithdraw = collateralSilo.maxWithdraw(borrower);
            if (maxWithdraw != 0) collateralSilo.withdraw(maxWithdraw, borrower, borrower);

            maxWithdraw = collateralSilo.maxWithdraw(borrower, ISilo.CollateralType.Protected);
            if (maxWithdraw != 0) {
                collateralSilo.withdraw(maxWithdraw, borrower, borrower, ISilo.CollateralType.Protected);
            }
            vm.stopPrank();

            _printLtv(borrower);
        }
    }

    function _printBalances(ISilo _silo, address _user) internal view {
        (address protectedShareToken, address collateralShareToken, address debtShareToken) =
            _silo.config().getShareTokens(address(_silo));
        string memory siloName = string.concat("silo", address(_silo) == address(silo0) ? "0" : "1");

        console2.log(siloName, "balance", IShareToken(collateralShareToken).balanceOf(_user));
        console2.log(siloName, "protected balance", IShareToken(protectedShareToken).balanceOf(_user));
        console2.log(siloName, "debt balance", IShareToken(debtShareToken).balanceOf(_user));
    }

    function _printLtv(address _user) internal {
        emit log_named_decimal_uint("LTV [%]", silo0.getLtv(_user), 16);
    }

    function _defaultingPossible(address _user) internal returns (bool possible) {
        uint256 margin = defaulting.LT_MARGIN_FOR_DEFAULTING();
        (ISilo collateralSilo,) = _getSilos();
        uint256 lt = collateralSilo.config().getConfig(address(collateralSilo)).lt;
        uint256 ltv = collateralSilo.getLtv(_user);

        possible = ltv >= lt + margin;

        if (!possible) {
            emit log_named_decimal_uint("    lt", lt, 16);
            emit log_named_decimal_uint("margin", margin, 16);
            emit log_named_decimal_uint("   ltv", ltv, 16);
        }

        console2.log("defaulting possible: ", possible ? "yes" : "no");
    }

    function _createIncentiveController() internal {
        // TODO test if revert for silo0
        (ISilo collateralSilo,) = _getSilos();
        gauge = new SiloIncentivesController(address(this), address(partialLiquidation), address(collateralSilo));

        address owner = Ownable(address(defaulting)).owner();
        vm.prank(owner);
        IGaugeHookReceiver(address(defaulting)).setGauge(gauge, IShareToken(address(collateralSilo)));
        console2.log("gauge configured");
    }

    /// @param _price 1e18 will make collateral:debt 1:1, 2e18 will make collateral to be 2x more valuable than debt
    function _setCollateralPrice(uint256 _price) internal {
        (ISilo collateralSilo,) = _getSilos();
        if (address(collateralSilo) == address(silo0)) oracle0.setPrice(_price);
        else oracle0.setPrice(1e36 / _price);

        emit log_named_decimal_uint(
            "value of token 0", oracle0.quote(10 ** token0.decimals(), address(token0)), token1.decimals()
        );
    }

    function _siloLp() internal view returns (string memory lp) {
        (ISilo collateralSilo,) = _getSilos();
        lp = address(collateralSilo) == address(silo0) ? "0" : "1";
    }

    // CONFIGURATION

    function _useConfigName() internal view virtual returns (string memory);

    function _useSameAssetPosition() internal pure virtual returns (bool);

    function _getSilos() internal view virtual returns (ISilo collateralSilo, ISilo debtSilo);

    function _getTokens() internal view virtual returns (address collateralAsset, address debtAsset);

    function _maxBorrow(address _borrower) internal view virtual returns (uint256);

    function _executeBorrow(address _borrower, uint256 _amount) internal virtual;
}
