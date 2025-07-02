// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {console2} from "forge-std/console2.sol";

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {Deployer} from "silo-foundry-utils/deployer/Deployer.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {PriceFormatter} from "silo-core/deploy/lib/PriceFormatter.sol";

import {SiloOraclesFactoriesDeployments} from "./SiloOraclesFactoriesContracts.sol";

contract CommonDeploy is Deployer {
    string internal constant _FORGE_OUT_DIR = "cache/foundry/out/silo-oracles";

    function _forgeOutDir() internal view override virtual returns (string memory) {
        return _FORGE_OUT_DIR;
    }

    function _contractBaseDir() internal view override virtual returns (string memory baseDir) {
        baseDir = "";
    }

    function _deploymentsSubDir() internal view override virtual returns (string memory) {
        return SiloOraclesFactoriesDeployments.DEPLOYMENTS_DIR;
    }

    function printQuote(
        ISiloOracle _oracle,
        address _baseToken,
        uint256 _baseAmount
    ) internal view returns (uint256 quote) {
        try _oracle.quote(_baseAmount, _baseToken) returns (uint256 price) {
            require(price > 0, string.concat("Quote for ", PriceFormatter.formatNumberInE(_baseAmount), " wei is 0"));
            console2.log(string.concat("Quote for ", PriceFormatter.formatNumberInE(_baseAmount), " wei is ", PriceFormatter.formatNumberInE(price)));
            quote = price;
        } catch {
            console2.log(string.concat("Failed to quote", PriceFormatter.formatNumberInE(_baseAmount), "wei"));
        }
    }

    function _printMetadata(address _token) internal view {
        console2.log("Token name:", IERC20Metadata(_token).name());
        console2.log("Token symbol:", IERC20Metadata(_token).symbol());
        console2.log("Token decimals:", IERC20Metadata(_token).decimals());
    }
}
