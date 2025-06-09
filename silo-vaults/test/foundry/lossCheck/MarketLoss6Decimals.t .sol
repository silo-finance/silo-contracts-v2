// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {MarketLossTest} from "./MarketLoss.t.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";

/*
 FOUNDRY_PROFILE=vaults_tests forge test --ffi --mc MarketLoss6Decimals -vv
*/
contract MarketLoss6Decimals is MarketLossTest {
    function setUp() public virtual override {
        super.setUp();
    }

    function _setTokens() internal override {
        loanToken = new MintableToken(6);
        collateralToken = new MintableToken(6);
    }
}
