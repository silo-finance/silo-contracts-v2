// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";
import {
    FlowCaps,
    FlowCapsConfig,
    Withdrawal,
    MAX_SETTABLE_FLOW_CAP,
    IPublicAllocatorStaticTyping,
    IPublicAllocatorBase
} from "silo-vaults/contracts/interfaces/IPublicAllocator.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title PublicAllocatorHandler
/// @notice Handler test contract for a set of actions
abstract contract PublicAllocatorHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function reallocateTo(uint8 i, uint128[NUM_MARKETS - 1] memory withdrawals) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three markets randomly
        address supplyMarket = _getRandomMarket(i);

        Withdrawal[] memory _withdrawals = _generateWithdrawalsArray(withdrawals, supplyMarket);

        address target = address(publicAllocator);

        _before();
        (success, returnData) = actor.proxy(
            target,
            abi.encodeWithSelector(IPublicAllocatorBase.reallocateTo.selector, vault, _withdrawals, supplyMarket)
        );

        if (success) {
            _after();
        } else {
            revert("SiloVaultHandler: deposit failed");
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _generateWithdrawalsArray(uint128[NUM_MARKETS - 1] memory withdrawals, address excludedAddress)
        internal
        returns (Withdrawal[] memory)
    {
        // Create a memory array of structs
        Withdrawal[] memory withdraws = new Withdrawal[](markets.length - 1);

        uint256 index;

        // Iterate through the storage array and populate the struct array
        for (uint256 i; i < markets.length; i++) {
            if (markets[i] != excludedAddress && _isMarketEnabled(markets[i])) {
                withdraws[index] = Withdrawal({
                    market: IERC4626(markets[i]),
                    amount: uint128(clampBetween(withdrawals[index], 1, _expectedSupplyAssets(markets[i]))) // Example random amount
                });
                index++;
            }
        }

        if (index != withdraws.length) {
            assembly {
                mstore(withdraws, index)
            }
        }

        return withdraws;
    }
}
