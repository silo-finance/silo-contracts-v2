// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title ERC4626PropertiesSpec
/// @notice Properties specification for the protocol
/// @dev Contains pseudo code and description for the invariant properties in the protocol
abstract contract ERC4626PropertiesSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// The properties listed below are a set of rules which check that the system is compliant 
    // with the ERC4626 standard. These properties are used to ensure that the system is working.

    /// Implemented across the testing suite as invariants, postconditions and specific custom handlers.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ASSET                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// ERC4626Invariants.sol
    string constant ERC4626_ASSETS_INVARIANT_A = "ERC4626_ASSETS_INVARIANT_A: asset MUST NOT revert";

    /// ERC4626Invariants.sol
    string constant ERC4626_ASSETS_INVARIANT_B = "ERC4626_ASSETS_INVARIANT_B: totalAssets MUST NOT revert";

    /// ERC4626Invariants.sol
    string constant ERC4626_ASSETS_INVARIANT_C =
        "ERC4626_ASSETS_INVARIANT_C: convertToShares MUST NOT show any variations depending on the caller";

    /// ERC4626Invariants.sol
    string constant ERC4626_ASSETS_INVARIANT_D =
        "ERC4626_ASSETS_INVARIANT_D: convertToAssets MUST NOT show any variations depending on the caller";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         DEPOSIT                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// ERC4626Invariants.sol
    string constant ERC4626_DEPOSIT_INVARIANT_A = "ERC4626_DEPOSIT_INVARIANT_A: maxDeposit MUST NOT revert";

    /// ERC4626Handler.sol
    string constant ERC4626_DEPOSIT_INVARIANT_B =
        "ERC4626_DEPOSIT_INVARIANT_B: previewDeposit MUST return close to and no more than shares minted at deposit if called in the same transaction";

    // ERC4626Handler.sol
    string constant ERC4626_DEPOSIT_INVARIANT_C =
        "ERC4626_DEPOSIT_INVARIANT_C: maxDeposit MUST return the maximum amount of assets deposit would allow to be deposited for receiver and not cause a revert";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           MINT                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// ERC4626Invariants.sol
    string constant ERC4626_MINT_INVARIANT_A = "ERC4626_MINT_INVARIANT_A: maxMint MUST NOT revert";

    /// ERC4626Handler.sol
    string constant ERC4626_MINT_INVARIANT_B =
        "ERC4626_MINT_INVARIANT_B: previewMint MUST return close to and no fewer than assets deposited at mint if called in the same transaction";

    /// ERC4626Handler.sol
    string constant ERC4626_MINT_INVARIANT_C =
        "ERC4626_MINT_INVARIANT_C: maxMint MUST return the maximum amount of shares mint would allow to be deposited to receiver and not cause a revert";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         WITHDRAW                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// ERC4626Invariants.sol
    string constant ERC4626_WITHDRAW_INVARIANT_A = "ERC4626_WITHDRAW_INVARIANT_A: maxWithdraw MUST NOT revert";

    /// ERC4626Handler.sol
    string constant ERC4626_WITHDRAW_INVARIANT_B =
        "ERC4626_WITHDRAW_INVARIANT_B: previewWithdraw MUST return close to and no fewer than shares burned at withdraw if called in the same transaction";

    /// ERC4626Handler.sol
    string constant ERC4626_WITHDRAW_INVARIANT_C =
        "ERC4626_WITHDRAW_INVARIANT_C: maxWithdraw MUST return the maximum amount of assets that could be transferred from owner through withdraw and not cause a revert";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           REDEEM                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// ERC4626Invariants.sol
    string constant ERC4626_REDEEM_INVARIANT_A = "ERC4626_REDEEM_INVARIANT_A: maxRedeem MUST NOT revert";

    /// ERC4626Handler.sol
    string constant ERC4626_REDEEM_INVARIANT_B =
        "ERC4626_REDEEM_INVARIANT_B: previewRedeem MUST return close to and no more than assets redeemed at redeem if called in the same transaction";

    /// ERC4626Handler.sol
    string constant ERC4626_REDEEM_INVARIANT_C =
        "ERC4626_REDEEM_INVARIANT_C: maxRedeem MUST return the maximum amount of shares that could be transferred from owner through redeem and not cause a revert";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     ROUNDTRIP PROPERTIES                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// ERC4626Handler.sol::ROUNDTRIP PROPERTIES
    string constant ERC4626_ROUNDTRIP_INVARIANT_A = "ERC4626_ROUNDTRIP_INVARIANT_A: redeem(deposit(a)) <= a";

    /// ERC4626Handler.sol::ROUNDTRIP PROPERTIES
    string constant ERC4626_ROUNDTRIP_INVARIANT_B =
        "ERC4626_ROUNDTRIP_INVARIANT_B: s = deposit(a) s' = withdraw(a) s' >= s";

    /// ERC4626Handler.sol::ROUNDTRIP PROPERTIES
    string constant ERC4626_ROUNDTRIP_INVARIANT_C = "ERC4626_ROUNDTRIP_INVARIANT_C: deposit(redeem(s)) <= s";

    /// ERC4626Handler.sol::ROUNDTRIP PROPERTIES
    string constant ERC4626_ROUNDTRIP_INVARIANT_D = "ERC4626_ROUNDTRIP_INVARIANT_D: a = redeem(s) a' = mint(s) a' >= a";

    /// ERC4626Handler.sol::ROUNDTRIP PROPERTIES
    string constant ERC4626_ROUNDTRIP_INVARIANT_E = "ERC4626_ROUNDTRIP_INVARIANT_E: withdraw(mint(s)) >= s";

    /// ERC4626Handler.sol::ROUNDTRIP PROPERTIES
    string constant ERC4626_ROUNDTRIP_INVARIANT_F = "ERC4626_ROUNDTRIP_INVARIANT_F: a = mint(s) a' = redeem(s) a' <= a";

    /// ERC4626Handler.sol::ROUNDTRIP PROPERTIES
    string constant ERC4626_ROUNDTRIP_INVARIANT_G = "ERC4626_ROUNDTRIP_INVARIANT_G: mint(withdraw(a)) >= a";

    /// ERC4626Handler.sol::ROUNDTRIP PROPERTIES
    string constant ERC4626_ROUNDTRIP_INVARIANT_H =
        "ERC4626_ROUNDTRIP_INVARIANT_H: s = withdraw(a) s' = deposit(a) s' <= s";
}
