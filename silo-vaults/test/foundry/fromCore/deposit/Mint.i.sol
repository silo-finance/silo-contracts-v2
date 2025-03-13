// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ErrorsLib} from "silo-vaults/contracts/libraries/ErrorsLib.sol";
import {MarketConfig} from "silo-vaults/contracts/libraries/PendingLib.sol";
import {VaultsLittleHelper} from "../_common/VaultsLittleHelper.sol";

/*
    FOUNDRY_PROFILE=vaults-tests forge test -vv --ffi --mc MintTest
*/
contract MintTest is VaultsLittleHelper {
    /*
    FOUNDRY_PROFILE=vaults-tests forge test -vv --ffi --mt test_mint
    */
    function test_mint() public {
        uint256 shares = 1e18;
        address depositor = makeAddr("Depositor");

        uint256 previewMint = vault.previewMint(shares);

        _mint(shares, depositor);

        assertEq(vault.totalAssets(), previewMint, "previewMint should give us expected assets amount");
    }

    /*
    FOUNDRY_PROFILE=vaults-tests forge test --ffi --mt test_mint_marketAllocation -vvv
    */
    function test_mint_marketAllocation() public {
        uint256 length = vault.supplyQueueLength();

        assertGt(length, 1, "supplyQueueLength less than 2");

        IERC4626 market0 = vault.supplyQueue(0);
        IERC4626 market1 = vault.supplyQueue(1);

        uint256 allocationBefore0 = vault.marketAllocation(market0);
        uint256 allocationBefore1 = vault.marketAllocation(market1);

        assertEq(allocationBefore0, 0, "expect allocationBefore0 to be 0");
        assertEq(allocationBefore1, 0, "expect allocationBefore1 to be 0");

        MarketConfig memory config0 = vault.config(market0);

        uint256 mintOverCapAssets = 100;
        uint256 mintOverCap = vault.convertToShares(mintOverCapAssets);

        uint256 mintAmount = vault.convertToShares(config0.cap) + mintOverCap;

        _mint(mintAmount, makeAddr("Depositor"));

        uint256 allocationAfter0 = vault.marketAllocation(market0);
        uint256 allocationAfter1 = vault.marketAllocation(market1);

        assertEq(allocationAfter0, config0.cap, "allocationAfter0 should be config0.cap");
        assertEq(allocationAfter1, mintOverCapAssets, "allocationAfter1 should be mintOverCapAssets");
    }
}
