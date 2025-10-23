// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {VmLib} from "silo-foundry-utils/lib/VmLib.sol";

import {IDynamicKinkModel} from "silo-core/contracts/interfaces/IDynamicKinkModel.sol";

contract DKinkIRMImmutableDataReader {
    error ImmutableArgsNotFound(string name);

    // must be in alphabetic order for JSON parsing
    struct ImmutableJsonData {
        string name;
        uint256 rcompCap;
        uint256 timelock;
    }

    struct ImmutableArgs {
        string name;
        IDynamicKinkModel.ImmutableArgs args;
    }

    function _getAllImmutableArgs() internal view returns (ImmutableArgs[] memory args) {
        ImmutableJsonData[] memory allImmutableArgs = _readImmutableDataFromJson();
        args = new ImmutableArgs[](allImmutableArgs.length);

        for (uint256 index = 0; index < allImmutableArgs.length; index++) {
            args[index] = _castToImmutableArgs(allImmutableArgs[index]);
        }

        return args;
    }

    function _getImmutableArgs(string memory _name) internal view returns (ImmutableArgs memory args) {
        ImmutableArgs[] memory allImmutableArgs = _getAllImmutableArgs();
        bool found = false;

        for (uint256 index = 0; index < allImmutableArgs.length; index++) {
            if (keccak256(bytes(allImmutableArgs[index].name)) == keccak256(bytes(_name))) {
                args = allImmutableArgs[index];

                found = true;

                break;
            }
        }

        require(found, ImmutableArgsNotFound(_name));
    }

    function _castToImmutableArgs(ImmutableJsonData memory _immutableArgs)
        private
        pure
        returns (ImmutableArgs memory args)
    {
        args.args.timelock = uint32(_immutableArgs.timelock);
        args.args.rcompCap = int96(int256(_immutableArgs.rcompCap));
        args.name = _immutableArgs.name;
    }

    function _printImmutableArgs(ImmutableArgs memory _immutableArgs) internal pure {
        console2.log("\nname:", _immutableArgs.name);
        console2.log("\ttimelock:", _immutableArgs.args.timelock);
        console2.log("\trcompCap:", _immutableArgs.args.rcompCap);
        console2.log("--------------------------------");

    }

    function _readImmutableDataFromJson() private view returns (ImmutableJsonData[] memory) {
        return abi.decode(
            VmLib.vm().parseJson(_readImmutableInput("DKinkIRMImmutable"), string(abi.encodePacked("."))),
            (ImmutableJsonData[])
        );
    }

    function _readImmutableInput(string memory input) private view returns (string memory) {
        string memory inputDir = string.concat(VmLib.vm().projectRoot(), "/silo-core/deploy/input/irmConfigs/kink/");
        string memory file = string.concat(input, ".json");
        return VmLib.vm().readFile(string.concat(inputDir, file));
    }
}
