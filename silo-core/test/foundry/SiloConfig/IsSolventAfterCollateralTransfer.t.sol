// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ShareCollateralToken} from "silo-core/contracts/utils/ShareCollateralToken.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc IsSolventAfterCollateralTransferTest
*/
contract IsSolventAfterCollateralTransferTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    address public shareCollateralToken0;
    address public shareProtectedToken0;
    address public shareCollateralToken1;
    address public shareProtectedToken1;

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        (shareProtectedToken0, shareCollateralToken0, ) = siloConfig.getShareTokens(address(silo0));
        (shareProtectedToken1, shareCollateralToken1, ) = siloConfig.getShareTokens(address(silo1));
    }

    /*
    forge test -vv --ffi --mt test_isSolventAfterCollateralTransfer_pass
    */
    function test_isSolventAfterCollateralTransfer_pass() public {
        vm.prank(shareCollateralToken0);
        siloConfig.isSolventAfterCollateralTransfer(address(silo0), address(0));

        vm.prank(shareProtectedToken0);
        siloConfig.isSolventAfterCollateralTransfer(address(silo0), address(0));

        vm.prank(shareCollateralToken1);
        siloConfig.isSolventAfterCollateralTransfer(address(silo1), address(0));

        vm.prank(shareProtectedToken1);
        siloConfig.isSolventAfterCollateralTransfer(address(silo1), address(0));
    }

    /*
    forge test -vv --ffi --mt test_isSolventAfterCollateralTransfer_reverts
    */
    function test_isSolventAfterCollateralTransfer_otherSTokens_reverts() public {
        vm.expectRevert(ISiloConfig.OnlyShareCollateralToken.selector);
        vm.prank(shareCollateralToken0);
        siloConfig.isSolventAfterCollateralTransfer(address(silo1), address(0));

        vm.expectRevert(ISiloConfig.OnlyShareCollateralToken.selector);
        vm.prank(shareProtectedToken0);
        siloConfig.isSolventAfterCollateralTransfer(address(silo1), address(0));

        vm.expectRevert(ISiloConfig.OnlyShareCollateralToken.selector);
        vm.prank(shareCollateralToken1);
        siloConfig.isSolventAfterCollateralTransfer(address(silo0), address(0));

        vm.expectRevert(ISiloConfig.OnlyShareCollateralToken.selector);
        vm.prank(shareProtectedToken1);
        siloConfig.isSolventAfterCollateralTransfer(address(silo0), address(0));
    }

    /*
    forge test -vv --ffi --mt test_isSolventAfterCollateralTransfer_reverts_shareCollateralToken0
    */
    function test_isSolventAfterCollateralTransfer_reverts__fuzz(address _any) public {
        vm.assume(
            _any != shareCollateralToken0
            && _any != shareCollateralToken1
            && _any != shareProtectedToken0
            && _any != shareProtectedToken1
        );

        vm.expectRevert(ISiloConfig.OnlyShareCollateralToken.selector);
        vm.prank(_any);
        siloConfig.isSolventAfterCollateralTransfer(address(silo0), address(1));
    }
}
