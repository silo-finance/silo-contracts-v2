// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ERC20, IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
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
import {IStakelessGauge} from "ve-silo/contracts/gauges/interfaces/IStakelessGauge.sol";
import {CCIPGaugeArbitrumDeploy} from "ve-silo/deploy/CCIPGaugeArbitrumDeploy.sol";
import {CCIPGaugeArbitrumUpgradeableBeaconDeploy} from "ve-silo/deploy/CCIPGaugeArbitrumUpgradeableBeaconDeploy.sol";
import {CCIPGaugeFactoryArbitrumDeploy} from "ve-silo/deploy/CCIPGaugeFactoryArbitrumDeploy.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {CheckpointerAdaptorMock} from "../_mocks/CheckpointerAdaptorMock.sol";
import {CCIPGaugeFactory} from "ve-silo/contracts/gauges/ccip/CCIPGaugeFactory.sol";
import {IChainlinkPriceFeedLike} from "ve-silo/test/gauges/interfaces/IChainlinkPriceFeedLike.sol";
import {CCIPTransferMessageLib} from "./CCIPTransferMessageLib.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc CCIPGaugeCheckpointer --ffi -vvv
contract CCIPGaugeCheckpointer is IntegrationTest {
    string constant internal _GAUGE_TYPE = "Ethereum";

    uint256 internal constant _FORKING_BLOCK_NUMBER = 192628160;
    uint256 internal constant _GAUGE_BALANCE = 100e18;
    uint256 internal constant _MINT_AMOUNT = 32393000;
    uint64 internal constant _DESTINATION_CHAIN = 5009297550715157269;
    uint256 internal constant _RELATIVE_WEIGHT_CAP = 1e18;
    address internal constant _LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address internal constant _WSTLINK = 0x3106E2e148525b3DB36795b04691D444c24972fB;
    address internal constant _WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant _CHAINLINK_PRICE_FEED = 0x13015e4E6f839E1Aa1016DF521ea458ecA20438c;
    address internal constant _CHAINLINL_PRICE_UPDATER = 0x6e37f4c82d9A31cc42B445874dd3c3De97AB553f;

    address internal _minter = makeAddr("Minter");
    address internal _tokenAdmin = makeAddr("Token Admin");
    address internal _gaugeController = makeAddr("Gauge Controller");
    address internal _chaildChainGauge = makeAddr("Chaild Chain Gauge");
    address internal _chaildChainGauge2 = makeAddr("Chaild Chain Gauge 2");
    address internal _gaugeAdder = makeAddr("Gauge adder");
    address internal _owner = makeAddr("Owner");
    address internal _user = makeAddr("User");
    address internal _gaugeFactory;
    address internal _deployer;

    uint256 internal _snapshotId;

    IStakelessGaugeCheckpointerAdaptor internal _adaptor;
    ICCIPGaugeCheckpointer internal _checkpointer;
    ICCIPGauge internal _gauge;

    event CCIPTransferMessage(bytes32 newMessage);

    // solhint-disable-next-line function-max-lines
    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(ARBITRUM_ONE_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);
        
        StakelessGaugeCheckpointerAdaptorDeploy adaptorDeploy = new StakelessGaugeCheckpointerAdaptorDeploy();
        CCIPGaugeCheckpointerDeploy deploy = new CCIPGaugeCheckpointerDeploy();
        deploy.disableDeploymentsSync();

        _adaptor = adaptorDeploy.run();

        setAddress(VeSiloContracts.GAUGE_ADDER, _gaugeAdder);
        setAddress(VeSiloContracts.TIMELOCK_CONTROLLER, _owner);
        setAddress(VeSiloContracts.MAINNET_BALANCER_MINTER, _minter);

        vm.mockCall(
            _gaugeAdder,
            abi.encodeWithSelector(IGaugeAdder.getGaugeController.selector),
            abi.encode(_gaugeController)
        );

        _checkpointer = deploy.run();

        _mockCallsBeforeGaugeCreation();

        CCIPGaugeArbitrumDeploy gaugeDeploy = new CCIPGaugeArbitrumDeploy();
        gaugeDeploy.run();

        CCIPGaugeArbitrumUpgradeableBeaconDeploy beaconDeploy = new CCIPGaugeArbitrumUpgradeableBeaconDeploy();
        beaconDeploy.run();

        CCIPGaugeFactoryArbitrumDeploy factoryDeploy = new CCIPGaugeFactoryArbitrumDeploy();
        CCIPGaugeFactory factory = factoryDeploy.run();

        vm.prank(_owner);
        Ownable2Step(address(factory)).acceptOwnership();

        _gaugeFactory = address(factory);

        _gauge = ICCIPGauge(factory.create(_chaildChainGauge, _RELATIVE_WEIGHT_CAP, _DESTINATION_CHAIN));
        vm.label(address(_gauge), "Gauge");

        _mockCallsAfterGaugeCreated(address(_gauge));

        vm.prank(_deployer);
        _adaptor.setStakelessGaugeCheckpointer(address(_checkpointer));

        _snapshotId = vm.snapshot();
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testCheckpointSingleGaugeLINK --ffi -vvv
    function testCheckpointSingleGaugeLINK() public {
        _setupGauge();
        _beforeCheckpointGaugeWithLINK(_gauge, address(this));

        _updateChainlinkPriceFeed();

        vm.recordLogs();

        _checkpointer.checkpointSingleGauge(_GAUGE_TYPE, _gauge, ICCIPGauge.PayFeesIn.LINK);

        CCIPTransferMessageLib.expectEmit();

        _afterCheckpointGaugeWithLINK();
        _ensureThereIsNoLeftovers(address(_gauge));
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testCheckpointSingleGaugeLINKWithFrontLoadedETH --ffi -vvv
    function testCheckpointSingleGaugeLINKWithFrontLoadedETH() public {
        // Front-loading 1 wei of ether to the gauge balance before it will be created
        uint256 amountOfEthToFrontLoad = 1;
        address userCheckpointer = makeAddr("User checkpointer");

        ICCIPGauge gaugeWithETH = _setupGaugeWithFrontLoadedEth(amountOfEthToFrontLoad);
        _beforeCheckpointGaugeWithLINK(gaugeWithETH, userCheckpointer);

        // Ensure we have correct balances
        assertEq(userCheckpointer.balance, 0, "User checkpointer should not have ether");
        assertEq(address(gaugeWithETH).balance, amountOfEthToFrontLoad, "Gauge should have ether");

        vm.recordLogs();

        vm.prank(userCheckpointer);
        _checkpointer.checkpointSingleGauge(_GAUGE_TYPE, gaugeWithETH, ICCIPGauge.PayFeesIn.LINK);

        CCIPTransferMessageLib.expectEmit();

        // Ensure we have correct balances
        // User should receive an ether from the gauge balance after checkpoint
        assertEq(userCheckpointer.balance, amountOfEthToFrontLoad, "User checkpointer should receive ether");

        _ensureThereIsNoLeftovers(address(gaugeWithETH));
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testCheckpointSingleGaugeETHWithExtraFee --ffi -vvv
    function testCheckpointSingleGaugeETHWithExtraFee() public {
        _setupGauge();

        address gauge = address(_gauge);

        deal(_WSTLINK, gauge, _GAUGE_BALANCE);

        vm.warp(block.timestamp + 1 weeks);
        _updateChainlinkPriceFeed();

        _mockMinter(gauge);

        uint256 unclaimed = IStakelessGauge(_gauge).unclaimedIncentives();

        uint256 calculatedFees = _gauge.calculateFee(unclaimed, ICCIPGauge.PayFeesIn.Native);
        uint256 extraFee = 1; // adding 1 wei to have ether leftover in the gauge after checkpoint
        uint256 fees = calculatedFees + extraFee;

        payable(_user).transfer(fees);

        uint256 gaugeBalance = IERC20(_WSTLINK).balanceOf(gauge);

        assertEq(gaugeBalance, _GAUGE_BALANCE, "Expect to have an initial balance");

        vm.recordLogs();

        vm.prank(_user);
        _checkpointer.checkpointSingleGauge{value: fees}(_GAUGE_TYPE, _gauge, ICCIPGauge.PayFeesIn.Native);

        CCIPTransferMessageLib.expectEmit();

        assertEq(_user.balance, extraFee, "Expect to receive extra ether from the fee");

        _afterCheckpointGaugeWithLINK();

        _ensureThereIsNoLeftovers(gauge);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testCheckpointSingleGaugeETH --ffi -vvv
    function testCheckpointSingleGaugeETH() public {
        _setupGauge();

        address gauge = address(_gauge);

        deal(_WSTLINK, gauge, _GAUGE_BALANCE);

        vm.warp(block.timestamp + 1 weeks);
        _updateChainlinkPriceFeed();

        _mockMinter(gauge);

        uint256 unclaimedBefore = _gauge.unclaimedIncentives();

        uint256 fees = _gauge.calculateFee(unclaimedBefore, ICCIPGauge.PayFeesIn.Native);
        // encrease fees by 10% to test leftover
        fees = fees + fees / 10;

        payable(_user).transfer(fees);

        uint256 gaugeBalance = IERC20(_WSTLINK).balanceOf(gauge);

        assertEq(gaugeBalance, _GAUGE_BALANCE, "Expect to have an initial balance");

        vm.recordLogs();

        vm.prank(_user);
        _checkpointer.checkpointSingleGauge{value: fees}(_GAUGE_TYPE, _gauge, ICCIPGauge.PayFeesIn.Native);

        CCIPTransferMessageLib.expectEmit();

        uint256 unclaimedAfter = _gauge.unclaimedIncentives();
        
        assertEq(unclaimedAfter, 0, "Expect to have no unclaimed incentives");

        _ensureThereIsNoLeftovers(gauge);
    }

    function _beforeCheckpointGaugeWithLINK(ICCIPGauge _gaugeToCheckpoint, address _userCheckpointer) internal {
        _mockMinter(address(_gaugeToCheckpoint));

        vm.warp(block.timestamp + 1 weeks);

        _updateChainlinkPriceFeed();

        uint256 unclaimed = _gaugeToCheckpoint.unclaimedIncentives();

        uint256 fees = _gaugeToCheckpoint.calculateFee(unclaimed, ICCIPGauge.PayFeesIn.LINK);

        deal(_LINK,_userCheckpointer, fees);
        deal(_WSTLINK, address(_gaugeToCheckpoint), _GAUGE_BALANCE);
        
        vm.prank(_userCheckpointer);
        IERC20(_LINK).approve(address(_checkpointer), fees);
    }

    function _afterCheckpointGaugeWithLINK() internal {
        uint256 gaugeBalance = IERC20(_WSTLINK).balanceOf(address(_gauge));

        // ensure `_MINT_AMOUNT` was transferred from the `gauge` balance
        assertEq(_GAUGE_BALANCE, gaugeBalance + _MINT_AMOUNT, "Unexpected balance change");
    }

    function _setupGauge() internal {
        ICCIPGauge[] memory gauges = new ICCIPGauge[](1);
        gauges[0] = _gauge;

        vm.prank(_deployer);
        _checkpointer.addGaugesWithVerifiedType(_GAUGE_TYPE, gauges);
    }

    function _setupGaugeWithFrontLoadedEth(uint256 _ethAmount) internal returns (ICCIPGauge _createdGauge) {
        address expectedGauge = _createExpectedGauge();

        payable(expectedGauge).transfer(_ethAmount);

        _createdGauge = ICCIPGauge(
            CCIPGaugeFactory(_gaugeFactory).create(_chaildChainGauge2, _RELATIVE_WEIGHT_CAP, _DESTINATION_CHAIN)
        );

        assertEq(expectedGauge, address(_createdGauge), "Unexpected gauge address");

        vm.label(address(_createdGauge), "Gauge with ETH");

        _mockCallsAfterGaugeCreated(address(_createdGauge));

        ICCIPGauge[] memory gauges = new ICCIPGauge[](1);
        gauges[0] = _createdGauge;

        vm.prank(_deployer);
        _checkpointer.addGaugesWithVerifiedType(_GAUGE_TYPE, gauges);
    }

    function _createExpectedGauge() internal returns (address _createdGauge) {
        _createdGauge = CCIPGaugeFactory(_gaugeFactory).create(
            _chaildChainGauge2,
            _RELATIVE_WEIGHT_CAP,
            _DESTINATION_CHAIN
        );

        vm.revertTo(_snapshotId);
    }
    
    // Ether/LINK leftover should be returned to the user
    // All components after checkpoint should not have any ether or LINK leftover
    function _ensureThereIsNoLeftovers(address _gaugeToVerify) internal {
        assertEq(_gaugeToVerify.balance, 0, "Gauge should not have ether leftover");
        assertEq(address(_adaptor).balance, 0, "Adaptor should not have ether leftover");
        assertEq(address(_checkpointer).balance, 0, "Checkpointer should not have ether leftover");

        assertEq(IERC20(_LINK).balanceOf(_gaugeToVerify), 0, "Gauge should not have LINK leftover");
        assertEq(IERC20(_LINK).balanceOf(address(_adaptor)), 0, "Adaptor should not have LINK leftover");
        assertEq(IERC20(_LINK).balanceOf(address(_checkpointer)), 0, "Checkpointer should not have LINK leftover");
    }

    function _mockMinter(address _gaugeToMock) internal {
        vm.mockCall(
            _minter,
            abi.encodeWithSelector(IBalancerMinter.minted.selector, _gaugeToMock, _gaugeToMock),
            abi.encode(0)
        );
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

    function _mockCallsAfterGaugeCreated(address _gaugeToMock) internal {
        vm.mockCall(
            _gaugeController,
            abi.encodeWithSelector(IGaugeController.checkpoint_gauge.selector, _gaugeToMock),
            abi.encode(true)
        );

        vm.mockCall(
            _gaugeController,
            abi.encodeWithSelector(IGaugeController.gauge_relative_weight.selector, _gaugeToMock, 1710979200),
            abi.encode(1e18)
        );

        vm.mockCall(
            _minter,
            abi.encodeWithSelector(IBalancerMinter.mint.selector, _gaugeToMock),
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
                _gaugeToMock
            ),
            abi.encode(true)
        );
    }

    function _updateChainlinkPriceFeed() internal {
        IChainlinkPriceFeedLike.TokenPriceUpdate[] memory tokenPrices =
            new IChainlinkPriceFeedLike.TokenPriceUpdate[](3);

        tokenPrices[0] = IChainlinkPriceFeedLike.TokenPriceUpdate({
            sourceToken: _LINK,
            usdPerToken: 17352748070000000000 // $17.35
        });

        tokenPrices[1] = IChainlinkPriceFeedLike.TokenPriceUpdate({
            sourceToken: _WSTLINK,
            usdPerToken: 17352748070000000000 // $17.35
        });

        tokenPrices[2] = IChainlinkPriceFeedLike.TokenPriceUpdate({
            sourceToken: _WETH,
            usdPerToken: 3539638400000000000000 // $3539.64
        });

        IChainlinkPriceFeedLike.GasPriceUpdate[] memory gasPrices = new IChainlinkPriceFeedLike.GasPriceUpdate[](1);
        gasPrices[0] = IChainlinkPriceFeedLike.GasPriceUpdate({
            destChainSelector: _DESTINATION_CHAIN,
            usdPerUnitGas: 106827130381460 // $0.00010682713038146
        });

        IChainlinkPriceFeedLike.PriceUpdates memory priceUpdates = IChainlinkPriceFeedLike.PriceUpdates({
            tokenPriceUpdates: tokenPrices,
            gasPriceUpdates: gasPrices
        });

        vm.prank(_CHAINLINL_PRICE_UPDATER);
        IChainlinkPriceFeedLike(_CHAINLINK_PRICE_FEED).updatePrices(priceUpdates);
    }
}
