// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ERC20 as ERC20WithoutMint, IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {ILiquidityGaugeFactory} from "ve-silo/contracts/gauges/interfaces/ILiquidityGaugeFactory.sol";
import {ISiloLiquidityGauge} from "ve-silo/contracts/gauges/interfaces/ISiloLiquidityGauge.sol";
import {LiquidityGaugeFactoryDeploy} from "ve-silo/deploy/LiquidityGaugeFactoryDeploy.s.sol";
import {GaugeControllerDeploy, IGaugeController} from "ve-silo/deploy/GaugeControllerDeploy.s.sol";
import {SiloGovernorDeploy} from "ve-silo/deploy/SiloGovernorDeploy.s.sol";

import {MainnetBalancerMinterDeploy, IBalancerTokenAdmin, IBalancerMinter}
    from "ve-silo/deploy/MainnetBalancerMinterDeploy.s.sol";

import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {IVeBoost} from "ve-silo/contracts/voting-escrow/interfaces/IVeBoost.sol";
import {IExtendedOwnable} from "ve-silo/contracts/access/IExtendedOwnable.sol";
import {IShareTokenLike as IShareToken} from "ve-silo/contracts/gauges/interfaces/IShareTokenLike.sol";
import {ISiloMock as ISilo} from "ve-silo/test/_mocks/ISiloMock.sol";
import {IFeesManager} from "ve-silo/contracts/silo-tokens-minter/interfaces/IFeesManager.sol";
import {FeesManagerTest} from "./FeesManager.unit.t.sol";

import {
    ISiloFactoryWithFeeDetails as ISiloFactory
} from "ve-silo/contracts/silo-tokens-minter/interfaces/ISiloFactoryWithFeeDetails.sol";

contract ERC20 is ERC20WithoutMint {
    constructor(string memory name, string memory symbol) ERC20WithoutMint(name, symbol) {}
    function mint(address _account, uint256 _amount) external {
        _mint(_account, _amount);
    }
}

