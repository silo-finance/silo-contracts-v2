// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {OracleFactory} from "../../_common/OracleFactory.sol";
import {IFixedPricePTAMMOracleConfig} from "../../interfaces/IFixedPricePTAMMOracleConfig.sol";
import {FixedPricePTAMMOracle} from "./FixedPricePTAMMOracle.sol";
import {FixedPricePTAMMOracleConfig} from "./FixedPricePTAMMOracleConfig.sol";

contract FixedPricePTAMMOracleFactory is Create2Factory, OracleFactory {
    constructor() OracleFactory(address(new FixedPricePTAMMOracle())) {
        // noting to configure
    }

    function create(
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config,
        bytes32 _externalSalt
    ) external virtual returns (FixedPricePTAMMOracle oracle) {
        bytes32 id = hashConfig(_config);

        FixedPricePTAMMOracleConfig oracleConfig = FixedPricePTAMMOracleConfig(getConfigAddress[id]);

        if (address(oracleConfig) != address(0)) {
            // config already exists, so oracle exists as well
            return FixedPricePTAMMOracle(getOracleAddress[address(oracleConfig)]);
        }

        verifyConfig(_config);

        oracleConfig = new FixedPricePTAMMOracleConfig(_config);
        oracle = FixedPricePTAMMOracle(Clones.cloneDeterministic(ORACLE_IMPLEMENTATION, _salt(_externalSalt)));

        _saveOracle(address(oracle), address(oracleConfig), id);

        oracle.initialize(oracleConfig);
    }

    function hashConfig(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config)
        public
        virtual
        view
        returns (bytes32 configId)
    {
        configId = keccak256(abi.encode(_config));
    }

    function verifyConfig(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) public view virtual {
        if (_config.quoteToken == address(0)) revert AddressZero();
        if (_config.baseToken == address(0)) revert AddressZero();
        if (_config.quoteToken == _config.baseToken) revert TokensAreTheSame();
    }
}
