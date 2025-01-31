// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

interface IOracleScalerFactory {
    event OracleScalerCreated(ISiloOracle indexed oracleScaler);

    /// @notice Create a new oracle scaler
    /// @param _quoteToken The quote token address to represent normalized price
    /// @return oracleScaler The oracle scaler created
    function createOracleScaler(
        IERC20Metadata _quoteToken
    ) external returns (ISiloOracle oracleScaler);
}
