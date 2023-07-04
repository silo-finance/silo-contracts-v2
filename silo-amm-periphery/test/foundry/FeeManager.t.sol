// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "silo-amm-core/test/foundry/helpers/Fixtures.sol";
import "silo-amm-core/test/foundry/helpers/TestToken.sol";
import "silo-amm-core/contracts/lib/PairMath.sol";

import "../../contracts/FeeManager.sol";

/*
    FOUNDRY_PROFILE=amm-periphery forge test -vv --match-contract FeeManagerTest
*/
contract FeeManagerTest is Test {
    IFeeManager internal feeManager;

    // TODO for some reason it can not work via IFeeManager.FeeSetupChanged
    event FeeSetupChanged(address feeReceiver, uint24 feePercent);

    constructor() {
        feeManager = new FeeManager(IFeeManager.FeeSetup(address(this), 0));
    }

    function test_FeeManager_feeBp() public {
        assertEq(feeManager.FEE_BP(), PairMath.feeBp());
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_SiloAmmPair_setFee
    */
    function test_SiloAmmPair_setFee() public {
        IFeeManager.FeeSetup memory fee = feeManager.getFeeSetup();
        vm.expectRevert(IFeeManager.NO_CHANGE.selector);
        feeManager.setupFee(fee);

        vm.prank(address(1));
        vm.expectRevert(IFeeManager.ONLY_PROTOCOL_FEE_RECEIVER.selector);
        feeManager.setupFee(fee);

        fee.percent = uint24(PairMath.feeBp() / 10 + 1);
        vm.expectRevert(IFeeManager.FEE_OVERFLOW.selector);
        feeManager.setupFee(fee);

        fee.percent = uint24(PairMath.feeBp() / 10);
        fee.receiver = address(0);
        vm.expectRevert(IFeeManager.ZERO_ADDRESS.selector);
        feeManager.setupFee(fee);

        fee.receiver = address(this);
        vm.expectEmit(true, true, true, true);
        emit FeeSetupChanged(fee.receiver, fee.percent);

        feeManager.setupFee(fee);
    }
}
