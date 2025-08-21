// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {Test} from "forge-std/Test.sol";

import {Initializable} from "openzeppelin5-upgradeable/proxy/utils/Initializable.sol";

import {FixedPricePTAMMOracleFactory} from "silo-oracles/contracts/pendle/amm/FixedPricePTAMMOracleFactory.sol";
import {IFixedPricePTAMMOracleConfig} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleConfig.sol";
import {IFixedPricePTAMMOracleFactory} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleFactory.sol";
import {IFixedPricePTAMMOracle} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracle.sol";
import {FixedPricePTAMMOracle} from "silo-oracles/contracts/pendle/amm/FixedPricePTAMMOracle.sol";
import {IPendleAMM} from "silo-oracles/contracts/interfaces/IPendleAMM.sol";

/*
    FOUNDRY_PROFILE=oracles forge test --mc FixedPricePTAMMOracleFactoryTest --ffi -vv
*/
contract FixedPricePTAMMOracleFactoryTest is Test {
    FixedPricePTAMMOracleFactory immutable factory;

    modifier assumeValidConfig(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) {
        vm.assume(_config.ptToken != address(0));
        vm.assume(_config.ptUnderlyingQuoteToken != address(0));
        vm.assume(_config.ptUnderlyingQuoteToken != _config.ptToken);
        vm.assume(_config.hardcoddedQuoteToken != _config.ptToken);

        _;
    }

    constructor() {
        factory = new FixedPricePTAMMOracleFactory();
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_predictAddress --ffi -vv
    */
    function test_predictAddress_fuzz(
        address _deployer,
        bytes32 _externalSalt,
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config
    ) 
        public 
        assumeValidConfig(_config) 
    {
        vm.assume(_deployer != address(0));

        address predictedAddress = factory.predictAddress(_config, _deployer, _externalSalt);

        vm.prank(_deployer);
        address oracle = address(factory.create(_config, _externalSalt));

        assertEq(oracle, predictedAddress, "Predicted address does not match");
        
        address oracle2 = address(factory.create(_config, _externalSalt));

        address predictedAddress2 = factory.predictAddress(_config, _deployer, _externalSalt);

        assertEq(
            predictedAddress, 
            predictedAddress2, 
            "predicted addresses should be the same if we reuse the same config"
        );

        assertEq(oracle2, oracle, "Oracle addresses should be the same if we reuse the same config");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_resolveExistingOracle --ffi -vv
    */
    function test_ptamm_resolveExistingOracle() public {
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config = IFixedPricePTAMMOracleConfig.DeploymentConfig({
            amm: IPendleAMM(makeAddr("amm")),
            ptToken: makeAddr("ptToken"),
            ptUnderlyingQuoteToken: makeAddr("ptUnderlyingQuoteToken"),
            hardcoddedQuoteToken: address(0)
        });

        bytes32 configId = factory.hashConfig(config);

        address existingOracle = factory.resolveExistingOracle(configId);

        assertEq(existingOracle, address(0), "No existing oracle should be found");

        address oracle = address(factory.create(config, bytes32(0)));

        existingOracle = factory.resolveExistingOracle(configId);
        assertEq(existingOracle, address(oracle), "Existing oracle should be found");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_reusableConfigs_fuzz --ffi -vv
    */
    function test_ptamm_reusableConfigs_fuzz(
        address _deployer,
        bytes32 _externalSalt,
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config
    ) 
        public 
        assumeValidConfig(_config) 
    {

        vm.prank(_deployer);
        address oracle1 = address(factory.create(_config, _externalSalt));
        address oracle2 = address(factory.create(_config, bytes32(0)));

        assertEq(oracle1, oracle2, "Oracle addresses should be the same if we reuse the same config");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_reorg --ffi -vv
    */
    function test_ptamm_reorg(
        address _eoa1, 
        address _eoa2,
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config1,
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config2
    ) 
        public 
        assumeValidConfig(_config1) 
        assumeValidConfig(_config2) 
    {
        vm.assume(_eoa1 != address(0));
        vm.assume(_eoa2 != address(0));
        vm.assume(_eoa1 != _eoa2);
        vm.assume(_hashConfig(_config1) != _hashConfig(_config2));

        uint256 snapshot = vm.snapshotState();

        vm.prank(_eoa1);
        address oracle1 = address(factory.create(_config1, bytes32(0)));

        vm.revertToState(snapshot);

        vm.prank(_eoa2);
        address oracle2 = address(factory.create(_config2, bytes32(0)));

        assertNotEq(oracle1, oracle2, "Oracle addresses should be different if we reorg");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_verifyConfig_pass_fuzz --ffi -vv
    */
    function test_ptamm_verifyConfig_pass_fuzz(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config)
        public
        view
        assumeValidConfig(_config)
    {

        factory.verifyConfig(_config);
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_verifyConfig_fail --ffi -vv
    */
    function test_ptamm_verifyConfig_fail() public {
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config;

        vm.expectRevert(abi.encodeWithSelector(IFixedPricePTAMMOracleFactory.AddressZero.selector));
        factory.verifyConfig(config);

        config.ptToken = address(1);
        vm.expectRevert(abi.encodeWithSelector(IFixedPricePTAMMOracleFactory.AddressZero.selector));
        factory.verifyConfig(config);

        config.ptUnderlyingQuoteToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(IFixedPricePTAMMOracleFactory.AddressZero.selector));
        factory.verifyConfig(config);

        config.ptUnderlyingQuoteToken = address(1);
        vm.expectRevert(abi.encodeWithSelector(IFixedPricePTAMMOracleFactory.TokensAreTheSame.selector));
        factory.verifyConfig(config);

        config.hardcoddedQuoteToken = address(1);
        vm.expectRevert(abi.encodeWithSelector(IFixedPricePTAMMOracleFactory.TokensAreTheSame.selector));
        factory.verifyConfig(config);

        config.ptUnderlyingQuoteToken = address(2);
        config.hardcoddedQuoteToken = address(0);
        factory.verifyConfig(config); // pass
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_hashConfig --ffi -vv
    */
    function test_ptamm_hashConfig_fuzz(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) public view {
        bytes32 configId = factory.hashConfig(_config);

        assertEq(configId, keccak256(abi.encode(_config)), "Config hash should match");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_implementation_canNotBeInit --ffi -vv
    */
    function test_ptamm_implementation_canNotBeInit() public {
        address implementation = address(factory.ORACLE_IMPLEMENTATION());

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        IFixedPricePTAMMOracle(implementation).initialize(IFixedPricePTAMMOracleConfig(address(1)));
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_disableInitializers --ffi -vv
    */
    function test_ptamm_disableInitializers() public {
        FixedPricePTAMMOracle oracle = new FixedPricePTAMMOracle();

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        oracle.initialize(IFixedPricePTAMMOracleConfig(address(1)));
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_clone_alreadyInitialized --ffi -vv
    */
    function test_ptamm_clone_alreadyInitialized() public {
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config = IFixedPricePTAMMOracleConfig.DeploymentConfig({
            amm: IPendleAMM(0x4d717868F4Bd14ac8B29Bb6361901e30Ae05e340),
            ptToken: address(1),
            ptUnderlyingQuoteToken: address(2),
            hardcoddedQuoteToken: address(0)
        });

        address oracle = address(factory.create(config, bytes32(0)));

        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        IFixedPricePTAMMOracle(oracle).initialize(IFixedPricePTAMMOracleConfig(address(1)));
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_getConfig --ffi -vv
    */
    function test_ptamm_getConfig(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) 
        public
        assumeValidConfig(_config) 
    {
        IFixedPricePTAMMOracle oracle = factory.create(_config, bytes32(0));
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory cfg = oracle.oracleConfig().getConfig();

        assertEq(address(cfg.amm), address(_config.amm), "AMM should match");
        assertEq(cfg.ptToken, _config.ptToken, "PT token should match");
        assertEq(cfg.ptUnderlyingQuoteToken, _config.ptUnderlyingQuoteToken, "PT underlying quote token should match");
        assertEq(cfg.hardcoddedQuoteToken, _config.hardcoddedQuoteToken, "Hardcoded quote token should match");
    }

    function _hashConfig(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) internal view returns (bytes32) {
        return keccak256(abi.encode(_config));
    }
}
