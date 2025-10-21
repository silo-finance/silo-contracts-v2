// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SiloVault} from "../../../contracts/SiloVault.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";

contract RescueTokensFromVault is Test {
    SiloVault internal vault = SiloVault(0x6c09bfdc1df45D6c4Ff78Dc9F1C13aF29eB335d4);
    IERC20 internal wAvax = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_AVALANCHE"), 70678297);
        console2.log("block number", block.number);
    }

    /*
    FOUNDRY_PROFILE=vaults_tests forge test --ffi --mt test_rescue_tokens_from_vault -vvv
    */
    function test_rescue_tokens_from_vault() public {
        uint256 wAvaxDecimals = IERC20Metadata(address(wAvax)).decimals();
        console2.log("wAvax decimals", wAvaxDecimals);
        emit log_named_decimal_uint("wAvax vault balance", wAvax.balanceOf(address(vault)), wAvaxDecimals);
        console2.log("vault assets", IERC20Metadata(vault.asset()).symbol());
        // use claimRewards
    }
}