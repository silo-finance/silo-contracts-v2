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

// import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";
/*

when 0 collateral, defaulting should NOT revert

defaulting should not change protected collateral ratio
everyone should be able to withdraw protected after defaulting liquidation

delay should be tested

should work exactly the same for same asset positions

revert for two way markets

should work for both collaterals (collateral and protected) in same way


TODO test if we revert with TooHigh error on repay because of delegate call

anything todo with decimals?

incentive distribution: 
- does everyone can claim? its shares so even 1 wei should be claimable


*/

abstract contract DefaultingLiquidationCommon is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;

    ISiloConfig siloConfig;

    address borrower = makeAddr("borrower");
    address depositor = makeAddr("depositor");

    DummyOracle oracle;

    IPartialLiquidationByDefaulting defaulting;
    ISiloIncentivesController gauge;

    function setUp() public {
        token0 = new MintableToken(18);
        token1 = new MintableToken(18);

        oracle = new DummyOracle(1e18, address(token1)); // 1:1 price

        token0.setOnDemand(true);
        token1.setOnDemand(true);

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        overrides.solvencyOracle0 = address(oracle);
        overrides.maxLtvOracle0 = address(oracle);
        overrides.configName = _useConfigName();

        SiloFixture siloFixture = new SiloFixture();

        address hook;
        (siloConfig, silo0, silo1,,, hook) = siloFixture.deploy_local(overrides);

        partialLiquidation = IPartialLiquidation(hook);
        defaulting = IPartialLiquidationByDefaulting(hook);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_defaulting_setup
    */
    function test_defaulting_setup() public {
        _createPosition(10, 10, false);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaulting_neverReverts_1weiCollateral -vv

    1 wei collateral fuzzing tests: goal is to make sure defaulting never reverts if oracle price > 0

    */
    function test_defaulting_neverReverts_1weiCollateral() public {
        oracle.setPrice(2e18);
        _createPosition({_collateral: 0, _protected: 10, _maxOut: true});
        oracle.setPrice(1e18);

        _printLtv(borrower);
        vm.assume(_defaultingPossible(borrower));

        _createIncentiveController();

        defaulting.liquidationCallByDefaulting(borrower);

        _printLtv(borrower);

        // assertEq(silo0.getLtv(borrower), 1e18, "expected LTV for test");
    }

    /*
    if _defaultingPossible() we never revert otherwise we do revert
    */

    /*
    bad debt scenario: everybody can exit with the same loss
    */

    /*
    if no bad debt, both liquidations are the same
    */

    /*
    fee is corectly splitted 
    */

    /*
    NoControllerForCollateral error should revert
    */

    function _mockQuote(uint256 _amountIn, uint256 _price) public {
        vm.mockCall(
            address(oracle),
            abi.encodeWithSelector(ISiloOracle.quote.selector, _amountIn, address(token0)),
            abi.encode(_price)
        );
    }

    function _depositAndBurn(uint256 _amount, uint256 _burn, ISilo.CollateralType _collateralType) public {
        if (_amount == 0) return;

        uint256 shares = _deposit(_amount, address(this), _collateralType);
        vm.assume(shares >= _burn);

        if (_burn != 0) {
            (address protectedShareToken, address collateralShareToken,) =
                silo0.config().getShareTokens(address(silo0));
            address token =
                _collateralType == ISilo.CollateralType.Protected ? protectedShareToken : collateralShareToken;

            vm.prank(address(silo0));
            IShareToken(token).burn(address(this), address(this), _burn);
        }
    }

    function _createPosition(uint256 _collateral, uint256 _protected, bool _maxOut) internal {
        bool sameAssetPosition = _useSameAssetPosition();

        uint256 forBorrow = Math.max(_collateral, _protected);

        if (sameAssetPosition) _deposit(forBorrow, depositor);
        else _depositForBorrow(forBorrow, depositor);

        if (_collateral != 0) _deposit(_collateral, borrower);
        if (_protected != 0) _deposit(_protected, borrower, ISilo.CollateralType.Protected);

        _printBalances(silo0, borrower);
        _printBalances(silo1, borrower);

        uint256 maxBorrow = sameAssetPosition ? silo0.maxBorrowSameAsset(borrower) : silo1.maxBorrow(borrower);
        console2.log("maxBorrow", maxBorrow);
        assertGt(maxBorrow, 0, "maxBorrow should be > 0");

        if (sameAssetPosition) {
            vm.prank(borrower);
            silo0.borrowSameAsset(maxBorrow, borrower, borrower);
        } else {
            _borrow(maxBorrow, borrower);
        }

        _printLtv(borrower);

        if (_maxOut) {
            uint256 maxWithdraw = silo0.maxWithdraw(borrower);
            if (maxWithdraw != 0) _withdraw(maxWithdraw, borrower);

            maxWithdraw = silo0.maxWithdraw(borrower, ISilo.CollateralType.Protected);
            if (maxWithdraw != 0) _withdraw(maxWithdraw, borrower, ISilo.CollateralType.Protected);
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

    function _defaultingPossible(address _user) internal view returns (bool) {
        uint256 margin = defaulting.LT_MARGIN_FOR_DEFAULTING();
        uint256 lt = silo0.config().getConfig(address(silo0)).lt;

        return silo0.getLtv(_user) >= lt + margin;
    }

    function _createIncentiveController() internal {
        // TODO test if revert for silo0
        gauge = new SiloIncentivesController(address(this), address(partialLiquidation), address(silo0));

        address owner = Ownable(address(defaulting)).owner();
        vm.prank(owner);
        IGaugeHookReceiver(address(defaulting)).setGauge(gauge, IShareToken(address(silo0)));
        console2.log("gauge configured");
    }

    // CONFIGURATION

    function _useConfigName() internal view virtual returns (string memory);

    function _useSameAssetPosition() internal pure virtual returns (bool);
}
