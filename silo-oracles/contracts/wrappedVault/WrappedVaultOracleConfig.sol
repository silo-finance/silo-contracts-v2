// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {IWrappedVaultOracle} from "../interfaces/IWrappedVaultOracle.sol";

contract WrappedVaultOracleConfig {
    /// @dev address of the vault itself, vault share is base token
    IERC4626 private immutable _VAULT; // solhint-disable-line var-name-mixedcase

    /// @dev quoteToken address of asset in which price id denominated in
    address private immutable _QUOTE_TOKEN; // solhint-disable-line var-name-mixedcase

    /// @dev vault.asset()
    address private immutable _VAULT_ASSET; // solhint-disable-line var-name-mixedcase

    /// @dev oracle address to provide price for `_VAULT_ASSET`
    ISiloOracle private immutable _ORACLE; // solhint-disable-line var-name-mixedcase


    /// @dev all verification should be done by factory
    constructor(ISiloOracle _oracle, IERC4626 _vault) {
        _VAULT = _vault;
        _ORACLE = _oracle;

        _VAULT_ASSET = _vault.asset();
        _QUOTE_TOKEN = _oracle.quoteToken();
    }

    function getConfig() external view returns (IWrappedVaultOracle.Config memory) {
        return IWrappedVaultOracle.Config({
            baseToken: _VAULT,
            quoteToken: _QUOTE_TOKEN,
            oracle: _ORACLE,
            vaultAsset: _VAULT_ASSET
        });
    }
}
