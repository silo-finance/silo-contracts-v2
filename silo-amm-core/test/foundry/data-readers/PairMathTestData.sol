// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/utils/Strings.sol";

contract PairMathTestData is Test {
    using Strings for uint256;

    struct TestData {
        uint256 debtQuote;
        uint256 onSwapK;
        uint256 fee;
        uint256 debtAmountIn;
        uint256 debtAmountInFee;
    }

    TestData[] dataFromJson;

    function testData() external returns (TestData[] memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/silo-amm-core/test/foundry/data/PairMathTest.json");
        string memory json = vm.readFile(path);

        uint item;
        TestData memory tmp;

        while(true) {
            string memory lp = item.toString();
            // emit log_named_string("processing item#", lp);

            try vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].fee"))) returns (uint256) {}
            catch { break; }

            tmp.debtQuote = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].debtQuote")));
            tmp.onSwapK = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].onSwapK")));
            tmp.fee = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].fee")));
            tmp.debtAmountIn = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].expected.debtAmountIn")));
            tmp.debtAmountInFee = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].expected.debtAmountInFee")));

            dataFromJson.push(tmp);

            item++;
        }

        return dataFromJson;
    }
}
