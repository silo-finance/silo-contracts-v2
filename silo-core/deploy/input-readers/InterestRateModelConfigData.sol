// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";

import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";

contract InterestRateModelConfigData {
    error ConfigNotFound();

    // must be in alphabetic order
    struct ModelConfig {
        int256 Tcrit;
        int256 beta;
        int256 kcrit;
        int256 ki;
        int256 klin;
        int256 klow;
        int256 ri;
        int256 ucrit;
        int256 ulow;
        int256 uopt;
    }

    struct ConfigData {
        ModelConfig config;
        string name;
    }

    function _readInput(string memory input) internal view returns (string memory) {
        string memory inputDir = string.concat(VmLib.vm().projectRoot(), "/silo-core/deploy/input/");
        string memory file = string.concat(input, ".json");
        return VmLib.vm().readFile(string.concat(inputDir, file));
    }

    function _readDataFromJson() internal view returns (ConfigData[] memory) {
        return abi.decode(
            VmLib.vm().parseJson(_readInput("InterestRateModelConfigs"), string(abi.encodePacked("."))), (ConfigData[])
        );
    }

    function getAllConfigs() public view returns (ConfigData[] memory) {
        return _readDataFromJson();
    }

    function getConfigData(string memory _name) public view returns (IInterestRateModelV2.Config memory modelConfig) {
        ConfigData[] memory configs = _readDataFromJson();

        for (uint256 index = 0; index < configs.length; index++) {
            if (keccak256(bytes(configs[index].name)) == keccak256(bytes(_name))) {
                modelConfig.beta = configs[index].config.beta;
                modelConfig.ki = configs[index].config.ki;
                modelConfig.kcrit = configs[index].config.kcrit;
                modelConfig.klin = configs[index].config.klin;
                modelConfig.klow = configs[index].config.klow;
                modelConfig.ucrit = configs[index].config.ucrit;
                modelConfig.ulow = configs[index].config.ulow;
                modelConfig.uopt = configs[index].config.uopt;
                modelConfig.ri = int112(configs[index].config.ri);
                modelConfig.Tcrit = int112(configs[index].config.Tcrit);

                require(modelConfig.ri == configs[index].config.ri, "ri overflow");
                require(modelConfig.Tcrit == configs[index].config.Tcrit, "Tcrit overflow");

                return modelConfig;
            }
        }

        revert ConfigNotFound();
    }

    function print(IInterestRateModelV2.Config memory _configData) public pure {
        console2.log("Tcrit", _configData.Tcrit);
        console2.log("beta", _configData.beta);
        console2.log("kcrit", _configData.kcrit);
        console2.log("ki", _configData.ki);
        console2.log("klin", _configData.klin);
        console2.log("klow", _configData.klow);
        console2.log("ri", _configData.ri);
        console2.log("ucrit", _configData.ucrit);
        console2.log("ulow", _configData.ulow);
        console2.log("uopt", _configData.uopt);
    }
}
