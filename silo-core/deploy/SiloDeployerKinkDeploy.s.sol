// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {console2} from "forge-std/console2.sol";

import {CommonDeploy} from "./_CommonDeploy.sol";

import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
import {SiloDeployerKink} from "silo-core/contracts/interestRateModel/kink/SiloDeployerKink.sol";
import {SiloDeployer} from "silo-core/contracts/SiloDeployer.sol";
import {IInterestRateModelFactory} from "silo-core/contracts/interfaces/IInterestRateModelFactory.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";
import {Silo} from "silo-core/contracts/Silo.sol";
import {ShareProtectedCollateralToken} from "silo-core/contracts/utils/ShareProtectedCollateralToken.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloDeployerKinkDeploy.s.sol \
        --ffi --rpc-url $RPC_INK --broadcast --verify

    Resume verification:
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloDeployerKinkDeploy.s.sol \
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
contract SiloDeployerKinkDeploy is CommonDeploy {
    function run() public returns (ISiloDeployer siloDeployerKink) {
        string memory chainAlias = ChainsLib.chainAlias();
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        ISiloFactory siloFactory = ISiloFactory(SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, chainAlias));
        SiloDeployer irmV2SiloDeployer = SiloDeployer(SiloCoreDeployments.get(SiloCoreContracts.SILO_DEPLOYER, chainAlias));

        address irmConfigFactory = SiloCoreDeployments.get(
            SiloCoreContracts.DYNAMIC_KINK_MODEL_FACTORY,
            chainAlias
        );

        address siloImpl;
        address shareProtectedCollateralTokenImpl;
        address shareDebtTokenImpl;

        // reuse implementations from SiloDeployer if already deployed
        if (address(irmV2SiloDeployer) != address(0)) {
            console2.log("[SiloDeployerKinkDeploy] SiloDeployer already deployed, reusing implementations");

            siloImpl = irmV2SiloDeployer.SILO_IMPL();
            shareProtectedCollateralTokenImpl = irmV2SiloDeployer.SHARE_PROTECTED_COLLATERAL_TOKEN_IMPL();
            shareDebtTokenImpl = irmV2SiloDeployer.SHARE_DEBT_TOKEN_IMPL();
        }

        vm.startBroadcast(deployerPrivateKey);

        if (siloImpl == address(0)) siloImpl = address(new Silo(siloFactory));
        if (shareProtectedCollateralTokenImpl == address(0)) shareProtectedCollateralTokenImpl = address(new ShareProtectedCollateralToken());
        if (shareDebtTokenImpl == address(0)) shareDebtTokenImpl = address(new ShareDebtToken());

        siloDeployerKink = ISiloDeployer(address(new SiloDeployerKink(
            IInterestRateModelFactory(irmConfigFactory),
            siloFactory,
            siloImpl,
            shareProtectedCollateralTokenImpl,
            shareDebtTokenImpl
        )));

        vm.stopBroadcast();

        _registerDeployment(address(siloDeployerKink), SiloCoreContracts.SILO_DEPLOYER_KINK);
        _registerDeployment(address(siloImpl), SiloCoreContracts.SILO);

        _registerDeployment(
            address(shareProtectedCollateralTokenImpl),
            SiloCoreContracts.SHARE_PROTECTED_COLLATERAL_TOKEN
        );

        _registerDeployment(address(shareDebtTokenImpl), SiloCoreContracts.SHARE_DEBT_TOKEN);
    }
}
