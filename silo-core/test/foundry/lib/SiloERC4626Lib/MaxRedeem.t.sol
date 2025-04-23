// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {IERC20Errors} from "openzeppelin5/interfaces/draft-IERC6093.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {SiloERC4626Lib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";
import {ShareTokenLib} from "silo-core/contracts/lib/ShareTokenLib.sol";
import {ShareTokenDecimalsPowLib} from "../../_common/ShareTokenDecimalsPowLib.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc MaxRedeemTest
*/
contract MaxRedeemTest is SiloLittleHelper, Test {
    function setUp() public {
        _setUpLocalFixture();
    }

    /*
        FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_maxWithdraw_protected_dust
    */
    function test_maxWithdraw_protected_dust() public {
        _maxWithdraw_dust(ISilo.CollateralType.Protected);
    }

    function _maxWithdraw_dust(ISilo.CollateralType _type) internal {
        address depositor = makeAddr("depositor");

        _deposit(1, depositor, _type);

        (address protectedShareToken, address collateralShareToken,,) = silo0.config().getShareTokens(address(silo0));
        address shareToken = _type == ISilo.CollateralType.Protected ? protectedShareToken : collateralShareToken;

        vm.prank(depositor);
        IShareToken(shareToken).transfer(address(this), 667);

        assertEq(silo0.maxRedeem(address(this), _type), 0, "max redeem should return 0 on dust shares");
    }
}
