// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";

import {IFeeDistributor} from "ve-silo/contracts/fees-distribution/interfaces/IFeeDistributor.sol";
import {FeeSwapper, IFeeSwapper} from "ve-silo/contracts/fees-distribution/fee-swapper/FeeSwapper.sol";

/**
FOUNDRY_PROFILE=ve-silo-test \
    forge script ve-silo/deploy/FeeSwapperDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract FeeSwapperDeploy is CommonDeploy {
    bytes32 constant public POOL_ID_ETH = 0x9cc64ee4cb672bc04c54b00a37e1ed75b2cc19dd0002000000000000000004c1;

    function run() public returns (IFeeSwapper feeSwapper) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address weth = getAddress(AddrKey.WETH);
        address silo = getAddress(SILO_TOKEN);
        address balancerVault = getAddress(AddrKey.BALANCER_VAULT);
        address feeDistributor = getDeployedAddress(VeSiloContracts.FEE_DISTRIBUTOR);

        bytes32 poolId = _poolId();

        vm.startBroadcast(deployerPrivateKey);

        IFeeSwapper.SwapperConfigInput[] memory _configs;

        feeSwapper = IFeeSwapper(address(
            new FeeSwapper(
                IERC20(weth),
                IERC20(silo),
                balancerVault,
                poolId,
                IFeeDistributor(feeDistributor),
                _configs
            )
        ));

        vm.stopBroadcast();

        _registerDeployment(address(feeSwapper), VeSiloContracts.FEE_SWAPPER);
    }

    function _poolId() internal returns (bytes32 poolId) {
        if (isChain(MAINNET_ALIAS)) return POOL_ID_ETH;

        revert UnsopportedNetworkForDeploy(getChain(getChainId()).chainAlias);
    }
}
