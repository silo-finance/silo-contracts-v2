// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {PRBMathSD59x18} from "silo-core/contracts/lib/PRBMathSD59x18.sol";
import {PRBMathCommon} from "silo-core/contracts/lib/PRBMathCommon.sol";
import {PropertiesAsserts} from "properties/util/PropertiesHelper.sol";

/*
./silo-core/scripts/echidnaBefore.sh
SOLC_VERSION=0.8.24 echidna silo-core/test/echidna/EchidnaPRBMath.sol --contract EchidnaPRBMath --config silo-core/test/echidna/irm.yaml --workers 10
*/
contract EchidnaPRBMath is PropertiesAsserts {
    using PRBMathSD59x18 for int256;
    /* ================================================================
                        TESTS FOR exp() FUNCTIONS
       ================================================================ */

    // Test that exp strictly increases
    function exp_test_strictly_increasing(int256 x, int256 y) public {
        require(x < 88722839111672999628 && x >= -41446531673892822322, "x too large");
        require(y < 88722839111672999628 && y >= -41446531673892822322, "x too large");

        int256 exp_x = PRBMathSD59x18.exp(x);
        int256 exp_y = PRBMathSD59x18.exp(y);

        if (y >= x) {
            assertGte(exp_y, exp_x, "exp(y) is not strictly increasing.");
        } else {
            assertGte(exp_x, exp_y, "exp(x) not increasing");
        }
    }

    function exp2_test_strictly_increasing(int256 x, int256 y) public {
        require(x < 128e18 && x >= -59794705707972522261, "x too large");
        require(y < 128e18 && y >= -59794705707972522261, "y too large");

        int256 exp_x = PRBMathSD59x18.exp2(x);
        int256 exp_y = PRBMathSD59x18.exp2(y);

        if (y >= x) {
            assertGte(exp_y, exp_x, "exp2(y) is not strictly increasing.");
        } else {
            assertGte(exp_x, exp_y, "exp2(x) not increasing");
        }
    }

    function exp2_common_test_strictly_increasing(uint256 x, uint256 y) public {
        require(x <= type(uint128).max && y <= type(uint128).max, "x or y too large");

        uint256 exp_x = PRBMathCommon.exp2(x);
        uint256 exp_y = PRBMathCommon.exp2(y);

        if (y >= x) {
            assertGte(exp_y, exp_x, "exp2(y) is not strictly increasing.");
        } else {
            assertGte(exp_x, exp_y, "exp2(x) not increasing");
        }
    }
}
