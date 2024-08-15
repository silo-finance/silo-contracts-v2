// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Strings} from "openzeppelin5/utils/Strings.sol";

import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";

import {TokenHelper} from "../lib/TokenHelper.sol";

library ShareTokenLib {
    // keccak256(abi.encode(uint256(keccak256("silo.storage.ShareToken")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant StorageLocation = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00; // TODO

    function _getShareTokenStorage() private pure returns (IShareToken.ShareTokenStorage storage $) {
        assembly {
            $.slot := StorageLocation
        }
    }

    /// @dev decimals of share token
    function decimals() external view returns (uint8) {
        IShareToken.ShareTokenStorage storage $ = _getShareTokenStorage();
        ISiloConfig.ConfigData memory configData = $.siloConfig.getConfig(address($.silo));
        return uint8(TokenHelper.assertAndGetDecimals(configData.token));
    }

    /// @dev Name convention:
    ///      NAME - asset name
    ///      SILO_ID - unique silo id
    ///
    ///      Protected deposit: "Silo Finance Non-borrowable NAME Deposit, SiloId: SILO_ID"
    ///      Borrowable deposit: "Silo Finance Borrowable NAME Deposit, SiloId: SILO_ID"
    ///      Debt: "Silo Finance NAME Debt, SiloId: SILO_ID"
    function name() external view returns (string memory) {
        IShareToken.ShareTokenStorage storage $ = _getShareTokenStorage();

        ISiloConfig.ConfigData memory configData = $.siloConfig.getConfig(address($.silo));
        string memory siloIdAscii = Strings.toString($.siloConfig.SILO_ID());

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
    function symbol() external view returns (string memory) {
        IShareToken.ShareTokenStorage storage $ = _getShareTokenStorage();

        ISiloConfig.ConfigData memory configData = $.siloConfig.getConfig(address($.silo));
        string memory siloIdAscii = Strings.toString($.siloConfig.SILO_ID());

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
