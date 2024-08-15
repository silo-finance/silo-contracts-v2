// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Strings} from "openzeppelin5/utils/Strings.sol";

import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";

import {TokenHelper} from "../lib/TokenHelper.sol";
import {CallBeforeQuoteLib} from "../lib/CallBeforeQuoteLib.sol";

import {ERC20Lib} from "../utils/siloERC20/lib/ERC20Lib.sol";

library ShareTokenLib {
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    // keccak256(abi.encode(uint256(keccak256("silo.storage.ShareToken")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant StorageLocation = 0x01b0b3f9d6e360167e522fa2b18ba597ad7b2b35841fec7e1ca4dbb0adea1200;

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

    function transfer(address _to, uint256 _amount) external returns (bool result) {
        ISiloConfig siloConfigCached = _crossNonReentrantBefore();

        result = ERC20Lib.transfer(_to, _amount);

        siloConfigCached.turnOffReentrancyProtection();
    }

    function transferFrom(address _from, address _to, uint256 _amount) external returns (bool result) {
        ISiloConfig siloConfigCached = _crossNonReentrantBefore();

        result = ERC20Lib.transferFrom(_from, _to, _amount);

        siloConfigCached.turnOffReentrancyProtection();
    }

    function _crossNonReentrantBefore() public returns (ISiloConfig siloConfigCached) {
        IShareToken.ShareTokenStorage storage $ = _getShareTokenStorage();

        siloConfigCached = $.siloConfig;
        siloConfigCached.turnOnReentrancyProtection();
    }

    /// @notice Call beforeQuote on solvency oracles
    /// @param _user user address for which the solvent check is performed
    function _callOracleBeforeQuote(address _user) public {
        IShareToken.ShareTokenStorage storage $ = _getShareTokenStorage();

        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = $.siloConfig.getConfigs(_user);

        collateralConfig.callSolvencyOracleBeforeQuote();
        debtConfig.callSolvencyOracleBeforeQuote();
    }
}
