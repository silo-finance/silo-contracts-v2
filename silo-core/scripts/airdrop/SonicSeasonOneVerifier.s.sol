// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {console2} from "forge-std/console2.sol";
import {SonicSeasonOneDataReader, TransferData} from "silo-core/scripts/airdrop/SonicSeasonOneDataReader.s.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {IMulticall3} from "silo-core/scripts/interfaces/IMulticall3.sol";
import {PriceFormatter} from "silo-core/deploy/lib/PriceFormatter.sol";
import {IsContract} from "silo-core/contracts/lib/IsContract.sol";

/*
    Verifies that amount is sent correctly. BLOCK is from tx sending funds.
    FOUNDRY_PROFILE=core START=0 END=15 BLOCK=40744675  \
    forge script silo-core/scripts/airdrop/SonicSeasonOneVerifier.s.sol \
    --ffi --rpc-url $RPC_SONIC
 */

contract SonicSeasonOneVerifier is SonicSeasonOneDataReader {
    uint256 start;
    uint256 end;
    uint256 airdropBlock;

    function run() public {
        if (start == 0 && end == 0) {
            start = vm.envUint("START");
            end = vm.envUint("END");
            airdropBlock = vm.envUint("BLOCK");
        }

        require(start < end, "end <= start");
        address addressWithProblem = _validateAirdrop();

        if (addressWithProblem == address(0)) {
            console2.log("SUCCESS, balances changed as expected for all addresses");
        } else {
            console2.log("FAILED at least for address", addressWithProblem);
            revert("FAILED");
        }
    }

    function _validateAirdrop() internal returns (address addressWithProblem) {
        TransferData[] memory data = readTransferData();
        uint256[] memory balancesAfterAirdrop = new uint256[](end - start);

        for (uint256 i = start; i < end; i++) {
            balancesAfterAirdrop[i - start] = data[i].addr.balance;
        }

        vm.createSelectFork(string(abi.encodePacked(vm.envString("RPC_SONIC"))), airdropBlock);

        for (uint256 i = start; i < end; i++) {
            if (data[i].addr.balance + data[i].amount != balancesAfterAirdrop[i - start]) {
                return data[i].addr;
            }
        }
    }

    function setBatch(uint256 _start, uint256 _end, uint256 _airdropBlock) external {
        start = _start;
        end = _end;
        airdropBlock = _airdropBlock;
    }
}
