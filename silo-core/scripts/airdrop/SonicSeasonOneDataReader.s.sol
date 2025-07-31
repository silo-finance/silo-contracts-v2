// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";

struct TransferData {
    address addr;
    uint256 amount;
}

contract SonicSeasonOneDataReader is Script {
    function readTransferData() public view returns (TransferData[] memory data) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/silo-core/scripts/airdrop/output.json");
        string memory json = vm.readFile(path);

        data = abi.decode(vm.parseJson(json, string(abi.encodePacked("."))), (TransferData[]));
    }
}
