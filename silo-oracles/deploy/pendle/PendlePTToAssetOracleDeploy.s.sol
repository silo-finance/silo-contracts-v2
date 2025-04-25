// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {PendlePTToAssetOracleFactory} from "silo-oracles/contracts/pendle/PendlePTToAssetOracleFactory.sol";
import {PendlePTToAssetOracle} from "silo-oracles/contracts/pendle/PendlePTToAssetOracle.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {OraclesDeployments} from "silo-oracles/deploy/OraclesDeployments.sol"; 
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

/**
FOUNDRY_PROFILE=oracles UNDERLYING_ORACLE_NAME=PYTH_REDSTONE_wstkscETH_ETH MARKET=0xd14117baf6EC5D12BE68CD06e763A4B82C9B6d1D \
    forge script silo-oracles/deploy/pendle/PendlePTToAssetOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract PendlePTToAssetOracleDeploy is CommonDeploy {
    PendlePTToAssetOracleFactory factory;
    ISiloOracle underlyingOracle;
    address market;

    function run() public returns (ISiloOracle oracle) {
        string memory underlyingOracleName;

        if (address(market) == address(0)) {
            underlyingOracleName = vm.envString("UNDERLYING_ORACLE_NAME");
            market = vm.envAddress("MARKET");
            underlyingOracle = ISiloOracle(OraclesDeployments.get(ChainsLib.chainAlias(), underlyingOracleName));

            address factoryAddress = getDeployedAddress(
                SiloOraclesFactoriesContracts.PENDLE_PT_TO_ASSET_ORACLE_FACTORY
            );

            factory = PendlePTToAssetOracleFactory(factoryAddress);
        }

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        oracle = factory.create({
            _underlyingOracle: underlyingOracle,
            _market: market,
            _externalSalt: bytes32(0)
        });

        vm.stopBroadcast();

        IERC20Metadata ptToken = IERC20Metadata(PendlePTToAssetOracle(address(oracle)).PT_TOKEN()); 

        string memory oracleName = string.concat(
            "PENDLE_PT_TO_ASSET_ORACLE_",
            ptToken.symbol(),
            "_",
            underlyingOracleName
        );

        OraclesDeployments.save(getChainAlias(), oracleName, address(oracle));
    }

    function setParams(
        address _market,
        ISiloOracle _underlyingOracle,
        PendlePTToAssetOracleFactory _factory
    ) external {
        market = _market;
        underlyingOracle = _underlyingOracle;
        factory = _factory;
    }
}
