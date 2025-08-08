// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {ERC4626Test} from "a16z-erc4626-tests/ERC4626.test.sol";

import {FirmVaultFactory} from "silo-core/contracts/firm/FirmVaultFactory.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {IRM} from "silo-core/contracts/firm/FirmVault.sol";

/*
 FOUNDRY_PROFILE=core_test forge test --ffi --mc FirmVaultERC4626ComplianceTest --mt test_mint -vvv 
*/
contract FirmVaultERC4626ComplianceTest is SiloLittleHelper, ERC4626Test {
    function setUp() public override {
        _setUpLocalFixture();

        token0.setOnDemand(false);
        token1.setOnDemand(false);

        FirmVaultFactory factory = new FirmVaultFactory();

        _underlying_ = address(token1);
        _vault_ = address(factory.create(address(this), silo1, bytes32(0)));
        _delta_ = 0;
        _vaultMayBeEmpty = true;
        _unlimitedAmount = true;

        // TODO remove this when we have real IRM 
        vm.mockCall(
            address(silo1.config().getConfig(address(silo1)).interestRateModel),
            abi.encodeWithSelector(IRM.pendingAccrueInterest.selector, block.timestamp),
            abi.encode(0)
        );
    }
}
