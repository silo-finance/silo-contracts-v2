// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import "./ShareToken.sol";

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

    /// @param _name token name
    /// @param _symbol token symbol
    /// @param _silo Silo address for which tokens was deployed
    /// @param _asset asset for which this tokens was deployed
    function initialize(string memory _name, string memory _symbol, ISilo _silo, address _asset) external initializer {
        __ShareToken_init(_name, _symbol, _silo, _asset);
    }

    /// @inheritdoc IShareToken
    function mint(address _owner, address, uint256 _amount) external override onlySilo {
        _mint(_owner, _amount);
    }

    /// @inheritdoc IShareToken
    function burn(address _owner, address _spender, uint256 _amount) external onlySilo {
        if (_owner != _spender) _spendAllowance(_owner, _spender, _amount);
        _burn(_owner, _amount);
    }

    function _beforeTokenTransfer(address _sender, address _recipient, uint256) internal view override {
        // if we minting or burning, Silo is responsible to check all necessary conditions
        if (!_isTransfer(_sender, _recipient)) {
            return;
        }

        // Silo forbids having debt and collateral position of the same asset in given Silo
        if (!silo.depositPossible(asset, _recipient)) revert ShareTransferNotAllowed();
    }

    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal override {
        ShareToken._afterTokenTransfer(_sender, _recipient, _amount);

        // if we minting or burning, Silo is responsible to check all necessary conditions
        // make sure that _sender is solvent after transfer
        if (_isTransfer(_sender, _recipient) && !silo.isSolvent(_sender)) {
            revert SenderNotSolventAfterTransfer();
        }
    }
}
