// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISiloVault} from "./interfaces/ISiloVault.sol";
import {ISiloVaultsDeployer} from "./interfaces/ISiloVaultsDeployer.sol";
import {ISiloVaultsFactory} from "./interfaces/ISiloVaultsFactory.sol";

import {IdleVaultsFactory} from "./IdleVaultsFactory.sol";

/// @title SiloVaultsDeployer
/// @dev Forked with gratitude from Morpho Labs.
/// @author Silo Labs
/// @custom:contact security@silo.finance
/// @notice This contract allows to create SiloVault with IdleVault and to index them easily.
contract SiloVaultsDeployer is ISiloVaultsDeployer {
    ISiloVaultsFactory public immutable VAULT_FACTORY;
    IdleVaultsFactory public immutable IDLE_FACTORY;

    constructor(ISiloVaultsFactory _vaultFactory, IdleVaultsFactory _idleFactory) {
        VAULT_FACTORY = _vaultFactory;
        IDLE_FACTORY = _idleFactory;
    }

    /// @inheritdoc ISiloVaultsDeployer
    function createSiloVaultWithIdle(
        address _initialOwner,
        uint256 _initialTimelock,
        address _asset,
        string memory _name,
        string memory _symbol
    ) external virtual returns (ISiloVault siloVault, IERC4626 idleVault) {
        siloVault = VAULT_FACTORY.createSiloVault(_initialOwner, _initialTimelock, _asset, _name, _symbol);
        idleVault = IDLE_FACTORY.createIdleVault(siloVault);
    }

    /// @inheritdoc ISiloVaultsDeployer
    function isSiloVault(address _target) external view returns (bool) {
        return VAULT_FACTORY.isSiloVault(_target);
    }

    /// @inheritdoc ISiloVaultsDeployer
    function isIdleVault(address _target) external view returns (bool) {
        return IDLE_FACTORY.isIdleVault(_target);
    }
}
