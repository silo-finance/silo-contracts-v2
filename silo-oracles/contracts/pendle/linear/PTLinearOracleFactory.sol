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

    function create(DeploymentConfig memory _config, bytes32 _externalSalt)
        external
        virtual
        returns (IPTLinearOracle oracle)
    {
        IPTLinearOracleConfig.OracleConfig memory oracleConfig = createAndVerifyConfig(_config);

        bytes32 id = hashConfig(oracleConfig);

        address existingOracle = resolveExistingOracle(id);

        if (existingOracle != address(0)) return IPTLinearOracle(existingOracle);

        oracleConfig.linearOracle = PENDLE_LINEAR_ORACLE_FACTORY.createWithPt({
            pt: _config.ptMarket, 
            baseDiscountPerYear: _config.maxYield
        });

        IPTLinearOracleConfig oracleConfigAddress = new PTLinearOracleConfig(oracleConfig);
        oracle = IPTLinearOracle(Clones.cloneDeterministic(ORACLE_IMPLEMENTATION, _salt(_externalSalt)));

        _saveOracle(address(oracle), address(oracleConfigAddress), id);

        oracle.initialize(oracleConfigAddress, _config.syRateMethod);
    }

    function predictAddress(DeploymentConfig memory _config, address _deployer, bytes32 _externalSalt)
        external
        view
        returns (address predictedAddress)
    {
        IPTLinearOracleConfig.OracleConfig memory oracleConfig = createAndVerifyConfig(_config);

        bytes32 id = hashConfig(oracleConfig);
        address existingOracle = resolveExistingOracle(id);
        if (existingOracle != address(0)) return existingOracle;

        require(_deployer != address(0), DeployerCannotBeZero());

        predictedAddress =
            Clones.predictDeterministicAddress(ORACLE_IMPLEMENTATION, _createSalt(_deployer, _externalSalt));
    }

    function hashConfig(IPTLinearOracleConfig.OracleConfig memory _config)
        public
        view
        virtual
        returns (bytes32 configId)
    {
        // for ID generation we using address(0) because linearOracleFactory deploy PTLinearOracle every time
        // even for the same config
        require(_config.linearOracle == address(0), AddressZero());

        configId = keccak256(abi.encode(_config));
    }

    function createAndVerifyConfig(DeploymentConfig memory _config)
        public
        view
        virtual
        returns (IPTLinearOracleConfig.OracleConfig memory oracleConfig)
    {
        require(_config.maxYield < 1e18, InvalidMaxYield());

        require(_config.expectedUnderlyingToken != address(0), AddressZero());
        require(_config.hardcodedQuoteToken != address(0), AddressZero());
        require(bytes(_config.syRateMethod).length > 2, InvalidSyRateMethod()); // `f()` is the minimum length

        /*
            Pendle Markets can have multiple PTs (one per maturity). PTs are issued per tokenization 
            (underlying asset + maturity). Each maturity creates its own PT (and YT); PT price moves toward 
            1:1 with the underlying at that maturity.

            In case we will have different PT as expected, quote will fail, because base asset will not match.
        */
        (address syToken, address ptToken,) = IPendleMarketV3Like(_config.ptMarket).readTokens();

        oracleConfig = IPTLinearOracleConfig.OracleConfig({
            ptToken: ptToken,
            syToken: syToken,
            expectedUnderlyingToken: _config.expectedUnderlyingToken,
            hardcodedQuoteToken: _config.hardcodedQuoteToken,
            syRateMethodSelector: bytes4(keccak256(bytes(_config.syRateMethod))),
            linearOracle: address(0) // for ID generation we using address(0)
        });

        _verifyMarket(oracleConfig);
    }

    function resolveExistingOracle(bytes32 _configId) public view virtual returns (address oracle) {
        address oracleConfig = getConfigAddress[_configId];
        return oracleConfig == address(0) ? address(0) : getOracleAddress[oracleConfig];
    }

    function _verifyMarket(IPTLinearOracleConfig.OracleConfig memory _oracleConfig) internal view virtual {
        // check if syRateMethod is valid
        PTLinearOracle(ORACLE_IMPLEMENTATION).callForExchangeFactor(
            _oracleConfig.syToken, _oracleConfig.syRateMethodSelector
        );

        (, address assetAddress,) = IPendleSYTokenLike(_oracleConfig.syToken).assetInfo();

        require(assetAddress == _oracleConfig.expectedUnderlyingToken, AssetAddressMustBeOurUnderlyingToken());

        uint256 maturityDate = IPendlePTLike(_oracleConfig.ptToken).expiry();
        require(maturityDate != 0 && maturityDate < type(uint64).max, MaturityDateInvalid());
        require(maturityDate > block.timestamp, MaturityDateIsInThePast());
    }
}
