// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {VeSiloAddrKey} from "ve-silo/common/VeSiloAddresses.sol";

import {IFeeSwap} from "ve-silo/contracts/fees-distribution/interfaces/IFeeSwap.sol";
import {UniswapSwapper} from "ve-silo/contracts/fees-distribution/fee-swapper/swappers/UniswapSwapper.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/UniswapSwapperDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract UniswapSwapperDeploy is CommonDeploy {
    function run() public returns (IFeeSwap uniswapSwapper) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        uniswapSwapper = IFeeSwap(address(
            new UniswapSwapper(getAddress(VeSiloAddrKey.UNISWAP_ROUTER))
        ));

        vm.stopBroadcast();

        _registerDeployment(address(uniswapSwapper), VeSiloContracts.UNISWAP_SWAPPER);

        _syncDeployments();
    }
}
