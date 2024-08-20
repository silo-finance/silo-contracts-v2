// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ERC20Permit, IERC20Permit} from "openzeppelin5/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20Metadata, IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

import {IHookReceiver} from "../interfaces/IHookReceiver.sol";
import {IShareToken, ISilo} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../SiloConfig.sol";
import {TokenHelper} from "../lib/TokenHelper.sol";
import {Hook} from "../lib/Hook.sol";
import {CallBeforeQuoteLib} from "../lib/CallBeforeQuoteLib.sol";
import {NonReentrantLib} from "../lib/NonReentrantLib.sol";
import {ShareTokenLib} from "../lib/ShareTokenLib.sol";
import {SiloERC20} from "../utils/siloERC20/SiloERC20.sol";
import {SiloERC20Permit} from "../utils/siloERC20/SiloERC20Permit.sol";
import {EIP712Lib} from "../utils/siloERC20/lib/EIP712Lib.sol";
import {ERC20Lib} from "../utils/siloERC20/lib/ERC20Lib.sol";


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
abstract contract ShareToken is Initializable, SiloERC20Permit, IShareToken {
    using Hook for uint24;
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    string private constant _NAME = "SiloShareToken";

    modifier onlySilo() {
        if (msg.sender != address(ShareTokenLib.getShareTokenStorage().silo)) revert OnlySilo();

        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() SiloERC20Permit() {
        ShareTokenLib.getShareTokenStorage().silo = ISilo(address(this)); // disable initializer
    }

    /// @param _silo Silo address for which tokens was deployed
    function initialize(ISilo _silo, address _hookReceiver, uint24 _tokenType) external virtual initializer {
        __ShareToken_init(_silo, _hookReceiver, _tokenType);
    }

    function silo() external view returns (ISilo) {
        return ShareTokenLib.getShareTokenStorage().silo;
    }

    function siloConfig() external view returns (ISiloConfig) {
        return ShareTokenLib.getShareTokenStorage().siloConfig;
    }

    /// @inheritdoc IShareToken
    function synchronizeHooks(uint24 _hooksBefore, uint24 _hooksAfter) external virtual onlySilo {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();

        $.hookSetup.hooksBefore = _hooksBefore;
        $.hookSetup.hooksAfter = _hooksAfter;
    }

    /// @inheritdoc IShareToken
    function forwardTransferFromNoChecks(address _from, address _to, uint256 _amount)
        external
        virtual
        onlySilo
    {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();

        $.transferWithChecks = false;
        _transfer(_from, _to, _amount);
        $.transferWithChecks = true;
    }

    function hookSetup() external view virtual returns (HookSetup memory) {
        return ShareTokenLib.getShareTokenStorage().hookSetup;
    }

    /// @inheritdoc SiloERC20
    function transferFrom(address _from, address _to, uint256 _amount)
        public
        virtual
        override(SiloERC20, IERC20)
        returns (bool result)
    {
        ISiloConfig siloConfigCached = _crossNonReentrantBefore();

        result = SiloERC20.transferFrom(_from, _to, _amount);

        siloConfigCached.turnOffReentrancyProtection();
    }

    /// @inheritdoc SiloERC20
    function transfer(address _to, uint256 _amount)
        public
        virtual
        override(SiloERC20, IERC20)
        returns (bool result)
    {
        ISiloConfig siloConfigCached = _crossNonReentrantBefore();

        result = SiloERC20.transfer(_to, _amount);

        siloConfigCached.turnOffReentrancyProtection();
    }

    function approve(address spender, uint256 value) public override(SiloERC20, IERC20) returns (bool result) {
        NonReentrantLib.nonReentrant(ShareTokenLib.getShareTokenStorage().siloConfig);

        result = SiloERC20.approve(spender, value);
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
        NonReentrantLib.nonReentrant(ShareTokenLib.getShareTokenStorage().siloConfig);

        SiloERC20Permit.permit(owner, spender, value, deadline, v, r, s);
    }

    /// @dev decimals of share token
    function decimals() public view virtual override(SiloERC20, IERC20Metadata) returns (uint8) {
        return ShareTokenLib.decimals();
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
        override(SiloERC20, IERC20Metadata)
        returns (string memory)
    {
        return ShareTokenLib.name();
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
        override(SiloERC20, IERC20Metadata)
        returns (string memory)
    {
        return ShareTokenLib.symbol();
    }

    function balanceOfAndTotalSupply(address _account) public view virtual returns (uint256, uint256) {
        return (balanceOf(_account), totalSupply());
    }

    /// @param _silo Silo address for which tokens was deployed
    // solhint-disable-next-line func-name-mixedcase
    function __ShareToken_init(ISilo _silo, address _hookReceiver, uint24 _tokenType) internal virtual {
        ShareTokenLib.__ShareToken_init(_silo, _hookReceiver, _tokenType);

        ERC20Lib.__ERC20_init(_NAME, _NAME);
        EIP712Lib.__EIP712_init(_NAME, "1");
    }

    /// @dev Call an afterTokenTransfer hook if registered
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        ShareTokenLib.afterTokenTransfer(_sender, _recipient, _amount);
    }

    function _crossNonReentrantBefore()
        internal
        virtual
        returns (ISiloConfig siloConfigCached)
    {
        siloConfigCached = ShareTokenLib.getShareTokenStorage().siloConfig;
        siloConfigCached.turnOnReentrancyProtection();
    }
}
