// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ERC20, IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
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
import {CCIPGaugeArbitrumDeploy} from "ve-silo/deploy/CCIPGaugeArbitrumDeploy.sol";
import {CCIPGaugeArbitrumUpgradeableBeaconDeploy} from "ve-silo/deploy/CCIPGaugeArbitrumUpgradeableBeaconDeploy.sol";
import {CCIPGaugeFactoryArbitrumDeploy} from "ve-silo/deploy/CCIPGaugeFactoryArbitrumDeploy.sol";
import {CCIPGaugeFactory} from "ve-silo/contracts/gauges/ccip/CCIPGaugeFactory.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {IChainlinkPriceFeedLike} from "ve-silo/test/gauges/interfaces/IChainlinkPriceFeedLike.sol";
import {CCIPTransferMessageLib} from "./CCIPTransferMessageLib.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc CCIPGaugeTest --ffi -vvv
contract CCIPGaugeTest is IntegrationTest {
    uint256 internal constant _FORKING_BLOCK_NUMBER = 192628160;
    uint256 internal constant _RELATIVE_WEIGHT_CAP = 1e18;
    address internal constant _LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address internal constant _WSTLINK = 0x3106E2e148525b3DB36795b04691D444c24972fB;
    address internal constant _WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant _CHAINLINK_PRICE_FEED = 0x13015e4E6f839E1Aa1016DF521ea458ecA20438c;
    address internal constant _CHAINLINL_PRICE_UPDATER = 0x6e37f4c82d9A31cc42B445874dd3c3De97AB553f;
    uint64 internal constant _DESTINATION_CHAIN = 5009297550715157269;

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
            getChainRpcUrl(ARBITRUM_ONE_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        _mockCallsBeforeGaugeCreation();

        setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, _owner);
        setAddress(VeSiloContracts.STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR, _checkpointer);
        setAddress(VeSiloContracts.MAINNET_BALANCER_MINTER, _minter);

        CCIPGaugeArbitrumDeploy gaugeDeploy = new CCIPGaugeArbitrumDeploy();
        gaugeDeploy.disableDeploymentsSync();
        gaugeDeploy.run();

        CCIPGaugeArbitrumUpgradeableBeaconDeploy beaconDeploy = new CCIPGaugeArbitrumUpgradeableBeaconDeploy();
        beaconDeploy.run();

        CCIPGaugeFactoryArbitrumDeploy factoryDeploy = new CCIPGaugeFactoryArbitrumDeploy();
        CCIPGaugeFactory factory = factoryDeploy.run();

        vm.prank(_owner);
        Ownable2Step(address(factory)).acceptOwnership();

        _gauge = ICCIPGauge(factory.create(_chaildChainGauge, _RELATIVE_WEIGHT_CAP, _DESTINATION_CHAIN));
        vm.label(address(_gauge), "Gauge");

        _mockCallsAfterGaugeCreated();

        vm.label(_CHAINLINK_PRICE_FEED, "ChainlinkPriceRegistry");
    }

    function testSetExtraArgs() public {
        bytes memory anyExtraArgs = abi.encodePacked("any extra args");

        // Test permissions and configuration
        address sender = makeAddr("another than an owner");
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, sender));
        vm.prank(sender);
        _gauge.setExtraArgs(anyExtraArgs);

        vm.expectEmit(false, false, false, true);
        emit ICCIPExtraArgsConfig.ExtraArgsUpdated(anyExtraArgs);

        vm.prank(_owner);
        _gauge.setExtraArgs(anyExtraArgs);

        assertEq(keccak256(_gauge.extraArgs()), keccak256(anyExtraArgs), "Args did not match after the config");

        // Test the message construction
        uint256 mintAmount = 1;
        Client.EVM2AnyMessage memory message = _gauge.buildCCIPMessage(mintAmount, ICCIPGauge.PayFeesIn.LINK);
        assertEq(keccak256(message.extraArgs), keccak256(anyExtraArgs), "Wrong args in the message");
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testTransferWithFeesInLINK --ffi -vvv
    function testTransferWithFeesInLINK() public {
        address gauge = address(_gauge);
        uint256 initialGaugeBalance = 100e18;

        vm.warp(block.timestamp + 1 weeks);

        vm.mockCall(
            _minter,
            abi.encodeWithSelector(IBalancerMinter.minted.selector, gauge, gauge),
            abi.encode(0)
        );

        uint256 mintAmount = _gauge.unclaimedIncentives();

        _updateChainlinkPriceFeed();

        uint256 fees = _gauge.calculateFee(mintAmount, ICCIPGauge.PayFeesIn.LINK);

        deal(_LINK, gauge, fees);
        deal(_WSTLINK, gauge, initialGaugeBalance);

        vm.recordLogs();

        vm.prank(_checkpointer);
        _gauge.checkpoint();

        CCIPTransferMessageLib.expectEmit();

        uint256 gaugeBalance = IERC20(_WSTLINK).balanceOf(gauge);

        // ensure `mintAmount` was transferred from the `gauge` balance
        assertEq(initialGaugeBalance, gaugeBalance + mintAmount, "Unexpected balance change");
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testTransferWithFeesInETH --ffi -vvv
    function testTransferWithFeesInETH() public {
        address gauge = address(_gauge);
        uint256 initialGaugeBalance = 100e18;

        vm.warp(block.timestamp + 1 weeks);

        vm.mockCall(
            _minter,
            abi.encodeWithSelector(IBalancerMinter.minted.selector, gauge, gauge),
            abi.encode(0)
        );

        uint256 mintAmount = _gauge.unclaimedIncentives();

        _updateChainlinkPriceFeed();

        deal(_WSTLINK, gauge, initialGaugeBalance);

        uint256 fees = _gauge.calculateFee(mintAmount, ICCIPGauge.PayFeesIn.Native);
        payable(_checkpointer).transfer(fees);

        uint256 gaugeBalance = IERC20(_WSTLINK).balanceOf(gauge);

        assertEq(gaugeBalance, initialGaugeBalance, "Expect to have an initial balance");

        vm.recordLogs();

        vm.prank(_checkpointer);
        _gauge.checkpoint{value: fees}();

        CCIPTransferMessageLib.expectEmit();

        gaugeBalance = IERC20(_WSTLINK).balanceOf(gauge);

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
            abi.encode(_WSTLINK)
        );

        vm.mockCall(
            _tokenAdmin,
            abi.encodeWithSelector(IBalancerTokenAdmin.RATE_REDUCTION_TIME.selector),
            abi.encode(1)
        );

        vm.mockCall(
            _tokenAdmin,
            abi.encodeWithSelector(IBalancerTokenAdmin.RATE_REDUCTION_COEFFICIENT.selector),
            abi.encode(10000000000e18)
        );

        vm.mockCall(
            _tokenAdmin,
            abi.encodeWithSelector(IBalancerTokenAdmin.RATE_DENOMINATOR.selector),
            abi.encode(1)
        );

        vm.mockCall(
            _tokenAdmin,
            abi.encodeWithSelector(IBalancerTokenAdmin.startEpochTimeWrite.selector),
            abi.encode(block.timestamp)
        );

        vm.mockCall(
            _tokenAdmin,
            abi.encodeWithSelector(IBalancerTokenAdmin.rate.selector),
            abi.encode(1e3)
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
            abi.encodeWithSelector(IGaugeController.gauge_relative_weight.selector, address(_gauge), 1710979200),
            abi.encode(0.1e18)
        );

        vm.mockCall(
            _minter,
            abi.encodeWithSelector(IBalancerMinter.mint.selector, address(_gauge)),
            abi.encode(true)
        );
    }

    function _updateChainlinkPriceFeed() internal {
        IChainlinkPriceFeedLike.TokenPriceUpdate[] memory tokenPrices =
            new IChainlinkPriceFeedLike.TokenPriceUpdate[](3);

        tokenPrices[0] = IChainlinkPriceFeedLike.TokenPriceUpdate({
            sourceToken: _LINK,
            usdPerToken: 1000097050000000000000000000000
        });

        tokenPrices[1] = IChainlinkPriceFeedLike.TokenPriceUpdate({
            sourceToken: _WSTLINK,
            usdPerToken: 1000097050000000000000000000000
        });

        tokenPrices[2] = IChainlinkPriceFeedLike.TokenPriceUpdate({
            sourceToken: _WETH,
            usdPerToken: 3539638400000000000000
        });

        IChainlinkPriceFeedLike.GasPriceUpdate[] memory gasPrices = new IChainlinkPriceFeedLike.GasPriceUpdate[](1);
        gasPrices[0] = IChainlinkPriceFeedLike.GasPriceUpdate({
            destChainSelector: _DESTINATION_CHAIN,
            usdPerUnitGas: 106827130381460
        });

        IChainlinkPriceFeedLike.PriceUpdates memory priceUpdates = IChainlinkPriceFeedLike.PriceUpdates({
            tokenPriceUpdates: tokenPrices,
            gasPriceUpdates: gasPrices
        });

        vm.prank(_CHAINLINL_PRICE_UPDATER);
        IChainlinkPriceFeedLike(_CHAINLINK_PRICE_FEED).updatePrices(priceUpdates);
    }
}
