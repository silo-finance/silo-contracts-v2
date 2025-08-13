// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {IRMZeroDeploy} from "silo-core/deploy/IRMZeroDeploy.s.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";

/**
AGGREGATOR=1INCH FOUNDRY_PROFILE=core_test forge test --ffi --mc IRMZeroTest -vv
*/
contract IRMZeroTest is Test {
    address silo0;

    function setUp() public {
        IRMZeroDeploy deploy = new IRMZeroDeploy();
        deploy.disableDeploymentsSync();
        deploy.run();
    }

    /**
    AGGREGATOR=1INCH FOUNDRY_PROFILE=core_test forge test --ffi --mt test_IRMzero_returns_zero -vv
    */
    function test_IRMzero_returns_zero() public {
        IInterestRateModel irmZero = IInterestRateModel(AddrLib.getAddress(SiloCoreContracts.IRM_ZERO));

        uint256 rcomp = irmZero.getCompoundInterestRate(address(silo0), block.timestamp);
        assertEq(rcomp, 0);

        uint256 rcur = irmZero.getCurrentInterestRate(address(silo0), block.timestamp);
        assertEq(rcur, 0);

        rcomp = irmZero.getCompoundInterestRateAndUpdate(1e18, 0, block.timestamp);
        assertEq(rcomp, 0);

        uint256 decimals = irmZero.decimals();
        assertEq(decimals, 0);

        irmZero.initialize(makeAddr("anyAddress")); // do nothing
    }
}
