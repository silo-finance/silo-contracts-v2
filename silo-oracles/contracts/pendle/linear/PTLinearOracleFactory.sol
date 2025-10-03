// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {Create2Factory} from "common/utils/Create2Factory.sol";
import {OracleFactory} from "../../_common/OracleFactory.sol";

import {PTLinearOracle} from "./PTLinearOracle.sol";
import {PTLinearOracleConfig} from "./PTLinearOracleConfig.sol";
import {IPTLinearOracleFactory} from "../../interfaces/IPTLinearOracleFactory.sol";
import {IPTLinearOracle} from "../../interfaces/IPTLinearOracle.sol";
import {IPTLinearOracleConfig} from "../../interfaces/IPTLinearOracleConfig.sol";

import {IPendleMarketV3Like} from "../interfaces/IPendleMarketV3Like.sol";
import {IPendleSYTokenLike} from "../interfaces/IPendleSYTokenLike.sol";
import {IPendlePTLike} from "../interfaces/IPendlePTLike.sol";
import {ISparkLinearDiscountOracleFactory} from "../interfaces/ISparkLinearDiscountOracleFactory.sol";

contract PTLinearOracleFactory is Create2Factory, OracleFactory, IPTLinearOracleFactory {
    ISparkLinearDiscountOracleFactory public immutable PENDLE_LINEAR_ORACLE_FACTORY;

    constructor(address _pendleLinearOracleFactory) OracleFactory(address(new PTLinearOracle())) {
        require(_pendleLinearOracleFactory != address(0), AddressZero());

        PENDLE_LINEAR_ORACLE_FACTORY = ISparkLinearDiscountOracleFactory(_pendleLinearOracleFactory);
    }

    /// @inheritdoc IPTLinearOracleFactory
    function create(DeploymentConfig memory _deploymentConfig, bytes32 _externalSalt)
        external
        virtual
        returns (IPTLinearOracle oracle)
    {
        bytes32 id = hashConfig(_deploymentConfig);

        address existingOracle = resolveExistingOracle(id);

        if (existingOracle != address(0)) return IPTLinearOracle(existingOracle);

        IPTLinearOracleConfig.OracleConfig memory oracleConfig = createAndVerifyOracleConfig(_deploymentConfig);

        IPTLinearOracleConfig oracleConfigAddress = new PTLinearOracleConfig(oracleConfig);
        oracle = IPTLinearOracle(Clones.cloneDeterministic(ORACLE_IMPLEMENTATION, _salt(_externalSalt)));

        _saveOracle(address(oracle), address(oracleConfigAddress), id);

        oracle.initialize(oracleConfigAddress);
    }

    /// @inheritdoc IPTLinearOracleFactory
    function predictAddress(DeploymentConfig memory _deploymentConfig, address _deployer, bytes32 _externalSalt)
        external
        view
        returns (address predictedAddress)
    {
        bytes32 id = hashConfig(_deploymentConfig);
        address existingOracle = resolveExistingOracle(id);
        if (existingOracle != address(0)) return existingOracle;

        require(_deployer != address(0), DeployerCannotBeZero());

        predictedAddress =
            Clones.predictDeterministicAddress(ORACLE_IMPLEMENTATION, _createSalt(_deployer, _externalSalt));
    }

    function hashConfig(DeploymentConfig memory _deploymentConfig) public view virtual returns (bytes32 configId) {
        configId = keccak256(abi.encode(_deploymentConfig));
    }

    function createAndVerifyOracleConfig(DeploymentConfig memory _deploymentConfig)
        public
        virtual
        returns (IPTLinearOracleConfig.OracleConfig memory oracleConfig)
    {
        require(_deploymentConfig.maxYield < 1e18, InvalidMaxYield());
        require(_deploymentConfig.ptToken != address(0), AddressZero());

        oracleConfig = IPTLinearOracleConfig.OracleConfig({
            ptToken: _deploymentConfig.ptToken,
            hardcodedQuoteToken: _deploymentConfig.hardcodedQuoteToken,
            linearOracle: PENDLE_LINEAR_ORACLE_FACTORY.createWithPt({
                ptToken: _deploymentConfig.ptToken,
                baseDiscountPerYear: _deploymentConfig.maxYield
            })
        });

        _verifyOracleConfig(oracleConfig);
    }

    function resolveExistingOracle(bytes32 _configId) public view virtual returns (address oracle) {
        address oracleConfig = getConfigAddress[_configId];
        return oracleConfig == address(0) ? address(0) : getOracleAddress[oracleConfig];
    }

    function _verifyOracleConfig(IPTLinearOracleConfig.OracleConfig memory _oracleConfig) internal view virtual {
        uint256 maturityDate = IPendlePTLike(_oracleConfig.ptToken).expiry();
        require(maturityDate != 0 && maturityDate < type(uint64).max, MaturityDateInvalid());
        require(maturityDate > block.timestamp, MaturityDateIsInThePast());

        require(_oracleConfig.hardcodedQuoteToken != address(0), AddressZero());
        require(_oracleConfig.linearOracle != address(0), LinearOracleCannotBeZero());
    }
}
