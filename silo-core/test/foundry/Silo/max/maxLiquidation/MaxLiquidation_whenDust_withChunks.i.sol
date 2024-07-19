// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";

import {MaxLiquidationDustTest} from "./MaxLiquidation_whenDust.i.sol";

/*
    forge test -vv --ffi --mc MaxLiquidationDustWithChunksTest

    this tests are MaxLiquidationDustTest cases, difference is, we splitting max liquidation in chunks
*/
contract MaxLiquidationDustWithChunksTest is MaxLiquidationDustTest {
    using SiloLensLib for ISilo;

    function _executeLiquidation(bool _sameToken, bool _receiveSToken)
        internal
        override
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        (
            uint256 collateralToLiquidate, uint256 debtToCover
        ) = partialLiquidation.maxLiquidation(address(silo1), borrower);

        emit log_named_decimal_uint("[DustWithChunks] collateralToLiquidate", collateralToLiquidate, 18);
        emit log_named_decimal_uint("[DustWithChunks] debtToCover", debtToCover, 18);
        emit log_named_decimal_uint("[DustWithChunks] ltv before", silo0.getLtv(borrower), 16);

        for (uint256 i; i < 5; i++) {
            emit log_named_uint("[DustWithChunks] case ------------------------", i);
            bool isSolvent = silo0.isSolvent(borrower);

            if (isSolvent) revert("it should be NOT possible to liquidate with chunk, so why user solvent?");

            uint256 testDebtToCover = _calculateChunk(debtToCover, i);
            emit log_named_uint("[DustWithChunks] testDebtToCover", testDebtToCover);

            _liquidationCallReverts(testDebtToCover, _sameToken, _receiveSToken);
        }

        // only full is possible
        return _liquidationCall(debtToCover, _sameToken, _receiveSToken);
    }

    function _liquidationCallReverts(uint256 _debtToCover, bool _sameToken, bool _receiveSToken) private {
        vm.expectRevert(IPartialLiquidation.DebtToCoverTooSmall.selector);

        partialLiquidation.liquidationCall(
            address(silo1),
            address(_sameToken ? token1 : token0),
            address(token1),
            borrower,
            _debtToCover,
            _receiveSToken
        );
    }
}
