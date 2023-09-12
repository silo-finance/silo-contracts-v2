// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ERC20 as ERC20WithoutMint, IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
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
import {IHookReceiverMock as IHookReceiver} from "../_mocks/IHookReceiverMock.sol";
import {IShareTokenLike as IShareToken} from "ve-silo/contracts/gauges/interfaces/IShareTokenLike.sol";

contract ERC20 is ERC20WithoutMint {
    constructor(string memory name, string memory symbol) ERC20WithoutMint(name, symbol) {}
    function mint(address _account, uint256 _amount) external {
        _mint(_account, _amount);
    }
}

// FOUNDRY_PROFILE=ve-silo forge test --mc MainnetBalancerMinterTest --ffi -vvv
contract MainnetBalancerMinterTest is IntegrationTest {
    uint256 internal constant _WEIGHT_CAP = 1e18;
    uint256 internal constant _BOB_BALANCE = 1e18;

    ILiquidityGaugeFactory internal _factory;
    ISiloLiquidityGauge internal _gauge;
    IBalancerTokenAdmin internal _balancerTokenAdmin;
    IBalancerMinter internal _minter;
    IGaugeController internal _gaugeController;

    address internal _hookReceiver = makeAddr("Hook receiver");
    address internal _shareToken = makeAddr("Share token");
    address internal _silo = makeAddr("Silo");
    address internal _bob = makeAddr("Bob");
    address internal _deployer;

    function setUp() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
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
            _hookReceiver,
            abi.encodeWithSelector(IHookReceiver.shareToken.selector),
            abi.encode(_shareToken)
        );

        vm.mockCall(
            _shareToken,
            abi.encodeWithSelector(IShareToken.silo.selector),
            abi.encode(_silo)
        );

        _gauge = ISiloLiquidityGauge(_factory.create(_WEIGHT_CAP, _hookReceiver));

        _mockCallsForTest();
    }

    /// @notice Should mint tokens
    function testMintFor() public {
        IERC20 siloToken = IERC20(getAddress(SILO_TOKEN));

        assertEq(siloToken.balanceOf(_bob), 0);

        vm.warp(block.timestamp + 3_600 * 24 * 30);

        vm.prank(_bob);
        _minter.setMinterApproval(_bob, true);
        vm.prank(_bob);
        _minter.mintFor(address(_gauge), _bob);

        assertEq(siloToken.balanceOf(_bob), _BOB_BALANCE);
    }

    function _dummySiloToken() internal {
        if (isChain(ANVIL_ALIAS)) {
            ERC20 siloToken = new ERC20("Silo test token", "SILO");
            ERC20 silo8020Token = new ERC20("Silo 80/20", "SILO-80-20");

            setAddress(getChainId(), SILO_TOKEN, address(siloToken));
            setAddress(getChainId(), SILO80_WETH20_TOKEN, address(silo8020Token));
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
