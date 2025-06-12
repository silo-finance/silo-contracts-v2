// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {CommonDeploy} from "../CommonDeploy.sol";
import {SiloOraclesFactoriesContracts} from "../SiloOraclesFactoriesContracts.sol";
import {ERC4626OracleHardcodeQuoteFactory} from "silo-oracles/contracts/erc4626/ERC4626OracleHardcodeQuoteFactory.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {OraclesDeployments} from "../OraclesDeployments.sol";

/**
FOUNDRY_PROFILE=oracles VAULT=woS HARDCODE_QUOTE_TOKEN=USDC \
    forge script silo-oracles/deploy/erc4626/ERC4626OracleHardcodeQuoteDeploy.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast --verify
 */
contract ERC4626OracleHardcodeQuoteDeploy is CommonDeploy {
    string public vaultKey;
    string public quoteTokenKey;

    function setVaultKey(string memory _vaultKey) public {
        vaultKey = _vaultKey;   
    }

    function setQuoteTokenKey(string memory _quoteTokenKey) public {
        quoteTokenKey = _quoteTokenKey;
    }

    function run() public returns (ISiloOracle oracle) {
        AddrLib.init();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        if (bytes(vaultKey).length == 0) {
            vaultKey = vm.envString("VAULT");
        }

        if (bytes(quoteTokenKey).length == 0) {
            quoteTokenKey = vm.envString("HARDCODE_QUOTE_TOKEN");
        }

        string memory chainAlias = ChainsLib.chainAlias();

        IERC4626 vault = IERC4626(AddrLib.getAddressSafe(chainAlias, vaultKey));
        address quoteToken = AddrLib.getAddressSafe(chainAlias, quoteTokenKey);

        address factory = getDeployedAddress(SiloOraclesFactoriesContracts.ERC4626_ORACLE_HARDCODE_QUOTE_FACTORY);

        vm.startBroadcast(deployerPrivateKey);

        oracle = ERC4626OracleHardcodeQuoteFactory(factory).createERC4626Oracle(vault, quoteToken, bytes32(0));

        vm.stopBroadcast();

        string memory oracleName = string.concat("ERC4626_", vaultKey, "_HARDCODE_QUOTE_", quoteTokenKey);

        OraclesDeployments.save(getChainAlias(), oracleName, address(oracle));
    }
}
