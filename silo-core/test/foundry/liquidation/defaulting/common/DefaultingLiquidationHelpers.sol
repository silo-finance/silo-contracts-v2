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
import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {SiloIncentivesController} from "silo-core/contracts/incentives/SiloIncentivesController.sol";

import {DummyOracle} from "silo-core/test/foundry/_common/DummyOracle.sol";

import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";

abstract contract DefaultingLiquidationHelpers is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;

    ISiloConfig siloConfig;

    address borrower = makeAddr("borrower");
    address depositor = makeAddr("depositor");

    address[] internal depositors;

    DummyOracle oracle0;

    IPartialLiquidationByDefaulting defaulting;
    ISiloIncentivesController gauge;

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

    function _createPosition(address _borrower, uint256 _collateral, uint256 _protected, bool _maxOut)
        internal
        returns (bool success)
    {
        (ISilo collateralSilo, ISilo debtSilo) = _getSilos();

        uint256 forBorrow = Math.max(_collateral, _protected);
        if (forBorrow == 0) return false;

        vm.prank(depositor);
        debtSilo.deposit(forBorrow, depositor);
        depositors.push(depositor);

        vm.startPrank(_borrower);
        if (_collateral != 0) collateralSilo.deposit(_collateral, _borrower);
        if (_protected != 0) collateralSilo.deposit(_protected, _borrower, ISilo.CollateralType.Protected);
        vm.stopPrank();

        _printBalances(silo0, _borrower);
        _printBalances(silo1, _borrower);

        uint256 maxBorrow = _maxBorrow(_borrower);
        console2.log("maxBorrow", maxBorrow);
        console2.log("liquidity0", silo0.getLiquidity());
        console2.log("liquidity1", silo1.getLiquidity());
        success = maxBorrow > 0;

        if (!success) return false;

        _executeBorrow(_borrower, maxBorrow);

        _printLtv(_borrower);

        if (_maxOut) {
            vm.startPrank(_borrower);

            uint256 maxWithdraw = collateralSilo.maxWithdraw(_borrower);
            if (maxWithdraw != 0) collateralSilo.withdraw(maxWithdraw, _borrower, _borrower);

            maxWithdraw = collateralSilo.maxWithdraw(_borrower, ISilo.CollateralType.Protected);

            if (maxWithdraw != 0) {
                collateralSilo.withdraw(maxWithdraw, _borrower, _borrower, ISilo.CollateralType.Protected);
            }

            vm.stopPrank();

            _printLtv(_borrower);
        }
    }

    function _printBalances(ISilo _silo, address _user) internal view {
        (address protectedShareToken, address collateralShareToken, address debtShareToken) =
            _silo.config().getShareTokens(address(_silo));

        string memory userLabel = vm.getLabel(_user);

        console2.log(
            "%s.balanceOf(%s)",
            vm.getLabel(collateralShareToken),
            userLabel,
            IShareToken(collateralShareToken).balanceOf(_user)
        );
        console2.log(
            "%s.balanceOf(%s)",
            vm.getLabel(protectedShareToken),
            userLabel,
            IShareToken(protectedShareToken).balanceOf(_user)
        );
        console2.log(
            "%s.balanceOf(%s)", vm.getLabel(debtShareToken), userLabel, IShareToken(debtShareToken).balanceOf(_user)
        );
    }

    function _printLtv(address _user) internal returns (uint256 ltv) {
        ltv = silo0.getLtv(_user);
        emit log_named_decimal_uint("LTV [%]", ltv, 16);
    }

    function _printMaxLiquidation(address _user) internal view {
        (uint256 collateralToLiquidate, uint256 debtToRepay,) = partialLiquidation.maxLiquidation(_user);
        console2.log("maxLiquidation: collateralToLiquidate", collateralToLiquidate);
        console2.log("maxLiquidation: debtToRepay", debtToRepay);
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
