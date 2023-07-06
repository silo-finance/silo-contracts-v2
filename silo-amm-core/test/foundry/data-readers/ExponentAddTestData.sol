// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/utils/Strings.sol";
import "silo-amm-core/contracts/lib/ExponentMath.sol";

contract ExponentAddTestData is Test {
    using Strings for uint256;

    struct TestData {
        Exponent a;
        Exponent b;
        Exponent sum;
    }

    TestData[] dataFromJson;

    function testData() external returns (TestData[] memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/silo-amm-core/test/foundry/data/ExponentAddTestData.json");
        string memory json = vm.readFile(path);

        uint item;
        TestData memory tmp;

        while(true) {
            string memory lp = item.toString();
            // emit log_named_string("processing item#", lp);

            try vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].a.m"))) returns (uint256) {}
            catch { break; }

            tmp.a.e = uint64(vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].a.e"))));
            tmp.a.m = uint64(vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].a.m"))));
            tmp.b.e = uint64(vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].b.e"))));
            tmp.b.m = uint64(vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].b.m"))));
            tmp.sum.e = uint64(vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].sum.e"))));
            tmp.sum.m = uint64(vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].sum.m"))));

            dataFromJson.push(tmp);

            item++;
        }

        return dataFromJson;
    }
}
