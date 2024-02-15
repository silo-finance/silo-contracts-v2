pragma solidity ^0.8.0;

import {Deployers} from "./utils/Deployers.sol";
import {Actor} from "./utils/Actor.sol";
import {ISiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {Silo, ISilo} from "silo-core/contracts/Silo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {PropertiesAsserts} from "properties/util/PropertiesHelper.sol";

import {TestERC20Token} from "properties/ERC4626/util/TestERC20Token.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

// Note: In order to run this campaign all library functions marked as `public` or `external`
// Need to be changed to be `internal`. This includes all library contracts in contracts/lib/

/*
Command to run:
./silo-core/scripts/echidnaBefore.sh
SOLC_VERSION=0.8.21 echidna silo-core/test/echidna/EchidnaE2E.sol --contract EchidnaE2E --config silo-core/test/echidna/e2e-internal.yaml --workers 10
*/
contract EchidnaE2E is Deployers, PropertiesAsserts {
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

        // Set up actors
        for(uint256 i; i < 3; i++) {
            actors.push(new Actor(Silo(_vault0), Silo(_vault1)));
        }
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
        emit LogString(string.concat("Deposited", amount.toString(), assetType == ISilo.AssetType.Collateral ? " collateral" : " protected" ," assets into vault", vaultZero ? "Zero" : "One", "and minted", shares.toString(), "shares"));

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

    function liquidationCall(uint8 actorIndexBorrower, uint8 actorIndexLiquidator, bool vaultZero, uint256 debtToCover, bool receiveSToken) public {
        Actor borrower = _selectActor(actorIndexBorrower);
        Actor liquidator = _selectActor(actorIndexLiquidator);
        liquidator.liquidationCall(vaultZero, address(borrower), debtToCover, receiveSToken, siloConfig);
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

    function maxMint_correctMax(uint8 actorIndex) public {
        Actor actor = _selectActor(actorIndex);
        uint256 maxShares = vault0.maxMint(address(actor));
        require(maxShares != 0, "max mint is zero");

        uint256 assets = vault0.previewMint(maxShares);
        uint256 userTokenBalance = _asset0.balanceOf(address(actor));
        require(userTokenBalance >= assets, "Not enough assets for mint");
        
        uint256 totalSupply = _asset0.totalSupply();
        _overflowCheck(totalSupply, assets);

        emit LogString(string.concat("Max Shares to mint:", maxShares.toString()));

        try actor.mint(true, maxShares) {

        } catch {
            assert(false);
        }
    }

    function maxWithdraw_correctMax(uint8 actorIndex) public {
        // require previous deposits
        Actor actor = _selectActor(actorIndex);

        uint256 maxAssets = vault0.maxWithdraw(address(actor));
        (, address collShareToken, ) = siloConfig.getShareTokens(address(vault0));
        require(IERC20(collShareToken).balanceOf(address(actor)) > 0, "No deposits");
        require(maxAssets != 0, "Zero assets to withdraw");

        uint256 liquidity = vault0.getLiquidity(); // includes interest
        emit LogString(string.concat("Max Assets to withdraw:", maxAssets.toString()));
        emit LogString(string.concat("Available liquidity:", liquidity.toString()));

        try actor.withdraw(true, maxAssets) {
            emit LogString("Withdrawal suceeded");
        } catch {
            emit LogString("Withdrawal failed");
            assert(false);
        }
    }

    function maxRedeem_correctMax(uint8 actorIndex) public {
        Actor actor = _selectActor(actorIndex);
        uint256 maxShares = vault0.maxRedeem(address(actor));
        (, address collShareToken, ) = siloConfig.getShareTokens(address(vault0));
        require(IERC20(collShareToken).balanceOf(address(actor)) > 0, "No deposits");
        require(maxShares != 0, "Zero shares to withdraw");

        emit LogString(string.concat("Max Shares to redeem:", maxShares.toString()));

        try actor.redeem(true, maxShares) {

        } catch {
            assert(false);
        }
    }

    function maxBorrow_correctReturnValue(uint8 actorIndex) public {
        Actor actor = _selectActor(actorIndex);
        uint256 maxAssets = vault0.maxBorrow(address(actor));
        require(maxAssets != 0, "Zero assets to borrow");

        emit LogString(string.concat("Max Assets to borrow:", maxAssets.toString()));

        try actor.borrow(true, maxAssets) {

        } catch {
            assert(false);
        }
    }

    function maxBorrowShares_correctReturnValue(uint8 actorIndex) public {
        Actor actor = _selectActor(actorIndex);
        uint256 maxShares = vault0.maxBorrowShares(address(actor));
        require(maxShares != 0, "Zero assets to borrow");

        emit LogString(string.concat("Max Shares to borrow:", maxShares.toString()));

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
        (uint256 collateralToLiquidate, uint256 debtToRepay) = vault0.maxLiquidation(address(actor));
        require(collateralToLiquidate != 0 && debtToRepay != 0, "Nothing to liquidate");

        emit LogString(string.concat("debtToRepay:", debtToRepay.toString()));
        emit LogString(string.concat("collateralToLiquidate:", collateralToLiquidate.toString()));
        emit LogString(string.concat("borrower LTV before liquidation:", vault0.getLtv(address(actor)).toString()));

        try secondActor.liquidationCall(true, address(actor), debtToRepay, false, siloConfig) {

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

    // Property: A user who's position is above the liquidation threshold cannot be liquidated by another user
    function cannotLiquidateUserUnderLt(uint8 actorIndex, bool vaultZero, bool receiveShares) public {
        Actor actor = _selectActor(actorIndex);
        Actor liquidator = _selectActor(actorIndex + 1);
        Silo vault = vaultZero ? vault0 : vault1;
        Silo otherVault = vaultZero ? vault1 : vault0;

        uint256 ltv = vault.getLtv(address(actor));
        uint256 lt = otherVault.getLt();

        require(ltv <= lt, "User LTV too large");

        (, uint256 debtToRepay) = vault.maxLiquidation(address(actor));
        try liquidator.liquidationCall(vaultZero, address(actor), debtToRepay, receiveShares, siloConfig) {
            emit LogString(string.concat("User LTV:", ltv.toString(), " Liq Threshold:", lt.toString()));
            emit LogString("User liquidated!");
            assert(false);
        } catch {
            // do nothing
        }
    }

    // Property: A user who's position is above the liquidation threshold cannot be liquidated by another user
    function cannotLiquidateASolventUser(uint8 actorIndex, bool vaultZero, bool receiveShares) public {
        Actor actor = _selectActor(actorIndex);
        Actor liquidator = _selectActor(actorIndex + 1);
        
        // The user should have debt shares in one of the Silos
        (, , address debtShareToken0) = siloConfig.getShareTokens(address(vault0));
        uint256 actorDebtShares = IERC20(debtShareToken0).balanceOf(address(actor));
        Silo vault = actorDebtShares > 0 ? vault0 : vault1;

        bool isSolvent = vault.isSolvent(address(actor));
        require(isSolvent, "user not solvent");

        (, uint256 debtToRepay) = vault.maxLiquidation(address(actor));
        try liquidator.liquidationCall(vaultZero, address(actor), debtToRepay, receiveShares, siloConfig) {
            emit LogString("Solvent user liquidated!");
            assert(false);
        } catch {
            // do nothing
        }
    }

    // Property: An insolvent user cannot prevent others from liquidating his position
    function cannotPreventInsolventUserFromBeingLiquidated(uint8 actorIndex, bool vaultZero, bool receiveShares) public {
        Actor actor = _selectActor(actorIndex);
        Actor liquidator = _selectActor(actorIndex + 1);
        Silo vault = vaultZero ? vault0 : vault1;

        bool isSolvent = vault.isSolvent(address(actor));
        require(!isSolvent, "user not solvent");
        // TODO check that the user has borrow shares

        (, uint256 debtToRepay) = vault.maxLiquidation(address(actor));
        try liquidator.liquidationCall(vaultZero, address(actor), debtToRepay, receiveShares, siloConfig) {

        } catch {
            emit LogString("Cannot liquidate insolvent user!");
            assert(false);
        }
    }

    // Property: A slightly insolvent user cannot be fully liquidated
    function cannotFullyLiquidateSmallLtv(bool vaultZero, uint8 actorIndex) public {
        Actor actor = _selectActor(actorIndex);
        Actor actorTwo = _selectActor(actorIndex + 1);
        Silo vault = vaultZero ? vault0 : vault1;
        Silo otherVault = vaultZero ? vault1 : vault0;
        uint256 ltv = vault.getLtv(address(actor));
        uint256 lt = otherVault.getLt();

        (, uint256 debtToRepay) = vault.maxLiquidation(address(actor));
        require(ltv > lt, "Not insolvent");

        emit LogString(string.concat("User LTV:", ltv.toString(), " Liq Threshold:", lt.toString()));

        actorTwo.liquidationCall(true, address(actor), debtToRepay, false, siloConfig);

        vault.getLtv(address(actor));
        assert(false);
    }

    // Property: A user self-liquidating cannot gain assets or shares
    function selfLiquidationDoesNotResultInMoreSharesOrAssets(bool vaultZero, uint8 actorIndex, uint256 debtToRepay, bool receiveSToken) public {
        Actor actor = _selectActor(actorIndex);
        Silo vault = vaultZero ? vault0 : vault1;
        Silo otherVault = vaultZero ? vault1 : vault0;

        (address protectedShareToken, address collateralShareToken, ) = siloConfig.getShareTokens(address(otherVault));
        (,, address debtShareToken ) = siloConfig.getShareTokens(address(vault));

        uint256 procBalanceBefore = IShareToken(protectedShareToken).balanceOf(address(actor));
        uint256 collBalanceBefore = IShareToken(collateralShareToken).balanceOf(address(actor));
        uint256 debtBalanceBefore = IShareToken(debtShareToken).balanceOf(address(actor));
        actor.liquidationCall(vaultZero, address(actor), debtToRepay, receiveSToken, siloConfig);

        uint256 procBalanceAfter = IShareToken(protectedShareToken).balanceOf(address(actor));
        uint256 collBalanceAfter = IShareToken(collateralShareToken).balanceOf(address(actor));
        uint256 debtBalanceAfter = IShareToken(debtShareToken).balanceOf(address(actor));

        assertLte(procBalanceAfter, procBalanceBefore, "Protected shares balance increased");
        assertLte(collBalanceAfter, collBalanceBefore, "Collateral shares balance increased");
        assertLte(debtBalanceAfter, debtBalanceBefore, "Debt shares balance increased");
    }

    // Property: A user transitioning his collateral cannot receive more shares 
    function transitionCollateral_doesNotResultInMoreShares(uint8 actorIndex, bool vaultZero, uint256 shares, ISilo.AssetType assetType) public {
        Actor actor = _selectActor(actorIndex);
        Silo vault = vaultZero ? vault0 : vault1;

        (address protected, address collateral, ) = siloConfig.getShareTokens(address(vault));
        uint256 procBalanceBefore = IShareToken(protected).balanceOf(address(actor));
        uint256 collBalanceBefore = IShareToken(collateral).balanceOf(address(actor));
        uint256 sumBefore = procBalanceBefore + collBalanceBefore;

        // note: this could result in false positives due to interest calculation, and differences between 
        // protected and unprotected shares/balances. Another way to check this property would be to 
        // transitioCollateral in one direction, and then in the opposite direction, and only check shares/assets
        // after the second transition.
        actor.transitionCollateral(vaultZero, shares, assetType);

        uint256 procBalanceAfter = IShareToken(protected).balanceOf(address(actor));
        uint256 collBalanceAfter = IShareToken(collateral).balanceOf(address(actor)); 
        uint256 sumAfter = procBalanceAfter + collBalanceAfter;
        assertLte(sumAfter, sumBefore, "Gained shares after transitionCollateral");
    }
}
