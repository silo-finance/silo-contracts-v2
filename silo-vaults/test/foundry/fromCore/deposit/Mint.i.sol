// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ErrorsLib} from "silo-vaults/contracts/libraries/ErrorsLib.sol";

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
}
