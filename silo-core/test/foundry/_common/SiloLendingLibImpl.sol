// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";

contract SiloLendingLibImpl {
    function borrow(
        address _debtShareToken,
        address _token,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _borrower,
        address _spender,
        uint256 _totalDebt,
        uint256 _totalCollateralAssets
    ) external returns (uint256 borrowedAssets, uint256 borrowedShares) {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        $.totalAssets[ISilo.AssetType.Debt] = _totalDebt;
        $.totalAssets[ISilo.AssetType.Collateral] = _totalCollateralAssets;

        (borrowedAssets, borrowedShares) = SiloLendingLib.borrow(
            _debtShareToken,
            _token,
            _spender,
            ISilo.BorrowArgs({
                assets: _assets,
                shares: _shares,
                receiver: _receiver,
                borrower: _borrower
            })
        );
    }
}
