// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ISiloAmmRouter.sol";

/// @dev Liquidity management is not supported in Silo AMM because it is restricted to Silos only.
/// This contact has list of all methods that are not supported but they are part of UniswapV2 router interface.
/// However it should not affect swaps in any way.
abstract contract NotSupported  is ISiloAmmRouter {
    function addLiquidityETH(address, uint, uint, uint, address, uint)
        external payable virtual override returns (uint, uint, uint)
    {
        revert NOT_SUPPORTED();
    }

    function addLiquidity(address, address, uint, uint, uint, uint, address, uint)
        external pure virtual override returns (uint, uint, uint)
    {
        revert NOT_SUPPORTED();
    }

    function removeLiquidity(address, address, uint, uint, uint, address, uint)
        external pure virtual override returns (uint, uint)
    {
        revert NOT_SUPPORTED();
    }

    function removeLiquidityETH(address, uint, uint, uint, address, uint)
        external pure virtual override returns (uint, uint)
    {
        revert NOT_SUPPORTED();
    }

    function removeLiquidityWithPermit(address, address, uint, uint, uint, address, uint, bool, uint8, bytes32, bytes32)
        external pure virtual override returns (uint, uint)
    {
        revert NOT_SUPPORTED();
    }

    function removeLiquidityETHWithPermit(address, uint, uint, uint, address, uint, bool, uint8, bytes32, bytes32)
        external pure virtual override returns (uint, uint)
    {
        revert NOT_SUPPORTED();
    }

    function removeLiquidityETHSupportingFeeOnTransferTokens(address, uint, uint, uint, address, uint)
        external pure virtual override returns (uint)
    {
        revert NOT_SUPPORTED();
    }

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address, uint, uint, uint, address, uint, bool, uint8, bytes32, bytes32
    ) external pure virtual override returns (uint) {
        revert NOT_SUPPORTED();
    }
}
