// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Math} from "openzeppelin5/utils/math/Math.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {SiloIncentivesController} from "silo-core/contracts/incentives/SiloIncentivesController.sol";
import {RevertLib} from "silo-core/contracts/lib/RevertLib.sol";

import {DummyOracle} from "silo-core/test/foundry/_common/DummyOracle.sol";

import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";

abstract contract DefaultingLiquidationHelpers is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;

    struct UserState {
        uint256 colalteralShares;
        uint256 collateralAssets;
        uint256 protectedShares;
        uint256 protectedAssets;
        uint256 debtShares;
        uint256 debtAssets;
    }

    struct SiloState {
        uint256 totalCollateral;
        uint256 totalProtected;
        uint256 totalDebt;
        uint256 totalCollateralShares;
        uint256 totalProtectedShares;
        uint256 totalDebtShares;
    }

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
        console2.log("\tremoving liquidity");
        address lpProvider = makeAddr("lpProvider");

        vm.startPrank(lpProvider);
        uint256 amount;

        try silo0.maxWithdraw(lpProvider) returns (uint256 _amount) {
            amount = _amount;
        } catch {
            console2.log("\t[_removeLiquidity] maxWithdraw #0 failed");
        }

        if (amount != 0) {
            try silo0.withdraw(amount, lpProvider, lpProvider) {
                // nothing to do
            } catch {
                console2.log("\t[_removeLiquidity] withdraw #0 failed");
            }
        }

        amount = 0;

        try silo1.maxWithdraw(lpProvider) returns (uint256 _amount) {
            amount = _amount;
        } catch {
            console2.log("\t[_removeLiquidity] maxWithdraw #1 failed");
        }

        if (amount != 0) {
            try silo1.withdraw(amount, lpProvider, lpProvider) {
                // nothing to do
            } catch {
                console2.log("\t[_removeLiquidity] withdraw #1 failed");
            }
        }

        vm.stopPrank();

        (, ISilo debtSilo) = _getSilos();
        assertLe(debtSilo.getLiquidity(), 1, "[_removeLiquidity] liquidity should be ~0");
    }

    // function _calculateLiquidityForBorrow(uint256 _collateral, uint256 _protected) internal view returns (uint256 forBorrow) {
    //     (ISilo collateralSilo, ISilo debtSilo) = _getSilos();
    //     uint256 maxCollateral = Math.max(_collateral, _protected);

    //     // for same token prcie is 1:1
    //     if (address(debtSilo) == address(collateralSilo)) return maxCollateral;

    //     if (address(collateralSilo) == address(silo0)) return oracle0.quote(maxCollateral, address(token0));

    //     // collateral is in silo1 and we need to add liquidity to silo0
    //     uint256 decimals0 = token0.decimals();
    //     uint256 valueOfOne = oracle0.quote(10 ** decimals0, address(token0));

    //     return  (10 ** decimals0) * maxCollateral / valueOfOne;
    // }

    function _addLiquidity(uint256 _amount) internal {
        if (_amount == 0) return;
        console2.log("\tadding liquidity", _amount);

        address lpProvider = makeAddr("lpProvider");
        (, ISilo debtSilo) = _getSilos();
        vm.prank(lpProvider);
        debtSilo.deposit(_amount, lpProvider);

        depositors.push(lpProvider);
    }

    function _createPosition(address _borrower, uint256 _collateral, uint256 _protected, bool _maxOut)
        internal
        returns (bool success)
    {
        console2.log("\tcreating position");
        (ISilo collateralSilo,) = _getSilos();

        vm.startPrank(_borrower);
        if (_collateral != 0) collateralSilo.deposit(_collateral, _borrower);
        if (_protected != 0) collateralSilo.deposit(_protected, _borrower, ISilo.CollateralType.Protected);
        vm.stopPrank();

        depositors.push(_borrower);

        _printBalances(silo0, _borrower);
        _printBalances(silo1, _borrower);

        uint256 maxBorrow = _maxBorrow(_borrower);
        console2.log("maxBorrow", maxBorrow);
        console2.log("liquidity0", silo0.getLiquidity());
        console2.log("liquidity1", silo1.getLiquidity());

        if (maxBorrow == 0) return false;

        success = _executeBorrow(_borrower, maxBorrow);
        if (!success) return false;

        _printLtv(_borrower);

        if (_maxOut) {
            vm.startPrank(_borrower);

            uint256 maxWithdraw;
            try collateralSilo.maxWithdraw(_borrower) returns (uint256 _maxWithdraw) {
                maxWithdraw = _maxWithdraw;
            } catch {
                // this can happen when price change and we will get ZeroQuote
                console2.log("\tmaxWithdraw #1 failed");
            }

            if (maxWithdraw != 0) {
                try collateralSilo.withdraw(maxWithdraw, _borrower, _borrower) {
                    // nothing to do
                } catch {
                    // this can happen when price change and we will get ZeroQuote
                    console2.log("\twithdraw #1 failed");
                }
            }

            try collateralSilo.maxWithdraw(_borrower, ISilo.CollateralType.Protected) returns (uint256 _maxWithdraw) {
                maxWithdraw = _maxWithdraw;
            } catch {
                // this can happen when price change and we will get ZeroQuote
                console2.log("\tmaxWithdraw #2 failed");
            }

            if (maxWithdraw != 0) {
                try collateralSilo.withdraw(maxWithdraw, _borrower, _borrower, ISilo.CollateralType.Protected) {
                    // nothing to do
                } catch {
                    // this can happen when price change and we will get ZeroQuote
                    console2.log("\twithdraw #2 failed");
                }
            }

            vm.stopPrank();

            _printLtv(_borrower);
        }
    }

    function _printBalances(ISilo _silo, address _user) internal view {
        (address protectedShareToken, address collateralShareToken, address debtShareToken) =
            _silo.config().getShareTokens(address(_silo));

        string memory userLabel = vm.getLabel(_user);

        uint256 balance = IShareToken(collateralShareToken).balanceOf(_user);
        console2.log("%s.balanceOf(%s)", vm.getLabel(collateralShareToken), userLabel, balance);
        uint256 assets = _silo.previewRedeem(balance);
        console2.log("\tbalance to assets", assets);
        console2.log("\tback to shares", _silo.convertToShares(assets));

        balance = IShareToken(protectedShareToken).balanceOf(_user);
        console2.log("%s.balanceOf(%s)", vm.getLabel(protectedShareToken), userLabel, balance);
        assets = _silo.previewRedeem(balance, ISilo.CollateralType.Protected);
        console2.log("\tbalance to assets", assets);
        console2.log("\tback to shares", _silo.convertToShares(assets));

        balance = IShareToken(debtShareToken).balanceOf(_user);
        console2.log("%s.balanceOf(%s)", vm.getLabel(debtShareToken), userLabel, balance);
        console2.log("\tbalance to assets", _silo.previewRepay(balance));
    }

    function _printOraclePrice(ISilo _silo) internal view {
        (ISiloConfig.ConfigData memory config) = siloConfig.getConfig(address(_silo));
        _printOraclePrice(_silo, 10 ** IERC20Metadata(config.token).decimals());
    }

    function _printOraclePrice(ISilo _silo, uint256 _amount) internal view {
        (ISiloConfig.ConfigData memory config) = siloConfig.getConfig(address(_silo));
        ISiloOracle oracle = ISiloOracle(config.solvencyOracle);

        if (address(oracle) == address(0)) {
            console2.log("no oracle configured, price is 1:1 for ", vm.getLabel(address(_silo)));
            return;
        }

        uint256 quote = oracle.quote(_amount, config.token);
        console2.log("quote(%s) = %s", _amount, quote);
    }

    function _isOracleThrowing(address _borrower) internal view returns (bool throwing) {
        try siloLens.getLtv(silo0, _borrower) {
            throwing = false;
        } catch {
            throwing = true;
        }
    }

    function _printLtv(address _user) internal returns (uint256 ltv) {
        try siloLens.getLtv(silo0, _user) returns (uint256 _ltv) {
            ltv = _ltv;
            emit log_named_decimal_uint(string.concat(vm.getLabel(_user), " LTV [%]"), ltv, 16);
        } catch {
            console2.log("\t[_printLtv] getLtv failed");
        }
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

        possible = ltv > lt + margin;

        if (!possible) {
            emit log_named_decimal_uint("    lt", lt, 16);
            emit log_named_decimal_uint("margin", margin, 16);
            emit log_named_decimal_uint("   ltv", ltv, 16);
        }

        console2.log("defaulting possible: ", possible ? "yes" : "no");
    }

    function _createIncentiveController() internal {
        // TODO test if revert for silo0
        (, ISilo debtSilo) = _getSilos();
        gauge = new SiloIncentivesController(address(this), address(partialLiquidation), address(debtSilo));

        address owner = Ownable(address(defaulting)).owner();
        vm.prank(owner);
        IGaugeHookReceiver(address(defaulting)).setGauge(gauge, IShareToken(address(debtSilo)));
        console2.log("gauge configured");
    }

    /// @param _price 1e18 will make collateral:debt 1:1, 2e18 will make collateral to be 2x more valuable than debt
    function _setCollateralPrice(uint256 _price) internal {
        emit log_named_decimal_uint("\t[_setCollateralPrice] setting price to", _price, 18);

        (ISilo collateralSilo,) = _getSilos();

        if (address(collateralSilo) == address(silo0)) oracle0.setPrice(_price);
        else oracle0.setPrice(_price == 0 ? 0 : 1e36 / _price);

        try oracle0.quote(10 ** token0.decimals(), address(token0)) returns (uint256 _quote) {
            emit log_named_decimal_uint("token 0 value", _quote, token1.decimals());
        } catch {
            console2.log("\t[_setCollateralPrice] quote failed");
        }
    }

    function _siloLp() internal view returns (string memory lp) {
        (ISilo collateralSilo,) = _getSilos();
        lp = address(collateralSilo) == address(silo0) ? "0" : "1";
    }

    function _printFractions(ISilo _silo) internal {
        (ISilo.Fractions memory fractions) = _silo.getFractionsStorage();
        
        emit log_named_decimal_uint(
            string.concat(vm.getLabel(address(_silo)), " fractions.interest"), fractions.interest, 18
        );
        emit log_named_decimal_uint(
            string.concat(vm.getLabel(address(_silo)), " fractions.revenue"), fractions.revenue, 18
        );
    }

    function _printRevenue(ISilo _silo) internal view returns (uint256 revenue) {
        (revenue,,,,) = _silo.getSiloStorage();
        console2.log(vm.getLabel(address(_silo)), "revenue", revenue);
    }

    function _getShareTokens(address _borrower)
        internal
        view
        virtual
        returns (IShareToken collateralShareToken, IShareToken protectedShareToken, IShareToken debtShareToken)
    {
        (ISiloConfig.ConfigData memory collateralConfig, ISiloConfig.ConfigData memory debtConfig) =
            siloConfig.getConfigsForSolvency(_borrower);

        return (
            IShareToken(collateralConfig.protectedShareToken),
            IShareToken(collateralConfig.collateralShareToken),
            IShareToken(debtConfig.debtShareToken)
        );
    }

    function _executeDefaulting(address _borrower) internal returns (bool success) {
        try defaulting.liquidationCallByDefaulting(_borrower) {
            success = true;
        } catch (bytes memory e) {
            if (
                keccak256(e)
                    == keccak256(
                        abi.encodeWithSelector(
                            IPartialLiquidationByDefaulting.WithdrawSharesForLendersTooHighForDistribution.selector
                        )
                    )
            ) {
                console2.log("WithdrawSharesForLendersTooHighForDistribution");
                vm.assume(false);
            }

            RevertLib.revertBytes(e, "executeDefaulting failed");
        }
    }

    function _executeMaxLiquidation(address _borrower) internal returns (bool success) {
        (address collateralAsset, address debtAsset) = _getTokens();

        try partialLiquidation.liquidationCall(collateralAsset, debtAsset, _borrower, type(uint256).max, true) {
            success = true;
        } catch {
            success = false;
        }
    }

    function _getSiloState(ISilo _silo) internal view returns (SiloState memory siloState) {
        siloState.totalCollateral = _silo.getTotalAssetsStorage(ISilo.AssetType.Collateral);
        siloState.totalProtected = _silo.getTotalAssetsStorage(ISilo.AssetType.Protected);
        siloState.totalDebt = _silo.getTotalAssetsStorage(ISilo.AssetType.Debt);

        (address protectedShareToken, address collateralShareToken, address debtShareToken) =
            siloConfig.getShareTokens(address(_silo));

        siloState.totalCollateralShares = IShareToken(collateralShareToken).totalSupply();
        siloState.totalProtectedShares = IShareToken(protectedShareToken).totalSupply();
        siloState.totalDebtShares = IShareToken(debtShareToken).totalSupply();
    }

    function _getUserState(ISilo _silo, address _user) internal view returns (UserState memory userState) {
        (address protectedShareToken, address collateralShareToken, address debtShareToken) =
            siloConfig.getShareTokens(address(_silo));

        userState.debtShares = IShareToken(debtShareToken).balanceOf(_user);
        userState.protectedShares = IShareToken(protectedShareToken).balanceOf(_user);
        userState.colalteralShares = IShareToken(collateralShareToken).balanceOf(_user);

        userState.collateralAssets = _silo.previewRedeem(userState.colalteralShares);
        userState.protectedAssets = _silo.previewRedeem(userState.protectedShares, ISilo.CollateralType.Protected);
        userState.debtAssets = _silo.maxRepay(_user);
    }

    function _calculateNewPrice(uint64 _initialPrice, int64 _changePricePercentage)
        internal
        pure
        returns (uint64 newPrice)
    {
        _changePricePercentage %= 1e18;

        int256 diff = int256(uint256(_initialPrice)) * _changePricePercentage / 1e18;
        newPrice = uint64(int64(int256(uint256(_initialPrice)) + diff));
    }

    // CONFIGURATION

    function _useConfigName() internal view virtual returns (string memory);

    function _getSilos() internal view virtual returns (ISilo collateralSilo, ISilo debtSilo);

    function _getTokens() internal view virtual returns (address collateralAsset, address debtAsset);

    /// @dev make sure it does not throw!
    function _maxBorrow(address _borrower) internal view virtual returns (uint256);

    function _executeBorrow(address _borrower, uint256 _amount) internal virtual returns (bool success);
}
