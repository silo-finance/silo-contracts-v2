// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {console2} from "forge-std/console2.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {SiloLens} from "silo-core/contracts/SiloLens.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

abstract contract UserState is Test {
    SiloLens internal constant lens = SiloLens(0xB95AD415b0fcE49f84FbD5B26b14ec7cf4822c69);

    function _printUserState(address _user, ISiloConfig _config) internal {
        (ISiloConfig.ConfigData memory collateralCfg, ISiloConfig.ConfigData memory debtCfg) =
            _config.getConfigsForSolvency(_user);

        console2.log("--------------------------------");

        string memory collateralSymbol = IERC20Metadata(collateralCfg.token).symbol();
        string memory debtSymbol = IERC20Metadata(debtCfg.token).symbol();

        console2.log("SILO ID: ", _config.SILO_ID(), string.concat(": ", collateralSymbol, " - ", debtSymbol));
        console2.log("block number: ", block.number);
        console2.log("block timestamp: ", block.timestamp);
        console2.log("user: ", _user);

        console2.log("collateral silo: ", collateralCfg.silo);
        console2.log("collateral asset: ", collateralSymbol, collateralCfg.token);
        console2.log("      debt silo: ", debtCfg.silo);
        console2.log("      debt asset: ", debtSymbol, debtCfg.token);
        console2.log("collateral Liquidation Threshold: ", collateralCfg.lt);
        console2.log("      debt Liquidation Threshold: ", debtCfg.lt);
        emit log_named_decimal_uint(
            "                        user LTV: ", lens.getUserLTV(ISilo(debtCfg.silo), _user), 16
        );
        emit log_named_string("user solvent?: ", ISilo(debtCfg.silo).isSolvent(_user) ? "yes" : "no");

        IPartialLiquidation hook = IPartialLiquidation(collateralCfg.hookReceiver);
        (uint256 collateralToLiquidate, uint256 debtToRepay, bool sTokenRequired) = hook.maxLiquidation(_user);

        uint256 collateralDecimals = IERC20Metadata(collateralCfg.token).decimals();
        uint256 debtDecimals = IERC20Metadata(debtCfg.token).decimals();

        emit log_named_decimal_uint(
            "[maxLiquidation] collateral to liquidate: ", collateralToLiquidate, collateralDecimals
        );
        emit log_named_decimal_uint("[maxLiquidation]           debt to repay: ", debtToRepay, debtDecimals);
        console2.log("[maxLiquidation] sToken required: ", sTokenRequired ? "yes" : "no");
    }
}
