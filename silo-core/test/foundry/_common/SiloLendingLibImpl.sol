// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";

contract SiloLendingLibImpl {
    ISilo.Assets totalDebt;

    function borrow(
        address _debtShareToken,
        address _token,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        address _borrower,
        address _spender,
        ISilo.Assets memory _totalDebt,
        uint256 _totalCollateralAssets
    ) external returns (uint256 borrowedAssets, uint256 borrowedShares) {
        totalDebt.assets = _totalDebt.assets;

        (borrowedAssets, borrowedShares) = SiloLendingLib.borrow(
            _debtShareToken,
            _token,
            _spender,
            ISilo.BorrowArgs({
                assets: _assets,
                shares: _shares,
                receiver: _receiver,
                borrower: _borrower,
                sameAsset: false,
                leverage: false
            }),
            _totalCollateralAssets,
            totalDebt
        );

        _totalDebt.assets = totalDebt.assets;
    }
}
