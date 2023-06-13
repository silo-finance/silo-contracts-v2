// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "silo-amm-core/contracts/external/interfaces/IUniswapV2Pair.sol";

interface ISiloAmmPair is IUniswapV2Pair {
    function feeTo() external view returns (address);
    function silo() external view returns (address);
}
