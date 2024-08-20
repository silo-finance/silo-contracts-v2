// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloSolvencyLib} from "../lib/SiloSolvencyLib.sol";
import {ShareToken} from "./ShareToken.sol";

contract VaultShareToken is ShareToken {
    function initialize(ISilo, address _hookReceiver, uint24 _tokenType) external {
        __ShareToken_init(_hookReceiver, _tokenType);
    }

    /// @inheritdoc IShareToken
    function mintShares(address _owner, address, uint256 _amount) external virtual override {
        // Prevent tokens `mint` on implementation contract
        if (_getInitializedVersion() == type(uint64).max) revert Forbidden();

        _mint(_owner, _amount);
    }

    /// @inheritdoc IShareToken
    function burn(address _owner, address _spender, uint256 _amount) external virtual {
        // Prevent `burn` on implementation contract
        if (_getInitializedVersion() == type(uint64).max) revert Forbidden();

        if (_owner != _spender) _spendAllowance(_owner, _spender, _amount);
        _burn(_owner, _amount);
    }

    function synchronizeHooks(uint24, uint24) external view {
        // Prevent `synchronizeHooks` on implementation contract
        if (_getInitializedVersion() == type(uint64).max) revert Forbidden();
    }

    function silo() external view returns (ISilo) {
        return _silo();
    }

    function hookSetup() public view override returns (HookSetup memory) {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        return IShareToken.HookSetup({
            hookReceiver: address($.sharedStorage.hookReceiver),
            hooksBefore: $.sharedStorage.hooksBefore,
            hooksAfter: $.sharedStorage.hooksAfter,
            tokenType: uint24(Hook.COLLATERAL_TOKEN)
        });
    }

    /// @dev Check if sender is solvent after the transfer
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        // for minting or burning, Silo is responsible to check all necessary conditions
        // for transfer make sure that _sender is solvent after transfer
        if (_isTransfer(_sender, _recipient) && _getShareTokenStorage().transferWithChecks) {
            if (!_isSolventAfterCollateralTransfer(_sender)) revert SenderNotSolventAfterTransfer();
        }

        ShareToken._afterTokenTransfer(_sender, _recipient, _amount);
    }

    function _isSolventAfterCollateralTransfer(address _borrower) internal virtual returns (bool) {
        (
            ISiloConfig.DepositConfig memory deposit,
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt
        ) = _getSiloConfig().getConfigsForWithdraw(address(_silo()), _borrower);

        // when deposit silo is collateral silo, that means this sToken is collateral for debt
        if (collateral.silo != deposit.silo) return true;

        _callOracleBeforeQuote(_borrower);

        return SiloSolvencyLib.isSolvent(collateral, debt, _borrower, ISilo.AccrueInterestInMemory.Yes);
    }

    function _getSiloConfig() internal view override returns (ISiloConfig) {
        return SiloStorageLib.siloConfig();
    }

    function _silo() internal view override returns (ISilo) {
        return ISilo(address(this));
    }
}
