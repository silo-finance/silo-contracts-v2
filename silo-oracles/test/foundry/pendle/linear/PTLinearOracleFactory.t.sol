// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {Test} from "forge-std/Test.sol";

import {Initializable} from "openzeppelin5-upgradeable/proxy/utils/Initializable.sol";

import {IPTLinearOracleConfig} from "silo-oracles/contracts/interfaces/IPTLinearOracleConfig.sol";
import {IPTLinearOracleFactory} from "silo-oracles/contracts/interfaces/IPTLinearOracleFactory.sol";
import {IPTLinearOracle} from "silo-oracles/contracts/interfaces/IPTLinearOracle.sol";

import {PTLinearOracle} from "silo-oracles/contracts/pendle/linear/PTLinearOracle.sol";

import {PTLinearOracleFactory} from "silo-oracles/contracts/pendle/linear/PTLinearOracleFactory.sol";

import {IPendleMarketV3Like} from "silo-oracles/contracts/pendle/interfaces/IPendleMarketV3Like.sol";
import {IPendleSYTokenLike} from "silo-oracles/contracts/pendle/interfaces/IPendleSYTokenLike.sol";
import {IPendlePTLike} from "silo-oracles/contracts/pendle/interfaces/IPendlePTLike.sol";

import {SparkLinearDiscountOracleFactoryMock} from "./_common/SparkLinearDiscountOracleFactoryMock.sol";
import {PTLinearMocks} from "./_common/PTLinearMocks.sol";

