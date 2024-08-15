// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Strings} from "openzeppelin5/utils/Strings.sol";

import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {IHookReceiver} from "../interfaces/IHookReceiver.sol";

import {TokenHelper} from "../lib/TokenHelper.sol";
import {CallBeforeQuoteLib} from "../lib/CallBeforeQuoteLib.sol";
import {Hook} from "../lib/Hook.sol";
import {NonReentrantLib} from "../lib/NonReentrantLib.sol";

import {ERC20Lib} from "../utils/siloERC20/lib/ERC20Lib.sol";

library ShareTokenLib {
    using Hook for uint24;
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    // keccak256(abi.encode(uint256(keccak256("silo.storage.ShareToken")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant StorageLocation = 0x01b0b3f9d6e360167e522fa2b18ba597ad7b2b35841fec7e1ca4dbb0adea1200;

    function _getShareTokenStorage() internal pure returns (IShareToken.ShareTokenStorage storage $) {
        assembly {
            $.slot := StorageLocation
        }
    }

    /// @param _silo Silo address for which tokens was deployed
    // solhint-disable-next-line func-name-mixedcase
    function __ShareToken_init(ISilo _silo, address _hookReceiver, uint24 _tokenType) internal {
        IShareToken.ShareTokenStorage storage $ = _getShareTokenStorage();

        $.silo = _silo;
        $.siloConfig = _silo.config();

        $.hookSetup.hookReceiver = _hookReceiver;
        $.hookSetup.tokenType = _tokenType;
        $.transferWithChecks = true;
    }

    function forwardTransferFromNoChecks(address _from, address _to, uint256 _amount) external {
        IShareToken.ShareTokenStorage storage $ = _getShareTokenStorage();

        $.transferWithChecks = false;
        ERC20Lib._transfer(_from, _to, _amount);
        $.transferWithChecks = true;
    }

    function synchronizeHooks(uint24 _hooksBefore, uint24 _hooksAfter) external {
        IShareToken.ShareTokenStorage storage $ = _getShareTokenStorage();

        $.hookSetup.hooksBefore = _hooksBefore;
        $.hookSetup.hooksAfter = _hooksAfter;
    }

    function hookSetup() external view returns (IShareToken.HookSetup memory) {
        IShareToken.ShareTokenStorage storage $ = _getShareTokenStorage();
        return $.hookSetup;
    }

    function hookReceiver() external view returns (address) {
        IShareToken.ShareTokenStorage storage $ = _getShareTokenStorage();
        return $.hookSetup.hookReceiver;
    }

    function approve(address spender, uint256 value) public returns (bool result) {
        IShareToken.ShareTokenStorage storage $ = _getShareTokenStorage();

        NonReentrantLib.nonReentrant($.siloConfig);
        result = ERC20Lib.approve(spender, value);
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

    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) external {
        IShareToken.ShareTokenStorage storage $ = _getShareTokenStorage();

        IShareToken.HookSetup memory setup = $.hookSetup;

        uint256 action = Hook.shareTokenTransfer(setup.tokenType);

        if (!setup.hooksAfter.matchAction(action)) return;

        // report mint, burn or transfer
        // even if it is possible to leave silo in a middle of mint/burn, where we can have invalid state
        // you can not enter any function because of cross reentrancy check
        // invalid mid-state can be eg: in a middle of transitionCollateral, after burn but before mint
        IHookReceiver(setup.hookReceiver).afterAction(
            address($.silo),
            action,
            abi.encodePacked(
                _sender,
                _recipient,
                _amount,
                ERC20Lib.balanceOf(_sender),
                ERC20Lib.balanceOf(_recipient),
                ERC20Lib.totalSupply()
            )
        );
    }
}