// FOUNDRY_PROFILE=ve-silo-test forge test --mc MainnetBalancerMinterTest --ffi -vvv
contract MainnetBalancerMinterTest is IntegrationTest {
    uint256 internal constant _WEIGHT_CAP = 1e18;
    uint256 internal constant _BOB_BALANCE = 1e18;
    uint256 internal constant _DAO_FEE = 1e3; // 10%
    uint256 internal constant _DEPLOYER_FEE = 2e3; // 20%

    ILiquidityGaugeFactory internal _factory;
    ISiloLiquidityGauge internal _gauge;
    IBalancerTokenAdmin internal _balancerTokenAdmin;
    IBalancerMinter internal _minter;
    IGaugeController internal _gaugeController;
    FeesManagerTest internal _feesTest;

    address internal _hookReceiver = makeAddr("Hook receiver");
    address internal _shareToken = makeAddr("Share token");
    address internal _silo = makeAddr("Silo");
    address internal _siloFactory = makeAddr("Silo Factory");
    address internal _daoFeeReceiver = makeAddr("DAO fee receiver");
    address internal _deployerFeeReceiver = makeAddr("Deployer fee receiver");
    address internal _bob = makeAddr("Bob");
    address internal _deployer;

    event MiningProgramStoped();

    // solhint-disable-next-line function-max-lines
    function setUp() public {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);

        _dummySiloToken();

        SiloGovernorDeploy _governanceDeploymentScript = new SiloGovernorDeploy();
        _governanceDeploymentScript.disableDeploymentsSync();

        LiquidityGaugeFactoryDeploy _factoryDeploy = new LiquidityGaugeFactoryDeploy();
        GaugeControllerDeploy _controllerDeploymentScript = new GaugeControllerDeploy();
        MainnetBalancerMinterDeploy _minterDeploy = new MainnetBalancerMinterDeploy();

        _governanceDeploymentScript.run();
        _gaugeController = _controllerDeploymentScript.run();
        (_minter, _balancerTokenAdmin) = _minterDeploy.run();

        vm.mockCall(
            getAddress(SILO_TOKEN),
            abi.encodeWithSelector(IExtendedOwnable.owner.selector),
            abi.encode(address(_balancerTokenAdmin))
        );

        _factory = _factoryDeploy.run();

        vm.prank(_deployer);
        _balancerTokenAdmin.activate();

        // Set manager of the `balancerTokenAdmin` a `minter` smart contract to be able to mint tokens
        vm.prank(_deployer);
        IExtendedOwnable(address(_balancerTokenAdmin)).changeManager(address(_minter));

        vm.mockCall(
            _shareToken,
            abi.encodeWithSelector(IShareToken.hookReceiver.selector),
            abi.encode(_hookReceiver)
        );

        vm.mockCall(
            _shareToken,
            abi.encodeWithSelector(IShareToken.silo.selector),
            abi.encode(_silo)
        );

        vm.mockCall(
            _silo,
            abi.encodeWithSelector(ISilo.factory.selector),
            abi.encode(_siloFactory)
        );

        _gauge = ISiloLiquidityGauge(_factory.create(_WEIGHT_CAP, _shareToken));

        _mockCallsForTest();

        _feesTest = new FeesManagerTest();
    }

    function testOnlyOwnerCanSetFees() public {
        _feesTest.onlyOwnerCanSetFees(
            IFeesManager(address(_minter)),
            _DAO_FEE,
            _DEPLOYER_FEE,
            _deployer
        );
    }

    function testMaxFees() public {
        _feesTest.onlyOwnerCanSetFees(
            IFeesManager(address(_minter)),
            _DAO_FEE,
            _DEPLOYER_FEE + 1,
            _deployer
        );
    }

    /// @notice Should mint tokens
    function testMintForNoFees() public {
        // without fees
        vm.mockCall(
            _siloFactory,
            abi.encodeWithSelector(ISiloFactory.getFeeReceivers.selector, _silo),
            abi.encode(
                address(0),
                address(0)
            )
        );

        IERC20 siloToken = IERC20(getAddress(SILO_TOKEN));

        assertEq(siloToken.balanceOf(_bob), 0);

        _mintFor();

        assertEq(siloToken.balanceOf(_bob), _BOB_BALANCE);
    }

    /// @notice Should mint tokens and collect fees
    function testMintForWithFees() public {
        // with fees
        // 10% - to DAO
        // 20% - to deployer
        vm.mockCall(
            _siloFactory,
            abi.encodeWithSelector(ISiloFactory.getFeeReceivers.selector, _silo),
            abi.encode(
                _daoFeeReceiver,
                _deployerFeeReceiver
            )
        );

        vm.prank(_deployer);
        IFeesManager(address(_minter)).setFees(_DAO_FEE, _DEPLOYER_FEE);

        IERC20 siloToken = IERC20(getAddress(SILO_TOKEN));

        assertEq(siloToken.balanceOf(_bob), 0);

        _mintFor();

        // 100% - 1e18
        // 10% to DAO
        uint256 expectedDAOBalance = 1e17;
        // 20$ to deployer
        uint256 expectedDeployerBalance = 2e17;
        // Bob's balance `_BOB_BALANCE` - 30% fees cut
        uint256 expectedBobBalance = 7e17;

        uint256 bobBalance = siloToken.balanceOf(_bob);
        uint256 daoBalance = siloToken.balanceOf(_daoFeeReceiver);
        uint256 deployerBalance = siloToken.balanceOf(_deployerFeeReceiver);

        assertEq(expectedBobBalance, bobBalance, "Wrong Bob's balance");
        assertEq(expectedDAOBalance, daoBalance, "Wrong DAO's balance");
        assertEq(expectedDeployerBalance, deployerBalance, "Wrong deployer's balance");
    }

    function testStopMining() public {
        vm.expectRevert("Ownable: caller is not the owner");
        _balancerTokenAdmin.stopMining();

        vm.mockCall(
            getAddress(SILO_TOKEN),
            abi.encodeWithSelector(Ownable.transferOwnership.selector, _deployer),
            abi.encode(true)
        );

        vm.expectEmit(false, false, false, false);
        emit MiningProgramStoped();

        vm.prank(_deployer);
        _balancerTokenAdmin.stopMining();
    }

    function _mintFor() internal {
        vm.warp(block.timestamp + 3_600 * 24 * 30);

        vm.prank(_bob);
        _minter.setMinterApproval(_bob, true);
        vm.prank(_bob);
        _minter.mintFor(address(_gauge), _bob);
    }

    function _dummySiloToken() internal {
        if (isChain(ANVIL_ALIAS)) {
            ERC20 siloToken = new ERC20("Silo test token", "SILO");

            setAddress(getChainId(), SILO_TOKEN, address(siloToken));
        }
    }

    function _mockCallsForTest() internal {
        vm.mockCall(
            address(_gaugeController),
            abi.encodeWithSelector(IGaugeController.gauge_types.selector, address(_gauge)),
            abi.encode(1)
        );

        vm.mockCall(
            address(_gauge),
            abi.encodeWithSelector(ISiloLiquidityGauge.user_checkpoint.selector, address(_bob)),
            abi.encode(true)
        );

        vm.mockCall(
            address(_gauge),
            abi.encodeWithSelector(ISiloLiquidityGauge.integrate_fraction.selector, address(_bob)),
            abi.encode(_BOB_BALANCE)
        );
    }
}
