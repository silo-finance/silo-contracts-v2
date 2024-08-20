// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20Permit} from "openzeppelin5/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20PermitUpgradeable} from "openzeppelin5-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20Upgradeable} from "openzeppelin5-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20Metadata, IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

import {IHookReceiver} from "../interfaces/IHookReceiver.sol";
import {IShareToken, ISilo} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../SiloConfig.sol";
import {TokenHelper} from "../lib/TokenHelper.sol";
import {Hook} from "../lib/Hook.sol";
import {CallBeforeQuoteLib} from "../lib/CallBeforeQuoteLib.sol";
import {NonReentrantLib} from "../lib/NonReentrantLib.sol";

/// @title ShareToken
/// @notice Implements common interface for Silo tokens representing debt or collateral.
/// @dev Docs borrowed from https://github.com/OpenZeppelin/openzeppelin-contracts/tree/v4.9.3
///
/// Implementation of the ERC4626 "Tokenized Vault Standard" as defined in
/// https://eips.ethereum.org/EIPS/eip-4626[EIP-4626].
///
/// This extension allows the minting and burning of "shares" (represented using the ERC20 inheritance) in exchange for
/// underlying "assets" through standardized {deposit}, {mint}, {redeem} and {burn} workflows. This contract extends
/// the ERC20 standard. Any additional extensions included along it would affect the "shares" token represented by this
/// contract and not the "assets" token which is an independent contract.
///
/// [CAUTION]
/// ====
/// In empty (or nearly empty) ERC-4626 vaults, deposits are at high risk of being stolen through frontrunning
/// with a "donation" to the vault that inflates the price of a share. This is variously known as a donation or
/// inflation attack and is essentially a problem of slippage. Vault deployers can protect against this attack by
/// making an initial deposit of a non-trivial amount of the asset, such that price manipulation becomes infeasible.
/// Withdrawals may similarly be affected by slippage. Users can protect against this attack as well as unexpected
/// slippage in general by verifying the amount received is as expected, using a wrapper that performs these checks
/// such as https://github.com/fei-protocol/ERC4626#erc4626router-and-base[ERC4626Router].
///
/// Since v4.9, this implementation uses virtual assets and shares to mitigate that risk. The `_decimalsOffset()`
/// corresponds to an offset in the decimal representation between the underlying asset's decimals and the vault
/// decimals. This offset also determines the rate of virtual shares to virtual assets in the vault, which itself
/// determines the initial exchange rate. While not fully preventing the attack, analysis shows that the default offset
/// (0) makes it non-profitable, as a result of the value being captured by the virtual shares (out of the attacker's
/// donation) matching the attacker's expected gains. With a larger offset, the attack becomes orders of magnitude more
/// expensive than it is profitable. More details about the underlying math can be found
/// xref:erc4626.adoc#inflation-attack[here].
///
/// The drawback of this approach is that the virtual shares do capture (a very small) part of the value being accrued
/// to the vault. Also, if the vault experiences losses, the users try to exit the vault, the virtual shares and assets
/// will cause the first user to exit to experience reduced losses in detriment to the last users that will experience
/// bigger losses. Developers willing to revert back to the pre-v4.9 behavior just need to override the
/// `_convertToShares` and `_convertToAssets` functions.
///
/// To learn more, check out our xref:ROOT:erc4626.adoc[ERC-4626 guide].
/// ====
///
/// _Available since v4.7._
/// @custom:security-contact security@silo.finance
abstract contract ShareToken is ERC20PermitUpgradeable, IShareToken {
    using Hook for uint24;
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    string private constant _NAME = "SiloShareToken";

    struct ShareTokenStorage {
        /// @notice Copy of hooks setup from SiloConfig for optimisation purposes
        HookSetup hookSetup;
        /// @notice Flag to enable/disable solvency checks (enabled by default)
        bool transferWithChecks;
    }

    // keccak256(abi.encode(uint256(keccak256("silo.shareToken.storage")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant ShareTokenStorageLocation =
        0x1c4b8c281ce724af42c81ec05b9bcdf032e75887d08c81d32adf3ad64780a400;

    function _getShareTokenStorage() internal pure returns (ShareTokenStorage storage $) {
        assembly {
            $.slot := ShareTokenStorageLocation
        }
    }

    /// @inheritdoc IShareToken
    function forwardTransferFromNoChecks(address _from, address _to, uint256 _amount)
        external
        virtual
    {
        _onlySilo();

        ShareTokenStorage storage $ = _getShareTokenStorage();

        $.transferWithChecks = false;
        _transfer(_from, _to, _amount);
        $.transferWithChecks = true;
    }

    function hookSetup() external view virtual returns (HookSetup memory) {
        return _getShareTokenStorage().hookSetup;
    }

    function hookReceiver() external view virtual returns (address) {
        return _getShareTokenStorage().hookSetup.hookReceiver;
    }

    function transferWithChecks() external view virtual returns (bool) {
        return _getShareTokenStorage().transferWithChecks;
    }

    /// @inheritdoc ERC20Upgradeable
    function transferFrom(address _from, address _to, uint256 _amount)
        public
        virtual
        override(ERC20Upgradeable, IERC20)
        returns (bool result)
    {
        ISiloConfig siloConfigCached = _crossNonReentrantBefore();

        result = ERC20Upgradeable.transferFrom(_from, _to, _amount);

        siloConfigCached.turnOffReentrancyProtection();
    }

    /// @inheritdoc ERC20Upgradeable
    function transfer(address _to, uint256 _amount)
        public
        virtual
        override(ERC20Upgradeable, IERC20)
        returns (bool result)
    {
        ISiloConfig siloConfigCached = _crossNonReentrantBefore();

        result = ERC20Upgradeable.transfer(_to, _amount);

        siloConfigCached.turnOffReentrancyProtection();
    }

    function approve(address spender, uint256 value) public override(ERC20Upgradeable, IERC20) returns (bool result) {
        NonReentrantLib.nonReentrant(_getSiloConfig());

        result = ERC20Upgradeable.approve(spender, value);
    }

    /// @inheritdoc IERC20Permit
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual override {
        NonReentrantLib.nonReentrant(_getSiloConfig());

        ERC20PermitUpgradeable.permit(owner, spender, value, deadline, v, r, s);
    }

    /// @dev decimals of share token
    function decimals() public view virtual override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        ISiloConfig.ConfigData memory configData = _getSiloConfig().getConfig(address(_silo()));
        return uint8(TokenHelper.assertAndGetDecimals(configData.token));
    }

    /// @dev Name convention:
    ///      NAME - asset name
    ///      SILO_ID - unique silo id
    ///
    ///      Protected deposit: "Silo Finance Non-borrowable NAME Deposit, SiloId: SILO_ID"
    ///      Borrowable deposit: "Silo Finance Borrowable NAME Deposit, SiloId: SILO_ID"
    ///      Debt: "Silo Finance NAME Debt, SiloId: SILO_ID"
    function name()
        public
        view
        virtual
        override(ERC20Upgradeable, IERC20Metadata)
        returns (string memory)
    {
        ISiloConfig.ConfigData memory configData = _getSiloConfig().getConfig(address(_silo()));
        string memory siloIdAscii = Strings.toString(_getSiloConfig().SILO_ID());

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
    function symbol()
        public
        view
        virtual
        override(ERC20Upgradeable, IERC20Metadata)
        returns (string memory)
    {
        ISiloConfig.ConfigData memory configData = _getSiloConfig().getConfig(address(_silo()));
        string memory siloIdAscii = Strings.toString(_getSiloConfig().SILO_ID());

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

    function balanceOfAndTotalSupply(address _account) public view virtual returns (uint256, uint256) {
        return (balanceOf(_account), totalSupply());
    }

    // solhint-disable-next-line func-name-mixedcase
    function __ShareToken_init(address _hookReceiver, uint24 _tokenType) internal virtual {
        __ERC20Permit_init(_NAME);
        __ERC20_init(_NAME, _NAME);

        ShareTokenStorage storage $ = _getShareTokenStorage();

        $.hookSetup.hookReceiver = _hookReceiver;
        $.hookSetup.tokenType = _tokenType;
        $.transferWithChecks = true;
    }

    /// @inheritdoc ERC20Upgradeable
    function _update(address from, address to, uint256 value) internal virtual override {
        if (value == 0) revert ZeroTransfer();

        _beforeTokenTransfer(from, to, value);

        ERC20Upgradeable._update(from, to, value);

        _afterTokenTransfer(from, to, value);
    }

    /// @dev By default, we do not have any hooks before token transfer. However,
    /// derived contracts can override this function if they need to execute any logic before token transfer.
    function _beforeTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual {}

    /// @dev Call an afterTokenTransfer hook if registered
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual {
        HookSetup memory setup = _getShareTokenStorage().hookSetup;

        uint256 action = Hook.shareTokenTransfer(setup.tokenType);

        if (!setup.hooksAfter.matchAction(action)) return;

        // report mint, burn or transfer
        // even if it is possible to leave silo in a middle of mint/burn, where we can have invalid state
        // you can not enter any function because of cross reentrancy check
        // invalid mid-state can be eg: in a middle of transitionCollateral, after burn but before mint
        IHookReceiver(setup.hookReceiver).afterAction(
            address(_silo()),
            action,
            abi.encodePacked(_sender, _recipient, _amount, balanceOf(_sender), balanceOf(_recipient), totalSupply())
        );
    }

    function _crossNonReentrantBefore()
        internal
        virtual
        returns (ISiloConfig siloConfigCached)
    {
        siloConfigCached = _getSiloConfig();
        siloConfigCached.turnOnReentrancyProtection();
    }

    /// @notice Call beforeQuote on solvency oracles
    /// @param _user user address for which the solvent check is performed
    function _callOracleBeforeQuote(address _user) internal virtual {
        (
            ISiloConfig.ConfigData memory collateralConfig,
            ISiloConfig.ConfigData memory debtConfig
        ) = _getSiloConfig().getConfigs(_user);

        collateralConfig.callSolvencyOracleBeforeQuote();
        debtConfig.callSolvencyOracleBeforeQuote();
    }

    /// @dev checks if operation is "real" transfer
    /// @param _sender sender address
    /// @param _recipient recipient address
    /// @return bool true if operation is real transfer, false if it is mint or burn
    function _isTransfer(address _sender, address _recipient) internal pure virtual returns (bool) {
        // in order this check to be true, it is required to have:
        // require(sender != address(0), "ERC20: transfer from the zero address");
        // require(recipient != address(0), "ERC20: transfer to the zero address");
        // on transfer. ERC20 has them, so we good.
        return _sender != address(0) && _recipient != address(0);
    }

    function _getSiloConfig() internal view virtual returns (ISiloConfig) {}
    function _onlySilo() internal view virtual {}
    function _silo() internal view virtual returns (ISilo) {}
}
