// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

/**
FOUNDRY_PROFILE=core \
    forge script silo-core/scripts/airdrop/SonicSeasonOneAirdrop.s.sol \
    --ffi --rpc-url $RPC_SONIC
 */

struct TransferData {
    address addr;
    uint256 amount;
}

contract SonicSeasonOneAirdrop is Script {
    function run() public {
        console2.log("Network:", ChainsLib.chainAlias());
        TransferData[] memory data = readTransferData();

        for (uint256 i; i < data.length; i++) {
            console2.log(i, data[i].addr, data[i].amount);
        }
    }

    function readTransferData() internal view returns (TransferData[] memory data) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/silo-core/scripts/airdrop/output.json");
        string memory json = vm.readFile(path);

        data = abi.decode(vm.parseJson(json, string(abi.encodePacked("."))), (TransferData[]));
    }
}
