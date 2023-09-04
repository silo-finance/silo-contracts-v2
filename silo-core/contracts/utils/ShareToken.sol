// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {
    ERC20Upgradeable,
    IERC20MetadataUpgradeable
} from "openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {StringsUpgradeable} from "openzeppelin-contracts-upgradeable/utils/StringsUpgradeable.sol";

import {ISiloFactory} from "../interfaces/ISiloFactory.sol";
import {IHookReceiver} from "../interfaces/IHookReceiver.sol";
import {IShareToken, ISilo} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../SiloConfig.sol";
import {TokenHelper} from "../lib/TokenHelper.sol";

/// @title ShareToken
/// @notice Implements common interface for Silo tokens representing debt or collateral positions.
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
abstract contract ShareToken is ERC20Upgradeable, IShareToken {
    ISiloFactory public immutable factory;

    /// @notice Silo address for which tokens was deployed
    ISilo public silo;

    /// @notice Address of hook contract called on each token transfer, mint and burn
    address public hookReceiver;

    /// @dev decimals that match the original asset decimals
    uint8 internal _decimals;

    error OnlySilo();

    modifier onlySilo() {
        if (msg.sender != address(silo)) revert OnlySilo();

        _;
    }

    /// @dev Token is always deployed for specific Silo and asset
    constructor(ISiloFactory _factory) {
        factory = _factory;
    }

    /// @param _silo Silo address for which tokens was deployed
    // solhint-disable-next-line func-name-mixedcase
    function __ShareToken_init(ISilo _silo, address _hookReceiver) internal onlyInitializing {
        silo = _silo;
        hookReceiver = _hookReceiver;
    }

    /// @dev Name convention:
    ///      NAME - asset name
    ///      SILO_ID - unique silo id
    ///
    ///      Protected deposit: "Silo Finance Non-borrowable NAME Deposit, SiloId: SILO_ID"
    ///      Borrowable deposit: "Silo Finance Borrowable NAME Deposit, SiloId: SILO_ID"
    ///      Debt: "Silo Finance NAME Debt, SiloId: SILO_ID"
    // solhint-disable-next-line ordering
    function name() public view override(ERC20Upgradeable, IERC20MetadataUpgradeable) returns (string memory) {
        ISiloConfig siloConfig = silo.config();
        ISiloConfig.ConfigData memory configData = siloConfig.getConfig();
        string memory siloIdAscii = StringsUpgradeable.toString(siloConfig.SILO_ID());

        address token;
        string memory pre = "";
        string memory post = " Deposit, SiloId: ";

        if (address(this) == configData.protectedShareToken0) {
            token = configData.token0;
            pre = "Non-borrowable ";
        } else if (address(this) == configData.collateralShareToken0) {
            token = configData.token0;
            pre = "Borrowable ";
        } else if (address(this) == configData.debtShareToken0) {
            token = configData.token0;
            post = " Debt, SiloId:  ";
        } else if (address(this) == configData.protectedShareToken1) {
            token = configData.token1;
            pre = "Non-borrowable ";
        } else if (address(this) == configData.collateralShareToken1) {
            token = configData.token1;
            pre = "Borrowable ";
        } else if (address(this) == configData.debtShareToken1) {
            token = configData.token1;
            post = " Debt, SiloId:  ";
        }

        string memory tokenSymbol = TokenHelper.symbol(token);
        return string.concat("Silo Finance ", pre, tokenSymbol, post, siloIdAscii);
    }

    /// @dev Symbol convention:
    ///      SYMBOL - asset symbol
    ///      SILO_ID - unique silo id
    ///
    ///      Protected deposit: "nbSYMBOL-SILO_ID"
    ///      Borrowable deposit: "bSYMBOL-SILO_ID"
    ///      Debt: "dSYMBOL-SILO_ID"
    function symbol() public view override(ERC20Upgradeable, IERC20MetadataUpgradeable) returns (string memory) {
        ISiloConfig siloConfig = silo.config();
        ISiloConfig.ConfigData memory configData = siloConfig.getConfig();
        string memory siloIdAscii = StringsUpgradeable.toString(siloConfig.SILO_ID());

        address token;
        string memory pre;

        if (address(this) == configData.protectedShareToken0) {
            token = configData.token0;
            pre = "nb";
        } else if (address(this) == configData.collateralShareToken0) {
            token = configData.token0;
            pre = "b";
        } else if (address(this) == configData.debtShareToken0) {
            token = configData.token0;
            pre = "d";
        } else if (address(this) == configData.protectedShareToken1) {
            token = configData.token1;
            pre = "nb";
        } else if (address(this) == configData.collateralShareToken1) {
            token = configData.token1;
            pre = "b";
        } else if (address(this) == configData.debtShareToken1) {
            token = configData.token1;
            pre = "d";
        }

        string memory tokenSymbol = TokenHelper.symbol(token);
        return string.concat(pre, tokenSymbol, "-", siloIdAscii);
    }

    function balanceOfAndTotalSupply(address _account) public view returns (uint256, uint256) {
        return (balanceOf(_account), totalSupply());
    }

    /// @dev Call an afterTokenTransfer hook if registered and check minimum share requirement on mint/burn
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        if (hookReceiver != address(0)) {
            // report mint, burn or transfer
            hookReceiver.call( // solhint-disable-line avoid-low-level-calls
                abi.encodeCall(
                    IHookReceiver.afterTokenTransfer,
                    (_sender, balanceOf(_sender), _recipient, balanceOf(_recipient), totalSupply(), _amount)
                )
            );
        }
    }

    /// @dev checks if operation is "real" transfer
    /// @param _sender sender address
    /// @param _recipient recipient address
    /// @return bool true if operation is real transfer, false if it is mint or burn
    function _isTransfer(address _sender, address _recipient) internal pure returns (bool) {
        // in order this check to be true, is is required to have:
        // require(sender != address(0), "ERC20: transfer from the zero address");
        // require(recipient != address(0), "ERC20: transfer to the zero address");
        // on transfer. ERC20 has them, so we good.
        return _sender != address(0) && _recipient != address(0);
    }
}
