// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Strings} from "openzeppelin5/utils/Strings.sol";

import {IHookReceiver} from "../interfaces/IHookReceiver.sol";
import {ISilo} from "../interfaces/ISilo.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {TokenHelper} from "../lib/TokenHelper.sol";

library ShareTokenLib {
    /// @dev decimals of share token
    function decimals(ISiloConfig _siloConfig, ISilo _silo) external view returns (uint8) {
        ISiloConfig.ConfigData memory configData = _siloConfig.getConfig(address(_silo));
        return uint8(TokenHelper.assertAndGetDecimals(configData.token));
    }

    /// @dev Name convention:
    ///      NAME - asset name
    ///      SILO_ID - unique silo id
    ///
    ///      Protected deposit: "Silo Finance Non-borrowable NAME Deposit, SiloId: SILO_ID"
    ///      Borrowable deposit: "Silo Finance Borrowable NAME Deposit, SiloId: SILO_ID"
    ///      Debt: "Silo Finance NAME Debt, SiloId: SILO_ID"
    function name(ISiloConfig _siloConfig, ISilo _silo) external view returns (string memory) {
        ISiloConfig.ConfigData memory configData = _siloConfig.getConfig(address(_silo));
        string memory siloIdAscii = Strings.toString(_siloConfig.SILO_ID());

        string memory pre = "";
        string memory post = " Deposit";

        if (address(this) == configData.protectedShareToken) {
            pre = "Non-borrowable ";
        } else if (address(this) == configData.collateralShareToken) {
            pre = "Borrowable ";
        } else if (address(this) == configData.debtShareToken) {
            post = " Debt";
        }

        string memory tokenSymbol = TokenHelper.symbol(configData.token);
        return string.concat("Silo Finance ", pre, tokenSymbol, post, ", SiloId: ", siloIdAscii);
    }

    /// @dev Symbol convention:
    ///      SYMBOL - asset symbol
    ///      SILO_ID - unique silo id
    ///
    ///      Protected deposit: "nbSYMBOL-SILO_ID"
    ///      Borrowable deposit: "bSYMBOL-SILO_ID"
    ///      Debt: "dSYMBOL-SILO_ID"
    function symbol(ISiloConfig _siloConfig, ISilo _silo) external view returns (string memory) {
        ISiloConfig.ConfigData memory configData = _siloConfig.getConfig(address(_silo));
        string memory siloIdAscii = Strings.toString(_siloConfig.SILO_ID());

        string memory pre;

        if (address(this) == configData.protectedShareToken) {
            pre = "nb";
        } else if (address(this) == configData.collateralShareToken) {
            pre = "b";
        } else if (address(this) == configData.debtShareToken) {
            pre = "d";
        }

        string memory tokenSymbol = TokenHelper.symbol(configData.token);
        return string.concat(pre, tokenSymbol, "-", siloIdAscii);
    }
}