/*
    FOUNDRY_PROFILE=oracles forge test --mc PTLinearOracleFactoryTest --ffi -vv
*/
contract PTLinearOracleFactoryTest is PTLinearMocks {
    PTLinearOracleFactory immutable factory;

    constructor() {
        factory = new PTLinearOracleFactory(address(new SparkLinearDiscountOracleFactoryMock()));
    }

    function setUp() public {
        vm.clearMockedCalls();
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_predictAddress_fuzz --ffi -vv
    */
    function test_ptLinear_predictAddress_fuzz(
        IPTLinearOracleFactory.DeploymentConfig memory _config,
        address _deployer,
        bytes32 _externalSalt
    ) public assumeValidConfig(_config) {
        vm.assume(_deployer != address(0));

        _doAllNecessaryMockCalls(_config);

        address predictedAddress = factory.predictAddress(_config, _deployer, _externalSalt);

        vm.prank(_deployer);
        address oracle = address(factory.create(_config, _externalSalt));

        assertEq(oracle, predictedAddress, "Predicted address does not match");

        address oracle2 = address(factory.create(_config, _externalSalt));

        address predictedAddress2 = factory.predictAddress(_config, _deployer, _externalSalt);

        assertEq(
            predictedAddress, predictedAddress2, "predicted addresses should be the same if we reuse the same config"
        );

        assertEq(oracle2, oracle, "Oracle addresses should be the same if we reuse the same config");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_resolveExistingOracle --ffi -vv
    */
    function test_ptLinear_resolveExistingOracle_fuzz(IPTLinearOracleFactory.DeploymentConfig memory _config)
        public
        assumeValidConfig(_config)
    {
        _doAllNecessaryMockCalls(_config);

        IPTLinearOracleConfig.OracleConfig memory oracleConfig = factory.createAndVerifyConfig(_config);

        bytes32 configId = factory.hashConfig(oracleConfig);

        address existingOracle = factory.resolveExistingOracle(configId);

        assertEq(existingOracle, address(0), "No existing oracle should be found");

        address oracle = address(factory.create(_config, bytes32(0)));

        existingOracle = factory.resolveExistingOracle(configId);
        assertEq(existingOracle, address(oracle), "Existing oracle should be found");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_reusableConfigs_fuzz --ffi -vv
    */
    function test_ptLinear_reusableConfigs_fuzz(
        IPTLinearOracleFactory.DeploymentConfig memory _config,
        address _deployer,
        bytes32 _externalSalt
    ) public assumeValidConfig(_config) {
        _doAllNecessaryMockCalls(_config);

        vm.prank(_deployer);
        address oracle1 = address(factory.create(_config, _externalSalt));

        // deployer does not matter here, because we use the same config
        address oracle2 = address(factory.create(_config, bytes32(0)));

        assertEq(oracle1, oracle2, "Oracle addresses should be the same if we reuse the same config");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_reorg --ffi -vv
    */
    function test_ptLinear_reorg(
        IPTLinearOracleFactory.DeploymentConfig memory _config1,
        IPTLinearOracleFactory.DeploymentConfig memory _config2,
        address _eoa1,
        address _eoa2
    ) public assumeValidConfig(_config1) assumeValidConfig(_config2) {
        vm.assume(_eoa1 != address(0));
        vm.assume(_eoa2 != address(0));
        vm.assume(_eoa1 != _eoa2);
        vm.assume(_hashConfig(_config1) != _hashConfig(_config2));

        _mockReadTokens();
        _mockReadSyRate();
        _mockExpiry();

        uint256 snapshot = vm.snapshotState();

        _mockAssetInfo(_config1.expectedUnderlyingToken);
        vm.prank(_eoa1);
        address oracle1 = address(factory.create(_config1, bytes32(0)));

        _mockAssetInfo(_config2.expectedUnderlyingToken);
        vm.prank(_eoa2);
        address oracle2 = address(factory.create(_config2, bytes32(0)));

        vm.revertToState(snapshot);

        vm.prank(_eoa1); // user1 but config2
        address oracle3 = address(factory.create(_config2, bytes32(0)));

        assertNotEq(oracle1, oracle2, "Oracle addresses should be different if we reorg");
        assertEq(oracle1, oracle3, "Oracle addresses should be the same for same user");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_verifyConfig_pass_fuzz --ffi -vv
    */
    function test_ptLinear_verifyConfig_pass_fuzz(IPTLinearOracleFactory.DeploymentConfig memory _config)
        public
        assumeValidConfig(_config)
    {
        _doAllNecessaryMockCalls(_config);

        factory.createAndVerifyConfig(_config);
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_createAndVerifyConfig_fail --ffi -vv
    */
    function test_skip_ptLinear_createAndVerifyConfig_fail() public {
        IPTLinearOracleFactory.DeploymentConfig memory config;

        config.maxYield = 1e18;
        vm.expectRevert(abi.encodeWithSelector(IPTLinearOracleFactory.InvalidMaxYield.selector));
        factory.createAndVerifyConfig(config);

        config.maxYield = 0.3e18;

        vm.expectRevert(abi.encodeWithSelector(IPTLinearOracleFactory.AddressZero.selector));
        factory.createAndVerifyConfig(config);

        config.expectedUnderlyingToken = makeAddr("underlyingToken");
        config.hardcodedQuoteToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(IPTLinearOracleFactory.AddressZero.selector));
        factory.createAndVerifyConfig(config);

        config.hardcodedQuoteToken = makeAddr("quoteToken");
        vm.expectRevert(abi.encodeWithSelector(IPTLinearOracleFactory.InvalidSyRateMethod.selector));
        factory.createAndVerifyConfig(config);

        config.syRateMethod = "exchangeRate()";
        config.ptMarket = makeAddr("ptMarket");
        _mockReadTokens(makeAddr("syToken"), address(2), address(3));
        vm.expectRevert(abi.encodeWithSelector(IPTLinearOracle.FailedToCallSyRateMethod.selector));
        factory.createAndVerifyConfig(config);

        _mockReadSyRate(0);
        vm.expectRevert(abi.encodeWithSelector(IPTLinearOracle.InvalidExchangeFactor.selector));
        factory.createAndVerifyConfig(config);

        _mockReadSyRate(0.3e18);
        _mockAssetInfo(makeAddr("differentUnderlyingToken"));
        vm.expectRevert(abi.encodeWithSelector(IPTLinearOracleFactory.AssetAddressMustBeOurUnderlyingToken.selector));
        factory.createAndVerifyConfig(config);

        _mockAssetInfo(makeAddr("underlyingToken"));
        vm.warp(100);
        _mockExpiry(makeAddr("ptToken"), block.timestamp);
        vm.expectRevert(abi.encodeWithSelector(IPTLinearOracleFactory.MaturityDateIsInThePast.selector));
        factory.createAndVerifyConfig(config);

        // factory.createAndVerifyConfig(config); // pass
        // TODO
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_hashConfig --ffi -vv
    */
    function test_ptLinear_hashConfig_fuzz(IPTLinearOracleConfig.OracleConfig memory _config) public view {
        _config.linearOracle = address(0); // hard requirement

        bytes32 configId = factory.hashConfig(_config);

        assertEq(configId, keccak256(abi.encode(_config)), "Config hash should match");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_implementation_canNotBeInit --ffi -vv
    */
    function test_ptLinear_implementation_canNotBeInit() public {
        address implementation = address(factory.ORACLE_IMPLEMENTATION());

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        IPTLinearOracle(implementation).initialize(IPTLinearOracleConfig(address(1)), "a()");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_disableInitializers --ffi -vv
    */
    function test_ptLinear_disableInitializers() public {
        PTLinearOracle oracle = new PTLinearOracle();

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        oracle.initialize(IPTLinearOracleConfig(address(1)), "f()");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_clone_alreadyInitialized --ffi -vv
    */
    function test_ptLinear_clone_alreadyInitialized() public {
        IPTLinearOracleFactory.DeploymentConfig memory config;

        _makeValidConfig(config);

        _doAllNecessaryMockCalls(config);

        address oracle = address(factory.create(config, bytes32(0)));

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        IPTLinearOracle(oracle).initialize(IPTLinearOracleConfig(address(1)), "f()");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptLinear_getConfig --ffi -vv
    */
    function test_ptLinear_getConfig(IPTLinearOracleFactory.DeploymentConfig memory _config)
        public
        assumeValidConfig(_config)
    {
        _doAllNecessaryMockCalls(_config);

        IPTLinearOracle oracle = factory.create(_config, bytes32(0));
        IPTLinearOracleConfig.OracleConfig memory cfg = oracle.oracleConfig().getConfig();

        assertEq(cfg.linearOracle, makeAddr("sparkLinearDiscountOracle"), "Linear oracle should match");
        assertEq(cfg.ptToken, makeAddr("ptToken"), "PT token should match");
        assertEq(cfg.syToken, makeAddr("syToken"), "SY token should match");
        assertEq(
            cfg.expectedUnderlyingToken, _config.expectedUnderlyingToken, "Expected underlying token should match"
        );
        assertEq(cfg.hardcodedQuoteToken, _config.hardcodedQuoteToken, "Hardcoded quote token should match");
        assertEq(cfg.syRateMethodSelector, bytes4(keccak256("exchangeRate()")), "method selector should match");
    }

    function _hashConfig(IPTLinearOracleFactory.DeploymentConfig memory _config) internal pure returns (bytes32) {
        return keccak256(abi.encode(_config));
    }
}
