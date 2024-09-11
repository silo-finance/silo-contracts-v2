// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ISilo} from "../interfaces/ISilo.sol";
import {IShareToken} from "../interfaces/IShareToken.sol";
import {ISiloConfig} from "../interfaces/ISiloConfig.sol";

import {ShareTokenLib} from "./ShareTokenLib.sol";
import {CallBeforeQuoteLib} from "./CallBeforeQuoteLib.sol";
import {SiloSolvencyLib} from "./SiloSolvencyLib.sol";

library ShareCollateralTokenLib {
    using CallBeforeQuoteLib for ISiloConfig.ConfigData;

    /// @dev Check if sender is solvent after the transfer
    function afterTokenTransfer(address _sender, address _recipient, uint256 _amount) external {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();

        // for minting or burning, Silo is responsible to check all necessary conditions
        // for transfer make sure that _sender is solvent after transfer
        if (ShareTokenLib.isTransfer(_sender, _recipient) && $.transferWithChecks) {
            if (!_isSolventAfterCollateralTransfer(_sender)) revert IShareToken.SenderNotSolventAfterTransfer();
        }

        // ShareTokenLib.afterTokenTransfer(_sender, _recipient, _amount);
    }

    function _isSolventAfterCollateralTransfer(address _borrower) private returns (bool) {
        IShareToken.ShareTokenStorage storage $ = ShareTokenLib.getShareTokenStorage();
        ISiloConfig siloConfig = $.siloConfig;

        (
            ISiloConfig.DepositConfig memory deposit,
            ISiloConfig.ConfigData memory collateral,
            ISiloConfig.ConfigData memory debt
        ) = siloConfig.getConfigsForWithdraw(address($.silo), _borrower);

        // when deposit silo is collateral silo, that means this sToken is collateral for debt
        if (collateral.silo != deposit.silo) return true;

        ShareTokenLib.callOracleBeforeQuote(siloConfig, _borrower);

        return SiloSolvencyLib.isSolvent(collateral, debt, _borrower, ISilo.AccrueInterestInMemory.Yes);
    }
}
