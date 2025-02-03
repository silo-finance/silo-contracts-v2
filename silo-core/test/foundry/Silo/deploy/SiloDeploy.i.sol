// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {Deployments} from "silo-foundry-utils/lib/Deployments.sol";

import {VeSiloContracts} from "ve-silo/common/VeSiloContracts.sol";

import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {SiloDeployWithGaugeHookReceiver} from "silo-core/deploy/silo/SiloDeployWithGaugeHookReceiver.s.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";
import {IHookReceiver} from "silo-core/contracts/interfaces/IHookReceiver.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {MainnetDeploy} from "silo-core/deploy/MainnetDeploy.s.sol";
import {SiloOraclesFactoriesContracts} from "silo-oracles/deploy/SiloOraclesFactoriesContracts.sol";

import {
   UniswapV3OracleFactoryMock
} from "silo-core/test/foundry/_mocks/oracles-factories/UniswapV3OracleFactoryMock.sol";

import {
   ChainlinkV3OracleFactoryMock
} from "silo-core/test/foundry/_mocks/oracles-factories/ChainlinkV3OracleFactoryMock.sol";

import {DIAOracleFactoryMock} from "silo-core/test/foundry/_mocks/oracles-factories/DIAOracleFactoryMock.sol";

// FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc SiloDeployTest
contract SiloDeployTest is IntegrationTest {
   uint256 internal constant _FORKING_BLOCK_NUMBER = 19780370;

   ISiloConfig internal _siloConfig;
   ISiloDeployer internal _siloDeployer;
   SiloDeployWithGaugeHookReceiver internal _siloDeploy;

   UniswapV3OracleFactoryMock internal _uniV3OracleFactoryMock;
   ChainlinkV3OracleFactoryMock internal _chainlinkV3OracleFactoryMock;
   DIAOracleFactoryMock internal _diaOracleFactoryMock;

   function setUp() public {
        vm.createSelectFork(getChainRpcUrl(MAINNET_ALIAS), _FORKING_BLOCK_NUMBER);

        // Mock addresses that we need for the `SiloFactoryDeploy` script
        AddrLib.setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, makeAddr("Timelock"));
        AddrLib.setAddress(VeSiloContracts.FEE_DISTRIBUTOR, makeAddr("FeeDistributor"));

        _uniV3OracleFactoryMock = new UniswapV3OracleFactoryMock();
        _chainlinkV3OracleFactoryMock = new ChainlinkV3OracleFactoryMock();
        _diaOracleFactoryMock = new DIAOracleFactoryMock();

        _mockOraclesFactories();

        Deployments.disableDeploymentsSync();

        MainnetDeploy mainnetDeploy = new MainnetDeploy();
        mainnetDeploy.run();

        _siloDeploy = new SiloDeployWithGaugeHookReceiver();

        // Mock addresses for oracles configurations
        AddrLib.setAddress("CHAINLINK_PRIMARY_AGGREGATOR", makeAddr("Chainlink primary aggregator"));
        AddrLib.setAddress("CHAINLINK_SECONDARY_AGGREGATOR", makeAddr("Chainlink secondary aggregator"));
        AddrLib.setAddress("DIA_ORACLE_EXAMPLE", makeAddr("DIA oracle example"));

        _siloConfig = _siloDeploy.useConfig(SiloConfigsNames.SILO_FULL_CONFIG_TEST).run();
    }

    // FOUNDRY_PROFILE=core-test forge test -vv --ffi --mt test_hooks_are_initialized
    function test_hooks_are_initialized() public view {
        (address silo0, address silo1) = _siloConfig.getSilos();

         _verifyHookReceiversForSilo(silo0);
         _verifyHookReceiversForSilo(silo1);
    }

    // FOUNDRY_PROFILE=core-test forge test -vv --ffi -mt test_oracles_deploy
    function test_oracles_deploy() public view { // solhint-disable-line func-name-mixedcase
        (, address silo1) = _siloConfig.getSilos();

        ISiloConfig.ConfigData memory siloConfig1 = _siloConfig.getConfig(silo1);

        assertEq(siloConfig1.solvencyOracle, _uniV3OracleFactoryMock.MOCK_ORACLE_ADDR(), "Invalid Uniswap oracle");

        // If maxLtv oracle is not set, fallback to solvency oracle
        assertEq(
            siloConfig1.maxLtvOracle,
            _uniV3OracleFactoryMock.MOCK_ORACLE_ADDR(),
            "Should have an Uniswap oracle as a fallback"
        );
    }

    function _verifyHookReceiversForSilo(address _silo) internal view {
        IHookReceiver hookReceiver = IHookReceiver(IShareToken(_silo).hookSetup().hookReceiver);

        assertNotEq(address(hookReceiver), address(0), "Hook receiver not initialized");

        address protectedShareToken;
        address collateralShareToken;
        address debtShareToken;

        (protectedShareToken, collateralShareToken, debtShareToken) = _siloConfig.getShareTokens(_silo);

        _verifyHookReceiverForToken(protectedShareToken);
        _verifyHookReceiverForToken(collateralShareToken);
        _verifyHookReceiverForToken(debtShareToken);
    }

    function _verifyHookReceiverForToken(address _token) internal view {
        IShareToken.HookSetup memory hookSetup = IShareToken(_token).hookSetup();

        assertNotEq(hookSetup.hookReceiver, address(0), "Hook receiver not initialized");
    }

    function _mockOraclesFactories() internal {
        AddrLib.setAddress(
            SiloOraclesFactoriesContracts.UNISWAP_V3_ORACLE_FACTORY,
            address(_uniV3OracleFactoryMock)
        );
    }
}
