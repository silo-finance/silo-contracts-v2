// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20R} from "../interfaces/IERC20R.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {SiloLensLib} from "../lib/SiloLensLib.sol";
import {IShareToken, ShareToken, ISilo} from "./ShareToken.sol";
import {NonReentrantLib} from "../lib/NonReentrantLib.sol";
import {ShareTokenLib} from "../lib/ShareTokenLib.sol";
import {ShareDebtTokenLib} from "../lib/ShareDebtTokenLib.sol";
import {ERC20Lib} from "../utils/siloERC20/lib/ERC20Lib.sol";

/// @title ShareDebtToken
/// @notice ERC20 compatible token representing debt in Silo
/// @dev It implements reversed approvals and checks solvency of recipient on transfer.
///
/// It is assumed that there is no attack vector on taking someone else's debt because we don't see
/// economical reason why one would do such thing. For that reason anyone can transfer owner's token
/// to any recipient as long as receiving wallet approves the transfer. In other words, anyone can
/// take someone else's debt without asking.
/// @custom:security-contact security@silo.finance
contract ShareDebtToken is IERC20R, ShareToken {
    error NotAvailable();

    using SiloLensLib for ISilo;

    /// @param _silo Silo address for which tokens was deployed
    function initialize(ISilo _silo, address _hookReceiver, uint24 _tokenType) external virtual initializer {
        __ShareToken_init(_silo, _hookReceiver, _tokenType);
    }

    function forwardTransferFromNoChecks(address, address, uint256) external pure override {
        revert NotAvailable();
    }

    /// @inheritdoc IERC20R
    function setReceiveApproval(address owner, uint256 _amount) external virtual override {
        NonReentrantLib.nonReentrant(ShareTokenLib.getShareTokenStorage().siloConfig);

        _setReceiveApproval(owner, ERC20Lib._msgSender(), _amount);
    }

    /// @inheritdoc IERC20R
    function decreaseReceiveAllowance(address _owner, uint256 _subtractedValue) public virtual override {
        NonReentrantLib.nonReentrant(ShareTokenLib.getShareTokenStorage().siloConfig);

        uint256 currentAllowance = ShareDebtTokenLib.receiveAllowance(_owner, ERC20Lib._msgSender());

        uint256 newAllowance;

        unchecked {
            // We will not underflow because of the condition `currentAllowance < _subtractedValue`
            newAllowance = currentAllowance < _subtractedValue ? 0 : currentAllowance - _subtractedValue;
        }

        _setReceiveApproval(_owner, ERC20Lib._msgSender(), newAllowance);
    }

    /// @inheritdoc IERC20R
    function increaseReceiveAllowance(address _owner, uint256 _addedValue) public virtual override {
        NonReentrantLib.nonReentrant(ShareTokenLib.getShareTokenStorage().siloConfig);

        uint256 currentAllowance = ShareDebtTokenLib.receiveAllowance(_owner, ERC20Lib._msgSender());

        _setReceiveApproval(_owner, ERC20Lib._msgSender(), currentAllowance + _addedValue);
    }

    /// @inheritdoc IERC20R
    function receiveAllowance(address _owner, address _recipient) public view virtual override returns (uint256) {
        return ShareDebtTokenLib.receiveAllowance(_owner, _recipient);
    }

    /// @dev Set approval for `_owner` to send debt to `_recipient`
    /// @param _owner owner of debt token
    /// @param _recipient wallet that allows `_owner` to send debt to its wallet
    /// @param _amount amount of token allowed to be transferred
    function _setReceiveApproval(address _owner, address _recipient, uint256 _amount) internal virtual {
        if (_owner == address(0)) revert IShareToken.OwnerIsZero();
        if (_recipient == address(0)) revert IShareToken.RecipientIsZero();

        IERC20R.Storage storage $ = ShareDebtTokenLib.getIERC20RStorage();

        $._receiveAllowances[_owner][_recipient] = _amount;

        emit ReceiveApproval(_owner, _recipient, _amount);
    }

    /// @dev Check receive allowance and if recipient is allowed to accept debt from silo
    function _beforeTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        (uint256 newDebtAllowance, bool updateRequired) = ShareDebtTokenLib.beforeTokenTransfer(_sender, _recipient, _amount);

        if (updateRequired) {
            _setReceiveApproval(_sender, _recipient, newDebtAllowance);
        }
    }

    /// @dev Check if recipient is solvent after debt transfer
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        ShareDebtTokenLib.afterTokenTransfer(_sender, _recipient, _amount);
    }
}
