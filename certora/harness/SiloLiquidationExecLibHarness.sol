// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import { ISiloConfig } from "silo-core/contracts/interfaces/ISiloConfig.sol";
import { SiloLiquidationExecLib } from "silo-core/contracts/lib/SiloLiquidationExecLib.sol";
import { ConfigForLib } from "./ConfigForLib.sol";

contract SiloLiquidationExecLibHarness is ConfigForLib {

    /// @dev it will be user responsibility to check profit
    function getExactLiquidationAmounts(
        address _user,
        uint256 _debtToCover,
        uint256 _liquidationFee,
        bool _selfLiquidation
    )
        external
        view
        returns (uint256 withdrawAssetsFromCollateral, uint256 withdrawAssetsFromProtected, uint256 repayDebtAssets)
    {
        ISiloConfig.ConfigData memory _collateralConfig = collateralConfig;
        ISiloConfig.ConfigData memory _debtConfig = debtConfig;

        return SiloLiquidationExecLib.getExactLiquidationAmounts
        (
            _collateralConfig,
            _debtConfig,
            _user,
            _debtToCover,
            _liquidationFee,
            _selfLiquidation
        );
    }
}