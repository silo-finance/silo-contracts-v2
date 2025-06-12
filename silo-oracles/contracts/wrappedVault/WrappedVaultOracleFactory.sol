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
        ISiloOracle _oracle, 
        IERC4626 _vault,
        bytes32 _externalSalt
    ) external virtual returns (WrappedVaultOracle oracle) {
        bytes32 id = hashConfig(_config);
        WrappedVaultOracleConfig oracleConfig = WrappedVaultOracleConfig(getConfigAddress[id]);

        if (address(oracleConfig) != address(0)) {
            // config already exists, so oracle exists as well
            return WrappedVaultOracle(getOracleAddress[address(oracleConfig)]);
        }

        verifyConfig(_oracle, _vault);

        oracleConfig = new WrappedVaultOracleConfig(oracle, _vault);
        oracle = WrappedVaultOracle(Clones.cloneDeterministic(ORACLE_IMPLEMENTATION, _salt(_externalSalt)));

        _saveOracle(address(oracle), address(oracleConfig), id);

        oracle.initialize(oracleConfig);
    }

    function hashConfig(ISiloOracle _oracle, IERC4626 _vault)
        public
        virtual
        view
        returns (bytes32 configId)
    {
        configId = keccak256(abi.encode(_oracle, _vault));
    }

    function verifyConfig(ISiloOracle _oracle, IERC4626 _vault)
        public
        view
        virtual
    {

        if (_vault.asset() == address(0)) revert IWrappedVaultOracle.AssetZero();
        if (_oracle.quoteToken() == address(0)) revert IWrappedVaultOracle.QuoteTokenZero();
    }
}
