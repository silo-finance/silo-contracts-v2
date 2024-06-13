// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {UniswapSwapperDeploy} from "ve-silo/deploy/UniswapSwapperDeploy.s.sol";
import {UniswapSwapper} from "ve-silo/contracts/fees-distribution/fee-swapper/swappers/UniswapSwapper.sol";

// FOUNDRY_PROFILE=ve-silo-test forge test --mc UniswapSwapperTest --ffi -vvv
contract UniswapSwapperTest is IntegrationTest {
    uint256 constant internal _FORKING_BLOCK_NUMBER = 18040200;

    address internal _deployer;
    address public snxWhale = 0x5Fd79D46EBA7F351fe49BFF9E87cdeA6c821eF9f;

    UniswapSwapper public feeSwap;

    IERC20 internal _snxToken;
    IERC20 internal _wethToken;

    event ConfigUpdated(IERC20 asset);

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(MAINNET_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);

        UniswapSwapperDeploy deploy = new UniswapSwapperDeploy();
        deploy.disableDeploymentsSync();

        feeSwap = UniswapSwapper(address(deploy.run()));

        _snxToken = IERC20(getAddress(AddrKey.SNX));
        _wethToken = IERC20(getAddress(AddrKey.WETH));
    }

    function testonlyOwnerCanConfigure() public {
        UniswapSwapper.SwapPath[] memory swapPath = getConfig();

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        feeSwap.configurePath(_snxToken, swapPath);

        vm.expectEmit(false, false, false, true);
        emit ConfigUpdated(_snxToken);
        
        vm.prank(_deployer);
        feeSwap.configurePath(_snxToken, swapPath);
    }

    function testSwap() public {
        configureSwapper();

        uint256 amount = 1000e18;
        vm.prank(snxWhale);
        _snxToken.transfer(address(feeSwap), amount);

        assertEq(_snxToken.balanceOf(address(feeSwap)), amount, "Expect to have tokens before swap");

        uint256 balance = _wethToken.balanceOf(address(this));
        assertEq(balance, 0, "Expect has no ETH before the swap");

        uint256 expectedAmount = 1163347406737788006;
        bytes memory data = abi.encodePacked(expectedAmount + 1); // One wei more than we can receive

        vm.expectRevert("Too little received");
        feeSwap.swap(_snxToken, amount, data);
        
        data = abi.encodePacked(expectedAmount);
        feeSwap.swap(_snxToken, amount, data);

        balance = _wethToken.balanceOf(address(this));
        assertEq(balance, expectedAmount, "Expect to have ETH after the swap");
    }

    function configureSwapper() public {
        UniswapSwapper.SwapPath[] memory swapPath = getConfig();
        vm.prank(_deployer);
        feeSwap.configurePath(_snxToken, swapPath);
    }

    function getConfig() public returns (UniswapSwapper.SwapPath[] memory swapPath) {
        swapPath = new UniswapSwapper.SwapPath[](2);

        swapPath[0] = UniswapSwapper.SwapPath({
            pool: IUniswapV3Pool(getAddress(AddrKey.SNX_USDC_UNIV3_POOL)),
            token0IsInterim: true
        });

        swapPath[1] = UniswapSwapper.SwapPath({
            pool: IUniswapV3Pool(getAddress(AddrKey.USDC_ETH_UNI_POOL)),
            token0IsInterim: false
        });
    }
}
