// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";

import {IDynamicKinkModel} from "silo-core/contracts/interfaces/IDynamicKinkModel.sol";

contract DKinkIRMConfigDataReader {
    error ModelConfigNotFound();

    // must be in alphabetic order for JSON parsing
    struct KinkIRMConfig {
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

    struct KinkJsonData {
        KinkIRMConfig config;
        string name;
    }

    function _getAllConfigs() internal view returns (KinkJsonData[] memory) {
        return _readDataFromJson();
    }

    function _getModelConfig(string memory _name) internal view returns (KinkJsonData memory modelConfig) {
        KinkJsonData[] memory allKinkJsonData = _getAllConfigs();
        bool found = false;

        for (uint256 index = 0; index < allKinkJsonData.length; index++) {
            if (keccak256(bytes(allKinkJsonData[index].name)) == keccak256(bytes(_name))) {
                modelConfig = allKinkJsonData[index];

                found = true;

                break;
            }
        }

        require(found, ModelConfigNotFound());
    }

    function _printModelConfig(KinkIRMConfig memory _modelConfig) internal pure {
        console2.log("ulow", _modelConfig.ulow);
        console2.log("u1", _modelConfig.u1);
        console2.log("u2", _modelConfig.u2);
        console2.log("ucrit", _modelConfig.ucrit);
        console2.log("rmin", _modelConfig.rmin);
        console2.log("kmin", _modelConfig.kmin);
        console2.log("kmax", _modelConfig.kmax);
        console2.log("alpha", _modelConfig.alpha);
        console2.log("cminus", _modelConfig.cminus);
        console2.log("cplus", _modelConfig.cplus);
        console2.log("c1", _modelConfig.c1);
        console2.log("c2", _modelConfig.c2);
        console2.log("dmax", _modelConfig.dmax);
    }

    function _readDataFromJson() private view returns (KinkJsonData[] memory) {
        return abi.decode(
            VmLib.vm().parseJson(_readInput("DKinkIRMConfigs"), string(abi.encodePacked("."))), (KinkJsonData[])
        );
    }

    function _readInput(string memory input) private view returns (string memory) {
        string memory inputDir = string.concat(VmLib.vm().projectRoot(), "/silo-core/deploy/input/irmConfigs/kink/");
        string memory file = string.concat(input, ".json");
        return VmLib.vm().readFile(string.concat(inputDir, file));
    }
}
