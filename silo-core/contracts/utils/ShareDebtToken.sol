// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20R} from "../interfaces/IERC20R.sol";
import {IShareToken, ShareToken, ISiloFactory, ISilo} from "./ShareToken.sol";

/// @title ShareDebtToken
/// @notice ERC20 compatible token representing debt position in Silo
/// @dev It implements reversed approvals and checks solvency of recipient on transfer.
///
/// It is assumed that there is no attack vector on taking someone else's debt because we don't see
/// economical reason why one would do such thing. For that reason anyone can transfer owner's token
/// to any recipient as long as receiving wallet approves the transfer. In other words, anyone can
/// take someone else's debt without asking.
/// @custom:security-contact security@silo.finance
contract ShareDebtToken is IERC20R, ShareToken {
    /// @dev maps _owner => _recipient => amount
    mapping(address => mapping(address => uint256)) private _receiveAllowances;

    error OwnerIsZero();
    error RecipientIsZero();
    error ShareTransferNotAllowed();
    error AmountExceedsAllowance();
    error RecipientNotSolventAfterTransfer();

    /// @param _silo Silo address for which tokens was deployed
    function initialize(ISilo _silo, address _hookReceiver) external virtual initializer {
        __ShareToken_init(_silo, _hookReceiver);
    }

    /// @inheritdoc IShareToken
    function mint(address _owner, address _spender, uint256 _amount) external virtual override onlySilo {
        if (_owner != _spender) _spendAllowance(_owner, _spender, _amount);
        _mint(_owner, _amount);
    }

    /// @inheritdoc IShareToken
    function burn(address _owner, address, uint256 _amount) external virtual override onlySilo {
        _burn(_owner, _amount);
    }

    /// @inheritdoc IERC20R
    function setReceiveApproval(address owner, uint256 _amount) external virtual override {
        _setReceiveApproval(owner, _msgSender(), _amount);
    }

    /// @inheritdoc IERC20R
    function decreaseReceiveAllowance(address _owner, uint256 _subtractedValue) public virtual override {
        uint256 currentAllowance = _receiveAllowances[_owner][_msgSender()];
        _setReceiveApproval(_owner, _msgSender(), currentAllowance - _subtractedValue);
    }

    /// @inheritdoc IERC20R
    function increaseReceiveAllowance(address _owner, uint256 _addedValue) public virtual override {
        uint256 currentAllowance = _receiveAllowances[_owner][_msgSender()];
        _setReceiveApproval(_owner, _msgSender(), currentAllowance + _addedValue);
    }

    /// @inheritdoc IERC20R
    function receiveAllowance(address _owner, address _recipient) public view virtual override returns (uint256) {
        return _receiveAllowances[_owner][_recipient];
    }

    /// @dev Set approval for `_owner` to send debt to `_recipient`
    /// @param _owner owner of debt token
    /// @param _recipient wallet that allows `_owner` to send debt to its wallet
    /// @param _amount amount of token allowed to be transferred
    function _setReceiveApproval(address _owner, address _recipient, uint256 _amount) internal virtual {
        if (_owner == address(0)) revert OwnerIsZero();
        if (_recipient == address(0)) revert RecipientIsZero();

        _receiveAllowances[_owner][_recipient] = _amount;

        emit ReceiveApproval(_owner, _recipient, _amount);
    }

    /// @dev Check receive allowance and if recipient is allowed to accept debt from silo
    function _beforeTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        // If we are minting or burning, Silo is responsible to check all necessary conditions
        if (_isTransfer(_sender, _recipient)) {
            // Silo forbids having debt and collateral position of the same asset in given Silo
            if (!silo.borrowPossible(_recipient)) revert ShareTransferNotAllowed();

            // _recipient must approve debt transfer, _sender does not have to
            uint256 currentAllowance = receiveAllowance(_sender, _recipient);
            if (currentAllowance < _amount) revert AmountExceedsAllowance();

            // There can't be an underflow in the subtraction because of the previous check
            unchecked {
                // update debt allowance
                _setReceiveApproval(_sender, _recipient, currentAllowance - _amount);
            }
        }
    }

    /// @dev Check if recipient is solvent after debt transfer
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        ShareToken._afterTokenTransfer(_sender, _recipient, _amount);

        // if we are minting or burning, Silo is responsible to check all necessary conditions
        // if we are NOT minting and not burning, it means we are transferring
        // make sure that _recipient is solvent after transfer
        if (_isTransfer(_sender, _recipient) && !silo.isSolvent(_recipient)) {
            revert RecipientNotSolventAfterTransfer();
        }
    }
}
