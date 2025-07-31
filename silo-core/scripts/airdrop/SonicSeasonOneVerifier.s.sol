// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {SonicSeasonOneDataReader, TransferData} from "silo-core/scripts/airdrop/SonicSeasonOneDataReader.s.sol";

/*
    Verifies that amount is sent correctly. BLOCK_AFTER is after airdrop tx, BLOCK_BEFORE is before tx.
    FOUNDRY_PROFILE=core START=0 END=15 BLOCK_BEFORE=40744674 BLOCK_AFTER=40744675 \
    forge script silo-core/scripts/airdrop/SonicSeasonOneVerifier.s.sol \
    --ffi --rpc-url $RPC_SONIC
 */

contract SonicSeasonOneVerifier is SonicSeasonOneDataReader {
    uint256 start;
    uint256 end;
    uint256 blockAfter;
    uint256 blockBefore;

    function run() public {
        if (start == 0 && end == 0) {
            start = vm.envUint("START");
            end = vm.envUint("END");
            blockBefore = vm.envUint("BLOCK_BEFORE");
            blockAfter = vm.envUint("BLOCK_AFTER");
        }

        require(start < end, "end <= start");
        require(blockBefore < blockAfter, "blockAfter <= blockBefore");
        address addressWithProblem = _validateAirdrop();

        if (addressWithProblem == address(0)) {
            console2.log("SUCCESS, balances changed as expected for all addresses");
        } else {
            console2.log("FAILED at least for address", addressWithProblem);
            revert("FAILED");
        }
    }

    function _validateAirdrop() internal returns (address addressWithProblem) {
        uint256 cachedFork = vm.activeFork();
        TransferData[] memory data = readTransferData();

        // forking on the same block will shadow the state of balances in tests
        if (blockAfter != block.number) {
            vm.createSelectFork(string(abi.encodePacked(vm.envString("RPC_SONIC"))), blockAfter);
        }

        uint256[] memory balancesAfterAirdrop = new uint256[](data.length);

        for (uint256 i = start; i < end; i++) {
            balancesAfterAirdrop[i] = data[i].addr.balance;
        }

        vm.createSelectFork(string(abi.encodePacked(vm.envString("RPC_SONIC"))), blockBefore);

        for (uint256 i = start; i < end; i++) {
            if (data[i].addr.balance + data[i].amount != balancesAfterAirdrop[i]) {
                addressWithProblem = data[i].addr;
                break;
            }
        }

        // bring back initial state to not break block when imported by other script
        vm.selectFork(cachedFork);
    }

    function setBatch(uint256 _start, uint256 _end, uint256 _blockBefore, uint256 _blockAfter) external {
        start = _start;
        end = _end;
        blockBefore = _blockBefore;
        blockAfter = _blockAfter;
    }
}
