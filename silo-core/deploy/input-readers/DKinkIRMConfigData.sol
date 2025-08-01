// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";

import {IDynamicKinkModel} from "silo-core/contracts/interfaces/IDynamicKinkModel.sol";

contract DKinkIRMConfigData {
    error ConfigNotFound();

    // must be in alphabetic order for JSON parsing
    struct ModelConfig {
        int256 alpha;
        int256 c1;
        int256 c2;
        int256 cminus;
        int256 cplus;
        int256 dmax;
        int256 kmax;
        int256 kmin;
        int256 rmin;
        int256 u1;
        int256 u2;
        int256 ucrit;
        int256 ulow;
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
            VmLib.vm().parseJson(_readInput("DKinkIRMConfigs"), string(abi.encodePacked("."))), (ConfigData[])
        );
    }

    function getAllConfigs() public view returns (ConfigData[] memory) {
        return _readDataFromJson();
    }

    function getConfigData(string memory _name) public view returns (IDynamicKinkModel.Config memory modelConfig) {
        ConfigData[] memory configs = _readDataFromJson();

        for (uint256 index = 0; index < configs.length; index++) {
            if (keccak256(bytes(configs[index].name)) == keccak256(bytes(_name))) {
                modelConfig.ulow = configs[index].config.ulow;
                modelConfig.u1 = configs[index].config.u1;
                modelConfig.u2 = configs[index].config.u2;
                modelConfig.ucrit = configs[index].config.ucrit;
                modelConfig.rmin = configs[index].config.rmin;
                modelConfig.kmin = configs[index].config.kmin;
                modelConfig.kmax = configs[index].config.kmax;
                modelConfig.alpha = configs[index].config.alpha;
                modelConfig.cminus = configs[index].config.cminus;
                modelConfig.cplus = configs[index].config.cplus;
                modelConfig.c1 = configs[index].config.c1;
                modelConfig.c2 = configs[index].config.c2;
                modelConfig.dmax = configs[index].config.dmax;

                return modelConfig;
            }
        }

        revert ConfigNotFound();
    }

    function print(IDynamicKinkModel.Config memory _configData) public pure {
        console2.log("ulow", _configData.ulow);
        console2.log("u1", _configData.u1);
        console2.log("u2", _configData.u2);
        console2.log("ucrit", _configData.ucrit);
        console2.log("rmin", _configData.rmin);
        console2.log("kmin", _configData.kmin);
        console2.log("kmax", _configData.kmax);
        console2.log("alpha", _configData.alpha);
        console2.log("cminus", _configData.cminus);
        console2.log("cplus", _configData.cplus);
        console2.log("c1", _configData.c1);
        console2.log("c2", _configData.c2);
        console2.log("dmax", _configData.dmax);
    }
}
