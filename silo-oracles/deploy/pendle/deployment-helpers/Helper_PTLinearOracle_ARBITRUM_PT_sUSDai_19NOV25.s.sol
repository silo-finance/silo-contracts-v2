// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {CommonDeploy} from "../../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../../SiloOraclesFactoriesContracts.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";

import {IPTLinearOracleFactory} from "silo-oracles/contracts/interfaces/IPTLinearOracleFactory.sol";
import {IPTLinearOracle} from "silo-oracles/contracts/interfaces/IPTLinearOracle.sol";


/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/deployment-helpers/Helper_PTLinearOracle_ARBITRUM_PT_sUSDai_19NOV25.s.sol \
    --ffi --rpc-url $RPC_ARBITRUM --broadcast --verify
 */
contract Helper_PTLinearOracle_ARBITRUM_PT_sUSDai_19NOV25 is CommonDeploy {
    function run() public {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address pt_sUSDai_19NOV25 = 0x936F210d277bf489A3211CeF9AB4BC47a7B69C96;
        address market = 0x43023675c804A759cBf900Da83DBcc97ee2afbe7;
        uint256 baseDiscountPerYear = 0.25e18;

        address USDai = AddrLib.getAddress(ChainsLib.chainAlias(), AddrKey.USDai);
        require(USDai != address(0), "USDai is not set");

        address USDC = AddrLib.getAddress(ChainsLib.chainAlias(), AddrKey.USDC);
        require(USDC != address(0), "USDC is not set");

        IPTLinearOracleFactory factory = IPTLinearOracleFactory(getDeployedAddress(SiloOraclesFactoriesContracts.PT_LINEAR_ORACLE_FACTORY));

        require(address(factory) != address(0), "factory is not deployed");

        IPTLinearOracleFactory.DeploymentConfig memory config = IPTLinearOracleFactory.DeploymentConfig({
            ptMarket: market,
            expectedUnderlyingToken: USDai,
            maxYield: baseDiscountPerYear,
            hardcodedQuoteToken: USDC,
            syRateMethod: "exchangeRate()"
        });

        console2.log("config.ptMarket", address(config.ptMarket));
        console2.log("config.expectedUnderlyingToken", address(config.expectedUnderlyingToken));
        console2.log("config.maxYield", config.maxYield);
        console2.log("config.hardcodedQuoteToken", address(config.hardcodedQuoteToken));
        console2.log("config.syRateMethod", config.syRateMethod);

        vm.startBroadcast(deployerPrivateKey);
        IPTLinearOracle oracle = factory.create(config, bytes32(0));
        vm.stopBroadcast();

        console2.log("oracle", address(oracle));

        console2.log("oracle.quote(1e18, pt_sUSDai_19NOV25)", oracle.quote(1e18, pt_sUSDai_19NOV25));

        console2.log("oracle.quoteToken()", oracle.quoteToken());
    }
}
