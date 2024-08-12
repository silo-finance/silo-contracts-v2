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

    function _executeLiquidation(bool _sameToken, bool _receiveSToken, bool _self)
        internal
        override
        returns (uint256 withdrawCollateral, uint256 repayDebtAssets)
    {
        (
            uint256 collateralToLiquidate, uint256 debtToCover, bool sTokenRequired
        ) = partialLiquidation.maxLiquidation(borrower);

        assertTrue(!sTokenRequired, "sTokenRequired not required");

        emit log_named_decimal_uint("[DustWithChunks] collateralToLiquidate", collateralToLiquidate, 18);
        emit log_named_decimal_uint("[DustWithChunks] debtToCover", debtToCover, 18);
        emit log_named_decimal_uint("[DustWithChunks] ltv before", silo0.getLtv(borrower), 16);

        uint256 sumOfCollateral;
        uint256 sumOfDebt;

        for (uint256 i; i < 5; i++) {
            emit log_named_uint("[DustWithChunks] case ------------------------", i);
            bool isSolvent = silo0.isSolvent(borrower);

            if (isSolvent && _self) break;
            if (isSolvent) revert("it should be NOT possible to liquidate with chunk, so why user solvent?");

            uint256 testDebtToCover = _calculateChunk(debtToCover, i);
            emit log_named_uint("[DustWithChunks] testDebtToCover", testDebtToCover);

            if (_self) {
                // self liquidation is always possible
                (uint256 c, uint256 d) = _liquidationCall(debtToCover, _sameToken, _receiveSToken, _self);
                sumOfCollateral += c;
                sumOfDebt += d;
            } else {
                _liquidationCallReverts(testDebtToCover, _sameToken, _receiveSToken, _self);
            }
        }

        if (_self) return (sumOfCollateral, sumOfDebt);

        // only full is possible
        return _liquidationCall(debtToCover, _sameToken, _receiveSToken, _self);
    }

    function _liquidationCallReverts(uint256 _debtToCover, bool _sameToken, bool _receiveSToken, bool _self) private {
        vm.expectRevert(IPartialLiquidation.DebtToCoverTooSmall.selector);

        if (_self) vm.prank(borrower);

        partialLiquidation.liquidationCall(
            address(_sameToken ? token1 : token0),
            address(token1),
            borrower,
            _debtToCover,
            _receiveSToken
        );
    }

    function _withChunks() internal pure override returns (bool) {
        return true;
    }
}
