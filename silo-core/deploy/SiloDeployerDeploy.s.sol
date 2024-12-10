// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "./_CommonDeploy.sol";
import {SiloCoreContracts, SiloCoreDeployments} from "silo-core/common/SiloCoreContracts.sol";
import {SiloDeployer} from "silo-core/contracts/SiloDeployer.sol";
import {IInterestRateModelV2Factory} from "silo-core/contracts/interfaces/IInterestRateModelV2Factory.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISiloDeployer} from "silo-core/contracts/interfaces/ISiloDeployer.sol";
import {Silo} from "silo-core/contracts/Silo.sol";
import {ShareProtectedCollateralToken} from "silo-core/contracts/utils/ShareProtectedCollateralToken.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";

/**
    FOUNDRY_PROFILE=core \
        forge script silo-core/deploy/SiloDeployerDeploy.s.sol \
        --ffi --broadcast --rpc-url http://127.0.0.1:8545

    Lib verification:

    ETHERSCAN_API_KEY=$ARBISCAN_API_KEY FOUNDRY_PROFILE=core forge verify-contract \
    0xe2eB6FD7743521d834650699d1419B247d3B34ef Actions \
    --chain 42161 --watch --compiler-version v0.8.28+commit.7893614a

    ETHERSCAN_API_KEY=$ARBISCAN_API_KEY FOUNDRY_PROFILE=core forge verify-contract \
    0x6De1C2dfc9061ABF37ee709Fe2776c74f09715c5 ShareCollateralTokenLib \
    --chain 42161 --watch --compiler-version v0.8.28+commit.7893614a

    ETHERSCAN_API_KEY=$ARBISCAN_API_KEY FOUNDRY_PROFILE=core forge verify-contract \
    0x2f332bBF37E0F42Ef01cDB2327cFd21BE2f5f41F ShareTokenLib \
    --chain 42161 --watch --compiler-version v0.8.28+commit.7893614a

    ETHERSCAN_API_KEY=$ARBISCAN_API_KEY FOUNDRY_PROFILE=core forge verify-contract \
    0x44Fa9F351fC12C47f1c7935E7d29A9B8dabAfe24 SiloLendingLib \
    --chain 42161 --watch --compiler-version v0.8.28+commit.7893614a

    ETHERSCAN_API_KEY=$ARBISCAN_API_KEY FOUNDRY_PROFILE=core forge verify-contract \
    0x08D5095e6e8B13D43C7A0C172373ae24e3B66895 Views \
    --chain 42161 --watch --compiler-version v0.8.28+commit.7893614a



    cast abi-encode "constructor(address,uint256,address,string,string)" \
    0xB85420016C1Df4e6Ad6e461Cf927913B5E04A430 86400 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1 "Test Vault1" "TV1"

    ETHERSCAN_API_KEY=$ARBISCAN_API_KEY FOUNDRY_PROFILE=vaults forge verify-contract \
    0xdA72ab48AD4389B427b44d0dad393D5E5b209514 silo-vaults/contracts/MetaMorpho.sol:MetaMorpho \
    --chain 42161 --watch --compiler-version v0.8.28+commit.7893614a \
    --constructor-args <cast abi-encode output>
 */
contract SiloDeployerDeploy is CommonDeploy {
    function run() public returns (ISiloDeployer siloDeployer) {
        string memory chainAlias = getChainAlias();
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        ISiloFactory siloFactory = ISiloFactory(SiloCoreDeployments.get(SiloCoreContracts.SILO_FACTORY, chainAlias));

        address irmConfigFactory = SiloCoreDeployments.get(
            SiloCoreContracts.INTEREST_RATE_MODEL_V2_FACTORY,
            chainAlias
        );

        vm.startBroadcast(deployerPrivateKey);

        address siloImpl = address(new Silo(siloFactory));
        address shareProtectedCollateralTokenImpl = address(new ShareProtectedCollateralToken());
        address shareDebtTokenImpl = address(new ShareDebtToken());

        siloDeployer = ISiloDeployer(address(new SiloDeployer(
            IInterestRateModelV2Factory(irmConfigFactory),
            siloFactory,
            siloImpl,
            shareProtectedCollateralTokenImpl,
            shareDebtTokenImpl
        )));

        vm.stopBroadcast();

        _registerDeployment(address(siloDeployer), SiloCoreContracts.SILO_DEPLOYER);
        _registerDeployment(address(siloImpl), SiloCoreContracts.SILO);

        _registerDeployment(
            address(shareProtectedCollateralTokenImpl),
            SiloCoreContracts.SHARE_PROTECTED_COLLATERAL_TOKEN
        );

        _registerDeployment(address(shareDebtTokenImpl), SiloCoreContracts.SHARE_DEBT_TOKEN);
    }
}
