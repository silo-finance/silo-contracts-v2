pragma solidity ^0.8.0;

import {Deployers} from "./utils/Deployers.sol";
import {Actor} from "./utils/Actor.sol";
import {ISiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {Silo, ISilo} from "silo-core/contracts/Silo.sol";
import {PartialLiquidation} from "silo-core/contracts/liquidation/PartialLiquidation.sol";
import {SiloLensLib} from "silo-core/contracts/lib/SiloLensLib.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {PropertiesAsserts} from "properties/util/PropertiesHelper.sol";

import {TestERC20Token} from "properties/ERC4626/util/TestERC20Token.sol";
import {IERC20} from "openzeppelin5/token/ERC20/ERC20.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";

// Note: In order to run this campaign all library functions marked as `public` or `external`
// Need to be changed to be `internal`. This includes all library contracts in contracts/lib/

/*
Command to run:
./silo-core/scripts/echidnaBefore.sh
SOLC_VERSION=0.8.21 echidna silo-core/test/echidna/EchidnaE2E.sol \
    --contract EchidnaE2E \
    --config silo-core/test/echidna/e2e-internal.yaml \
    --workers 10
*/
contract EchidnaE2E is Deployers, PropertiesAsserts {
    using SiloLensLib for Silo;
    using Strings for uint256;
    ISiloConfig siloConfig;

    address deployer;
    uint256 startTimestamp = 1706745600;
    // The same block height also needs to be set in the e2e.yaml file
    uint256 startBlockHeight = 17336000;

    address public _vault0;
    address public _vault1;
    Silo public vault0;
    Silo public vault1;

    TestERC20Token _asset0;
    TestERC20Token _asset1;

    Actor[] public actors;

    bool sameAsset;

    event ExactAmount(string msg, uint256 amount);

    constructor() payable {
        deployer = msg.sender;

        hevm.warp(startTimestamp);
        hevm.roll(startBlockHeight);

        // Deploy the relevant contracts
        ve_setUp(startTimestamp);
        core_setUp(address(this));
        _setupBasicData();

        _asset0 = new TestERC20Token("Test Token0", "TT0", 18);
        _asset1 = new TestERC20Token("Test Token1", "TT1", 18);
        _initData(address(_asset0), address(_asset1));

        // deploy silo
        siloConfig = siloFactory.createSilo(siloData["MOCK"]);
        (_vault0, _vault1) = siloConfig.getSilos();
        vault0 = Silo(_vault0);
        vault1 = Silo(_vault1);
        liquidationModule = PartialLiquidation(vault0.config().getConfig(_vault0).liquidationModule);

        // Set up actors
        for(uint256 i; i < 3; i++) {
            actors.push(new Actor(Silo(_vault0), Silo(_vault1)));
        }
    }
    /* ================================================================
                            Echodna invariants
       ================================================================ */

    function echidna_isSolventIsTheSameEverywhere() public view returns (bool success) {
        for(uint256 i; i < actors.length; i++) {
            address actor = address(actors[i]);
            assert(vault0.isSolvent(actor) == vault1.isSolvent(actor));
            assert(vault0.getLtv(actor) == vault1.getLtv(actor));
        }

        success = true;
    }

    /* ================================================================
                            Utility functions
       ================================================================ */
    function _selectActor(uint8 index) internal returns (Actor actor) {
        uint256 actorIndex = clampBetween(uint256(index), 0, actors.length - 1);
        emit LogString(string.concat("Actor selected index:", actorIndex.toString()));

        return actors[actorIndex];
    }

    function _overflowCheck(uint256 a, uint256 b) internal pure {
        uint256 c;
        unchecked {
            c = a + b;
        }

        require(c >= a, "OVERFLOW!");
    }

    function balanceOfSilo(bool vaultZero) public view returns (uint256 assets) {
        address vault = vaultZero ? _vault0 : _vault1;
        TestERC20Token asset = vaultZero ? _asset0 : _asset1;
        assets = asset.balanceOf(vault);
    }

    /* ================================================================
                            Functions used for system interaction
       ================================================================ */

    function deposit(uint8 actorIndex, bool vaultZero, uint256 amount) public returns (uint256 shares) {
        Actor actor = _selectActor(actorIndex);

        shares = actor.deposit(vaultZero, amount);
        emit LogString(string.concat("Deposited", amount.toString(), "assets into vault", vaultZero ? "Zero" : "One", "and minted", shares.toString(), "shares"));
    }

    function depositAssetType(uint8 actorIndex, bool vaultZero, uint256 amount, ISilo.AssetType assetType) public returns (uint256 shares) {
        Actor actor = _selectActor(actorIndex);

        shares = actor.depositAssetType(vaultZero, amount, assetType);

        emit LogString(string.concat(
            "Deposited",
            amount.toString(),
            assetType == ISilo.AssetType.Collateral ? " collateral" : " protected",
            " assets into vault",
            vaultZero ? "Zero" : "One",
            "and minted",
            shares.toString(),
            "shares"
        ));
    }

    function mint(uint8 actorIndex, bool vaultZero, uint256 shares) public returns (uint256 assets) {
        Actor actor = _selectActor(actorIndex);

        assets = actor.mint(vaultZero, shares);
        emit LogString(string.concat("Minted", shares.toString()," shares from vault", vaultZero ? "Zero" : "One", "and deposited", assets.toString(), "assets"));
    }

    function mintAssetType(uint8 actorIndex, bool vaultZero, uint256 shares, ISilo.AssetType assetType) public returns (uint256 assets) {
        Actor actor = _selectActor(actorIndex);

        assets = actor.mintAssetType(vaultZero, shares, assetType);
        emit LogString(string.concat("Minted", shares.toString()," shares from vault", vaultZero ? "Zero" : "One", "and deposited", assets.toString(), assetType == ISilo.AssetType.Collateral ? " collateral" : " protected", " assets"));
    }

    function withdraw(uint8 actorIndex, bool vaultZero, uint256 assets) public {
        Actor actor = _selectActor(actorIndex);
        actor.withdraw(vaultZero, assets);
    }

    function withdrawAssetType(uint8 actorIndex, bool vaultZero, uint256 assets, ISilo.AssetType assetType) public {
        Actor actor = _selectActor(actorIndex);
        actor.withdrawAssetType(vaultZero, assets, assetType);
    }

    function redeem(uint8 actorIndex, bool vaultZero, uint256 shares) public {
        Actor actor = _selectActor(actorIndex);
        actor.redeem(vaultZero, shares);
    }

    function redeemAssetType(uint8 actorIndex, bool vaultZero, uint256 shares, ISilo.AssetType assetType) public {
        Actor actor = _selectActor(actorIndex);
        actor.redeemAssetType(vaultZero, shares, assetType);
    }

    function borrow(uint8 actorIndex, bool vaultZero, uint256 assets) public {
        Actor actor = _selectActor(actorIndex);
        actor.borrow(vaultZero, assets);
    }

    function borrowShares(uint8 actorIndex, bool vaultZero, uint256 shares) public {
        Actor actor = _selectActor(actorIndex);
        actor.borrowShares(vaultZero, shares);
    }

    function repay(uint8 actorIndex, bool vaultZero, uint256 amount) public {
        Actor actor = _selectActor(actorIndex);
        actor.repay(vaultZero, amount);
    }

    function repayShares(uint8 actorIndex, bool vaultZero, uint256 shares) public returns (uint256 assets) {
        Actor actor = _selectActor(actorIndex);
        assets = actor.repayShares(vaultZero, shares);
    }

    function accrueInterest(bool vaultZero) public {
        Silo vault = vaultZero ? vault0 : vault1;
        vault.accrueInterest();
    }

    function withdrawFees(bool vaultZero) public {
        Silo vault = vaultZero ? vault0 : vault1;
        vault.withdrawFees();
    }

    function transitionCollateral(uint8 actorIndex, bool vaultZero, uint256 shares, ISilo.AssetType withdrawType) public returns (uint256 assets) {
        Actor actor = _selectActor(actorIndex);
        assets = actor.transitionCollateral(vaultZero, shares, withdrawType);
    }

    function liquidationCall(
        uint8 actorIndexBorrower,
        uint8 actorIndexLiquidator,
        uint256 debtToCover,
        bool receiveSToken
    ) public {
        Actor borrower = _selectActor(actorIndexBorrower);
        Actor liquidator = _selectActor(actorIndexLiquidator);

        (, bool _vaultZeroWithDebt) = _invariant_insolventHasDebt(address(borrower));

        liquidator.liquidationCall(_vaultZeroWithDebt, address(borrower), debtToCover, receiveSToken, siloConfig);
    }

    /* ================================================================
                            Properties:
            checking if max* functions are aligned with ERC4626
       ================================================================ */

    // maxDeposit functions are aligned with ERC4626 standard
    function maxDeposit_correctMax(uint8 actorIndex) public {
        Actor actor = _selectActor(actorIndex);
        uint256 maxAssets = vault0.maxDeposit(address(actor));
        require(maxAssets != 0, "max deposit is zero");

        uint256 userTokenBalance = _asset0.balanceOf(address(actor));
        uint256 totalSupply = _asset0.totalSupply();
        _overflowCheck(totalSupply, maxAssets);
        require(userTokenBalance >= maxAssets, "Not enough assets for deposit");

        emit LogString(string.concat("Max Assets to deposit:", maxAssets.toString()));

        try actor.deposit(true, maxAssets) {

        } catch {
            assert(false);
        }
    }

    function maxMint_correctMax(uint8 actorIndex, bool vaultZero) public {
        Actor actor = _selectActor(actorIndex);
        Silo vault = vaultZero ? vault0 : vault1;
        TestERC20Token token = vaultZero ? _asset0 : _asset1;

        uint256 maxShares = vault.maxMint(address(actor));
        require(maxShares != 0, "max mint is zero");

        uint256 assets = vault.previewMint(maxShares);
        uint256 userTokenBalance = token.balanceOf(address(actor));
        require(userTokenBalance >= assets, "Not enough assets for mint");
        
        uint256 totalSupply = token.totalSupply();
        _overflowCheck(totalSupply, assets);

        emit LogString(string.concat("Max Shares to mint:", maxShares.toString()));

        try actor.mint(vaultZero, maxShares) {

        } catch {
            assert(false);
        }
    }

    function maxWithdraw_correctMax(uint8 actorIndex) public {
        Actor actor = _selectActor(actorIndex);

        (, bool _vaultWithCollateral) = _invariant_onlySolventUserCanRedeem(address(actor));
        Silo vault = _vaultWithCollateral ? vault0 : vault1;
        require(_requireHealthySilos(), "we dont want IRM to fail");

        uint256 maxAssets = vault.maxWithdraw(address(actor));
        (, address collShareToken, ) = siloConfig.getShareTokens(address(vault));
        require(IERC20(collShareToken).balanceOf(address(actor)) > 0, "No deposits");
        require(maxAssets != 0, "Zero assets to withdraw");

        uint256 liquidity = vault.getLiquidity(); // includes interest
        emit LogString(string.concat("Max Assets to withdraw:", maxAssets.toString()));
        emit LogString(string.concat("Available liquidity:", liquidity.toString()));

        try actor.withdraw(_vaultWithCollateral, maxAssets) {
            emit LogString("Withdrawal succeeded");
        } catch {
            emit LogString("Withdrawal failed");
            assert(false);
        }
    }

    function maxRedeem_correctMax(uint8 actorIndex) public {
        Actor actor = _selectActor(actorIndex);

        (, bool _vaultWithCollateral) = _invariant_onlySolventUserCanRedeem(address(actor));
        Silo vault = _vaultWithCollateral ? vault0 : vault1;
        require(_requireHealthySilos(), "we dont want IRM to fail");

        uint256 maxShares = vault.maxRedeem(address(actor));
        require(maxShares != 0, "Zero shares to withdraw");

        emit LogString(string.concat("Max Shares to redeem:", maxShares.toString()));

        try actor.redeem(_vaultWithCollateral, maxShares) {

        } catch {
            assert(false);
        }
    }

    function maxBorrow_correctReturnValue(uint8 actorIndex) public {
        Actor actor = _selectActor(actorIndex);
        uint256 maxAssets = vault0.maxBorrow(address(actor), sameAsset);
        require(maxAssets != 0, "Zero assets to borrow");

        emit LogString(string.concat("Max Assets to borrow:", maxAssets.toString()));
        emit ExactAmount("maxAssets:", maxAssets);

        (address protShareToken, address collShareToken, ) = siloConfig.getShareTokens(address(vault1));
        emit ExactAmount("protected share decimals:", TestERC20Token(protShareToken).decimals());
        emit ExactAmount("protected decimals:", _asset0.decimals());
        emit ExactAmount("collateral balance:", TestERC20Token(collShareToken).balanceOf(address(actor)));
        emit ExactAmount("collateral share decimals:", TestERC20Token(collShareToken).decimals());
        emit ExactAmount("collateral decimals:", _asset1.decimals());

        try actor.borrow(true, maxAssets) {

        } catch {
            assert(false);
        }
    }

    function maxBorrowShares_correctReturnValue(uint8 actorIndex) public {
        Actor actor = _selectActor(actorIndex);
        uint256 maxShares = vault0.maxBorrowShares(address(actor), sameAsset);
        require(maxShares != 0, "Zero assets to borrow");

        emit LogString(string.concat("Max Shares to borrow:", maxShares.toString()));
        _dumpState(address(actor));

        try actor.borrowShares(true, maxShares) {

        } catch {
            assert(false);
        }
    }

    function maxRepay_correctReturnValue(uint8 actorIndex) public {
        Actor actor = _selectActor(actorIndex);
        uint256 maxAssets = vault0.maxRepay(address(actor));
        require(maxAssets != 0, "Zero assets to repay");
        require(_asset0.balanceOf(address(actor)) >= maxAssets, "Insufficient balance for debt repayment");

        (, , address debtShareToken0) = siloConfig.getShareTokens(address(vault0));
        uint256 actorDebt = IERC20(debtShareToken0).balanceOf(address(actor));
        require(actorDebt > 0, "Actor has no debt");

        emit LogString(string.concat("Max Assets to repay:", maxAssets.toString()));

        try actor.repay(true, maxAssets) {

        } catch {
            assert(false);
        }
    }

    function maxRepayShares_correctReturnValue(uint8 actorIndex) public {
        Actor actor = _selectActor(actorIndex);
        uint256 maxShares = vault0.maxRepayShares(address(actor));
        require(maxShares != 0, "Zero shares to repay");
        (, , address debtShareToken0) = siloConfig.getShareTokens(address(vault0));
        uint256 actorDebt = IERC20(debtShareToken0).balanceOf(address(actor));
        require(actorDebt > 0, "Actor has no debt");

        uint256 assets = vault0.previewRepayShares(maxShares);
        require(_asset0.balanceOf(address(actor)) >= assets, "Not enough assets to repay");

        emit LogString(string.concat("User debt shares:", actorDebt.toString()));
        emit LogString(string.concat("Max Shares to repay:", maxShares.toString()));

        try actor.repayShares(true, maxShares) {

        } catch {
            assert(false);
        }
    }

    function maxLiquidation_correctReturnValue(uint8 actorIndex) public {
        Actor actor = _selectActor(actorIndex);
        Actor secondActor = _selectActor(actorIndex + 1);

        (bool isSolvent, bool _vaultZeroWithDebt) = _invariant_insolventHasDebt(address(actor));
        require(!isSolvent, "user not solvent");

        Silo siloWithDebt = _vaultZeroWithDebt ? vault0 : vault1;

        (
            uint256 collateralToLiquidate, uint256 debtToRepay
        ) = liquidationModule.maxLiquidation(address(siloWithDebt), address(actor));

        require(collateralToLiquidate != 0 && debtToRepay != 0, "Nothing to liquidate");

        emit LogString(string.concat("debtToRepay:", debtToRepay.toString()));
        emit LogString(string.concat("collateralToLiquidate:", collateralToLiquidate.toString()));
        emit LogString(string.concat("borrower LTV before liquidation:", siloWithDebt.getLtv(address(actor)).toString()));

        try secondActor.liquidationCall(_vaultZeroWithDebt, address(actor), debtToRepay, false, siloConfig) {

        } catch {
            assert(false);
        }
    }

    /* ================================================================
                            Properties:
            checking if preview* functions are aligned with ERC4626
       ================================================================ */

    function previewDeposit_doesNotReturnMoreThanDeposit(uint8 actorIndex, uint256 assets) public {
        Actor actor = _selectActor(actorIndex);
        uint256 previewShares = vault0.previewDeposit(assets);
        uint256 shares = actor.deposit(true, assets);
        assertLte(previewShares, shares, "previewDeposit overestimates shares!");
    }

    function previewMint_DoesNotReturnLessThanMint(uint8 actorIndex, uint256 shares) public {
        Actor actor = _selectActor(actorIndex);
        uint256 previewAssets = vault0.previewMint(shares);
        uint256 assets = actor.mint(true, shares);
        assertGte(previewAssets, assets, "previewMint underestimates assets!");
    }

    function previewWithdraw_doesNotReturnLessThanWithdraw(uint8 actorIndex, uint256 assets) public {
        Actor actor = _selectActor(actorIndex);
        uint256 previewShares = vault0.previewWithdraw(assets);
        uint256 shares = actor.withdraw(true, assets);
        assertGte(previewShares, shares, "previewWithdraw underestimates shares!");
    }

    function previewRedeem_doesNotReturnMoreThanRedeem(uint8 actorIndex, uint256 shares) public {
        Actor actor = _selectActor(actorIndex);
        uint256 previewAssets = vault0.previewRedeem(shares);
        uint256 assets = actor.redeem(true, shares);
        assertLte(previewAssets, assets, "previewRedeem overestimates assets!");
    }

    /* ================================================================
                            Properties:
            Check if shares or assets can round down to zero
       ================================================================ */
    function depositNeverMintsZeroShares(uint8 actorIndex, bool vaultZero, uint256 amount) public {
        uint256 shares = deposit(actorIndex, vaultZero, amount);
        assertNeq(shares, 0 , "Deposit minted zero shares");
    }

    function repayNeverReturnsZeroAssets(uint8 actorIndex, bool vaultZero, uint256 shares) public {
        uint256 assets = repayShares(actorIndex, vaultZero, shares);
        assertNeq(assets, 0, "repayShares returned zero assets");
    }

    /* ================================================================
                            Other properties
       ================================================================ */

    // Property: Total debt shares should never be larger than total debt
    function debtSharesNeverLargerThanDebt() public view {
        uint256 debt0 = vault0.getDebtAssets();
        uint256 debt1 = vault1.getDebtAssets();

        (, , address debtShareToken0) = siloConfig.getShareTokens(address(vault0));
        (, , address debtShareToken1) = siloConfig.getShareTokens(address(vault1));

        uint256 debtShareBalance0 = IERC20(debtShareToken0).totalSupply();
        uint256 debtShareBalance1 = IERC20(debtShareToken1).totalSupply();

        assert(debt0 >= debtShareBalance0);
        assert(debt1 >= debtShareBalance1);
    }

    // Property: A user who's debt is above the liquidation threshold cannot be liquidated by another user
    function cannotLiquidateUserUnderLt(uint8 actorIndex, bool receiveShares) public {
        Actor actor = _selectActor(actorIndex);
        Actor liquidator = _selectActor(actorIndex + 1);

        (bool isSolvent, bool _vaultZeroWithDebt) = _invariant_insolventHasDebt(address(actor));

        Silo vault = _vaultZeroWithDebt ? vault0 : vault1;

        require(isSolvent, "User LTV too large");

        uint256 lt = vault.getLt();
        uint256 ltv = vault.getLtv(address(actor));

        (, uint256 debtToRepay) = liquidationModule.maxLiquidation(address(vault), address(actor));

        try liquidator.liquidationCall(_vaultZeroWithDebt, address(actor), debtToRepay, receiveShares, siloConfig) {
            emit LogString(string.concat("User LTV:", ltv.toString(), " Liq Threshold:", lt.toString()));
            emit LogString("User liquidated!");
            assert(false);
        } catch {
            // do nothing, it is expected
        }
    }

    // Property: A user who's debt is above the liquidation threshold cannot be liquidated by another user
    function cannotLiquidateASolventUser(uint8 actorIndex, bool receiveShares) public {
        Actor actor = _selectActor(actorIndex);
        Actor liquidator = _selectActor(actorIndex + 1);

        (bool isSolvent, bool _vaultZeroWithDebt) = _invariant_insolventHasDebt(address(actor));

        Silo vault = _vaultZeroWithDebt ? vault0 : vault1;
        require(isSolvent, "user not solvent");

        (, uint256 debtToRepay) = liquidationModule.maxLiquidation(address(vault), address(actor));

        try liquidator.liquidationCall(_vaultZeroWithDebt, address(actor), debtToRepay, receiveShares, siloConfig) {
            emit LogString("Solvent user liquidated!");
            assert(false);
        } catch {
            // do nothing
        }
    }

    // Property: An insolvent user cannot prevent others from liquidating his debt
    function cannotPreventInsolventUserFromBeingLiquidated(uint8 actorIndex, bool receiveShares) public {
        Actor actor = _selectActor(actorIndex);
        Actor liquidator = _selectActor(actorIndex + 1);

        (bool isSolvent, bool _vaultZeroWithDebt) = _invariant_insolventHasDebt(address(actor));
        require(!isSolvent, "user not solvent");

        Silo siloWithDebt = _vaultZeroWithDebt ? vault0 : vault1;
        (, uint256 debtToRepay) = liquidationModule.maxLiquidation(address(siloWithDebt), address(actor));

        try liquidator.liquidationCall(_vaultZeroWithDebt, address(actor), debtToRepay, receiveShares, siloConfig) {
        } catch {
            emit LogString("Cannot liquidate insolvent user!");
            assert(false);
        }
    }

    // Property: A slightly insolvent user cannot be fully liquidated
    function cannotFullyLiquidateSmallLtv(uint8 actorIndex) public {
        Actor actor = _selectActor(actorIndex);
        Actor actorTwo = _selectActor(actorIndex + 1);

        (bool isSolvent, bool _vaultZeroWithDebt) = _invariant_insolventHasDebt(address(actor));

        Silo vault = _vaultZeroWithDebt ? vault0 : vault1;
        Silo siloWithCollateral = _vaultZeroWithDebt ? vault1 : vault0;

        uint256 lt = siloWithCollateral.getLt();
        uint256 ltv = vault.getLtv(address(actor));

        (, uint256 debtToRepay) = liquidationModule.maxLiquidation(address(vault), address(actor));
        require(!isSolvent, "Not insolvent");

        emit LogString(string.concat("User LTV:", ltv.toString(), " Liq Threshold:", lt.toString()));

        actorTwo.liquidationCall(_vaultZeroWithDebt, address(actor), debtToRepay, false, siloConfig);

        uint256 afterLtv = vault.getLtv(address(actor));
        emit LogString(string.concat("User afterLtv:", afterLtv.toString()));

        assert(afterLtv > 0 && afterLtv < lt);
    }

    // Property: A user self-liquidating cannot gain assets or shares
    function selfLiquidationDoesNotResultInMoreSharesOrAssets(uint8 actorIndex, uint256 debtToRepay, bool receiveSToken)
        public
    {
        Actor actor = _selectActor(actorIndex);
        (, bool _vaultZeroWithDebt) = _invariant_insolventHasDebt(address(actor));

        Silo vault = _vaultZeroWithDebt ? vault0 : vault1;
        Silo otherVault = _vaultZeroWithDebt ? vault1 : vault0;

        (address protectedShareToken, address collateralShareToken, ) = siloConfig.getShareTokens(address(otherVault));
        (,, address debtShareToken ) = siloConfig.getShareTokens(address(vault));

        { // to deep
            uint256 procBalanceBefore = IShareToken(protectedShareToken).balanceOf(address(actor));
            uint256 collBalanceBefore = IShareToken(collateralShareToken).balanceOf(address(actor));
            uint256 debtBalanceBefore = IShareToken(debtShareToken).balanceOf(address(actor));
            actor.liquidationCall(_vaultZeroWithDebt, address(actor), debtToRepay, receiveSToken, siloConfig);

            uint256 procBalanceAfter = IShareToken(protectedShareToken).balanceOf(address(actor));
            uint256 collBalanceAfter = IShareToken(collateralShareToken).balanceOf(address(actor));
            uint256 debtBalanceAfter = IShareToken(debtShareToken).balanceOf(address(actor));

            assertLte(procBalanceAfter, procBalanceBefore, "Protected shares balance increased");
            assertLte(collBalanceAfter, collBalanceBefore, "Collateral shares balance increased");
            assertLte(debtBalanceAfter, debtBalanceBefore, "Debt shares balance increased");
        }
    }

    // Property: A user transitioning his collateral cannot receive more shares
    function transitionCollateral_doesNotResultInMoreShares(
        uint8 actorIndex,
        bool vaultZero,
        uint256 shares,
        ISilo.AssetType assetType
    ) public {
        Actor actor = _selectActor(actorIndex);
        Silo vault = vaultZero ? vault0 : vault1;

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

        actor.transitionCollateral(vaultZero, shares, assetType);

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

    function _checkForInterest(Silo _silo) internal returns (bool noInterest) {
        (, uint256 interestRateTimestamp) = _silo.siloData();
        noInterest = block.timestamp == interestRateTimestamp;

        if (noInterest) assertEq(_silo.accrueInterest(), 0, "no interest should be applied");
    }

    function _invariant_insolventHasDebt(address _user)
        internal
        returns (bool isSolvent, bool _vaultZeroWithDebt)
    {
        isSolvent = vault0.isSolvent(_user);

        (,, address debtShareToken0 ) = siloConfig.getShareTokens(_vault0);
        (,, address debtShareToken1 ) = siloConfig.getShareTokens(_vault1);

        uint256 balance0 = IShareToken(debtShareToken0).balanceOf(_user);
        uint256 balance1 = IShareToken(debtShareToken1).balanceOf(_user);

        if (isSolvent) return (isSolvent, balance0 > 0);

        assertEq(balance0 * balance1, 0, "[_invariant_insolventHasDebt] one balance must be 0");
        assertGt(balance0 + balance1, 0, "user should have debt if he is insolvent");

        return (isSolvent, balance0 > 0);
    }

    function _invariant_onlySolventUserCanRedeem(address _user)
        internal
        returns (bool isSolvent, bool vaultZeroWithCollateral)
    {
        // _dumpState(_user);

        isSolvent = vault0.isSolvent(_user);

        (
            address protectedShareToken0, address collateralShareToken0, address debtShareToken0
        ) = siloConfig.getShareTokens(address(_vault0));

        (,, address debtShareToken1 ) = siloConfig.getShareTokens(_vault1);

        uint256 debtBalance0 = IShareToken(debtShareToken0).balanceOf(_user);
        uint256 debtBalance1 = IShareToken(debtShareToken1).balanceOf(_user);

        assertEq(debtBalance0 * debtBalance1, 0, "[onlySolventUserCanRedeem] one balance must be 0");

        if (debtBalance0 + debtBalance1 != 0) return (isSolvent, debtBalance0 == 0);

        uint256 protectedBalance0 = IShareToken(protectedShareToken0).balanceOf(_user);
        uint256 collateralBalance0 = IShareToken(collateralShareToken0).balanceOf(_user);

        vaultZeroWithCollateral = protectedBalance0 + collateralBalance0 != 0;
    }

    function _requireHealthySilos() internal view returns (bool healthy) {
        return _requireHealthySilo(vault0) && _requireHealthySilo(vault1);
    }

    function _requireHealthySilo(Silo _silo) internal view returns (bool healthy) {
        ISiloConfig.ConfigData memory cfg = siloConfig.getConfig(address(_silo));

        try IInterestRateModel(cfg.interestRateModel).getCompoundInterestRate(address(_silo), block.timestamp) {
            // we only accepting cased were we do not revert
            healthy = true;
        } catch {
            // we dont want case, where IRM fail
        }
    }

    function _dumpState(address _actor) internal {
        emit ExactAmount("block.number:", block.number);
        emit ExactAmount("block.timestamp:", block.timestamp);

        (uint256 collectedFees0, uint256 irmTimestamp0) = vault0.siloData();
        (uint256 collectedFees1, uint256 irmTimestamp1) = vault1.siloData();

        emit ExactAmount("collectedFees0:", collectedFees0);
        emit ExactAmount("irmTimestamp0:", irmTimestamp0);
        emit ExactAmount("collectedFees1:", collectedFees1);
        emit ExactAmount("irmTimestamp1:", irmTimestamp1);

        emit ExactAmount("LTV0:", vault0.getLtv(_actor));
        emit ExactAmount("LTV1:", vault1.getLtv(_actor));

        (address protectedToken0, address collateralToken0, address debtShareToken0) = siloConfig.getShareTokens(_vault0);
        (address protectedToken1, address collateralToken1,  address debtShareToken1 ) = siloConfig.getShareTokens(_vault1);

        emit ExactAmount("protectedToken0.balanceOf:", IShareToken(protectedToken0).balanceOf(_actor));
        emit ExactAmount("collateralToken0.balanceOf:", IShareToken(collateralToken0).balanceOf(_actor));
        emit ExactAmount("debtShareToken0.balanceOf:", IShareToken(debtShareToken0).balanceOf(_actor));

        emit ExactAmount("protectedToken1.balanceOf:", IShareToken(protectedToken1).balanceOf(_actor));
        emit ExactAmount("collateralToken1.balanceOf:", IShareToken(collateralToken1).balanceOf(_actor));
        emit ExactAmount("debtShareToken1.balanceOf:", IShareToken(debtShareToken1).balanceOf(_actor));

        emit ExactAmount("maxWithdraw0:", vault0.maxWithdraw(_actor));
        emit ExactAmount("maxWithdraw1:", vault1.maxWithdraw(_actor));

        uint256 maxBorrow0 = vault0.maxBorrow(_actor, sameAsset);
        uint256 maxBorrow1 = vault1.maxBorrow(_actor, sameAsset);
        emit ExactAmount("maxBorrow0:", maxBorrow0);
        emit ExactAmount("maxBorrow1:", maxBorrow1);

        emit ExactAmount("convertToShares(maxBorrow0):", vault0.convertToShares(maxBorrow0, ISilo.AssetType.Debt));
        emit ExactAmount("convertToShares(maxBorrow1):", vault1.convertToShares(maxBorrow1, ISilo.AssetType.Debt));

        emit ExactAmount("maxBorrowShares0:", vault0.maxBorrowShares(_actor, sameAsset));
        emit ExactAmount("maxBorrowShares1:", vault1.maxBorrowShares(_actor, sameAsset));
    }
}
