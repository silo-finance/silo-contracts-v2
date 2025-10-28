// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

// solhint-disable ordering

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {Address} from "openzeppelin5/utils/Address.sol";

import {ISiloConfig} from "../../../interfaces/ISiloConfig.sol";
import {ISilo} from "../../../interfaces/ISilo.sol";
import {IShareToken} from "../../../interfaces/IShareToken.sol";
import {IHookReceiver} from "../../../interfaces/IHookReceiver.sol";

import {Hook} from "../../../lib/Hook.sol";
import {ShareTokenLib} from "../../../lib/ShareTokenLib.sol";
import {RepayNoTransferLib} from "./RepayNoTransferLib.sol";

/// @dev This is 1 to 1 copy of lib/Actions.sol repay() function.
library RepayActionLib {
    using Address for address;
    using SafeERC20 for IERC20;
    using Hook for uint256;
    using Hook for uint24;

    /// @notice Repays a given asset amount and returns the equivalent number of shares
    /// @param _assets Amount of assets to be repaid
    /// @param _borrower Address of the borrower whose debt is being repaid
    /// @param _repayer Address of the repayer who repay debt
    /// @return assets number of assets that had been repay
    /// @return shares number of shares that had been repay
    // solhint-disable-next-line function-max-lines
    function repay(
        uint256 _assets,
        uint256 _shares,
        address _borrower,
        address _repayer
    )
        external
        returns (uint256 assets, uint256 shares)
    {
        IShareToken.ShareTokenStorage storage _shareStorage = ShareTokenLib.getShareTokenStorage();

        if (_shareStorage.hookSetup.hooksBefore.matchAction(Hook.REPAY)) {
            bytes memory data = abi.encodePacked(_assets, _shares, _borrower, _repayer);
            IHookReceiver(_shareStorage.hookSetup.hookReceiver).beforeAction(address(this), Hook.REPAY, data);
        }

        ISiloConfig siloConfig = _shareStorage.siloConfig;

        siloConfig.turnOnReentrancyProtection();
        siloConfig.accrueInterestForSilo(address(this));

        (address debtShareToken, address debtAsset) = siloConfig.getDebtShareTokenAndAsset(address(this));

        (assets, shares) = RepayNoTransferLib.repay(
            IShareToken(debtShareToken), debtAsset, _assets, _shares, _borrower, _repayer
        );

        siloConfig.turnOffReentrancyProtection();

        if (_shareStorage.hookSetup.hooksAfter.matchAction(Hook.REPAY)) {
            bytes memory data = abi.encodePacked(_assets, _shares, _borrower, _repayer, assets, shares);
            IHookReceiver(_shareStorage.hookSetup.hookReceiver).afterAction(address(this), Hook.REPAY, data);
        }
    }
}
