// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

import {CommonDeploy} from "../_CommonDeploy.sol";

import {IInterestRateModelV2} from "silo-core/contracts/interfaces/IInterestRateModelV2.sol";

contract InterestRateModelConfigData is Test, CommonDeploy {
    error ConfigNotFound();

    // must be in alphabetic order
    struct ModelConfig {
        int256 beta;
        int256 kcrit;
        int256 ki;
        int256 klin;
        int256 klow;
        int256 ucrit;
        int256 ulow;
        int256 uopt;
    }

    struct ConfigData {
        ModelConfig config;
        string name;
    }

    function _readInput(string memory input) internal view returns (string memory) {
        string memory inputDir = string.concat(vm.projectRoot(), "/silo-core/deploy/input/");
        string memory chainDir = string.concat(ChainsLib.chainAlias(block.chainid), "/");
        string memory file = string.concat(input, ".json");
        return vm.readFile(string.concat(inputDir, chainDir, file));
    }

    function _readDataFromJson() internal view returns (ConfigData[] memory) {
        return abi.decode(
            vm.parseJson(_readInput("InterestRateModelConfigs"), string(abi.encodePacked("."))), (ConfigData[])
        );
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

                return modelConfig;
            }
        }

        revert ConfigNotFound();
    }

    function print(IInterestRateModelV2.Config memory _configData) public {
        emit log_named_int("beta", _configData.beta);
        emit log_named_int("kcrit", _configData.kcrit);
        emit log_named_int("ki", _configData.ki);
        emit log_named_int("klin", _configData.klin);
        emit log_named_int("klow", _configData.klow);
        emit log_named_int("ucrit", _configData.ucrit);
        emit log_named_int("ulow", _configData.ulow);
        emit log_named_int("uopt", _configData.uopt);
    }
}
