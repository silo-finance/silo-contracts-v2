// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console2} from "forge-std/console2.sol";

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";

import {PriceFormatter} from "silo-core/deploy/lib/PriceFormatter.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {
    SiloOraclesFactoriesContracts,
    SiloOraclesFactoriesDeployments
} from "silo-oracles/deploy/SiloOraclesFactoriesContracts.sol";


import {SaveDeployedOracle} from "../_common/SaveDeployedOracle.sol";

import {IFixedPricePTAMMOracleFactory} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleFactory.sol";
import {IFixedPricePTAMMOracleConfig} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracleConfig.sol";
import {IFixedPricePTAMMOracle} from "silo-oracles/contracts/interfaces/IFixedPricePTAMMOracle.sol";
import {IPendleAMM} from "silo-oracles/contracts/interfaces/IPendleAMM.sol";

/*
FOUNDRY_PROFILE=oracles \
 PT_TOKEN=PT_Ethena_USDe_27Nov2025 \
 PT_UNDERLYING_QUOTE_TOKEN=USDe \
 HARDCODED_QUOTE_TOKEN=USDC \
    forge script silo-oracles/deploy/pendle/FixedPricePTAmmOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_AVALANCHE --broadcast --verify
 */
contract FixedPricePTAmmOracleDeploy is CommonDeploy, SaveDeployedOracle {
    function run() public {
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory config = IFixedPricePTAMMOracleConfig.DeploymentConfig({
            amm: IPendleAMM(AddrLib.getAddress(ChainsLib.chainAlias(), AddrKey.PENDLE_FIXED_PRICE_AMM_ORACLE)),
            ptToken: AddrLib.getAddress(ChainsLib.chainAlias(), vm.envString("PT_TOKEN")),
            ptUnderlyingQuoteToken: AddrLib.getAddress(ChainsLib.chainAlias(), vm.envString("PT_UNDERLYING_QUOTE_TOKEN")),
            hardcoddedQuoteToken: AddrLib.getAddress(ChainsLib.chainAlias(), vm.envString("HARDCODED_QUOTE_TOKEN"))
        });

        _deployPTAmmOracle(config);
    }

    function _deployPTAmmOracle(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) internal {
        require(_config.hardcoddedQuoteToken != address(0), "hardcoddedQuoteToken is not set");

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        string memory chainAlias = ChainsLib.chainAlias();

        IFixedPricePTAMMOracleFactory factory = IFixedPricePTAMMOracleFactory(
            SiloOraclesFactoriesDeployments.get(
                SiloOraclesFactoriesContracts.FIXED_PRICE_PT_AMM_ORACLE_FACTORY, chainAlias
            )
        );

        console2.log("factory: ", address(factory));
        require(address(factory) != address(0), "factory is not deployed");

        address existingOracle = factory.resolveExistingOracle(factory.hashConfig(_config));

        console2.log("existing oracle: ", existingOracle);

        if (existingOracle != address(0)) {
            _querySamplePrice(IFixedPricePTAMMOracle(existingOracle), _config);
            return;
        }

        vm.startBroadcast(deployerPrivateKey);
        IFixedPricePTAMMOracle oracle = factory.create(_config, bytes32(0));
        vm.stopBroadcast();

        console2.log("deployed oracle: ", address(oracle));

        _saveDeployedOracle(address(oracle), _makeOracleName(_config));

        _querySamplePrice(oracle, _config);
    }

    function _makeOracleName(IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config) internal view returns (string memory) {
        bool hardcodedQuote = _config.hardcoddedQuoteToken != _config.ptUnderlyingQuoteToken;

        return string.concat(
            "PENDLE_FIXED_PRICE_PT_AMM_ORACLE_",
            IERC20Metadata(_config.ptToken).symbol(),
            "_",
            hardcodedQuote ? "HARDCODED_" : "",
            IERC20Metadata(hardcodedQuote ? _config.hardcoddedQuoteToken : _config.ptUnderlyingQuoteToken).symbol()
        );
    }

    function _querySamplePrice(
        IFixedPricePTAMMOracle _oracle,
        IFixedPricePTAMMOracleConfig.DeploymentConfig memory _config
    ) internal view {
        uint256 samplePrice = _oracle.quote(1e18, _config.ptToken);
        console2.log("sample price for 1e18 PT: ", PriceFormatter.formatPriceInE18(samplePrice));
    }
}
