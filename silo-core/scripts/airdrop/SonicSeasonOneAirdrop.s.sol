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
    AIRDROP_PRIVATE_KEY must be set in env.

    FOUNDRY_PROFILE=core START=0 END=15 \
    forge script silo-core/scripts/airdrop/SonicSeasonOneAirdrop.s.sol \
    --ffi --rpc-url $RPC_SONIC -- --dry-run
 */

contract SonicSeasonOneAirdrop is SonicSeasonOneDataReader {
    // https://www.multicall3.com/deployments
    IMulticall3 public constant MULTICALL3 = IMulticall3(0xcA11bde05977b3631167028862bE2a173976CA11);

    uint256 start;
    uint256 end;

    function run() public {
        require(Strings.equal(ChainsLib.chainAlias(), ChainsLib.SONIC_ALIAS), "Unsupported chain");

        if (start == 0 && end == 0) {
            start = vm.envUint("START");
            end = vm.envUint("END");
        }

        require(start < end, "end <= start");
        TransferData[] memory data = readTransferData();
        uint256 totalToTransfer;
        console2.log("transfers:");

        for (uint256 i = start; i < end; i++) {
            console2.log(i, data[i].addr, PriceFormatter.formatPriceInE18(data[i].amount));
            totalToTransfer += data[i].amount;
        }

        console2.log("Total to send in current batch", PriceFormatter.formatPriceInE18(totalToTransfer));
        _sendTokens(data);
    }

    function _sendTokens(TransferData[] memory _data) internal {
        IMulticall3.Call3Value[] memory call3Values = new IMulticall3.Call3Value[](end - start);
        uint256 totalToTransfer;

        for (uint256 i = start; i < end; i++) {
            require(!IsContract.isContract(_data[i].addr), "receiver should not be a contract");

            call3Values[i - start] = IMulticall3.Call3Value({
                target: _data[i].addr,
                allowFailure: false,
                value: _data[i].amount,
                callData: bytes("")
            });

            totalToTransfer += _data[i].amount;
        }

        vm.startBroadcast(uint256(vm.envBytes32("AIRDROP_PRIVATE_KEY")));
        MULTICALL3.aggregate3Value{ value: totalToTransfer }(call3Values);
        vm.stopBroadcast();
    }

    function setBatch(uint256 _start, uint256 _end) external {
        start = _start;
        end = _end;
    }
}
