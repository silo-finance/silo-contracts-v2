// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

contract AmmPriceModelTestData is Test {
    using Strings for uint256;

    enum Action { INIT, ADD_LIQUIDITY, SWAP, WITHDRAW }

    struct TestData {
        uint time;
        uint tCur;
        uint tPast;
        uint twap;
        bool al;
        bool swap;
        int k;
        uint price;
        Action action;
    }

    TestData[] dataFromJson;

    function testData() external returns (TestData[] memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/silo-amm/test/foundry/data/AmmPriceModelTest.json");
        string memory json = vm.readFile(path);

        uint item;
        TestData memory tmp;

        while(true) {
            string memory lp = item.toString();
            // emit log_named_string("processing item#", lp);

            try vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].price"))) returns (uint256) {}
            catch { break; }

            tmp.time = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].time")));
            tmp.tCur = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].tCur")));
            tmp.tPast = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].tPast")));
            tmp.twap = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].twap")));
            tmp.al = vm.parseJsonBool(json, string(abi.encodePacked(".[", lp, "].AL")));
            tmp.swap = vm.parseJsonBool(json, string(abi.encodePacked(".[", lp, "].SWAP")));

            tmp.k = vm.parseJsonInt(json, string(abi.encodePacked(".[", lp, "].k")));
            tmp.price = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].price")));
            tmp.action = Action(vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].action"))));

            // emit log_named_uint("price", tmp.price);
            // emit log_named_int("k", tmp.k);

            dataFromJson.push(tmp);

            item++;
        }

        return dataFromJson;
    }
}
