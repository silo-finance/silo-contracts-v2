// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {SiloConfigOverride, SiloFixture} from "../../_common/fixtures/SiloFixture.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";


// import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";
/*
1 wei collateral fuzzing tests: goal is to make sure defaulting never reverts if oracle price > 0

when 0 collateral, defaulting should NOT revert

defaulting should not change protected collateral ratio
everyone should be able to withdraw protected after defaulting liquidation

delay should be tested

should work exactly the same for same asset positions

revert for two way markets

should work for both collaterals (collateral and protected) in same way


TODO test if we revert with TooHigh error on repay because of delegate call
*/

contract DefaultingLiquidationTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    address borrower = makeAddr("borrower");

    function setUp() public virtual {
        siloConfig = _setUpLocalFixture(SiloConfigsNames.SILO_LOCAL_NO_ORACLE_DEFAULTING);
    }


    address oracle = makeAddr("Oracle");

    function setUp() public {
        token0 = new MintableToken(8);
        token1 = new MintableToken(10);

        token0.setOnDemand(true);
        token1.setOnDemand(true);

        vm.mockCall(oracle, abi.encodeWithSelector(ISiloOracle.quoteToken.selector), abi.encode(address(token1)));

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        overrides.solvencyOracle0 = oracle;
        overrides.maxLtvOracle0 = oracle;
        overrides.configName = SiloConfigsNames.SILO_LOCAL_NO_ORACLE_DEFAULTING;

        SiloFixture siloFixture = new SiloFixture();

        address hook;
        (siloConfig, silo0, silo1,,, hook) = siloFixture.deploy_local(overrides);

        partialLiquidation = IPartialLiquidation(hook);
    }

    /*
    FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_defaulting_setup
    */
    function test_defaulting_setup() public {
        _createPosition(1, 1, false);
    }


    function _mockQuote(uint256 _amountIn, uint256 _price) public {
        vm.mockCall(
            oracle, abi.encodeWithSelector(ISiloOracle.quote.selector, _amountIn, address(token0)), abi.encode(_price)
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
        if (_collateral != 0) _depositCollateral(_collateral, borrower, _sameAssetPosition());
        if (_protected != 0) _depositCollateral(_protected, borrower, _sameAssetPosition(), ISilo.CollateralType.Protected);

        uint256 maxBorrow = silo1.maxBorrow(borrower);
        assertGt(maxBorrow, 0, "maxBorrow should be > 0");

        _borrow(maxBorrow, borrower);

        if (_maxOut) {
            uint256 maxWithdraw = silo0.maxWithdraw(borrower);
            if (maxWithdraw != 0) _withdraw(maxWithdraw, borrower);

            maxWithdraw = silo0.maxWithdraw(borrower, ISilo.CollateralType.Protected);
            if (maxWithdraw != 0) _withdraw(maxWithdraw, borrower, ISilo.CollateralType.Protected);
        }
    }

    function _sameAssetPosition() internal pure virtual returns (bool) {
        return false;
    }
}
