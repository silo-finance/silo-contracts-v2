// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {CommonDeploy, VeSiloContracts} from "./_CommonDeploy.sol";
import {IVeBoost} from "ve-silo/contracts/voting-escrow/interfaces/IVeBoost.sol";

/**
FOUNDRY_PROFILE=ve-silo \
    forge script ve-silo/deploy/VeBoostDeploy.s.sol \
    --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract VeBoostDeploy is CommonDeploy {
    string internal constant _BASE_DIR = "external/balancer-v2-monorepo/pkg/liquidity-mining/contracts";

    function run() public returns (IVeBoost veBoost) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

         address veBoostAddr = _deploy(
            VeSiloContracts.VE_BOOST,
            abi.encode(
                address(0), // veBoostV1 - an empty address
                _votingEscrowAddress()
            )
         );

        veBoost = IVeBoost(veBoostAddr);

        vm.stopBroadcast();

        _syncDeployments();
    }

    function _votingEscrowAddress() internal returns (address) {
        if (!isChain(MAINNET_ALIAS)) return getDeployedAddress(VeSiloContracts.VOTING_ESCROW_CHILD_CHAIN);

        return getDeployedAddress(VeSiloContracts.VOTING_ESCROW);
    }

    function _contractBaseDir() internal pure override virtual returns (string memory) {
        return _BASE_DIR;
    }
}
