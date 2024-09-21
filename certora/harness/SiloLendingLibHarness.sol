// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import { ISiloConfig } from "silo-core/contracts/interfaces/ISiloConfig.sol";
import { SiloLendingLib } from "silo-core/contracts/lib/SiloLendingLib.sol";
import { SiloMock } from "../mocks/SiloMock.sol";

contract SiloLendingLibHarness is SiloMock {
    function maxBorrow(
        ISiloConfig _siloConfig,
        address _borrower,
        bool _sameAsset
    )
        external
        view
        returns (uint256 assets, uint256 shares)
    {
        return SiloLendingLib.maxBorrow(
            _siloConfig,
            _borrower,
            _sameAsset
        );
    }

    function getLiquidityAndAssetsWithInterest(ISiloConfig.ConfigData memory _config)
        external view returns (uint256 liquidity, uint256 totalCollateralAssets, uint256 totalDebtAssets) {
            return SiloLendingLib.getLiquidityAndAssetsWithInterest(_config);
        }
}
