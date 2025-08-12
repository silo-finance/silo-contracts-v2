// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";

import {DynamicKinkModel, IDynamicKinkModel} from "../../../../contracts/interestRateModel/kink/DynamicKinkModel.sol";
import {DynamicKinkModelConfig} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelConfig.sol";
import {DynamicKinkModelFactory} from "../../../../contracts/interestRateModel/kink/DynamicKinkModelFactory.sol";

import {ISilo} from "../../../../contracts/interfaces/ISilo.sol";


/* 
FOUNDRY_PROFILE=core_test forge test -vv --mc DynamicKinkModelTest
*/
contract DynamicKinkModelTest is Test {
    DynamicKinkModelFactory immutable FACTORY = new DynamicKinkModelFactory();
    DynamicKinkModel irm;

    int256 constant _DP = 10 ** 18;

    ISilo.UtilizationData public utilizationData;

    function setUp() public {
        IDynamicKinkModel.Config memory emptyConfig; 
        // IDynamicKinkModel.Config({
        //     ulow: 0,
        //     u1: 0,
        //     u2: 0,
        //     ucrit: 0,
        //     rmin: 0,
        //     kmin: 0,
        //     kmax: 0,
        //     alpha: 0,
        //     cminus: 0,
        //     cplus: 0,
        //     c1: 0,
        //     c2: 0,
        //     dmax: 0
        // });

        irm = DynamicKinkModel(address(FACTORY.create(emptyConfig, address(this), address(this))));
    }

    /* 
    FOUNDRY_PROFILE=core_test forge test -vv --mt test_kink_emptyConfigPass
    */
    function test_kink_emptyConfigPass() public view {
        // pass
    }
}
