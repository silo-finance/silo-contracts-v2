// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {OracleFactory} from "../../_common/OracleFactory.sol";
import {IFixedPricePTAMMOracleConfig} from "../../interfaces/IFixedPricePTAMMOracleConfig.sol";
import {FixedPricePTAMMOracle} from "./FixedPricePTAMMOracle.sol";
import {FixedPricePTAMMOracleConfig} from "./FixedPricePTAMMOracleConfig.sol";
import {IFixedPricePTAMMOracleFactory} from "../../interfaces/IFixedPricePTAMMOracleFactory.sol";
import {IFixedPricePTAMMOracle} from "../../interfaces/IFixedPricePTAMMOracle.sol";

contract FixedPricePTAMMOracleFactory is Create2Factory, OracleFactory, IFixedPricePTAMMOracleFactory {
    constructor() OracleFactory(address(new FixedPricePTAMMOracle())) {
        // noting to configure
    }

    function create(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config, bytes32 _externalSalt)
        external
        virtual
        returns (IFixedPricePTAMMOracle oracle)
    {
        bytes32 id = hashConfig(_config);

        IFixedPricePTAMMOracleConfig oracleConfig = IFixedPricePTAMMOracleConfig(getConfigAddress[id]);

        if (address(oracleConfig) != address(0)) {
            // config already exists, so oracle exists as well
            return IFixedPricePTAMMOracle(getOracleAddress[address(oracleConfig)]);
        }

        verifyConfig(_config);

        oracleConfig = new FixedPricePTAMMOracleConfig(_config);
        oracle = IFixedPricePTAMMOracle(Clones.cloneDeterministic(ORACLE_IMPLEMENTATION, _salt(_externalSalt)));

        _saveOracle(address(oracle), address(oracleConfig), id);

        oracle.initialize(oracleConfig);
    }

    function predictAddress(address _deployer, bytes32 _externalSalt)
        external
        view
        returns (address predictedAddress)
    {
        require(_deployer != address(0), DeployerCannotBeZero());

        predictedAddress =
            Clones.predictDeterministicAddress(ORACLE_IMPLEMENTATION, _createSalt(_deployer, _externalSalt));
    }

    function hashConfig(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config)
        public
        view
        virtual
        returns (bytes32 configId)
    {
        configId = keccak256(abi.encode(_config));
    }

    function verifyConfig(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) public view virtual {
        require(_config.ptUnderlyingQuoteToken != address(0), AddressZero());
        require(_config.ptToken != address(0), AddressZero());
        require(_config.ptUnderlyingQuoteToken != _config.ptToken, TokensAreTheSame());
    }
}
