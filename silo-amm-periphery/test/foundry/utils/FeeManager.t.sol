// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "silo-amm-core/test/foundry/helpers/Fixtures.sol";
import "silo-amm-core/test/foundry/helpers/TestToken.sol";
import "silo-amm-core/contracts/lib/PairMath.sol";

import "../../../contracts/utils/FeeManager.sol";

/*
    FOUNDRY_PROFILE=amm-periphery forge test -vv --match-contract FeeManagerTest
*/
contract FeeManagerTest is Test, FeeManager {
    IFeeManager feeManager;

    constructor() FeeManager(Fee(address(this), 0)) {
        feeManager = IFeeManager(address(this));
    }

    function test_FeeManager_feeBp() public {
        assertEq(_FEE_BP, PairMath.feeBp());
    }

    /*
        FOUNDRY_PROFILE=amm-core forge test -vv --match-test test_SiloAmmPair_setFee
    */
    function test_SiloAmmPair_setFee() public {
        IFeeManager.Fee memory fee = feeManager.protocolFee();
        vm.expectRevert(IFeeManager.NO_CHANGE.selector);
        feeManager.setFee(fee);

        vm.prank(address(1));
        vm.expectRevert(IFeeManager.ONLY_PROTOCOL_FEE_RECEIVER.selector);
        feeManager.setFee(fee);

        fee.percent = uint24(PairMath.feeBp() / 10 + 1);
        vm.expectRevert(IFeeManager.FEE_OVERFLOW.selector);
        feeManager.setFee(fee);

        fee.percent = uint24(PairMath.feeBp() / 10);
        fee.receiver = address(0);
        vm.expectRevert(IFeeManager.ZERO_ADDRESS.selector);
        feeManager.setFee(fee);

        fee.receiver = address(this);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.FeeSetup(fee.receiver, fee.percent);

        feeManager.setFee(fee);
    }
}
