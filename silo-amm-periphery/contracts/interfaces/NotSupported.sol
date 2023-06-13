// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ISiloAmmRouter.sol";

abstract contract NotSupported  is ISiloAmmRouter {
    function addLiquidity(address, address, uint, uint, uint, uint, address, uint)
        external pure virtual override returns (uint, uint, uint)
    {
        revert NOT_SUPPORTED();
    }

    function addLiquidityETH(address, uint, uint, uint, address, uint)
        external payable virtual override returns (uint, uint, uint)
    {
        revert NOT_SUPPORTED();
    }

    // **** REMOVE LIQUIDITY ****
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

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
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
