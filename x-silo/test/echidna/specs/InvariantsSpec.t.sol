// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title InvariantsSpec
/// @notice Invariants specification for the protocol
/// @dev Contains pseudo code and description for the invariant properties in the protocol
abstract contract InvariantsSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - INVARIANTS (INV): 
    ///   - Properties that should always hold true in the system. 
    ///   - Implemented in the /invariants folder.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          BASE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice related to silo property UT_Silo_accrueInterest
    string constant BASE_INVARIANT_A = "BASE_INVARIANT_A: silo.totalAssets == 0 <=> silo.totalSupply == 0";

    /// @notice related to silo property UT_Silo_accrueInterest
    string constant BASE_INVARIANT_B =
        "BASE_INVARIANT_B: debtShareToken.totalSupply == 0 <=> silo.totalAssets[debt] == 0";

    /// @notice related to silo property VS_Silo_interestRateTimestamp_daoAndDeployerFees
    string constant BASE_INVARIANT_C =
        "BASE_INVARIANT_C: siloData.interestRateTimestamp == 0 => siloData.daoAndDeployerFees == 0";

    /// @notice related to silo property VS_Silo_debtShareToken_balance_notZero
    string constant BASE_INVARIANT_D =
        "BASE_INVARIANT_D: user is solvent and shareDebtToken.balanceOf(user) != zero => protectedShareToken.balanceOf(user) + collateralShareToken.balanceOf(user) != 0";

    /// @notice related to silo property VS_Silo_balance_totalAssets
    string constant BASE_INVARIANT_E = "BASE_INVARIANT_E: balanceOf(silo) >= silo.totalAssets[Protected]";

    /// @notice related to silo property VS_silo_getLiquidity_less_equal_balance
    string constant BASE_INVARIANT_F =
        "BASE_INVARIANT_F: silo.getLiquidity() <= balanceOf(silo) - silo.totalAssets[Protected] - daoAndDeployerRevenue";

    string constant BASE_INVARIANT_H = "BASE_INVARIANT_H:  reentrancyGuardEntered == false";

    string constant BASE_INVARIANT_I =
        "BASE_INVARIANT_I: _collateralShareToken totalSupply MUST be the sum of all deposited shares)"; // TODO

    string constant BASE_INVARIANT_J = "BASE_INVARIANT_J: fractions reminder should always be < _PRECISION_DECIMALS";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SILO MARKET                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant SILO_INVARIANT_A = "SILO_INVARIANT_A: accrueInterest should never revert";

    string constant SILO_INVARIANT_B = "SILO_INVARIANT_B: getCollateralAmountsWithInterest >= _collateralAssets"; // TODO

    string constant SILO_INVARIANT_C = "SILO_INVARIANT_C: debtAssetsWithInterest >= _debtAssets"; // TODO

    string constant SILO_INVARIANT_D =
        "SILO_INVARIANT_D: collateralConfig.silo is equal borrowerCollateralSilo[_depositOwner] if there is debt";

    string constant SILO_INVARIANT_E =
        "SILO_INVARIANT_E: if debtConfig.silo is not zero then collateralConfig.silo is not zero";

    string constant SILO_INVARIANT_F =
        "SILO_INVARIANT_F: if no debt, both configs (collateralConfig, debtConfig) are zero";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          STREAM                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant SET_EMISSION_TIME =
        "SET_EMISSION_TIME: setting emission always sets `lastUpdateTimestamp`";


    string constant LENDING_INVARIANT_C = "LENDING_INVARIANT_C: If user has no debt and liquidity > 1, maxRedeem() output equals shareToken.balanceOf(user)";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        BORROWING                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant BORROWING_INVARIANT_A = "BORROWING_INVARIANT_A: debtAssets >= any userDebtAssets";

    string constant BORROWING_INVARIANT_B = "BORROWING_INVARIANT_B: totalBorrowed = sum of all userDebtAssets";

    string constant BORROWING_INVARIANT_C =
        "BORROWING_INVARIANT_C: sum of all userDebtAssets == 0 <=> totalBorrowed == 0"; // Included in the previous invariant

    string constant BORROWING_INVARIANT_D =
        "BORROWING_INVARIANT_D: If user has debt in one silo, his share token balance on the borrowing silo should be != 0";

    string constant BORROWING_INVARIANT_E =
        "BORROWING_INVARIANT_E: A user cannot have debt in two silos at the same moment";

    string constant BORROWING_INVARIANT_F = "BORROWING_INVARIANT_F: totalShares != 0 => totalAssets > 0";

    string constant BORROWING_INVARIANT_G =
        "BORROWING_INVARIANT_G: if user has no debt, should always be solvent and ltv == 0";

    string constant BORROWING_INVARIANT_H =
        "BORROWING_INVARIANT_H: result of maxRedeem() should never be more than collateral share token balanceOf user";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                    SILO  ERC4626 INVARIANTS                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice ASSETS

    string constant MAX_WITHDRAW_NEVER_REVERTS =
    "MAX_WITHDRAW_NEVER_REVERTS: maxWithdraw() used as input to withdraw() should never revert";

    string constant MAX_WITHDRAW_AS_INPUT =
    "MAX_WITHDRAW_AS_INPUT: Result of maxWithdraw() used as input to withdraw() should never revert";

    string constant ERC4626_ASSETS_INVARIANT_A = "ERC4626_ASSETS_INVARIANT_A: asset MUST NOT revert";

    string constant ERC4626_ASSETS_INVARIANT_B = "ERC4626_ASSETS_INVARIANT_B: totalAssets MUST NOT revert";

    string constant ERC4626_ASSETS_INVARIANT_C =
        "ERC4626_ASSETS_INVARIANT_C: convertToShares MUST NOT show any variations depending on the caller";

    string constant ERC4626_ASSETS_INVARIANT_D =
        "ERC4626_ASSETS_INVARIANT_D: convertToAssets MUST NOT show any variations depending on the caller";

    /// @notice DEPOSIT

    string constant ERC4626_DEPOSIT_INVARIANT_A = "ERC4626_DEPOSIT_INVARIANT_A: maxDeposit MUST NOT revert";

    string constant ERC4626_DEPOSIT_INVARIANT_B =
        "ERC4626_DEPOSIT_INVARIANT_B: previewDeposit MUST return close to and no more than shares minted at deposit if called in the same transaction";

    /// @notice MINT

    string constant ERC4626_MINT_INVARIANT_A = "ERC4626_MINT_INVARIANT_A: maxMint MUST NOT revert";

    string constant ERC4626_MINT_INVARIANT_B =
        "ERC4626_MINT_INVARIANT_B: previewMint MUST return close to and no fewer than assets deposited at mint if called in the same transaction";

    /// @notice WITHDRAW

    string constant ERC4626_WITHDRAW_INVARIANT_A = "ERC4626_WITHDRAW_INVARIANT_A: maxWithdraw MUST NOT revert";

    string constant ERC4626_WITHDRAW_INVARIANT_B =
        "ERC4626_WITHDRAW_INVARIANT_B: previewWithdraw MUST return close to and no fewer than shares burned at withdraw if called in the same transaction";

    /// @notice REDEEM

    string constant ERC4626_REDEEM_INVARIANT_A = "ERC4626_REDEEM_INVARIANT_A: maxRedeem MUST NOT revert";

    string constant ERC4626_REDEEM_INVARIANT_B =
        "ERC4626_REDEEM_INVARIANT_B: previewRedeem MUST return close to and no more than assets redeemed at redeem if called in the same transaction";

    /// @notice ROUNDTRIP

    string constant ERC4626_ROUNDTRIP_INVARIANT_A = "ERC4626_ROUNDTRIP_INVARIANT_A: redeem(deposit(a)) <= a";

    string constant ERC4626_ROUNDTRIP_INVARIANT_B =
        "ERC4626_ROUNDTRIP_INVARIANT_B: s = deposit(a) s' = withdraw(a) s' >= s";

    string constant ERC4626_ROUNDTRIP_INVARIANT_C = "ERC4626_ROUNDTRIP_INVARIANT_C: deposit(redeem(s)) <= s";

    string constant ERC4626_ROUNDTRIP_INVARIANT_D = "ERC4626_ROUNDTRIP_INVARIANT_D: a = redeem(s) a' = mint(s) a' >= a";

    string constant ERC4626_ROUNDTRIP_INVARIANT_E = "ERC4626_ROUNDTRIP_INVARIANT_E: withdraw(mint(s)) >= s";

    string constant ERC4626_ROUNDTRIP_INVARIANT_F = "ERC4626_ROUNDTRIP_INVARIANT_F: a = mint(s) a' = redeem(s) a' <= a";

    string constant ERC4626_ROUNDTRIP_INVARIANT_G = "ERC4626_ROUNDTRIP_INVARIANT_G: mint(withdraw(a)) >= a";

    string constant ERC4626_ROUNDTRIP_INVARIANT_H =
        "ERC4626_ROUNDTRIP_INVARIANT_H: s = withdraw(a) s' = deposit(a) s' <= s";

    /// @notice ADDITIVE

    string constant ERC4626_ROUNDTRIP_INVARIANT_I =
        "ERC4626_ROUNDTRIP_INVARIANT_I: deposit(x + y) should be the same as deposit(x) + deposit(y)"; // TODO

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          SILO ROUTER                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant ROUTER_INVARIANT_A =
        "ROUTER_INVARIANT_A: Router ETH balance should always be 0 after function execution"; // TODO
}
