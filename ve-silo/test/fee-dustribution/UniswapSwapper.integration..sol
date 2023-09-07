// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {UniswapSwapperDeploy} from "ve-silo/deploy/UniswapSwapperDeploy.s.sol";
import {UniswapSwapper} from "ve-silo/contracts/fees-distribution/fee-swapper/swappers/UniswapSwapper.sol";

import {VeSiloAddresses} from "ve-silo/deploy/_CommonDeploy.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc UniswapSwapperTest --ffi -vvv
contract UniswapSwapperTest is IntegrationTest, VeSiloAddresses {
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

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        _deployer = vm.addr(deployerPrivateKey);

        UniswapSwapperDeploy deploy = new UniswapSwapperDeploy();
        deploy.disableDeploymentsSync();

        feeSwap = UniswapSwapper(address(deploy.run()));

        _snxToken = IERC20(getAddress(SNX));
        _wethToken = IERC20(getAddress(WETH));
    }

    function testonlyOwnerCanConfigure() public {
        UniswapSwapper.SwapPath[] memory swapPath = getConfig();

        vm.expectRevert("Ownable: caller is not the owner");
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

        feeSwap.swap(_snxToken, amount);

        balance = _wethToken.balanceOf(address(this));
        assertEq(balance, 1163347406737788006, "Expect to have ETH after the swap");
    }

    function configureSwapper() public {
        UniswapSwapper.SwapPath[] memory swapPath = getConfig();
        vm.prank(_deployer);
        feeSwap.configurePath(_snxToken, swapPath);
    }

    function getConfig() public view returns (UniswapSwapper.SwapPath[] memory swapPath) {
        swapPath = new UniswapSwapper.SwapPath[](2);

        swapPath[0] = UniswapSwapper.SwapPath({
            pool: IUniswapV3Pool(getAddress(SNX_USDC_UNIV3_POOL)),
            token0IsInterim: true
        });

        swapPath[1] = UniswapSwapper.SwapPath({
            pool: IUniswapV3Pool(getAddress(USDC_ETH_UNI_POOL)),
            token0IsInterim: false
        });
    }
}
