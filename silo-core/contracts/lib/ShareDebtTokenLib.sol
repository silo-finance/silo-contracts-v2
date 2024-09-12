// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {IERC20R} from "../interfaces/IERC20R.sol";

import {ShareTokenLib} from "./ShareTokenLib.sol";
import {CallBeforeQuoteLib} from "../lib/CallBeforeQuoteLib.sol";

// TODO do we need lib here? debt token size is not a concern, so maybe we can avoid this lib, unless we want to move
// before/after share to `_update`.

library ShareDebtTokenLib {
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    // keccak256(abi.encode(uint256(keccak256("silo.storage.ERC20R")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _STORAGE_LOCATION = 0x5a499b742bad5e18c139447ced974d19a977bcf86e03691ee458d10efcd04d00;

    function getIERC20RStorage() internal pure returns (IERC20R.Storage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _STORAGE_LOCATION
        }
    }

    /// @dev Check receive allowance and if recipient is allowed to accept debt from silo
    function beforeTokenTransfer(address _sender, address _recipient, uint256 _amount)
        internal
        returns (uint256 newDebtAllowance, bool updateRequired)
    {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();

        // If we are minting or burning, Silo is responsible to check all necessary conditions
        if (ShareTokenLib.isTransfer(_sender, _recipient)) {
            // Silo forbids having two debts and this condition will be checked inside `onDebtTransfer`.
            // If `_recepient` has no collateral silo set yet, it will be copiet from sender.
            $.siloConfig.onDebtTransfer(_sender, _recipient);

            // _recipient must approve debt transfer, _sender does not have to
            uint256 currentAllowance = receiveAllowance(_sender, _recipient);
            if (currentAllowance < _amount) revert IShareToken.AmountExceedsAllowance();

            // There can't be an underflow in the subtraction because of the previous check
            unchecked {
                // update debt allowance
                newDebtAllowance = currentAllowance - _amount;
            }

            updateRequired = true;
        }
    }

    /// @dev Check if recipient is solvent after debt transfer
    function afterTokenTransfer(address _sender, address _recipient, uint256 /* _amount */) internal {
        // debt transfer is such a rare use case and extra gas is worth additional security,
        // so we do not return even when _amount == 0

        // if we are minting or burning, Silo is responsible to check all necessary conditions
        // if we are NOT minting and not burning, it means we are transferring
        // make sure that _recipient is solvent after transfer
        if (ShareTokenLib.isTransfer(_sender, _recipient)) {
            IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
            ShareTokenLib.callOracleBeforeQuote($.siloConfig, _recipient);
            if (!$.silo.isSolvent(_recipient)) revert IShareToken.RecipientNotSolventAfterTransfer();
        }
    }

    function receiveAllowance(address _owner, address _recipient) internal view returns (uint256) {
        return getIERC20RStorage()._receiveAllowances[_owner][_recipient];
    }
}
