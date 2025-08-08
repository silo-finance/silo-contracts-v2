pragma solidity ^0.8.28;

import {FirmVaultFactory} from "silo-core/contracts/firm/FirmVaultFactory.sol";

import {VaultDonationTest} from "../common/VaultDonationTest.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

import {IRM} from "silo-core/contracts/firm/FirmVault.sol";

/*
    FOUNDRY_PROFILE=core_test forge test --ffi --mc FirmVaultDonationTest -vvv 
*/
contract FirmVaultDonationTest is VaultDonationTest, SiloLittleHelper {
    FirmVaultFactory factory = new FirmVaultFactory();

    function setUp() public override {
        _setUpLocalFixture();

        token1.setOnDemand(true);

        vault = factory.create(address(this), silo1, bytes32(0));

        vm.mockCall(
            address(silo1.config().getConfig(address(silo1)).interestRateModel),
            abi.encodeWithSelector(IRM.pendingAccrueInterest.selector, block.timestamp),
            abi.encode(0)
        );
    }

    function _executeDonation(uint256 _donation) internal override {
        _depositForBorrow(_donation, address(this));
        silo1.transfer(address(vault), _donation);
    }
}