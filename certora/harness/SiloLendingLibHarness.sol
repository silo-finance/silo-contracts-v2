// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import { ISiloConfig } from "silo-core/contracts/interfaces/ISiloConfig.sol";
import { SiloLendingLib } from "silo-core/contracts/lib/SiloLendingLib.sol";
import { SiloMock } from "../mocks/SiloMock.sol";

contract SiloLendingLibHarness is SiloMock {
    function maxBorrow(
        ISiloConfig.ConfigData memory _collateralConfig,
        ISiloConfig.ConfigData memory _debtConfig,
        address _borrower,
        uint256 _totalDebtAssets,
        uint256 _totalDebtShares,
        ISiloConfig _siloConfig
    )
        external
        view
        returns (uint256 assets, uint256 shares)
    {
        return SiloLendingLib.maxBorrow(
            _collateralConfig,
            _debtConfig,
            _borrower,
            _totalDebtAssets,
            _totalDebtShares,
            _siloConfig
        );
    }

    function getLiquidityAndAssetsWithInterest(ISiloConfig.ConfigData memory _config)
        external view returns (uint256 liquidity, uint256 totalCollateralAssets, uint256 totalDebtAssets) {
            return SiloLendingLib.getLiquidityAndAssetsWithInterest(_config);
        }
}