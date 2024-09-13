// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {FeeDistributorDeploy} from "ve-silo/deploy/FeeDistributorDeploy.s.sol";
import {VotingEscrowTest} from "ve-silo/test/voting-escrow/VotingEscrow.integration.t.sol";
import {IFeeDistributor} from "ve-silo/contracts/fees-distribution/interfaces/IFeeDistributor.sol";
import {IFeeSwapper} from "ve-silo/contracts/fees-distribution/interfaces/IFeeSwapper.sol";
import {IFeeSwap} from "ve-silo/contracts/fees-distribution/interfaces/IFeeSwap.sol";
import {FeeSwapperDeploy} from "ve-silo/deploy/FeeSwapperDeploy.s.sol";
import {UniswapSwapperDeploy} from "ve-silo/deploy/UniswapSwapperDeploy.s.sol";
import {UniswapSwapper} from "ve-silo/contracts/fees-distribution/fee-swapper/swappers/UniswapSwapper.sol";
import {UniswapSwapperTest} from "ve-silo/test/fee-dustribution/UniswapSwapper.integration..sol";
import {Manageable} from "ve-silo/contracts/access/Manageable.sol";
import {FeeSwapper} from "ve-silo/contracts/fees-distribution/fee-swapper/FeeSwapper.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc FeeSwapperTest --ffi -vvv
contract FeeSwapperTest is IntegrationTest {
    uint256 constant internal _FORKING_BLOCK_NUMBER = 18040200;
    address constant internal _SNX_WHALE = 0x5Fd79D46EBA7F351fe49BFF9E87cdeA6c821eF9f;

    UniswapSwapperTest internal _uniswapSwapperTest;
    IFeeDistributor internal _feeDistributor;
    IFeeSwapper internal _feeSwapper;
    FeeSwapperDeploy internal _feeSwapperDeploy;
    IERC20 internal _testAsset = IERC20(makeAddr("Test asset"));
    IFeeSwap internal _testSwap = IFeeSwap(makeAddr("Test swap"));
    IERC20 internal _snxToken;
    IERC20 internal _wethToken;
    IERC20 internal _siloToken;
    UniswapSwapper internal _feeSwap;

    address internal _user1 = makeAddr("User1");
    address internal _user2 = makeAddr("User2");
    address internal _tokenHolder = makeAddr("Token holder");
    address internal _deployer;

    event SwapperUpdated(IERC20 asset, IFeeSwap swapper);

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(MAINNET_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        VotingEscrowTest votingEscrowTest = new VotingEscrowTest();
        votingEscrowTest.deployVotingEscrowForTests();

        FeeDistributorDeploy feeDistributorDeploy = new FeeDistributorDeploy();
        feeDistributorDeploy.disableDeploymentsSync();

        _feeDistributor = feeDistributorDeploy.run();

        _feeSwapperDeploy = new FeeSwapperDeploy();
        _feeSwapper = _feeSwapperDeploy.run();

        vm.warp(feeDistributorDeploy.startTime() + 1 seconds);

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);

        UniswapSwapperDeploy swapDeploy = new UniswapSwapperDeploy();
        swapDeploy.disableDeploymentsSync();

        _feeSwap = UniswapSwapper(address(swapDeploy.run()));

        _snxToken = IERC20(getAddress(AddrKey.SNX));
        _wethToken = IERC20(getAddress(AddrKey.WETH));
        _siloToken = IERC20(getAddress(SILO_TOKEN));

        _uniswapSwapperTest = new UniswapSwapperTest();
    }

    function testOnlyOwnerCanConfigureSwappers() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        _addSwapper(address(this), _testAsset, _testSwap);

        vm.expectEmit(false, false, true, true);
        emit SwapperUpdated(_testAsset, _testSwap);

        _addSwapper(_deployer, _testAsset, _testSwap);
    }

    function testSwapFees() public {
        _preconfigureSwap();

        address[] memory inputs = _swapInputs();

        uint256 balance = _wethToken.balanceOf(address(_feeSwapper));
        assertEq(balance, 0, "Expect has no ETH before the swap");

        uint256 expectedAmount = 4005102755468086219;
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodePacked(expectedAmount);

        vm.expectRevert(abi.encodePacked(Manageable.OnlyManager.selector));
        _feeSwapper.swapFees(inputs, data);

        vm.prank(_deployer);
        _feeSwapper.swapFees(inputs, data);

        balance = _wethToken.balanceOf(address(_feeSwapper));
        assertEq(balance, expectedAmount, "Expect to have ETH after the swap");

        data = new bytes[](2);
        data[0] = abi.encodePacked(expectedAmount);
        data[1] = abi.encodePacked(expectedAmount);

        vm.prank(_deployer);
        vm.expectRevert(abi.encodePacked(FeeSwapper.ArraysLengthMissMutch.selector));
        _feeSwapper.swapFees(inputs, data);
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testSwapFeesAndDeposit --ffi -vvv
    function testGetSiloTokens() public {
        uint256 amount = 1e18;
        deal(getAddress(AddrKey.WETH), address(_feeSwapper), amount);

        uint256 balance = _siloToken.balanceOf(address(_feeSwapper));
        assertEq(balance, 0, "SILO token balance should be 0");

        uint256 expectedAmount = 36186755173227576313430;

        _feeSwapper.getSiloTokens(expectedAmount);

        balance = _siloToken.balanceOf(address(_feeSwapper));
        assertEq(balance, expectedAmount, "Expecting to have SILO tokens");
    }

    function testFeeDistributor() public {
        uint256 amount = 1000e18;

        deal(address(_siloToken), address(_feeSwapper), amount);

        _feeSwapper.depositSiloTokens(amount);

        uint256 tokenBalance = _feeDistributor.getTokenLastBalance(_siloToken);

        assertEq(tokenBalance, amount, "Token balance differs from the expected tokens amount");
    }

    // FOUNDRY_PROFILE=ve-silo-test forge test --mt testSwapFeesAndDeposit --ffi -vvv
    function testSwapFeesAndDeposit() public {
        _preconfigureSwap();
        address[] memory inputs = _swapInputs();

        uint256 tokenBalance = _feeDistributor.getTokenLastBalance(_siloToken);
        assertEq(tokenBalance, 0, "Expect has no any token balance in the FeeDistributor");

        uint256 expectedAmount = 6587321744;
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodePacked(expectedAmount);

        uint256 siloExpectedAmount = 143215631856922242299414;

        vm.expectRevert(abi.encodePacked(Manageable.OnlyManager.selector));
        _feeSwapper.swapFeesAndDeposit(inputs, data, siloExpectedAmount);

        vm.prank(_deployer);
        _feeSwapper.swapFeesAndDeposit(inputs, data, siloExpectedAmount);

        tokenBalance = _feeDistributor.getTokenLastBalance(_siloToken);
        assertEq(tokenBalance, siloExpectedAmount,"Expect to has token balance in the FeeDistributor");
    }

    function _preconfigureSwap() internal {
        uint256 snxAmount = 100_000e18;
        vm.prank(_SNX_WHALE);
        _snxToken.transfer(address(_feeSwapper), snxAmount);

        _addSwapper(_deployer, _snxToken, IFeeSwap(address(_feeSwap)));
        
        UniswapSwapper.SwapPath[] memory swapPath = _uniswapSwapperTest.getConfig();
        
        vm.prank(_deployer);
        _feeSwap.configurePath(_snxToken, swapPath);
    }

    function _addSwapper(address _signer, IERC20 _asset, IFeeSwap _swap) internal {
        IFeeSwapper.SwapperConfigInput[] memory configs = new IFeeSwapper.SwapperConfigInput[](1);
        configs[0] = IFeeSwapper.SwapperConfigInput({
            asset: _asset,
            swap: _swap
        });

        vm.prank(_signer);
        _feeSwapper.setSwappers(configs);
    }

    function _swapInputs() internal view returns (address[] memory inputs) {
        inputs = new address[](1);
        inputs[0] = address(_snxToken);
    }
}
