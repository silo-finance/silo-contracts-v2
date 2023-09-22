// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

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
    /// @dev ERC4626 decimal offset
    /// see https://docs.openzeppelin.com/contracts/4.x/erc4626 for details
    uint8 internal constant _DECIMALS_OFFSET = 2;

    /// @notice Silo address for which tokens was deployed
    ISilo public silo;

    /// @notice Address of hook contract called on each token transfer, mint and burn
    address public hookReceiver;

    error OnlySilo();

    modifier onlySilo() {
        if (msg.sender != address(silo)) revert OnlySilo();

        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IShareToken
    function liquidationTransfer(address _owner, address _recipient, uint256 _amount) external virtual onlySilo {
        _transfer(_owner, _recipient, _amount);
    }

    /// @dev decimals of share token
    function decimals() public view virtual override(ERC20Upgradeable, IERC20MetadataUpgradeable) returns (uint8) {
        ISiloConfig siloConfig = silo.config();
        ISiloConfig.ConfigData memory configData = siloConfig.getConfig(address(silo));

        return uint8(TokenHelper.assertAndGetDecimals(configData.token)) + _DECIMALS_OFFSET;
    }

    /// @dev Name convention:
    ///      NAME - asset name
    ///      SILO_ID - unique silo id
    ///
    ///      Protected deposit: "Silo Finance Non-borrowable NAME Deposit, SiloId: SILO_ID"
    ///      Borrowable deposit: "Silo Finance Borrowable NAME Deposit, SiloId: SILO_ID"
    ///      Debt: "Silo Finance NAME Debt, SiloId: SILO_ID"
    function name() public view virtual override(ERC20Upgradeable, IERC20MetadataUpgradeable) returns (string memory) {
        ISiloConfig siloConfig = silo.config();
        ISiloConfig.ConfigData memory configData = siloConfig.getConfig(address(silo));
        string memory siloIdAscii = StringsUpgradeable.toString(siloConfig.SILO_ID());

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
        override(ERC20Upgradeable, IERC20MetadataUpgradeable)
        returns (string memory)
    {
        ISiloConfig siloConfig = silo.config();
        ISiloConfig.ConfigData memory configData = siloConfig.getConfig(address(silo));
        string memory siloIdAscii = StringsUpgradeable.toString(siloConfig.SILO_ID());

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

    /// @param _silo Silo address for which tokens was deployed
    // solhint-disable-next-line func-name-mixedcase
    function __ShareToken_init(ISilo _silo, address _hookReceiver) internal virtual onlyInitializing {
        silo = _silo;
        hookReceiver = _hookReceiver;
    }
    
    /// @dev Call an afterTokenTransfer hook if registered and check minimum share requirement on mint/burn
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        if (hookReceiver == address(0)) return;

        // report mint, burn or transfer
        (bool resultIgnored,) = hookReceiver.call( // solhint-disable-line avoid-low-level-calls
            abi.encodeCall(
                IHookReceiver.afterTokenTransfer,
                (_sender, balanceOf(_sender), _recipient, balanceOf(_recipient), totalSupply(), _amount)
            )
        );

        resultIgnored; // this is to fix: Warning (2072): Unused local variable
    }

    /// @dev checks if operation is "real" transfer
    /// @param _sender sender address
    /// @param _recipient recipient address
    /// @return bool true if operation is real transfer, false if it is mint or burn
    function _isTransfer(address _sender, address _recipient) internal pure virtual returns (bool) {
        // in order this check to be true, is is required to have:
        // require(sender != address(0), "ERC20: transfer from the zero address");
        // require(recipient != address(0), "ERC20: transfer to the zero address");
        // on transfer. ERC20 has them, so we good.
        return _sender != address(0) && _recipient != address(0);
    }
}
