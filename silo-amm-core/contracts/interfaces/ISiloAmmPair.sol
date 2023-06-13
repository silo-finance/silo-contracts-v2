// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import "../external/interfaces/IUniswapV2Pair.sol";

interface ISiloAmmPair is IUniswapV2Pair {
    enum OracleSetup { NONE, BOTH, FOR_TOKEN0, FOR_TOKEN1 }

    error ONLY_SILO();
    error NOT_SUPPORTED();

    error ZERO_ADDRESS();
    error LOCKED();
    error TRANSFER_FAILED();
    error OVERFLOW();
    error PERCENT_OVERFLOW();
    error INSUFFICIENT_LIQUIDITY_MINTED();
    error INSUFFICIENT_LIQUIDITY_BURNED();
    error INSUFFICIENT_OUTPUT_AMOUNT();
    error INSUFFICIENT_LIQUIDITY();
    error INVALID_TO();
    error INVALID_OUT();
    error INSUFFICIENT_INPUT_AMOUNT();
    error K();

    function feeTo() external view returns (address);
    function silo() external view returns (address);
}
