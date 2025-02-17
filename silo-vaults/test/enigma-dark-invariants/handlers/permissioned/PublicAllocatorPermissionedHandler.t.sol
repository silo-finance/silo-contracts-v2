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
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title SiloVaultHandler
/// @notice Handler test contract for a set of actions
abstract contract PublicAllocatorPermissionedHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function setFeeAllocator(uint256 newFee) external {
        publicAllocator.setFee(vault, newFee);
    }

    function setFlowCaps(FlowCaps[NUM_MARKETS + 1] memory _flowCaps) external {
        FlowCapsConfig[] memory flowCapsConfig = _getFlowCaps(_flowCaps);

        publicAllocator.setFlowCaps(vault, flowCapsConfig);
    }

    function setFee() external {
        publicAllocator.transferFee(vault, FEE_RECIPIENT);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _getFlowCaps(FlowCaps[NUM_MARKETS + 1] memory _flowcaps) internal view returns (FlowCapsConfig[] memory) {
        // Create a memory array of FlowCapsConfig structs
        FlowCapsConfig[] memory flowCapsConfigs = new FlowCapsConfig[](NUM_MARKETS + 1);

        uint256 enabledMarkets;
        for (uint256 i; i < NUM_MARKETS; i++) {
            if (_isMarketEnabled(markets[i])) {
                flowCapsConfigs[enabledMarkets++] = FlowCapsConfig({market: IERC4626(markets[i]), caps: _flowcaps[i]});
            }
        }

        if (flowCapsConfigs.length != enabledMarkets) {
            assembly {
                mstore(flowCapsConfigs, enabledMarkets)
            }
        }

        return flowCapsConfigs;
    }
}
