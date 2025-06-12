// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

interface IWrappedVaultOracle {
    struct WrappedVaultDeploymentConfig {
        ISiloOracle oracle;
        IERC4626 vault;
    }

    struct Config {
        address vaultAsset;
        address quoteToken;
        ISiloOracle oracle;
        IERC4626 vault;
    }

    event WrappedVaultOracleDeployed(address configAddress);

    error BaseAmountOverflow();
    error AssetNotSupported();
    error ZeroQuote();
    error AssetZero();
    error QuoteTokenZero();
}
