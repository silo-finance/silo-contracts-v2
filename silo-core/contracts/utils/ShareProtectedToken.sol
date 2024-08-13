// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {SiloSolvencyLib} from "../lib/SiloSolvencyLib.sol";
import {SiloLensLib} from "../lib/SiloLensLib.sol";
import {IShareToken, ShareToken, ISilo} from "./ShareToken.sol";

/// @title ShareProtectedToken
/// @notice ERC20 compatible token representing collateral in Silo
/// @custom:security-contact security@silo.finance
contract ShareProtectedToken is ShareToken {
    using SiloLensLib for ISilo;

    /// @param _silo Silo address for which tokens was deployed
    function initialize(ISilo _silo, address _hookReceiver, uint24 _tokenType) external virtual initializer {
        __ShareToken_init(_silo, _hookReceiver, _tokenType);
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

    /// @dev Check if sender is solvent after the transfer
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        // for minting or burning, Silo is responsible to check all necessary conditions
        // for transfer make sure that _sender is solvent after transfer
        if (_isTransfer(_sender, _recipient) && transferWithChecks) {
            if (!_isSolventAfterCollateralTransfer(_sender)) revert SenderNotSolventAfterTransfer();
        }

        ShareToken._afterTokenTransfer(_sender, _recipient, _amount);
    }

    function _isSolventAfterCollateralTransfer(address _borrower) internal virtual returns (bool) {
        (
            ISiloConfig.DepositConfig memory deposit,
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt
        ) = siloConfig.getConfigsForWithdraw(address(silo), _borrower);

        // when deposit silo is collateral silo, that means this sToken is collateral for debt
        if (collateral.silo != deposit.silo) return true;

        _callOracleBeforeQuote(_borrower);

        return SiloSolvencyLib.isSolvent(collateral, debt, _borrower, ISilo.AccrueInterestInMemory.Yes);
    }
}
