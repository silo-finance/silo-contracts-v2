// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {DefaultingRepayLib} from "silo-core/contracts/hooks/defaulting/DefaultingRepayLib.sol";

/// @title DefaultingSiloLogic
/// @dev implements custom logic for Silo to do delegate calls
contract DefaultingSiloLogic {

    /// @dev This is a copy of Silo.sol repay() function with a single line changed.
    /// DefaultingRepayLib.repay() is used instead of Actions.repay().
    function repayDebtByDefaulting(uint256 _assets, address _borrower)
        external
        virtual
        returns (uint256 shares)
    {
        uint256 assets;

        (assets, shares) = DefaultingRepayLib.repay({
            _assets: _assets,
            _shares: 0,
            _borrower: _borrower,
            _repayer: msg.sender
        });

        emit ISilo.Repay(msg.sender, _borrower, assets, shares);
    }

    function decreaseTotalCollateralAssets(uint256 _assetsToRepay) external virtual {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        uint256 totalCollateralAssets = $.totalAssets[ISilo.AssetType.Collateral];
        require(totalCollateralAssets >= _assetsToRepay, ISilo.RepayTooHigh());

        $.totalAssets[ISilo.AssetType.Collateral] = totalCollateralAssets - _assetsToRepay;
    }
}
