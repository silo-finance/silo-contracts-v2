// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

import {MintableToken} from "../_common/MintableToken.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {SiloFixture, SiloConfigOverride} from "../_common/fixtures/SiloFixture.sol";

// setup must match what was set for `EchidnaE2E`
contract EchidnaSetup is SiloLittleHelper, Test {
    using SiloLensLib for ISilo;

    uint256 constant ACTORS_COUNT = 3;
    mapping (uint256 index => address actor) actors;

    ISiloConfig siloConfig;

    constructor() {
        actors[0] = makeAddr("Actor 0");
        actors[1] = makeAddr("Actor 1");
        actors[2] = makeAddr("Actor 2");
    }

    function setUp() public {
        siloConfig = _setUpLocalFixture("Echidna_MOCK");

        assertTrue(siloConfig.getConfig(address(silo0)).maxLtv != 0, "we need borrow to be allowed");

        token0.setOnDemand(true);
        token1.setOnDemand(true);

        // same block and time as for E2E Echidna
        vm.warp(1706745600);
        vm.roll(17336000);
    }

    function _chooseActor(uint256 value) internal returns (address) {
        uint256 low = 0;
        uint256 high = ACTORS_COUNT - 1;

        if (value < low || value > high) {
            uint ans = low + (value % (high - low + 1));
            string memory valueStr = Strings.toString(value);
            string memory ansStr = Strings.toString(ans);
            bytes memory message = abi.encodePacked(
                "Clamping value ",
                valueStr,
                " to ",
                ansStr
            );
            emit log(string(message));
            return actors[ans];
        }

        return actors[value];
    }

    function _invariant_checkForInterest(ISilo _silo) internal returns (bool noInterest) {
        (, uint256 interestRateTimestamp) = _silo.siloData();
        noInterest = block.timestamp == interestRateTimestamp;

        if (noInterest) assertEq(_silo.accrueInterest(), 0, "no interest should be applied");
    }

    function _invariant_insolventHasDebt(address _user)
        internal
        returns (bool isSolvent, ISilo _siloWithDebt)
    {
        _dumpState(_user);

        isSolvent = silo0.isSolvent(_user);
        if (isSolvent) return (isSolvent, ISilo(address(0)));

        (,, address debtShareToken0 ) = siloConfig.getShareTokens(address(silo0));
        (,, address debtShareToken1 ) = siloConfig.getShareTokens(address(silo1));

        uint256 balance0 = IShareToken(debtShareToken0).balanceOf(_user);
        uint256 balance1 = IShareToken(debtShareToken1).balanceOf(_user);

        assertEq(balance0 * balance1, 0, "[_invariant_insolventHasDebt] one balance must be 0");
        assertGt(balance0 + balance1, 0, "user should have debt if he is insolvent");

        return (isSolvent, balance0 > 0 ? silo0 : silo1);
    }


    function _dumpState(uint256 _actorIndex) internal {
        _dumpState(_chooseActor(_actorIndex));
    }

    function _dumpState(address _actor) internal {
        emit log_named_uint("block.number:", block.number);
        emit log_named_uint("block.timestamp:", block.timestamp);

        (uint256 collectedFees0, uint256 irmTimestamp0) = silo0.siloData();
        (uint256 collectedFees1, uint256 irmTimestamp1) = silo1.siloData();

        emit log_named_decimal_uint("collectedFees0:", collectedFees0, 18);
        emit log_named_uint("irmTimestamp0:", irmTimestamp0);
        emit log_named_decimal_uint("collectedFees1:", collectedFees1, 18);
        emit log_named_uint("irmTimestamp1:", irmTimestamp1);

        emit log_named_decimal_uint("LTV0:", silo0.getLtv(_actor), 16);
        emit log_named_decimal_uint("LTV1:", silo1.getLtv(_actor), 16);

        (
            address protectedToken0, address collateralToken0, address debtShareToken0
        ) = siloConfig.getShareTokens(address(silo0));

        (
            address protectedToken1, address collateralToken1,  address debtShareToken1
        ) = siloConfig.getShareTokens(address(silo1));

        emit log_named_decimal_uint("protectedToken0.balanceOf:", IShareToken(protectedToken0).balanceOf(_actor), 18);
        emit log_named_decimal_uint("collateralToken0.balanceOf:", IShareToken(collateralToken0).balanceOf(_actor), 18);
        emit log_named_decimal_uint("debtShareToken0.balanceOf:", IShareToken(debtShareToken0).balanceOf(_actor), 18);

        emit log_named_decimal_uint("protectedToken1.balanceOf:", IShareToken(protectedToken1).balanceOf(_actor), 18);
        emit log_named_decimal_uint("collateralToken1.balanceOf:", IShareToken(collateralToken1).balanceOf(_actor), 18);
        emit log_named_decimal_uint("debtShareToken1.balanceOf:", IShareToken(debtShareToken1).balanceOf(_actor), 18);

        emit log_named_decimal_uint("maxWithdraw0:", silo0.maxWithdraw(_actor), 18);
        emit log_named_decimal_uint("maxWithdraw1:", silo1.maxWithdraw(_actor), 18);

        uint256 maxBorrow0 = silo0.maxBorrow(_actor);
        uint256 maxBorrow1 = silo1.maxBorrow(_actor);
        emit log_named_decimal_uint("maxBorrow0:", maxBorrow0, 18);
        emit log_named_decimal_uint("maxBorrow1:", maxBorrow1, 18);

        emit log_named_decimal_uint("convertToShares(maxBorrow0):", silo0.convertToShares(maxBorrow0, ISilo.AssetType.Debt), 18);
        emit log_named_decimal_uint("convertToShares(maxBorrow1):", silo1.convertToShares(maxBorrow1, ISilo.AssetType.Debt), 18);

        emit log_named_decimal_uint("maxBorrowShares0:", silo0.maxBorrowShares(_actor), 18);
        emit log_named_decimal_uint("maxBorrowShares1:", silo1.maxBorrowShares(_actor), 18);

        emit log_named_decimal_uint("liquidity0", silo0.getLiquidity(), 18);
        emit log_named_decimal_uint("liquidity1", silo1.getLiquidity(), 18);
    }
}
