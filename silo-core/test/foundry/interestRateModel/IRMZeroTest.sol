// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {AddrLib} from "silo-foundry-utils/lib/AddrLib.sol";

import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";
import {SiloCoreContracts} from "silo-core/common/SiloCoreContracts.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";
import {SiloDeployerDeploy} from "silo-core/deploy/SiloDeployerDeploy.s.sol";
import {IRMZeroDeploy} from "silo-core/deploy/IRMZeroDeploy.s.sol";
import {SiloFixture, SiloConfigOverride} from "silo-core/test/foundry/_common/fixtures/SiloFixture.sol";
import {SiloLittleHelper} from "silo-core/test/foundry/_common/SiloLittleHelper.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";

/**
AGGREGATOR=1INCH FOUNDRY_PROFILE=core_test forge test --ffi --mc IRMZeroTest -vv
*/
contract IRMZeroTest is Test, SiloLittleHelper {
    function setUp() public {
        token0 = new MintableToken(18);
        token1 = new MintableToken(18);

        SiloConfigOverride memory overrides;
        overrides.token0 = address(token0);
        overrides.token1 = address(token1);
        overrides.configName = SiloConfigsNames.SILO_LOCAL_ZERO_IRM;

        SiloFixture siloFixture = new SiloFixture();

        (, silo0, silo1,,,) = siloFixture.deploy_local(overrides);
    }

    /**
    AGGREGATOR=1INCH FOUNDRY_PROFILE=core_test forge test --ffi --mt test_deposit_withraw_borrow_repay_with_IRMZero -vv
    */
    function test_deposit_withraw_borrow_repay_with_IRMZero() public {
        address depositor = makeAddr("Depositor");
        address borrower = makeAddr("Borrower");

        vm.warp(block.timestamp + 1 days);
        _deposit(1e18, borrower);

        vm.warp(block.timestamp + 1 days);
        _depositForBorrow(1e18, depositor);

        vm.warp(block.timestamp + 1 days);
        _borrow(0.75e18, borrower);

        vm.warp(block.timestamp + 1 days);
        _repay(0.75e18, borrower);

        vm.warp(block.timestamp + 1 days);
        _withdraw(1e18, borrower);
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
