// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
import {SiloDeployer} from "silo-core/contracts/SiloDeployer.sol";
import {IInterestRateModelV2Factory} from "silo-core/contracts/interfaces/IInterestRateModelV2Factory.sol";
import {IDynamicKinkModelFactory} from "silo-core/contracts/interfaces/IDynamicKinkModelFactory.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";

import {Silo} from "silo-core/contracts/Silo.sol";
import {ShareProtectedCollateralToken} from "silo-core/contracts/utils/ShareProtectedCollateralToken.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloImplementationDeploy.s.sol \
        --ffi --rpc-url $RPC_SONIC --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloImplementationDeploy.s.sol \
        --ffi --rpc-url $RPC_INK \
        --verify \
        --verifier blockscout \
        --verifier-url $VERIFIER_URL_INK \
        --private-key $PRIVATE_KEY \
        --resume

    Lib verification:

    FOUNDRY_PROFILE=core forge verify-contract <contract-address> \
         silo-core/contracts/lib/Actions.sol:Actions \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --compiler-version 0.8.28 \
        --num-of-optimizations 200 \
        --watch

    FOUNDRY_PROFILE=core forge verify-contract <contract-address> \
         silo-core/contracts/lib/ShareCollateralTokenLib.sol:ShareCollateralTokenLib \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --compiler-version 0.8.28 \
        --num-of-optimizations 200 \
        --watch

    FOUNDRY_PROFILE=core forge verify-contract <contract-address> \
         silo-core/contracts/lib/ShareTokenLib.sol:ShareTokenLib \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --compiler-version 0.8.28 \
        --num-of-optimizations 200 \
        --watch

    FOUNDRY_PROFILE=core forge verify-contract <contract-address> \
         silo-core/contracts/lib/SiloLendingLib.sol:SiloLendingLib \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --compiler-version 0.8.28 \
        --num-of-optimizations 200 \
        --watch

    FOUNDRY_PROFILE=core forge verify-contract <contract-address> \
         silo-core/contracts/lib/Views.sol:Views \
        --verifier blockscout --verifier-url $VERIFIER_URL_INK \
        --compiler-version 0.8.28 \
        --num-of-optimizations 200 \
        --watch
 */
contract SiloImplementationDeploy is CommonDeploy {
    function run() public returns (ISiloDeployer siloDeployer) {
        string memory chainAlias = ChainsLib.chainAlias();
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        console2.log("[SiloImplementationDeploy] chainAlias", chainAlias);

        address siloFactory = SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, chainAlias);

        require(siloFactory != address(0), string.concat(SiloCoreContracts.SILO_FACTORY, " not deployed"));
        console2.log("siloFactory", siloFactory);

        vm.startBroadcast(deployerPrivateKey);

        _deployNewSiloImplementation(ISiloFactory(siloFactory));

        vm.stopBroadcast();
    }

    function _deployNewSiloImplementation(ISiloFactory _siloFactory) internal {
        console2.log("\n[SiloImplementationDeploy] deploying new SiloImplementation\n");

        address siloImpl = address(new Silo(_siloFactory));
        address shareProtectedCollateralTokenImpl = address(new ShareProtectedCollateralToken());
        address shareDebtTokenImpl = address(new ShareDebtToken());

        _registerDeployment(siloImpl, SiloCoreContracts.SILO);

        _registerDeployment(shareProtectedCollateralTokenImpl, SiloCoreContracts.SHARE_PROTECTED_COLLATERAL_TOKEN);

        _registerDeployment(shareDebtTokenImpl, SiloCoreContracts.SHARE_DEBT_TOKEN);
    }
}
