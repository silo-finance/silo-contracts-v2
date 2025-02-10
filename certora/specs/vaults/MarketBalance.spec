// SPDX-License-Identifier: GPL-2.0-or-later
import "Tokens.spec";

methods {

    }

rule onlySpecicifeidMethodsCanDecreaseMarketBalance(env e, method f, address market)
{ 
    address asset = asset();
    uint balanceBefore = ERC20.balanceOf(asset, currentContract);
    //(balanceBefore, _) = supplyBalance(e, market);
    calldataarg args;
    f(e, args);
    uint balanceAfter = ERC20.balanceOf(asset, currentContract);
    //(balanceAfter, _) = supplyBalance(e, market);
    assert balanceAfter >= balanceBefore;
}
