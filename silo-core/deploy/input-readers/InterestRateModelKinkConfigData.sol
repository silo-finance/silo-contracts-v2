// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";

import {IDynamicKinkModel} from "silo-core/contracts/interfaces/IDynamicKinkModel.sol";

contract InterestRateModelKinkConfigData {
    error ConfigNotFound();

    // must be in alphabetic order
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
    }

    struct ConfigData {
        ModelConfig config;
        string name;
    }

    function getAllConfigs() public view virtual returns (ConfigData[] memory) {
        return _readDataFromJson();
    }

    function getConfigData(string memory _name) public view virtual returns (bytes memory modelConfig) {
        ConfigData[] memory configs = _readDataFromJson();

        for (uint256 index = 0; index < configs.length; index++) {
            if (keccak256(bytes(configs[index].name)) == keccak256(bytes(_name))) {
                modelConfig = abi.encode(
                    IDynamicKinkModel.Config({
                        ulow: configs[index].config.u1,
                        u1: configs[index].config.u1,
                        u2: configs[index].config.u2,
                        ucrit: configs[index].config.ucrit,
                        rmin: configs[index].config.rmin,
                        kmin: configs[index].config.kmin,
                        kmax: configs[index].config.kmax,
                        alpha: configs[index].config.alpha,
                        cminus: configs[index].config.cminus,
                        cplus: configs[index].config.cplus,
                        c1: configs[index].config.c1,
                        c2: configs[index].config.c2,
                        dmax: configs[index].config.dmax
                    })
                );

                print(modelConfig);

                return modelConfig;
            }
        }

        revert ConfigNotFound();
    }

    function print(bytes memory _configData) public pure virtual {
        IDynamicKinkModel.Config memory cfg = abi.decode(_configData, (IDynamicKinkModel.Config));

        console2.log("DynamicKinkModel.Config:");
        console2.log("ulow: ", cfg.ulow);
        console2.log("u1: ", cfg.u1);
        console2.log("u2: ", cfg.u2);
        console2.log("ucrit: ", cfg.ucrit);
        console2.log("rmin: ", cfg.rmin);
        console2.log("kmin: ", cfg.kmin);
        console2.log("kmax: ", cfg.kmax);
        console2.log("alpha: ", cfg.alpha);
        console2.log("cminus: ", cfg.cminus);
        console2.log("cplus: ", cfg.cplus);
        console2.log("c1: ", cfg.c1);
        console2.log("c2: ", cfg.c2);
        console2.log("dmax: ", cfg.dmax);
    }

    function _readInput(string memory input) internal view virtual returns (string memory) {
        string memory inputDir = string.concat(VmLib.vm().projectRoot(), "/silo-core/deploy/input/");
        string memory file = string.concat(input, ".json");
        return VmLib.vm().readFile(string.concat(inputDir, file));
    }

    function _readDataFromJson() internal view virtual returns (ConfigData[] memory) {
        return abi.decode(
            VmLib.vm().parseJson(_readInput("InterestRateModelKinkConfigs"), string(abi.encodePacked("."))),
            (ConfigData[])
        );
    }
}
