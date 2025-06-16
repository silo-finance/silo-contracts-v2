// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

import {console2} from "forge-std/console2.sol";

import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

import {Deployer} from "silo-foundry-utils/deployer/Deployer.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";

import {SiloOraclesFactoriesDeployments} from "./SiloOraclesFactoriesContracts.sol";

contract CommonDeploy is Deployer {
    string internal constant _FORGE_OUT_DIR = "cache/foundry/out/silo-oracles";

    function _forgeOutDir() internal pure override virtual returns (string memory) {
        return _FORGE_OUT_DIR;
    }

    function _deploymentsSubDir() internal pure override virtual returns (string memory) {
        return SiloOraclesFactoriesDeployments.DEPLOYMENTS_DIR;
    }

    function printQuote(
        ISiloOracle _oracle,
        address _baseToken,
        uint256 _baseAmount
    ) internal view returns (uint256 quote) {
        try _oracle.quote(_baseAmount, _baseToken) returns (uint256 price) {
            require(price > 0, string.concat("Quote for ", _formatNumberInE(_baseAmount), " wei is 0"));
            console2.log(string.concat("Quote for ", _formatNumberInE(_baseAmount), " wei is ", _formatNumberInE(price)));
            quote = price;
        } catch {
            console2.log(string.concat("Failed to quote", _formatNumberInE(_baseAmount), "wei"));
        }
    }

    function _formatNumberInE(uint256 _in) internal pure returns (string memory) {
        if (_in < 1e3) return vm.toString(_in);

        uint256 e;
        uint256 out = _in;

        while (out != 0) {
            if (out % 10 != 0) break;

            e++;
            out /= 10;
        }

        if (e < 3 || _in < 1e7) return vm.toString(_in);

        return string.concat(vm.toString(out), "e", vm.toString(e));
    }

    function _printMetadata(address _token) internal view {
        console2.log("Token name:", IERC20Metadata(_token).name());
        console2.log("Token symbol:", IERC20Metadata(_token).symbol());
        console2.log("Token decimals:", IERC20Metadata(_token).decimals());
    }
}
