// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {PendlePTOracleFactory} from "silo-oracles/contracts/pendle/PendlePTOracleFactory.sol";
import {PendlePTOracle} from "silo-oracles/contracts/pendle/PendlePTOracle.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {OraclesDeployments} from "silo-oracles/deploy/OraclesDeployments.sol"; 
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";


interface IPendleMarketV3 {
    function increaseObservationsCardinalityNext(uint16 cardinalityNext) external;
}

/**
FOUNDRY_PROFILE=oracles UNDERLYING_ORACLE_NAME=CHAINLINK_USDC_USD_aggregator MARKET=0x43023675c804A759cBf900Da83DBcc97ee2afbe7 \
    forge script silo-oracles/deploy/pendle/PendlePTOracleDeploy.s.sol \
    --ffi --rpc-url $RPC_ARBITRUM --broadcast --verify
 */
contract PendlePTOracleDeploy is CommonDeploy {
    ISiloOracle underlyingOracle;
    address market;

    function run() public returns (ISiloOracle oracle) {
        PendlePTOracleFactory factory =
            PendlePTOracleFactory(getDeployedAddress(SiloOraclesFactoriesContracts.PENDLE_PT_ORACLE_FACTORY));

        string memory underlyingOracleName;

        if (address(market) == address(0)) {
            underlyingOracleName = vm.envString("UNDERLYING_ORACLE_NAME");
            market = vm.envAddress("MARKET");
            underlyingOracle = ISiloOracle(OraclesDeployments.get(ChainsLib.chainAlias(), underlyingOracleName));
        }

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);

        /* 
        uncomment below line in case of issue with cardinality, or do it in etherscan
        
        issue looks like this:
            PendlePYLpOracle::getOracleState(PendleMarketV3, 1800) [delegatecall]
    │   │   │   │   ├─ [5018] PendleMarketV3::_storage() [staticcall]
    │   │   │   │   │   └─ ← [Return] [5.942e23], [4.652e23], [1.414e17], 0, 1, 1 (<<< _storage)
    │   │   │   │   ├─ [2512] PendleMarketV3::observations(0) [staticcall]
    │   │   │   │   │   └─ ← [Return] [1.756e9], [8.409e22], true
    │   │   │   │   └─ ← [Return] true, 1801, false
    │   │   │   └─ ← [Return] true, 1801, false
        │   └─ ← [Revert] PendleOracleNotReady()
        
        last 3 variables in _storage() are:
        observationIndex   uint16 :  0
        observationCardinality   uint16 :  1
        observationCardinalityNext   uint16 :  1 << we need this to be 1801 for 30 min

        increase can be done in steps.

        we might also ask business to increase cardinality, as it might be expensive
        */

        // IPendleMarketV3(market).increaseObservationsCardinalityNext(900);
        // IPendleMarketV3(market).increaseObservationsCardinalityNext(1801);

        oracle = factory.create({
            _underlyingOracle: underlyingOracle,
            _market: market,
            _externalSalt: bytes32(0)
        });

        vm.stopBroadcast();

        IERC20Metadata ptToken = IERC20Metadata(PendlePTOracle(address(oracle)).PT_TOKEN()); 

        string memory oracleName = string.concat(
            "PENDLE_PT_ORACLE_",
            ptToken.symbol(),
            "_",
            underlyingOracleName
        );

        OraclesDeployments.save(getChainAlias(), oracleName, address(oracle));
    }

    function setParams(address _market, ISiloOracle _underlyingOracle) external {
        market = _market;
        underlyingOracle = _underlyingOracle;
    }
}
