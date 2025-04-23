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
        FOUNDRY_PROFILE=core_test forge test -vv --ffi --mt test_maxWithdraw_dust


        there might be a case where conversion from assets <=> shares is not returning same amounts eg:
        // _assets.mulDiv(_newTotalSupply + 10 ** _decimalsOffset(), _newTotalAssets + 1, _rounding);
        convert to shares ==> 1 * (1002 + 1e3) / (2 + 1) = 667.3
        convert to assets ==> 667 * (2 + 1) / (1002 + 1e3) = 0.9995
        so when user will use 667 withdrawal will fail, this is why we have to cross check:

        assets = _shares.mulDiv(_newTotalAssets + 1, _newTotalSupply + 10 ** _decimalsOffset(), _rounding);
        shares = 667
        _newTotalAssets = 1
        _newTotalSupply = 1002
    */
    function test_maxWithdraw_dust() public {
        uint256 protectedTotalSupply = 1002;
        uint256 protectedTotalAssets = 2;

        _deposit(1, address(1), ISilo.CollateralType.Protected);
        _deposit(1, address(this), ISilo.CollateralType.Protected);

        (address protectedShareToken,,) = silo0.config().getShareTokens(address(silo0));

//        vm.mockCall(
//            address(protectedShareToken),
//            abi.encodeWithSelector(IERC20.totalSupply.selector),
//            abi.encode(protectedTotalSupply)
//        );

//        assertEq(IShareToken(protectedShareToken).totalSupply(), protectedTotalSupply, "totalSupply");
//        assertEq(silo0.getTotalAssetsStorage(ISilo.AssetType.Protected), protectedTotalAssets, "totalAssets");

        // without fix, maxRedeem returned 667
        assertEq(silo0.maxRedeem(address(this), ISilo.CollateralType.Protected), 0, "max redeem should return 0 on dust shares");
    }
}
