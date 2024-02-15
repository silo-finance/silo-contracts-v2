// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

import {EchidnaSetup} from "./EchidnaSetup.sol";

contract EchidnaMiddleman is EchidnaSetup {
    function __depositNeverMintsZeroShares(uint8 _actor, bool _siloZero, uint256 _amount) internal {
        address actor = _chooseActor(_actor);
        ISilo silo = __chooseSilo(_siloZero);

        vm.prank(actor);
        silo.deposit(_amount, actor);
    }

    function __borrow(uint8 _actor, bool _siloZero, uint256 _amount) internal {
        address actor = _chooseActor(_actor);
        ISilo silo = __chooseSilo(_siloZero);

        vm.prank(actor);
        silo.borrow(_amount, actor, actor);
    }

    function __previewDeposit_doesNotReturnMoreThanDeposit(uint8 _actor, uint256 _assets)
        internal
        returns (uint256 shares)
    {
        address actor = _chooseActor(_actor);
        vm.startPrank(actor);

        uint256 depositShares = silo0.previewDeposit(_assets);
        shares = silo0.deposit(_assets, actor);
        assertEq(depositShares, shares, "previewDeposit fail");

        vm.stopPrank();
    }

    function __maxBorrow_correctReturnValue(uint8 _actor) internal returns (uint256 maxAssets, uint256 shares) {
        address actor = _chooseActor(_actor);
        maxAssets = silo0.maxBorrow(actor);

        vm.prank(actor);
        shares = silo0.borrow(maxAssets, actor, actor); // should not revert!
    }

    function __mint(uint8 _actor, bool _siloZero, uint256 _shares) internal {
        address actor = _chooseActor(_actor);
        ISilo silo = __chooseSilo(_siloZero);

        vm.prank(actor);
        silo.mint(_shares, actor);
    }

    function __maxBorrowShares_correctReturnValue(uint8 _actor) internal returns (uint256 maxBorrow, uint256 shares) {
        address actor = _chooseActor(_actor);

        maxBorrow = silo0.maxBorrowShares(actor);
        assertGt(maxBorrow, 0, "in echidna scenarios we exclude zeros, so we should not get it here as well");

        vm.prank(actor);
        shares = silo0.borrowShares(maxBorrow, actor, actor);
    }

    function __maxLiquidation_correctReturnValue(uint8 _actor) internal {
        address actor = _chooseActor(_actor);
        vm.startPrank(actor);

        (bool isSolvent, ISilo siloWithDebt) = _invariant_insolventHasDebt(actor);
        assertFalse(isSolvent, "expect not solvent user");

        (, uint256 debtToRepay) = siloWithDebt.maxLiquidation(actor);

        (address collateral, address debt) = __liquidationTokens(address(siloWithDebt));

        siloWithDebt.liquidationCall(debt, collateral, actor, debtToRepay, false);

        vm.stopPrank();
    }

    function __maxWithdraw_correctMax(uint8 _actor) internal {
        address actor = _chooseActor(_actor);
        uint256 maxWithdraw = silo0.maxWithdraw(actor);
        _withdraw(maxWithdraw, actor);
    }

    function __deposit(uint8 _actor, bool _siloZero, uint256 _amount) internal {
        address actor = _chooseActor(_actor);
        vm.startPrank(actor);

        __chooseSilo(_siloZero).deposit(_amount, actor);
    }

    function __transitionCollateral_doesNotResultInMoreShares(
        uint8 _actor,
        bool _siloZero,
        uint256 _amount,
        uint8 _type
    ) internal returns (uint256) {
        address actor = _chooseActor(_actor);

        ISilo vault = __chooseSilo(_siloZero);
        _invariant_checkForInterest(vault);

        vm.prank(actor);
        return vault.transitionCollateral(_amount, actor, ISilo.AssetType(_type));
    }

    function __cannotPreventInsolventUserFromBeingLiquidated(
        uint8 _actor,
        bool /* _siloZero */,
        bool _receiveShares
    ) internal {
        address actor = _chooseActor(_actor);

        (bool isSolvent, ISilo siloWithDebt) = _invariant_insolventHasDebt(actor);
        assertFalse(isSolvent, "expect not solvent user");

        (, uint256 debtToRepay) = siloWithDebt.maxLiquidation(actor);
        (address collateral, address debt) = __liquidationTokens(address(siloWithDebt));

        siloWithDebt.liquidationCall(debt, collateral, actor, debtToRepay, _receiveShares);
    }

    function __debtSharesNeverLargerThanDebt() internal {
        uint256 debt0 = silo0.getDebtAssets();
        uint256 debt1 = silo1.getDebtAssets();

        (, , address debtShareToken0) = siloConfig.getShareTokens(address(silo0));
        (, , address debtShareToken1) = siloConfig.getShareTokens(address(silo1));

        uint256 debtShareBalance0 = IShareToken(debtShareToken0).totalSupply();
        uint256 debtShareBalance1 = IShareToken(debtShareToken1).totalSupply();

        assertGe(debt0, debtShareBalance0, "[debt] assets0 must be >= shares0");
        assertGe(debt1, debtShareBalance1, "[debt] assets1 must be >= shares1");
    }

    function __borrowShares(uint8 _actorIndex, bool _siloZero, uint256 _shares) internal {
        address actor = _chooseActor(_actorIndex);
        ISilo silo = __chooseSilo(_siloZero);

        vm.prank(actor);
        silo.borrowShares(_shares, actor, actor);
    }

    function __maxRedeem_correctMax(uint8 _actorIndex) internal {
        address actor = _chooseActor(_actorIndex);

        // you need to repay when debt is?!
        uint256 maxShares = silo0.maxRedeem(address(actor));
        (, address collShareToken, ) = siloConfig.getShareTokens(address(silo0));
        assertGt(IShareToken(collShareToken).balanceOf(actor), 0, "No deposits");
        assertGt(maxShares, 0, "Zero shares to withdraw");

        emit log_named_decimal_uint("Max Shares to redeem", maxShares, 18);

        vm.prank(actor);
        silo0.redeem(maxShares, actor, actor); // expect not to fail!
    }

    function __chooseSilo(bool _siloZero) private view returns (ISilo) {
        return _siloZero ? silo0 : silo1;
    }

    function __liquidationTokens(address _siloWithDebt) private view returns (address collateral, address debt) {
        (collateral, debt) = _siloWithDebt == address(silo0)
            ? (address(token0), address(token1))
            : (address(token1), address(token0));
    }

    function __timeDelay(uint256 _t) internal {
        vm.warp(block.timestamp + _t);
    }

    function __timeDelay(uint256 _t, uint256 _roll) internal {
        vm.warp(block.timestamp + _t);
        vm.roll(block.number + _roll);
    }
}
