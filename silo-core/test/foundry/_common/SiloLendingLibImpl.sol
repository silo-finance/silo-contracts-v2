// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {AssetTypes} from "silo-core/contracts/lib/AssetTypes.sol";
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
        ISilo.Assets memory _totalDebt,
        uint256 _totalCollateralAssets
    ) external returns (uint256 borrowedAssets, uint256 borrowedShares) {
        ISilo.SiloStorage storage $ = SiloStorageLib.getSiloStorage();

        $.total[AssetTypes.DEBT].assets = _totalDebt.assets;

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

        _totalDebt.assets = $.total[AssetTypes.DEBT].assets;
    }
}
