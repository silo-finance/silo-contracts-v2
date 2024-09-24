// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {MintableToken} from "../../../_common/MintableToken.sol";
import {SiloLittleHelper} from "../../../_common/SiloLittleHelper.sol";

/*
    forge test -vv --ffi --mc MaxMintTest
*/
contract MaxMintTest is SiloLittleHelper, Test {
    uint256 internal constant _REAL_ASSETS_LIMIT = type(uint128).max;

    function setUp() public {
        _setUpLocalFixture(SiloConfigsNames.LOCAL_NO_ORACLE_NO_LTV_SILO);
    }

    /*
    forge test -vv --ffi --mt test_maxMint
    */
    function test_maxMint() public {
        assertEq(silo0.maxMint(address(1)), 2 ** 256 - 1, "ERC4626 expect to return 2 ** 256 - 1");
    }
}
