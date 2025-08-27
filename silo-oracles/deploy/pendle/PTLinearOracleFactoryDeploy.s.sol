// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {PTLinearOracleFactory} from "silo-oracles/contracts/pendle/linear/PTLinearOracleFactory.sol";
import {IPTLinearOracleFactory} from "silo-oracles/contracts/interfaces/IPTLinearOracleFactory.sol";
import {IPTLinearOracle} from "silo-oracles/contracts/interfaces/IPTLinearOracle.sol";

import {AddrKey} from "common/addresses/AddrKey.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";

/**
FOUNDRY_PROFILE=oracles \
    forge script silo-oracles/deploy/pendle/PTLinearOracleFactoryDeploy.s.sol \
    --ffi --rpc-url $RPC_ARBITRUM --broadcast --verify
 */
contract PTLinearOracleFactoryDeploy is CommonDeploy {
    function run() public returns (address factory) {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        address pendleLinearOracleFactory = AddrLib.getAddress(ChainsLib.chainAlias(), AddrKey.PENDLE_LINEAR_ORACLE_FACTORY);
        console2.log("pendleLinearOracleFactory", pendleLinearOracleFactory);
        require(pendleLinearOracleFactory != address(0), "pendleLinearOracleFactory is not set");

        vm.startBroadcast(deployerPrivateKey);

        factory = address(new PTLinearOracleFactory(pendleLinearOracleFactory));

        vm.stopBroadcast();

        // _testFactory(factory);

        _registerDeployment(factory, SiloOraclesFactoriesContracts.PT_LINEAR_ORACLE_FACTORY);
    }

    // function _testFactory(address _factory) internal {
    //     // code to test the factory
    //     address pt_sUSDai_19NOV25 = 0x936F210d277bf489A3211CeF9AB4BC47a7B69C96;
    //     address USDai = AddrLib.getAddress(ChainsLib.chainAlias(), AddrKey.USDai);
    //     address USDC = AddrLib.getAddress(ChainsLib.chainAlias(), AddrKey.USDC);

    //     address market = 0x43023675c804A759cBf900Da83DBcc97ee2afbe7;
    //     uint256 baseDiscountPerYear = 0.25e18;

    //     IPTLinearOracleFactory.DeploymentConfig memory config = IPTLinearOracleFactory.DeploymentConfig({
    //         ptMarket: market,
    //         expectedUnderlyingToken: USDai,
    //         maxYield: baseDiscountPerYear,
    //         hardcodedQuoteToken: USDC,
    //         syRateMethod: "exchangeRate()"
    //     });

    //     IPTLinearOracle oracle = PTLinearOracleFactory(factory).create(config, bytes32(0));


    //     console2.log("oracle", address(oracle));

    //     console2.log("oracle.quote(1e18, pt_sUSDai_19NOV25)", oracle.quote(1e18, pt_sUSDai_19NOV25));

    //     console2.log("oracle.quoteToken()", oracle.quoteToken());
    // }
}
