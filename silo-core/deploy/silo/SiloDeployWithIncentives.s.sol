// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";

import {SiloDeployWithDeployerOwner} from "silo-core/deploy/silo/SiloDeployWithDeployerOwner.s.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {
    SiloIncentivesControllerCreateAndConfigure
} from "silo-core/deploy/incentives-controller/SiloIncentivesControllerCreateAndConfigure.sol";

/**
FOUNDRY_PROFILE=core CONFIG=wS_scUSD_Silo INCENTIVES_OWNER=GROWTH_MULTISIG INCENTIVIZED_ASSET=scUSD \
    forge script silo-core/deploy/silo/SiloDeployWithIncentives.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify

    It is possible to define an optional parameter for share token type:
    SHARE_TOKEN_TYPE=COLLATERAL (borrowable collateral, default value)
    SHARE_TOKEN_TYPE=COLLATERAL_ONLY (protected deposits)
    SHARE_TOKEN_TYPE=DEBT (debt share token)
 */
contract SiloDeployWithIncentives is SiloDeployWithDeployerOwner {
    function run() public override returns (ISiloConfig siloConfig) {
        siloConfig = super.run();

        SiloIncentivesControllerCreateAndConfigure createAndConfigure =
            new SiloIncentivesControllerCreateAndConfigure();

        createAndConfigure.createIncentivesController().setSiloConfig(address(siloConfig));
        createAndConfigure.run();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        address hookReceiver = createAndConfigure.createIncentivesController().hookReceiver();
        address dao = AddrLib.getAddress(AddrKey.DAO);

        vm.startBroadcast(deployerPrivateKey);

        Ownable(hookReceiver).transferOwnership(dao);

        vm.stopBroadcast();
    }
}
