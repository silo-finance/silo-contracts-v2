// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

/**
FOUNDRY_PROFILE=core CONFIG=0xC1F3d4F5f734d6Dc9E7D4f639EbE489Acd4542ab \
    forge script silo-core/deploy/silo/SiloVerifier.s.sol \
    --ffi --rpc-url $RPC_SONIC
 */
contract SiloVerifier is Script, Test {
    function run() public {
        ISiloConfig siloConfig = ISiloConfig(vm.envAddress("CONFIG"));

        (address silo0, address silo1) = siloConfig.getSilos();

        _printSilo(siloConfig, silo0);
        _printSilo(siloConfig, silo1);
    }

    function _printSilo(ISiloConfig _siloConfig, address _silo) internal {
        emit log_named_address("\nsiloConfig", address(_siloConfig));

        ISiloConfig.ConfigData memory configData = ISiloConfig(_siloConfig).getConfig(_silo);

        (address silo0,) = _siloConfig.getSilos();

        emit log_string(_silo == silo0 ? "silo0" : "silo1");
        emit log_named_address("silo", _silo);
        emit log_named_address("token", configData.token);
        emit log_named_string("symbol", IERC20Metadata(configData.token).symbol());
        emit log_named_uint("decimals", IERC20Metadata(configData.token).decimals());

        // print the config data
        emit log_named_decimal_uint("daoFee", configData.daoFee, 18);
        emit log_named_decimal_uint("deployerFee", configData.deployerFee, 18);
        emit log_named_decimal_uint("liquidationFee", configData.liquidationFee, 18);
        emit log_named_decimal_uint("flashloanFee", configData.flashloanFee, 18);
        emit log_named_decimal_uint("maxLtv", configData.maxLtv, 18);
        emit log_named_decimal_uint("lt", configData.lt, 18);
        emit log_named_decimal_uint("liquidationTargetLtv", configData.liquidationTargetLtv, 18);
        emit log_named_address("solvencyOracle", configData.solvencyOracle);
        emit log_named_address("maxLtvOracle", configData.maxLtvOracle);

        _verifySiloImplementation(_silo);

        _printOracleInfo(configData.solvencyOracle, configData.token);
    }

    function _printOracleInfo(address _oracle, address _baseToken) internal {
        ISiloOracle oracle = ISiloOracle(_oracle);

        address quoteToken = oracle.quoteToken();
        uint256 quoteTokenDecimals = IERC20Metadata(quoteToken).decimals();

        console2.log("\nOracle:", _oracle);
        console2.log("Token name:", IERC20Metadata(_baseToken).name());
        console2.log("Token symbol:", IERC20Metadata(_baseToken).symbol());
        console2.log("Token decimals:", IERC20Metadata(_baseToken).decimals());
        console2.log("Quote token:", quoteToken);
        console2.log("Quote token decimals:", quoteTokenDecimals);

        uint256 quote = oracle.quote(10 ** IERC20Metadata(_baseToken).decimals(), _baseToken);

        emit log_named_uint("Quote for 1 base token:", quote);
        emit log_named_decimal_uint("Quote for 1 base token (18 decimals):", quote, 18);
    }

    function _verifySiloImplementation(address _silo) internal returns (uint256 errorsCounter) {
        bytes memory bytecode = address(_silo).code;

        if (bytecode.length != 45) {
            emit log_string("Can't verify implementation");
            return 1;
        }

        uint256 offset = 10;
        uint256 length = 20;

        bytes memory implBytes = new bytes(length);

        for (uint256 i = offset; i < offset + length; i++) {
            implBytes[i - offset] = bytecode[i];
        }

        address impl = address(bytes20(implBytes));

        bool isOurImplementation = false;

        string memory root = vm.projectRoot();
        string memory abiPath = string.concat(root, "/silo-core/deploy/silo/_siloImplementations.json");
        string memory json = vm.readFile(abiPath);

        string memory chainAlias = ChainsLib.chainAlias();

        bytes memory chainData = vm.parseJson(json, string(abi.encodePacked(".", chainAlias)));

        for (uint256 i = 0; i < chainData.length; i++) {
            bytes memory implementationData = vm.parseJson(
                json,
                string(abi.encodePacked(".", chainAlias, "[", vm.toString(i), "].implementation"))
            );

            address implementationAddress = abi.decode(implementationData, (address));

            if (impl == implementationAddress) {
                isOurImplementation = true;
                break;
            }
        }

        emit log_named_address("Implementation", impl);

        return isOurImplementation ? 0 : 1;
    }
}
