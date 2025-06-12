// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISiloOracle} from "../interfaces/ISiloOracle.sol";

contract WrappedVaultOracleConfig {
    /// @dev vault.asset()
    address private immutable _VAULT_ASSET; // solhint-disable-line var-name-mixedcase

    /// @dev oracle for underlying price
    ISiloOracle private immutable _ORACLE; // solhint-disable-line var-name-mixedcase

    /// @dev vault that is on top of price
    IERC4626 private immutable _VAULT; // solhint-disable-line var-name-mixedcase

    /// @dev all verification should be done by factory
    constructor(ISiloOracle _oracle, IERC4626 _vault) {
        VAULT = _vault;
        _ORACLE = _oracle;
        _VAULT_ASSET = _vault.asset();
    }

    function getConfig() external view returns (ISiloOracle oracle, IERC4626 vault, address vaultAsset) {
        return (_ORACLE, _VAULT, _VAULT_ASSET);
    }
}
