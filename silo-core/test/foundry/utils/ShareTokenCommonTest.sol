// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloLittleHelper} from "silo-core/test/foundry/_common/SiloLittleHelper.sol";

// solhint-disable ordering

/*
FOUNDRY_PROFILE=core-test forge test -vv --ffi --mc ShareTokenCommonTest
*/
contract ShareTokenCommonTest is SiloLittleHelper, Test {
    address user = makeAddr("someUser");
    address otherUser = makeAddr("someOtherUser");

    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();
    }
    
    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_approveAndAllowance
    */
    function test_approveAndAllowance() public {
        _executeForAllShareTokens(_approveAndAllowance);
    }

    function _approveAndAllowance(IShareToken _shareToken) internal {
        uint256 allowance = _shareToken.allowance(user, otherUser);
        assertEq(allowance, 0, "allowance should be 0");

        uint256 approveAmount = 100e18;

        vm.prank(user);
        _shareToken.approve(otherUser, approveAmount);

        allowance = _shareToken.allowance(user, otherUser);
        assertEq(allowance, approveAmount, "allowance should be equal to approveAmount");
    }

    /*
    FOUNDRY_PROFILE=core-test forge test -vvv --ffi --mt test_burnPermissions
    */
    function test_burnPermissions() public {
        _executeForAllShareTokens(_burnPermissions);
    }

    function _burnPermissions(IShareToken _shareToken) internal {
        vm.expectRevert(IShareToken.OnlySilo.selector);
        _shareToken.burn(user, otherUser, 100e18);
    }

    function _executeForAllShareTokens(function(IShareToken) internal func) internal {
        (address protected0, address collateral0, address debt0) = siloConfig.getShareTokens(address(silo0));
        (address protected1, address collateral1, address debt1) = siloConfig.getShareTokens(address(silo1));

        func(IShareToken(protected0));
        func(IShareToken(collateral0));
        func(IShareToken(debt0));

        func(IShareToken(protected1));
        func(IShareToken(collateral1));
        func(IShareToken(debt1));
    }

    function _executeForAllCollateralShareTokens(function(IShareToken) internal func) internal {
        (address protected0, address collateral0,) = siloConfig.getShareTokens(address(silo0));
        (address protected1, address collateral1,) = siloConfig.getShareTokens(address(silo1));

        func(IShareToken(protected0));
        func(IShareToken(collateral0));

        func(IShareToken(protected1));
        func(IShareToken(collateral1));
    }

    function _executeForAllDebtShareTokens(function(IShareToken) internal func) internal {
        (,, address debt0) = siloConfig.getShareTokens(address(silo0));
        (,, address debt1) = siloConfig.getShareTokens(address(silo1));

        func(IShareToken(debt0));
        func(IShareToken(debt1));
    }
}
