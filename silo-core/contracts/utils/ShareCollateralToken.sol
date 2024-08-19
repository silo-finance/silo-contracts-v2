// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ISiloConfig} from "../interfaces/ISiloConfig.sol";
import {ShareTokenLib} from "../lib/ShareTokenLib.sol";
import {ShareCollateralTokenLib} from "../lib/ShareCollateralTokenLib.sol";
import {SiloSolvencyLib} from "../lib/SiloSolvencyLib.sol";
import {SiloLensLib} from "../lib/SiloLensLib.sol";
import {IShareToken, ShareToken, ISilo} from "./ShareToken.sol";

/// @title ShareCollateralToken
/// @notice ERC20 compatible token representing collateral in Silo
/// @custom:security-contact security@silo.finance
contract ShareCollateralToken is ShareToken {
    using SiloLensLib for ISilo;

    /// @dev Check if sender is solvent after the transfer
    function _afterTokenTransfer(address _sender, address _recipient, uint256 _amount) internal virtual override {
        ShareCollateralTokenLib.afterTokenTransfer(_sender, _recipient, _amount);
    }
}
