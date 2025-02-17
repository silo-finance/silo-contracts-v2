// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC4626, IERC20} from "openzeppelin5/interfaces/IERC4626.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title SiloVaultPermissionedHandler
/// @notice Handler test contract for a set of actions
abstract contract SiloVaultPermissionedHandler is BaseHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function submitTimelock(uint256 _newTimelock) external {
        vault.submitTimelock(_newTimelock);
    }

    function setFee(uint256 _newTimelock) external {
        vault.setFee(_newTimelock);
    }

    function submitCap(uint256 _newSupplyCap, uint8 i) external {
        IERC4626 market = IERC4626(_getRandomMarket(i));

        vault.submitCap(market, _newSupplyCap);
    }

    function submitMarketRemoval(uint8 i) external {
        IERC4626 market = IERC4626(_getRandomMarket(i));

        vault.submitMarketRemoval(market);
    }

    function setSupplyQueue(uint8 i) external {
        IERC4626[] memory _newSupplyQueue = _generateRandomMarketArray(i);

        vault.setSupplyQueue(_newSupplyQueue);

        uint256 supplyQueueLength = vault.supplyQueueLength();

        // POSTCONDITIONS

        for (uint256 j; j < supplyQueueLength; j++) {
            assertGt(vault.config(vault.supplyQueue(j)).cap, 0, HSPOST_QUEUES_F);
        }
    }

    function updateWithdrawQueue(uint8[] memory _indexes, uint8 i) external {
        uint256[] memory _clampedIndexes = _clampIndexesArray(_indexes, i);

        vault.updateWithdrawQueue(_clampedIndexes);
    }

    function acceptTimelock() external {
        vault.acceptTimelock();
    }

    function acceptCap(uint8 i) external {
        IERC4626 market = IERC4626(_getRandomMarket(i));

        vault.acceptCap(IERC4626(market));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _generateRandomMarketArray(uint8 seed) internal returns (IERC4626[] memory) {
        // TODO check coverage improvements
        uint256 randomLength = clampLe(seed, markets.length);

        IERC4626[] memory randomArray = new IERC4626[](randomLength);

        for (uint256 i; i < randomLength; i++) {
            randomArray[i] = IERC4626(markets[(uint256(seed) + i) % markets.length]);
        }

        assert(randomArray.length <= markets.length);

        return randomArray;
    }

    function _clampIndexesArray(uint8[] memory _indexes, uint8 seed) internal returns (uint256[] memory) {
        require(_indexes.length <= markets.length, "SiloVaultPermissionedHandler: indexes array too long");

        uint256 length = clampLe(seed, markets.length);

        uint256[] memory clampedIndexes = new uint256[](length);

        for (uint256 i; i < seed; i++) {
            clampedIndexes[i] = clampLt(seed, markets.length);
        }

        return clampedIndexes;
    }
}
