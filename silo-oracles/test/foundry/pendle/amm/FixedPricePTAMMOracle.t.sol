// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {Test} from "forge-std/Test.sol";

import {FixedPricePTAMMOracleFactory} from "silo-oracles/contracts/pendle/amm/FixedPricePTAMMOracleFactory.sol";
import {IFixedPricePTAMMOracleConfig} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleConfig.sol";
import {IFixedPricePTAMMOracle} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracle.sol";
import {IPendleAMM} from "silo-oracles/contracts/interfaces/IPendleAMM.sol";
import {IFixedPricePTAMMOracleFactory} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleFactory.sol";

contract FixedPricePTAMMOracleTest is Test {
    FixedPricePTAMMOracleFactory factory;

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_AVALANCHE"), 67369870);

        factory = new FixedPricePTAMMOracleFactory();
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_PT_USDe_price --ffi -vv
    */
    function test_ptamm_PT_USDe_price() public {
        address pt = 0xB4205a645c7e920BD8504181B1D7f2c5C955C3e7;
        address usde = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34; // underlying token of PT

        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config = IFixedPricePTAMMOracleConfig.DeploymentConfig({
            amm: IPendleAMM(0x4d717868F4Bd14ac8B29Bb6361901e30Ae05e340),
            baseToken: pt,
            quoteToken: usde
        });

        IFixedPricePTAMMOracle oracle = factory.create(config, bytes32(0));

        uint256 price = oracle.quote(1e18, pt);

        assertEq(price, 0.980531592031963470e18, "PT price");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_predictAddress --ffi -vv
    */
    function test_predictAddress_fuzz(
        address _deployer, 
        bytes32 _externalSalt,
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config
    ) public {
        vm.assume(_deployer != address(0));
        vm.assume(_config.baseToken != address(0));
        vm.assume(_config.quoteToken != address(0));
        vm.assume(_config.quoteToken != _config.baseToken);

        address predictedAddress = factory.predictAddress(_deployer, _externalSalt);

        vm.prank(_deployer);
        address oracle = address(factory.create(_config, _externalSalt));

        assertEq(oracle, predictedAddress, "Predicted address does not match");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_reusableConfigs_fuzz --ffi -vv
    */
    function test_ptamm_reusableConfigs_fuzz(
        address _deployer, 
        bytes32 _externalSalt,
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config
    ) public {
        vm.assume(_deployer != address(0));
        vm.assume(_config.baseToken != address(0));
        vm.assume(_config.quoteToken != address(0));
        vm.assume(_config.quoteToken != _config.baseToken);

        vm.prank(_deployer);
        address oracle1 = address(factory.create(_config, _externalSalt));
        address oracle2 = address(factory.create(_config, bytes32(0)));

        assertEq(oracle1, oracle2, "Oracle addresses should be the same if we reuse the same config");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_reorg --ffi -vv
    */
    function test_ptamm_reorg(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) public {
        address eoa1 = makeAddr("eoa1");
        address eoa2 = makeAddr("eoa2");

        uint256 snapshot = vm.snapshotState();

        vm.prank(eoa1);
        address oracle1 = address(factory.create(_config, bytes32(0)));

        vm.revertToState(snapshot);

        vm.prank(eoa2);
        address oracle2 = address(factory.create(_config, bytes32(0)));

        assertNotEq(oracle1, oracle2, "Oracle addresses should be different if we reorg");
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_verifyConfig_pass_fuzz --ffi -vv
    */
    function test_ptamm_verifyConfig_pass_fuzz(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) 
        public 
        view 
    {
        vm.assume(_config.baseToken != address(0));
        vm.assume(_config.quoteToken != address(0));
        vm.assume(_config.quoteToken != _config.baseToken);

        factory.verifyConfig(_config);
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_verifyConfig_fail --ffi -vv
    */
    function test_ptamm_verifyConfig_fail() public {
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config;

        vm.expectRevert(abi.encodeWithSelector(IFixedPricePTAMMOracleFactory.AddressZero.selector));
        factory.verifyConfig(config);

        config.baseToken = address(1);
        vm.expectRevert(abi.encodeWithSelector(IFixedPricePTAMMOracleFactory.AddressZero.selector));
        factory.verifyConfig(config);

        config.quoteToken = address(0);
        vm.expectRevert(abi.encodeWithSelector(IFixedPricePTAMMOracleFactory.AddressZero.selector));
        factory.verifyConfig(config);

        config.quoteToken = address(1);
        vm.expectRevert(abi.encodeWithSelector(IFixedPricePTAMMOracleFactory.TokensAreTheSame.selector));
        factory.verifyConfig(config);

        config.quoteToken = address(2);
        factory.verifyConfig(config); // pass
    }

    /*
    FOUNDRY_PROFILE=oracles forge test --mt test_ptamm_hashConfig --ffi -vv
    */
    function test_ptamm_hashConfig_fuzz(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) public view {
        bytes32 configId = factory.hashConfig(_config);

        assertEq(configId, keccak256(abi.encode(_config)), "Config hash should match");
    }
}