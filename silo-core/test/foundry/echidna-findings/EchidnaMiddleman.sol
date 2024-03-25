// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";

import {EchidnaSetup} from "./EchidnaSetup.sol";

contract EchidnaMiddleman is EchidnaSetup {
    using SiloLensLib for ISilo;

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
        silo.borrow(_amount, actor, actor, false /* sameToken */);
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
        maxAssets = silo0.maxBorrow(actor, false /* sameToken */);

        vm.prank(actor);
        shares = silo0.borrow(maxAssets, actor, actor, false /* sameToken */); // should not revert!
    }

    function __mint(uint8 _actor, bool _siloZero, uint256 _shares) internal {
        address actor = _chooseActor(_actor);
        ISilo silo = __chooseSilo(_siloZero);

        vm.prank(actor);
        silo.mint(_shares, actor);
    }

    function __maxBorrowShares_correctReturnValue(uint8 _actor) internal returns (uint256 maxBorrow, uint256 shares) {
        address actor = _chooseActor(_actor);

        maxBorrow = silo0.maxBorrowShares(actor, false /* sameToken */);
        assertGt(maxBorrow, 0, "in echidna scenarios we exclude zeros, so we should not get it here as well");

        vm.prank(actor);
        shares = silo0.borrowShares(maxBorrow, actor, actor, false /* sameToken */);
    }

    function __maxLiquidation_correctReturnValue(uint8 _actor) internal {
        address actor = _chooseActor(_actor);
        vm.startPrank(actor);

        (bool isSolvent, ISilo siloWithDebt, ) = _invariant_insolventHasDebt(actor);
        assertFalse(isSolvent, "expect not solvent user");

        (, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(siloWithDebt), actor);

        (address collateral, address debt) = __liquidationTokens(address(siloWithDebt));

        partialLiquidation.liquidationCall(address(siloWithDebt), debt, collateral, actor, debtToRepay, false);

        vm.stopPrank();
    }

    function __maxWithdraw_correctMax(uint8 _actor) internal {
        address actor = _chooseActor(_actor);

        (, ISilo _siloWithCollateral) = _invariant_onlySolventUserCanRedeem(actor);
        _requireHealthySilo(_siloWithCollateral);

        uint256 maxWithdraw = _siloWithCollateral.maxWithdraw(actor);
        emit log_named_decimal_uint("maxWithdraw", maxWithdraw, 18);

        vm.prank(actor);
        _siloWithCollateral.withdraw(maxWithdraw, actor, actor);
    }

    function __deposit(uint8 _actor, bool _siloZero, uint256 _amount) internal {
        address actor = _chooseActor(_actor);
        ISilo silo = __chooseSilo(_siloZero);

        vm.prank(actor);
        silo.deposit(_amount, actor);
    }

    function __transitionCollateral_doesNotResultInMoreShares(
        uint8 _actor,
        bool _siloZero,
        uint256 _amount,
        uint8 _type
    ) internal returns (uint256 transitionedAssets) {
        address actor = _chooseActor(_actor);

        ISilo vault = __chooseSilo(_siloZero);
        _invariant_checkForInterest(vault);

        (address protected, address collateral, ) = siloConfig.getShareTokens(address(vault));

        uint256 shareSumBefore;
        uint256 previewAssetsSumBefore;

        { // too deep
            uint256 protBalanceBefore = IShareToken(protected).balanceOf(address(actor));
            uint256 collBalanceBefore = IShareToken(collateral).balanceOf(address(actor));
            uint256 previewCollateralBefore = vault.previewRedeem(collBalanceBefore, ISilo.AssetType.Collateral);
            uint256 previewProtectedBefore = vault.previewRedeem(protBalanceBefore, ISilo.AssetType.Protected);

            shareSumBefore = protBalanceBefore + collBalanceBefore;
            previewAssetsSumBefore = previewCollateralBefore + previewProtectedBefore;
        }

        bool noInterest = _checkForInterest(vault);

        vm.prank(actor);
        transitionedAssets = vault.transitionCollateral(_amount, actor, ISilo.AssetType(_type));

        uint256 protBalanceAfter = IShareToken(protected).balanceOf(address(actor));
        uint256 collBalanceAfter = IShareToken(collateral).balanceOf(address(actor));

        uint256 shareSumAfter = protBalanceAfter + collBalanceAfter;

        // note: this could result in false positives due to interest calculation, and differences between
        // protected and unprotected shares/balances. Another way to check this property would be to
        // transitionCollateral in one direction, and then in the opposite direction, and only check shares/assets
        // after the second transition.
        // because of above condition is off
        if (noInterest) {
            assertEq(shareSumBefore, shareSumAfter, "Gained shares after transitionCollateral (no interest)");
        }

        uint256 previewCollateralAfter = vault.previewRedeem(collBalanceAfter, ISilo.AssetType.Collateral);
        uint256 previewProtectedAfter = vault.previewRedeem(protBalanceAfter, ISilo.AssetType.Protected);

        assertEq(
            previewAssetsSumBefore, previewCollateralAfter + previewProtectedAfter,
            "price is flat, so there should be no gains"
        );
    }

    function __cannotPreventInsolventUserFromBeingLiquidated(uint8 _actor, bool _receiveShares) internal {
        address actor = _chooseActor(_actor);

        (bool isSolvent, ISilo siloWithDebt, ) = _invariant_insolventHasDebt(actor);
        assertFalse(isSolvent, "expect not solvent user");

        (, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(siloWithDebt), actor);
        (address collateral, address debt) = __liquidationTokens(address(siloWithDebt));

        partialLiquidation.liquidationCall(address(siloWithDebt), debt, collateral, actor, debtToRepay, _receiveShares);
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
        silo.borrowShares(_shares, actor, actor, false /* sameToken */);
    }

    function __maxRedeem_correctMax(uint8 _actorIndex) internal {
        address actor = _chooseActor(_actorIndex);

        (, ISilo _siloWithCollateral) = _invariant_onlySolventUserCanRedeem(actor);
        _requireHealthySilos();

        // you can redeem where there is no debt
        uint256 maxShares = _siloWithCollateral.maxRedeem(address(actor));
        assertGt(maxShares, 0, "Zero shares to withdraw");

        emit log_named_decimal_uint("Max Shares to redeem", maxShares, 18);

        vm.prank(actor);
        _siloWithCollateral.redeem(maxShares, actor, actor); // expect not to fail!
    }

    function __mintAssetType(uint8 _actorIndex, bool _vaultZero, uint256 _shares, uint8 _assetType)
        public returns (uint256 assets)
    {
        address actor = _chooseActor(_actorIndex);
        ISilo silo = __chooseSilo(_vaultZero);

        vm.prank(actor);
        assets = silo.mint(_shares, actor, ISilo.AssetType(_assetType));

        assertLe(_assetType, 3, "we have only 3 types");
    }

    function __withdraw(uint8 _actorIndex, bool _vaultZero, uint256 _assets) public {
        address actor = _chooseActor(_actorIndex);
        ISilo silo = __chooseSilo(_vaultZero);

        vm.prank(actor);
        silo.withdraw(_assets, actor, actor);
    }

    function __maxMint_correctMax(uint8 _actorIndex, bool _vaultZero) public {
        address actor = _chooseActor(_actorIndex);
        ISilo silo = __chooseSilo(_vaultZero);

        uint256 maxShares = silo.maxMint(address(actor));
        assertGt(maxShares, 0, "max mint is zero");

        uint256 assets = silo.previewMint(maxShares);
        assertGt(assets, 0, "expect assets not to be 0");

        emit log_named_decimal_uint("Max Shares to mint:", maxShares, 18);

        vm.prank(actor);
        assertEq(silo.mint(maxShares, actor), assets, "expect preview to be correct");
    }

    function __accrueInterest(bool _vaultZero) public {
        ISilo silo = __chooseSilo(_vaultZero);
        silo.accrueInterest();
    }

    function __depositAssetType(
        uint8 _actorIndex,
        bool _vaultZero,
        uint256 _amount,
        uint8 _assetType
    )
        public returns (uint256 shares)
    {
        address actor = _chooseActor(_actorIndex);
        ISilo silo = __chooseSilo(_vaultZero);

        vm.prank(actor);
        shares = silo.deposit(_amount, actor, ISilo.AssetType(_assetType));

        assertLe(_assetType, 3, "we have only 3 types");
    }

    function __cannotLiquidateASolventUser(uint8 _actorIndex, bool _receiveShares) public {
        address actor = _chooseActor(_actorIndex);
        (bool isSolvent, ISilo siloWithDebt, ) = _invariant_insolventHasDebt(actor);

        assertFalse(isSolvent, "user not solvent");

        (, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(siloWithDebt), address(actor));
        (address collateral, address debt) = __liquidationTokens(address(siloWithDebt));

        try partialLiquidation.liquidationCall(address(siloWithDebt), debt, collateral, actor, debtToRepay, _receiveShares) {
            emit log("Solvent user liquidated!");
            assert(false);
        } catch {
            // do nothing
        }
    }

    function __cannotFullyLiquidateSmallLtv(uint8 _actorIndex) public {
        address actor = _chooseActor(_actorIndex);
        (bool isSolvent, ISilo siloWithDebt, ISilo siloWithCollateral) = _invariant_insolventHasDebt(actor);

        assertFalse(isSolvent, "expect not solvent user");

        uint256 lt = siloWithCollateral.getLt();
        uint256 ltv = siloWithDebt.getLtv(address(actor));

        (, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(siloWithDebt), address(actor));
        assertFalse(isSolvent, "expect user to be not insolvent");

        emit log_named_decimal_uint("User LTV:", ltv, 16);
        emit log_named_decimal_uint("Liq Threshold:", lt, 16);

        (address collateral, address debt) = __liquidationTokens(address(siloWithDebt));
        partialLiquidation.liquidationCall(address(siloWithDebt), debt, collateral, actor, debtToRepay, false);

        uint256 afterLtv = siloWithDebt.getLtv(address(actor));
        emit log_named_decimal_uint("afterLtv:", afterLtv, 16);

        assertEq(silo0.getLtv(address(actor)), silo1.getLtv(address(actor)), "LTV must match on both silos");

        assertTrue(siloWithDebt.isSolvent(address(actor)), "expect user to be solvent (isSolvent)");
        assertGt(afterLtv, 0, "expect some debt");
        assertLt(afterLtv, lt, "expect user LTV to be below LT");
    }

    function __cannotLiquidateUserUnderLt(uint8 _actorIndex, bool _receiveShares) public {
        address actor = _chooseActor(_actorIndex);
        (bool isSolvent, ISilo siloWithDebt, ) = _invariant_insolventHasDebt(actor);

        assertTrue(isSolvent, "expect not solvent user");

        uint256 lt = siloWithDebt.getLt();
        uint256 ltv = siloWithDebt.getLtv(address(actor));

        (, uint256 debtToRepay) = partialLiquidation.maxLiquidation(address(siloWithDebt), address(actor));

        (address collateral, address debt) = __liquidationTokens(address(siloWithDebt));

        try partialLiquidation.liquidationCall(address(siloWithDebt), debt, collateral, actor, debtToRepay, _receiveShares) {
            emit log_named_decimal_uint("User LTV:", ltv, 16);
            emit log_named_decimal_uint("Liq Threshold:", lt, 16);
            emit log("User liquidated!");
            assert(false);
        } catch {
            assertLe(ltv, lt, "ltv <= lt");

            emit log_named_string(
                "it is expected liquidationCall to throw, because user is solvent",
                isSolvent ? "YES" : "NO?!"
            );

        }
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
