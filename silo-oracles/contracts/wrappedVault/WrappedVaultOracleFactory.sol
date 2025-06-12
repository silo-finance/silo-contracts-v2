// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {OracleFactory} from "../_common/OracleFactory.sol";
import {IWrappedVaultOracle} from "../interfaces/IWrappedVaultOracle.sol";
import {WrappedVaultOracle} from "../wrappedVault/WrappedVaultOracle.sol";
import {WrappedVaultOracleConfig} from "../wrappedVault/WrappedVaultOracleConfig.sol";

contract WrappedVaultOracleFactory is Create2Factory, OracleFactory {
    constructor() OracleFactory(address(new WrappedVaultOracle())) {
        // noting to configure
    }

    function create(
        IWrappedVaultOracle.WrappedVaultDeploymentConfig calldata _cfg,
        bytes32 _externalSalt
    ) external virtual returns (WrappedVaultOracle oracle) {
        bytes32 id = hashConfig(_cfg);
        WrappedVaultOracleConfig oracleConfig = WrappedVaultOracleConfig(getConfigAddress[id]);

        if (address(oracleConfig) != address(0)) {
            // config already exists, so oracle exists as well
            return WrappedVaultOracle(getOracleAddress[address(oracleConfig)]);
        }

        verifyConfig(_cfg);

        oracleConfig = new WrappedVaultOracleConfig(_cfg.oracle, _cfg.vault);
        oracle = WrappedVaultOracle(Clones.cloneDeterministic(ORACLE_IMPLEMENTATION, _salt(_externalSalt)));

        _saveOracle(address(oracle), address(oracleConfig), id);

        oracle.initialize(oracleConfig);
    }

    function hashConfig(IWrappedVaultOracle.WrappedVaultDeploymentConfig calldata _cfg)
        public
        virtual
        view
        returns (bytes32 configId)
    {
        configId = keccak256(abi.encode(_cfg));
    }

    function verifyConfig(IWrappedVaultOracle.WrappedVaultDeploymentConfig calldata _cfg)
        public
        view
        virtual
    {
        address vaultAsset = _cfg.vault.asset();

        if (vaultAsset == address(0)) revert IWrappedVaultOracle.AssetZero();
        if (_cfg.oracle.quoteToken() == address(0)) revert IWrappedVaultOracle.QuoteTokenZero();

        // sanity check for baseAsset
        _cfg.oracle.quote(1e15, vaultAsset);
    }
}
