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
        --ffi --broadcast --rpc-url http://127.0.0.1:8545 --verify

    Lib verification:

    ETHERSCAN_API_KEY=$ARBISCAN_API_KEY FOUNDRY_PROFILE=core forge verify-contract \
    0xe2eB6FD7743521d834650699d1419B247d3B34ef Actions \
    --chain 42161 --watch --compiler-version 0.8.28

    contracts verification:

    FOUNDRY_PROFILE=core forge verify-contract 0x058A54bF6560038ca2CB58d6CDaF17c5d93cD436 \
    silo-core/contracts/utils/ShareDebtToken.sol:ShareDebtToken \
    --libraries silo-core/contracts/lib/ShareTokenLib.sol:ShareTokenLib:0xC65Ca9496257CEC7d9d1802e3af60f62e12CD46B \
    --compiler-version 0.8.28 \
    --rpc-url $RPC_ARBITRUM \
    --watch

    FOUNDRY_PROFILE=core forge verify-contract 0x30aaA84098CD71781aafCbfE8bB06aC6643a29DC \
    silo-core/contracts/Silo.sol:Silo \
    --libraries silo-core/contracts/lib/ShareTokenLib.sol:ShareTokenLib:0xC65Ca9496257CEC7d9d1802e3af60f62e12CD46B \
    --libraries silo-core/contracts/lib/SiloLendingLib.sol:SiloLendingLib:0xC48dFAd68A909e01eE2e82EFbb3F406e3549349C \
    --libraries silo-core/contracts/lib/Actions.sol:Actions:0x23d286b11b071CBe1C5df2D6340d23D6CEd8Ff53 \
    --libraries silo-core/contracts/lib/Views.sol:Views:0x029E2F45ada84d3734b7D030D4d8bf9E169A00D7 \
    --libraries silo-core/contracts/lib/ShareCollateralTokenLib.sol:ShareCollateralTokenLib:0x939E48510C64307201aB90dE70b9405c138E8bf9 \
    --constructor-args 0x00000000000000000000000044347a91cf3e9b30f80e2161438e0f10fceda0a0 \
    --compiler-version 0.8.28 \
    --rpc-url $RPC_ARBITRUM \
    --watch
    
    FOUNDRY_PROFILE=core forge verify-contract 0x0E8696a9f49020Bb76718d705981ECb5BA725B28 \
    silo-core/contracts/utils/ShareProtectedCollateralToken.sol:ShareProtectedCollateralToken \
    --libraries silo-core/contracts/lib/ShareTokenLib.sol:ShareTokenLib:0xC65Ca9496257CEC7d9d1802e3af60f62e12CD46B \
    --libraries silo-core/contracts/lib/ShareCollateralTokenLib.sol:ShareCollateralTokenLib:0x939E48510C64307201aB90dE70b9405c138E8bf9 \
    --compiler-version 0.8.28 \
    --rpc-url $RPC_ARBITRUM \
    --watch

    FOUNDRY_PROFILE=core forge verify-contract 0x44347A91Cf3E9B30F80e2161438E0f10fCeDA0a0 \
    silo-core/contracts/SiloFactory.sol:SiloFactory \
    --libraries silo-core/contracts/lib/Views.sol:Views:0x029E2F45ada84d3734b7D030D4d8bf9E169A00D7 \
    --constructor-args 0x0000000000000000000000006d228fa4dad2163056a48fc2186d716f5c65e89a \
    --compiler-version 0.8.28 \
    --rpc-url $RPC_ARBITRUM \
    --watch

    FOUNDRY_PROFILE=core forge verify-contract 0xF2D1f664b81388C0767460d9795aE2d86a29eF7B \
    silo-core/contracts/SiloDeployer.sol:SiloDeployer \
    --libraries silo-core/contracts/lib/Views.sol:Views:0x029E2F45ada84d3734b7D030D4d8bf9E169A00D7 \
    --constructor-args 0x000000000000000000000000da91d956498d667f5db71eecd58ba02c4b960a5300000000000000000000000044347a91cf3e9b30f80e2161438e0f10fceda0a000000000000000000000000030aaa84098cd71781aafcbfe8bb06ac6643a29dc0000000000000000000000000e8696a9f49020bb76718d705981ecb5ba725b28000000000000000000000000058a54bf6560038ca2cb58d6cdaf17c5d93cd436 \
    --compiler-version 0.8.28 \
    --rpc-url $RPC_ARBITRUM \
    --watch
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
