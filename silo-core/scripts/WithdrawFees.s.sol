// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {IMulticall3} from "silo-core/scripts/interfaces/IMulticall3.sol";
import {console2} from "forge-std/console2.sol";

/**
FOUNDRY_PROFILE=core FACTORY=0x4e9dE3a64c911A37f7EB2fCb06D1e68c3cBe9203\
    forge script silo-core/scripts/WithdrawFees.s.sol \
    --ffi --rpc-url $RPC_SONIC
 */

contract WithdrawFees is Script {
    IMulticall3 multicall3 = IMulticall3(0xcA11bde05977b3631167028862bE2a173976CA11);

    function run() public {
        ISiloFactory factory = ISiloFactory(vm.envAddress("FACTORY"));
        uint256 startingSiloId;

        if (_startingIdIsOne(factory)) {
            startingSiloId = 1;
        } else if (_startingIdIsHundredOne(factory)) {
            startingSiloId = 101;
        } else {
            revert("Starting Silo id is not 1 or 101");
        }

        console2.log("Starting silo id for a SiloFactory is", startingSiloId);
        console2.log("Next silo id for a SiloFactory is", factory.getNextSiloId());

        uint256 amountOfMarkets = factory.getNextSiloId() - startingSiloId;
        console2.log("Total markets amount to withdraw fees", amountOfMarkets);

        // 2 silos in 1 market
        IMulticall3.Call3[] memory calls = new IMulticall3.Call3[](2 * amountOfMarkets);

        for (uint256 i = 0; i < amountOfMarkets; i++) {
            uint256 siloId = startingSiloId + i;
            ISiloConfig config = ISiloConfig(factory.idToSiloConfig(siloId));
            console2.log("Withdrawing fees for silo id", siloId);

            (address silo0, address silo1) = config.getSilos();

            calls[2 * i] = _withdrawFeesCall(silo0);
            calls[2 * i + 1] = _withdrawFeesCall(silo1);
        }

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);
        multicall3.aggregate3(calls);
        vm.stopBroadcast();
    }

    function _withdrawFeesCall(address _silo) internal pure returns (IMulticall3.Call3 memory) {
        return IMulticall3.Call3({
            target: _silo,
            callData: abi.encodeWithSelector(ISilo.withdrawFees.selector),
            allowFailure: true // may revert with EarnedZero() when fees == 0
        });
    }

    function _startingIdIsOne(ISiloFactory _factory) internal view returns (bool) {
        return _factory.idToSiloConfig(1) != address(0);
    }

    function _startingIdIsHundredOne(ISiloFactory _factory) internal view returns (bool) {
        return _factory.idToSiloConfig(101) != address(0);
    }
}
