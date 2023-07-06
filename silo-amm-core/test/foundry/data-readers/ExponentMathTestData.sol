// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/utils/Strings.sol";
import "silo-amm-core/contracts/lib/ExponentMath.sol";

contract ExponentMathTestData is Test {
    using Strings for uint256;

    struct TestData {
        uint256 scalar;
        Exponent exp;
    }

    TestData[] dataFromJson;

    function testData() external returns (TestData[] memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/silo-amm-core/test/foundry/data/ExponentMathTestData.json");
        string memory json = vm.readFile(path);

        uint item;
        TestData memory tmp;

        while(true) {
            string memory lp = item.toString();
            // emit log_named_string("processing item#", lp);

            try vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].scalar"))) returns (uint256) {}
            catch { break; }

            uint256 decimals = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].decimals")));

            tmp.scalar = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].scalar"))) * 10 ** decimals;
            tmp.exp.e = uint64(vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].exp.e"))));
            tmp.exp.m = uint64(vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].exp.m"))));

            dataFromJson.push(tmp);

            item++;
        }

        return dataFromJson;
    }
}
