// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {IShareToken, ShareToken, ISiloFactory, ISilo} from "./ShareToken.sol";

/// @title ShareCollateralToken
/// @notice ERC20 compatible token representing collateral position in Silo
/// @custom:security-contact security@silo.finance
contract ShareCollateralToken is ShareToken {
    error SenderNotSolventAfterTransfer();
    error ShareTransferNotAllowed();

    /// @dev Token is always deployed for specific Silo and asset
    constructor(ISiloFactory _factory) ShareToken(_factory) {
        // all setup is done in parent contracts, nothing to do here
    }

    /// @param _silo Silo address for which tokens was deployed
    function initialize(ISilo _silo, address _hookReceiver) external virtual initializer {
        __ShareToken_init(_silo, _hookReceiver);
    }

    /// @inheritdoc IShareToken
    function mint(address _owner, address, uint256 _amount) external virtual override onlySilo {
        _mint(_owner, _amount);
    }

    /// @inheritdoc IShareToken
    function burn(address _owner, address _spender, uint256 _amount) external virtual onlySilo {
        if (_owner != _spender) _spendAllowance(_owner, _spender, _amount);
        _burn(_owner, _amount);
    }

    function _beforeTokenTransfer(address _sender, address _recipient, uint256) internal view virtual override {
        // if we minting or burning, Silo is responsible to check all necessary conditions
        if (_isTransfer(_sender, _recipient)) {
            // Silo forbids having debt and collateral position of the same asset in given Silo
            if (!silo.depositPossible(_recipient)) revert ShareTransferNotAllowed();
        }
    }

    /// @dev Check if sender is solvent after the transfer
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        // solhint-disable-previous-line ordering
        ShareToken._afterTokenTransfer(_sender, _recipient, _amount);

        // for minting or burning, Silo is responsible to check all necessary conditions
        // for transfer make sure that _sender is solvent after transfer
        if (_isTransfer(_sender, _recipient) && !silo.isSolvent(_sender)) revert SenderNotSolventAfterTransfer();
    }
}
