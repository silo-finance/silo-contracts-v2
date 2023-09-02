// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ERC20, IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {MainnetBalancerMinterTest} from "../silo-tokens-minter/MainnetBalancerMinter.integration.t.sol";
import {ArbitrumRootGaugeFactoryDeploy} from "ve-silo/deploy/ArbitrumRootGaugeFactoryDeploy.s.sol";
import {ArbitrumRootGaugeFactory} from "ve-silo/contracts/gauges/arbitrum/ArbitrumRootGaugeFactory.sol";
import {ArbitrumRootGauge} from "ve-silo/contracts/gauges/arbitrum/ArbitrumRootGauge.sol";

import {VeSiloAddresses, VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc ArbitrumRootGaugeFactoryTest --ffi -vvv
contract ArbitrumRootGaugeFactoryTest is IntegrationTest {
    uint256 internal constant _FORKING_BLOCK_NUMBER = 17985150;
    uint256 internal constant _RELATIVE_WEIGHT_CAP = 1e18;
    address internal constant _GATEWAY_ADDR = 0xB2535b988dcE19f9D71dfB22dB6da744aCac21bf;

    address internal _recipient = makeAddr("L2 recepient");
    address internal _checkpointer = makeAddr("Checkpointer");
    address internal _newCheckpointer = makeAddr("NewCheckpointer");

    ArbitrumRootGaugeFactory internal _factory;
    ArbitrumRootGaugeFactoryDeploy internal _deploy;

    event NewCheckpointer(address checkpointer);

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(MAINNET_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        MainnetBalancerMinterTest minterTest = new MainnetBalancerMinterTest();
        minterTest.setUp();

        _deploy = new ArbitrumRootGaugeFactoryDeploy();
        _deploy.disableDeploymentsSync();

        setAddress(getChainId(), VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR, _checkpointer);

        _factory = _deploy.run();
    }

    function testEnsureFactoryDeployedWithCorrectData() public {
        uint256 gasLimit = _deploy.gasLimit();
        uint256 gasPrice = _deploy.gasPrice();
        uint256 maxSubmissionCost = _deploy.maxSubmissionCost();

        (
            uint256 gasLimitFactory,
            uint256 gasPriceFactory,
            uint256 maxSubmissionCostFactory
        ) = _factory.getArbitrumFees();

        assertEq(gasLimit, gasLimitFactory, "Deployed with wrong gasLimit");
        assertEq(gasPrice, gasPriceFactory, "Deployed with wrong gasPrice");
        assertEq(maxSubmissionCost, maxSubmissionCostFactory, "Deployed with wrong maxSubmissionCost");
    }

    function testShouldCreateArbRootGauge() public {
        ArbitrumRootGauge gauge = _createArbitrumRootGauge();

        address recipient = gauge.getRecipient();
        assertEq(recipient, _recipient, "Wrong recipinet after gauge creation");

        uint256 gasLimit = _deploy.gasLimit();
        uint256 gasPrice = _deploy.gasPrice();
        uint256 maxSubmissionCost = _deploy.maxSubmissionCost();

        uint256 calculated = gasLimit * gasPrice + maxSubmissionCost;

        uint256 totalBridgeCost = gauge.getTotalBridgeCost();
        
        assertEq(calculated, totalBridgeCost, "Invalid total bridge cost");

        address checkpointer = gauge.getCheckpointer();
        assertEq(checkpointer, _checkpointer, "Failed to intialize a gauge");
    }

    function testStakelessGaugeCheckpointerConfig() public {
        ArbitrumRootGauge gauge = _createArbitrumRootGauge();

        vm.expectRevert("Ownable: caller is not the owner");
        gauge.setCheckpointer(_newCheckpointer);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.addr(deployerPrivateKey);

        vm.expectEmit(false, false, false, true);
        emit NewCheckpointer(_newCheckpointer);

        vm.prank(owner);
        gauge.setCheckpointer(_newCheckpointer);
    }

    function testOnlyCheckpointerCanCheckpoint() public {
        ArbitrumRootGauge gauge = _createArbitrumRootGauge();
        
        vm.expectRevert("Only checkpointer");
        gauge.checkpoint();

        vm.prank(_checkpointer);
        gauge.checkpoint();
    }

    function _createArbitrumRootGauge() internal returns (ArbitrumRootGauge _gauge) {
        _gauge = ArbitrumRootGauge(_factory.create(_recipient, _RELATIVE_WEIGHT_CAP));
    }
}
