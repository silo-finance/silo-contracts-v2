// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {CommonDeploy} from "silo-core/deploy/_CommonDeploy.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ISiloLens} from "silo-core/contracts/interfaces/ISiloLens.sol";
import {IMulticall3} from "silo-core/scripts/interfaces/IMulticall3.sol";
import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {console2} from "forge-std/console2.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";

/**
FOUNDRY_PROFILE=core FACTORY=0x4e9dE3a64c911A37f7EB2fCb06D1e68c3cBe9203\
    forge script silo-core/scripts/WithdrawFees.s.sol \
    --ffi --rpc-url $RPC_SONIC --broadcast
 */

contract WithdrawFees is CommonDeploy, StdAssertions {
    IMulticall3 multicall3 = IMulticall3(0xcA11bde05977b3631167028862bE2a173976CA11);
    IMulticall3.Call3[] calls;

    function run() public {
        ISiloFactory factory = ISiloFactory(vm.envAddress("FACTORY"));
        ISiloLens lens = ISiloLens(getDeployedAddress(SiloCoreContracts.SILO_LENS));

        uint256 startingSiloId;

        if (_startingIdIsOne(factory)) {
            startingSiloId = 1;
        } else if (_startingIdIsHundredOne(factory)) {
            startingSiloId = 101;
        } else {
            revert("Starting Silo id is not 1 or 101");
        }

        console2.log("Starting silo id for a SiloFactory is", startingSiloId);
        uint256 amountOfMarkets = factory.getNextSiloId() - startingSiloId;
        console2.log("Total markets exist", amountOfMarkets);

        for (uint256 i = 0; i < amountOfMarkets; i++) {
            uint256 siloId = startingSiloId + i;
            ISiloConfig config = ISiloConfig(factory.idToSiloConfig(siloId));

            (address silo0, address silo1) = config.getSilos();
            _pushWithdrawFeesCall(lens, silo0, siloId);
            _pushWithdrawFeesCall(lens, silo1, siloId);
        }

        console2.log("Total amount of silos to call", calls.length);

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        vm.startBroadcast(deployerPrivateKey);
        multicall3.aggregate3(calls);
        vm.stopBroadcast();
    }

    function _pushWithdrawFeesCall(ISiloLens _lens, address _silo, uint256 _siloId) internal {
        ISilo(_silo).accrueInterest();
        uint256 daoAndDeployerRevenue = _lens.protocolFees(ISilo(_silo));
        (,, uint256 daoFee, uint256 deployerFee) = _lens.getFeesAndFeeReceivers(ISilo(_silo));
        uint256 feesToWithdraw = daoAndDeployerRevenue * daoFee / (daoFee + deployerFee);

        uint256 underlyingAssetDecimals = TokenHelper.assertAndGetDecimals(ISilo(_silo).asset());

        // skip markets with < 0.0001 token fees
        if (feesToWithdraw < 10 ** underlyingAssetDecimals / 10_000) return;

        calls.push(
            IMulticall3.Call3({
                target: _silo,
                callData: abi.encodeWithSelector(ISilo.withdrawFees.selector),
                allowFailure: false
            })
        );

        string memory messageToLog = string.concat(
            Strings.toString(_siloId),
            " id daoAndDeployerRevenue in token ",
            TokenHelper.symbol(ISilo(_silo).asset()),
            " amount (in asset decimals)"
        );

        emit log_named_decimal_uint(
            messageToLog,
            feesToWithdraw,
            underlyingAssetDecimals
        );
    }

    function _startingIdIsOne(ISiloFactory _factory) internal view returns (bool) {
        return _factory.idToSiloConfig(1) != address(0);
    }

    function _startingIdIsHundredOne(ISiloFactory _factory) internal view returns (bool) {
        return _factory.idToSiloConfig(101) != address(0);
    }
}
