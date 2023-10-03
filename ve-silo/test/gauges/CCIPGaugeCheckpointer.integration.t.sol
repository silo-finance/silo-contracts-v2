// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ERC20, IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {Client} from "chainlink-ccip/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "chainlink-ccip/v0.8/ccip/interfaces/IRouterClient.sol";

import {CCIPGaugeCheckpointerDeploy} from "ve-silo/deploy/CCIPGaugeCheckpointerDeploy.s.sol";
import {StakelessGaugeCheckpointerAdaptorDeploy} from "ve-silo/deploy/StakelessGaugeCheckpointerAdaptorDeploy.s.sol";

import {IMainnetBalancerMinter, ILMGetters, IBalancerMinter}
    from "ve-silo/contracts/silo-tokens-minter/interfaces/IMainnetBalancerMinter.sol";
import {IStakelessGaugeCheckpointerAdaptor}
    from "ve-silo/contracts/gauges/interfaces/IStakelessGaugeCheckpointerAdaptor.sol";

import {CCIPGauge} from "ve-silo/contracts/gauges/ccip/CCIPGauge.sol";
import {IGaugeAdder} from "ve-silo/contracts/gauges/interfaces/IGaugeAdder.sol";
import {IBalancerTokenAdmin} from "ve-silo/contracts/silo-tokens-minter/interfaces/IBalancerTokenAdmin.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {ICCIPGaugeCheckpointer} from "ve-silo/contracts/gauges/interfaces/ICCIPGaugeCheckpointer.sol";
import {CCIPGaugeFactorySepoliaMumbai} from "ve-silo/test/_mocks/CCIPGaugeFactorySepoliaMumbai.sol";
import {CCIPGaugeSepoliaMumbai} from "ve-silo/test/_mocks/CCIPGaugeSepoliaMumbai.sol";
import {VeSiloAddresses, VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {CheckpointerAdaptorMock} from "../_mocks/CheckpointerAdaptorMock.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc CCIPGaugeCheckpointer --ffi -vvv
contract CCIPGaugeCheckpointer is IntegrationTest {
    string constant internal _GAUGE_TYPE = "Ethereum";

    uint256 internal constant _FORKING_BLOCK_NUMBER = 4291900;
    uint256 internal constant _GAUGE_BALANCE = 100e18;
    uint256 internal constant _MINT_AMOUNT = 6048000000000000;
    uint256 internal constant _RELATIVE_WEIGHT_CAP = 1e18;
    address internal constant _LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address internal constant _CCIP_BNM = 0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05;
    bytes32 internal constant _MESSAGE_ID_LINK = 0x5b07634290aeb7c9fa5e4c1b8f8c6a3276bf9b3d548cd9ac35bc1c90585d704a;
    bytes32 internal constant _MESSAGE_ID_ETH = 0x487ecde8247c0b2fb3ca0eb78cd25f0134537c96c10af8531ae535e675685b2b;

    address internal _minter = makeAddr("Minter");
    address internal _tokenAdmin = makeAddr("Token Admin");
    address internal _gaugeController = makeAddr("Gauge Controller");
    address internal _chaildChainGauge = makeAddr("Chaild Chain Gauge");
    address internal _gaugeAdder = makeAddr("Gauge adder");
    address internal _owner = makeAddr("Owner");
    address internal _user = makeAddr("User");
    address internal _gaugeFactory;
    address internal _deployer;

    ICCIPGaugeCheckpointer internal _checkpointer;
    ICCIPGauge internal _gauge;

    event CCIPTransferMessage(bytes32 newMessage);

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(SEPOLIA_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        vm.warp(1694761200);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        _deployer = vm.addr(deployerPrivateKey);
        
        StakelessGaugeCheckpointerAdaptorDeploy adaptorDeploy = new StakelessGaugeCheckpointerAdaptorDeploy();
        CCIPGaugeCheckpointerDeploy deploy = new CCIPGaugeCheckpointerDeploy();
        deploy.disableDeploymentsSync();

        IStakelessGaugeCheckpointerAdaptor adaptor = adaptorDeploy.run();

        setAddress(VeSiloContracts.GAUGE_ADDER, _gaugeAdder);

        vm.mockCall(
            _gaugeAdder,
            abi.encodeWithSelector(IGaugeAdder.getGaugeController.selector),
            abi.encode(_gaugeController)
        );
        
        _checkpointer = deploy.run();

        _mockCallsBeforeGaugeCreation();

        CCIPGaugeSepoliaMumbai gaugeImpl = new CCIPGaugeSepoliaMumbai(IMainnetBalancerMinter(_minter));

        CCIPGaugeFactorySepoliaMumbai factory = new CCIPGaugeFactorySepoliaMumbai(
            address(adaptor),
            address(gaugeImpl)
        );

        _gaugeFactory = address(factory);

        _gauge = ICCIPGauge(factory.create(_chaildChainGauge, _RELATIVE_WEIGHT_CAP));
        vm.label(address(_gauge), "Gauge");

        _mockCallsAfterGaugeCreated();

        vm.prank(_deployer);
        adaptor.setStakelessGaugeCheckpointer(address(_checkpointer));
    }

    function testCheckpointSingleGaugeLINK() public {
        _setupGauge();
        _beforeCheckpointGaugeWithLINK();

        vm.expectEmit(false, false, false, true);
        emit CCIPTransferMessage(_MESSAGE_ID_LINK);

        _checkpointer.checkpointSingleGauge(_GAUGE_TYPE, _gauge, ICCIPGauge.PayFeesIn.LINK);

        _afterCheckpointGaugeWithLINK();
    }

    function testCheckpointSingleGaugeETH() public {
        _setupGauge();

        address gauge = address(_gauge);

        deal(_CCIP_BNM, gauge, _GAUGE_BALANCE);

        Client.EVM2AnyMessage memory message = _gauge.buildCCIPMessage(_MINT_AMOUNT, ICCIPGauge.PayFeesIn.Native);
        uint256 fees = _gauge.calculateFee(message);
        payable(_user).transfer(fees);

        uint256 gaugeBalance = IERC20(_CCIP_BNM).balanceOf(gauge);

        assertEq(gaugeBalance, _GAUGE_BALANCE, "Expect to have an initial balance");

        vm.warp(block.timestamp + 1 weeks);

        vm.expectEmit(false, false, false, true);
        emit CCIPTransferMessage(_MESSAGE_ID_ETH);

        vm.prank(_user);
        _checkpointer.checkpointSingleGauge{value: fees}(_GAUGE_TYPE, _gauge, ICCIPGauge.PayFeesIn.Native);

        _afterCheckpointGaugeWithLINK();
    }

    function _beforeCheckpointGaugeWithLINK() internal {
        Client.EVM2AnyMessage memory message = _gauge.buildCCIPMessage(_MINT_AMOUNT, ICCIPGauge.PayFeesIn.LINK);
        uint256 fees = _gauge.calculateFee(message);

        deal(_LINK, address(this), fees);
        deal(_CCIP_BNM, address(_gauge), _GAUGE_BALANCE);

        IERC20(_LINK).approve(address(_checkpointer), fees);

        vm.warp(block.timestamp + 1 weeks);
    }

    function _afterCheckpointGaugeWithLINK() internal {
        uint256 gaugeBalance = IERC20(_CCIP_BNM).balanceOf(address(_gauge));

        // ensure `_MINT_AMOUNT` was transferred from the `gauge` balance
        assertEq(_GAUGE_BALANCE, gaugeBalance + _MINT_AMOUNT, "Unexpected balance change");
    }

    function _setupGauge() internal {
        ICCIPGauge[] memory gauges = new ICCIPGauge[](1);
        gauges[0] = _gauge;

        vm.prank(_deployer);
        _checkpointer.addGaugesWithVerifiedType(_GAUGE_TYPE, gauges);
    }

    // solhint-disable-next-line function-max-lines
    function _mockCallsBeforeGaugeCreation() internal {
        vm.mockCall(
            _minter,
            abi.encodeWithSelector(ILMGetters.getBalancerTokenAdmin.selector),
            abi.encode(_tokenAdmin)
        );

        vm.mockCall(
            _minter,
            abi.encodeWithSelector(ILMGetters.getGaugeController.selector),
            abi.encode(_gaugeController)
        );

        vm.mockCall(
            _tokenAdmin,
            abi.encodeWithSelector(IBalancerTokenAdmin.getBalancerToken.selector),
            abi.encode(_CCIP_BNM)
        );

        vm.mockCall(
            _tokenAdmin,
            abi.encodeWithSelector(IBalancerTokenAdmin.RATE_REDUCTION_TIME.selector),
            abi.encode(100)
        );

        vm.mockCall(
            _tokenAdmin,
            abi.encodeWithSelector(IBalancerTokenAdmin.RATE_REDUCTION_COEFFICIENT.selector),
            abi.encode(100)
        );

        vm.mockCall(
            _tokenAdmin,
            abi.encodeWithSelector(IBalancerTokenAdmin.RATE_DENOMINATOR.selector),
            abi.encode(100)
        );

        vm.mockCall(
            _tokenAdmin,
            abi.encodeWithSelector(IBalancerTokenAdmin.startEpochTimeWrite.selector),
            abi.encode(block.timestamp)
        );

        vm.mockCall(
            _tokenAdmin,
            abi.encodeWithSelector(IBalancerTokenAdmin.rate.selector),
            abi.encode(1e10)
        );

        vm.mockCall(
            address(this),
            abi.encodeWithSelector(Ownable.owner.selector),
            abi.encode(_owner)
        );
    }

    function _mockCallsAfterGaugeCreated() internal {
        vm.mockCall(
            _gaugeController,
            abi.encodeWithSelector(IGaugeController.checkpoint_gauge.selector, address(_gauge)),
            abi.encode(true)
        );

        vm.mockCall(
            _gaugeController,
            abi.encodeWithSelector(IGaugeController.gauge_relative_weight.selector, address(_gauge), 1694649600),
            abi.encode(1e18)
        );

        vm.mockCall(
            _minter,
            abi.encodeWithSelector(IBalancerMinter.mint.selector, address(_gauge)),
            abi.encode(true)
        );

        vm.mockCall(
            _gaugeAdder,
            abi.encodeWithSelector(
                IGaugeAdder.isValidGaugeType.selector,
                _GAUGE_TYPE
            ),
            abi.encode(true)
        );

        vm.mockCall(
            _gaugeAdder,
            abi.encodeWithSelector(
                IGaugeAdder.getFactoryForGaugeType.selector,
                _GAUGE_TYPE
            ),
            abi.encode(_gaugeFactory)
        );

        vm.mockCall(
            _gaugeController,
            abi.encodeWithSelector(
                IGaugeController.gauge_exists.selector,
                _gauge
            ),
            abi.encode(true)
        );
    }
}
