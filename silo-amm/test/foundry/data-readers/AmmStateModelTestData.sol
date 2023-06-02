// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

contract AmmStateModelTestData is Test {
    using Strings for uint256;

    enum Action { STATE_CHECK, ADD_LIQUIDITY, SWAP, WITHDRAW }

    struct StateData {
        uint collateralAmount;
        uint liquidationTimeValue;
        uint shares;
        uint availableCollateral;
        uint debtAmount;
        uint r;
    }

    struct TestData {
        address user;
        Action action;
        uint amount;
        uint price;
        StateData userState;
        StateData totalState;
    }

    TestData[] private dataFromJson;

    function testData() external returns (TestData[] memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/silo-amm/test/foundry/data/AmmStateModelTest.json");
        string memory json = vm.readFile(path);

        uint item;

        while(true) {
            string memory lp = item.toString();
            TestData memory tmp;

            try vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].user"))) returns (uint256) {}
            catch { break; }

            tmp.user = address(uint160(vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].user")))));
            tmp.action = Action(vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].action"))));
            tmp.amount = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].amount")));
            tmp.price = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].price")));

            if (tmp.action == Action.SWAP) {
                dataFromJson.push(tmp);
                item++;
                continue;
            }

            StateData memory user;

            user.collateralAmount = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].userState.Ai")));
            user.liquidationTimeValue = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].userState.Vi")));
            user.shares = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].userState.Si")));
            user.availableCollateral = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].userState.Ci")));
            user.debtAmount = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].userState.Di")));
            user.r = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].userState.Ri")));

            tmp.userState = user;

            StateData memory total;

            total.collateralAmount = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].totalState.A")));
            total.liquidationTimeValue = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].totalState.V")));
            total.shares = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].totalState.S")));
            total.availableCollateral = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].totalState.C")));
            total.debtAmount = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].totalState.D")));
            total.r = vm.parseJsonUint(json, string(abi.encodePacked(".[", lp, "].totalState.R")));

            tmp.totalState = total;

            // emit log_named_address("user", tmp.user);
            // emit log_named_uint("price", tmp.price);

            dataFromJson.push(tmp);
            item++;
        }

        return dataFromJson;
    }
}
