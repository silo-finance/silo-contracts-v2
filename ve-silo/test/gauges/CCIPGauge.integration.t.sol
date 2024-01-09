// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ERC20, IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";
import {Client} from "chainlink-ccip/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "chainlink-ccip/v0.8/ccip/interfaces/IRouterClient.sol";

import {CCIPGauge} from "ve-silo/contracts/gauges/ccip/CCIPGauge.sol";

import {IMainnetBalancerMinter, ILMGetters, IBalancerMinter}
    from "ve-silo/contracts/silo-tokens-minter/interfaces/IMainnetBalancerMinter.sol";

import {IBalancerTokenAdmin} from "ve-silo/contracts/silo-tokens-minter/interfaces/IBalancerTokenAdmin.sol";
import {IGaugeController} from "ve-silo/contracts/gauges/interfaces/IGaugeController.sol";
import {ICCIPGauge} from "ve-silo/contracts/gauges/interfaces/ICCIPGauge.sol";
import {ICCIPExtraArgsConfig} from "ve-silo/contracts/gauges/interfaces/ICCIPExtraArgsConfig.sol";

import {CCIPGaugeFactoryAnyChain} from "ve-silo/test/_mocks/CCIPGaugeFactoryAnyChain.sol";
import {CCIPGaugeSepoliaMumbai} from "ve-silo/test/_mocks/CCIPGaugeSepoliaMumbai.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc CCIPGaugeTest --ffi -vvv
contract CCIPGaugeTest is IntegrationTest {
    uint256 internal constant _FORKING_BLOCK_NUMBER = 4291900;
    uint256 internal constant _RELATIVE_WEIGHT_CAP = 1e18;
    address internal constant _LINK = 0x779877A7B0D9E8603169DdbD7836e478b4624789;
    address internal constant _CCIP_BNM = 0xFd57b4ddBf88a4e07fF4e34C487b99af2Fe82a05;
    bytes32 internal constant _MESSAGE_ID_LINK = 0xb25ab84f0aa9cf2627b7f14ac84894ed2b20cd21c73827ff98441a8a1e5e0edd;
    bytes32 internal constant _MESSAGE_ID_ETH = 0x40a85bd54f8009e4a3b9b107dcc8429a3c3e6d2f26d6c221915408d32add73db;

    address internal _minter = makeAddr("Minter");
    address internal _tokenAdmin = makeAddr("TokenAdmin");
    address internal _gaugeController = makeAddr("GaugeController");
    address internal _chaildChainGauge = makeAddr("ChaildChainGauge");
    address internal _checkpointer = makeAddr("Checkpointer");
    address internal _owner = makeAddr("Owner");

    ICCIPGauge internal _gauge;

    event CCIPTransferMessage(bytes32 newMessage);
    event ExtraArgsUpdated(bytes extraArgs);

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(SEPOLIA_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        vm.warp(1694761200);

        _mockCallsBeforeGaugeCreation();

        CCIPGaugeSepoliaMumbai gaugeImpl = new CCIPGaugeSepoliaMumbai(IMainnetBalancerMinter(_minter));

        CCIPGaugeFactoryAnyChain factory = new CCIPGaugeFactoryAnyChain(
            _checkpointer,
            address(gaugeImpl)
        );

        _gauge = ICCIPGauge(factory.create(_chaildChainGauge, _RELATIVE_WEIGHT_CAP));
        vm.label(address(_gauge), "Gauge");

        _mockCallsAfterGaugeCreated();
    }

    function testSetExtraArgs() public {
        bytes memory anyExtraArgs = abi.encodePacked("any extra args");

        // Test permissions and configuration
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(makeAddr("another than an owner"));
        _gauge.setExtraArgs(anyExtraArgs);

        vm.expectEmit(false, false, false, true);
        emit ICCIPExtraArgsConfig.ExtraArgsUpdated(anyExtraArgs);

        _gauge.setExtraArgs(anyExtraArgs);

        assertEq(keccak256(_gauge.extraArgs()), keccak256(anyExtraArgs), "Args did not match after the config");

        // Test the message construction
        uint256 mintAmount = 1;
        Client.EVM2AnyMessage memory message = _gauge.buildCCIPMessage(mintAmount, ICCIPGauge.PayFeesIn.LINK);
        assertEq(keccak256(message.extraArgs), keccak256(anyExtraArgs), "Wrong args in the message");
    }

    function testTransferWithFeesInLINK() public {
        address gauge = address(_gauge);
        uint256 initialGaugeBalance = 100e18;
        uint256 mintAmount = 6048000000000000;

        Client.EVM2AnyMessage memory message = _gauge.buildCCIPMessage(mintAmount, ICCIPGauge.PayFeesIn.LINK);
        uint256 fees = _gauge.calculateFee(message);

        deal(_LINK, gauge, fees);
        deal(_CCIP_BNM, gauge, initialGaugeBalance);

        vm.warp(block.timestamp + 1 weeks);

        vm.expectEmit(false, false, false, true);
        emit CCIPTransferMessage(_MESSAGE_ID_LINK);

        vm.prank(_checkpointer);
        _gauge.checkpoint();

        uint256 gaugeBalance = IERC20(_CCIP_BNM).balanceOf(gauge);

        // ensure `mintAmount` was transferred from the `gauge` balance
        assertEq(initialGaugeBalance, gaugeBalance + mintAmount, "Unexpected balance change");
    }

    function testTransferWithFeesInETH() public {
        address gauge = address(_gauge);
        uint256 initialGaugeBalance = 100e18;

        deal(_CCIP_BNM, gauge, initialGaugeBalance);

        uint256 mintAmount = 6048000000000000;

        Client.EVM2AnyMessage memory message = _gauge.buildCCIPMessage(mintAmount, ICCIPGauge.PayFeesIn.Native);
        uint256 fees = _gauge.calculateFee(message);
        payable(_checkpointer).transfer(fees);

        uint256 gaugeBalance = IERC20(_CCIP_BNM).balanceOf(gauge);

        assertEq(gaugeBalance, initialGaugeBalance, "Expect to have an initial balance");

        vm.warp(block.timestamp + 1 weeks);

        vm.expectEmit(false, false, false, true);
        emit CCIPTransferMessage(_MESSAGE_ID_ETH);

        vm.prank(_checkpointer);
        _gauge.checkpoint{value: fees}();

        gaugeBalance = IERC20(_CCIP_BNM).balanceOf(gauge);

        // ensure `mintAmount` was transferred from the `gauge` balance
        assertEq(initialGaugeBalance, gaugeBalance + mintAmount, "Unexpected balance change");
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
    }
}
