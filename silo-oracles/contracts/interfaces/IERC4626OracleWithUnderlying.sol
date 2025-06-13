// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

interface IERC4626OracleWithUnderlying is ISiloOracle {
    /// @param baseToken address of the vault itself, vault share is base token
    /// @param quoteToken address of asset in which price id denominated in
    /// @param vaultAsset vault underlying asset
    /// @param oracle oracle address to provide price for `vaultAsset`
    struct Config {
        IERC4626 baseToken;
        address quoteToken;
        address vaultAsset;
        ISiloOracle oracle;
    }

    event ERC4626OracleWithUnderlyingDeployed(address configAddress);

    error BaseAmountOverflow();
    error AssetNotSupported();
    error ZeroAddress();
    error ZeroQuote();
    error AssetZero();
    error QuoteTokenZero();

    function getConfig() external view returns (Config memory);
}
