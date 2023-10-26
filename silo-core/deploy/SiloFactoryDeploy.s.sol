// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {CommonDeploy, SiloCoreContracts} from "./_CommonDeploy.sol";

import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {SiloFactory} from "silo-core/contracts/SiloFactory.sol";
import {Silo} from "silo-core/contracts/Silo.sol";
import {ShareCollateralToken} from "silo-core/contracts/utils/ShareCollateralToken.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";

import {console2} from "forge-std/console2.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloFactoryDeploy.s.sol:SiloFactoryDeploy \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545
 */
contract SiloFactoryDeploy is CommonDeploy {
    function run() public returns (ISiloFactory siloFactory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        siloFactory = ISiloFactory(address(new SiloFactory()));

        address siloImpl = address(new Silo(siloFactory));
        address shareCollateralTokenImpl = address(new ShareCollateralToken());
        address shareDebtTokenImpl = address(new ShareDebtToken());

        uint256 daoFee = 0.15e18;
        address daoFeeReceiver = VeSiloDeployments.get(VeSiloContracts.FEE_DISTRIBUTOR, getChainAlias());

        siloFactory.initialize(siloImpl, shareCollateralTokenImpl, shareDebtTokenImpl, daoFee, daoFeeReceiver);

        address timelock = VeSiloDeployments.get(VeSiloContracts.TIMELOCK_CONTROLLER, getChainAlias());
        OwnableUpgradeable(address(siloFactory)).transferOwnership(timelock);

        vm.stopBroadcast();

        _registerDeployment(address(siloFactory), SiloCoreContracts.SILO_FACTORY);
        _syncDeployments();
    }
}
