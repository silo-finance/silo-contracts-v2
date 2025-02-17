// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {
    FlowCaps,
    FlowCapsConfig,
    Withdrawal,
    MAX_SETTABLE_FLOW_CAP,
    IPublicAllocatorStaticTyping,
    IPublicAllocatorBase
} from "silo-vaults/contracts/interfaces/IPublicAllocator.sol";

// Contracts
import {Invariants} from "./Invariants.t.sol";
import {Setup} from "./Setup.t.sol";

/*
 * Test suite that converts from  "fuzz tests" to foundry "unit tests"
 * The objective is to go from random values to hardcoded values that can be analyzed more easily
 */
contract CryticToFoundry is Invariants, Setup {
    CryticToFoundry Tester = this;

    modifier setup() override {
        _;
    }

    function setUp() public {
        // Deploy protocol contracts
        _setUp();

        // Deploy actors
        _setUpActors();

        // Initialize handler contracts
        _setUpHandlers();

        // Initialize hook contracts
        _setUpHooks();

        /// @dev fixes the actor to the first user
        actor = actors[USER1];

        vm.warp(101007);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  POSTCONDITIONS REPLAY                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_replay_2redeem() public {
        Tester.submitCap(1, 0);
        _delay(557906);
        _delay(47130);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(196);
        Tester.mintVault(1, 0);
        Tester.deposit(3440, 9, 3);
        Tester.redeem(1178, 0, 3);
    }

    function test_replay_2withdraw() public {
        Tester.mint(314578, 0, 3);
        Tester.submitCap(418, 0);
        _delay(692162);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(16);
        Tester.assert_ERC4626_MINT_INVARIANT_C();
        Tester.withdraw(11, 0, 3);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     INVARIANTS REPLAY                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_replay_echidna_INV_MARKETS() public {
        Tester.submitCap(1, 0);
        echidna_INV_MARKETS();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                               BROKEN POSTCONDITIONS REPLAY                                //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // DONATIONS

    function test_replay_depositVault() public {
        // @audit-issue amounts donated to idleVault skew the exchange rate
        // Drastic change in exchange rate
        Tester.submitCap(1, 3);
        _delay(300400);
        _delay(314034);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(131);
        Tester.depositVault(1, 0);
        Tester.donateUnderlyingToSilo(24244493425189653970967633769294996162695044172722878947969214851, 3); // idle vault assets 24244493425189653970967633769294996162695044172722878947969214851 shares
        Tester.withdrawVault(16362308469563993950950965155643540714247646454230, 0);
        Tester.depositVault(1, 0);
        Tester.redeemVault(1, 0);
    }

    function test_replay_withdrawVault() public {
        // @audit-issue amounts donated to idleVault skew the exchange rate
        // Drastic change in exchange rate after donation
        Tester.submitCap(1, 3);
        _delay(300400);
        _delay(314034);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(131);
        Tester.depositVault(1, 0);
        Tester.donateUnderlyingToSilo(24244493425189653970967633769294996162695044172722878947969214851, 3); // idle vault assets 24244493425189653970967633769294996162695044172722878947969214851 shares
        Tester.withdrawVault(16362308469563993950950965155643540714247646454230, 0);
        Tester.depositVault(1, 0);
    }

    function test_replay_mintVault() public {
        // @audit-issue amounts donated to idleVault skew the exchange rate
        Tester.submitCap(1, 3);
        _delay(623553);
        Tester.acceptCap(3);
        Tester.donateUnderlyingToSilo(1, 3);
        Tester.setSupplyQueue(11);
        Tester.mintVault(1, 0);
    }

    function test_replay_redeemVault() public {
        // @audit-issue amounts donated to idleVault skew the exchange rate
        Tester.submitCap(1, 3);
        _delay(317245);
        _delay(291843);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.depositVault(1, 0);
        Tester.donateUnderlyingToSilo(2, 3);
        Tester.redeemVault(1, 0);
    }

    // ERC4626

    function test_replay_assert_ERC4626_DEPOSIT_INVARIANT_C() public {
        // @audit-issue `if (_shares == 0) revert ErrorsLib.InputZeroShares();` make 0 deposit revert which breaks the ERC4626 rule
        Tester.assert_ERC4626_DEPOSIT_INVARIANT_C();
    }

    function test_replay_assert_ERC4626_MINT_INVARIANT_C() public {
        // @audit-issue `if (_shares == 0) revert ErrorsLib.InputZeroShares();` make 0 deposit revert which breaks the ERC4626 rule
        Tester.assert_ERC4626_MINT_INVARIANT_C();
    }

    function test_replay_assert_ERC4626_ROUNDTRIP_INVARIANT_C() public {
        // @audit-issue deposit(redeem(s)) > s, this breaks ERC4626_ROUNDTRIP_INVARIANT_C
        // Current exmaple: 2 > 1
        Tester.submitCap(2, 3);
        _delay(610502);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.mintVault(1, 0);
        Tester.donateUnderlyingToSilo(1, 3);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_C(1);
    }

    function test_replay_assert_ERC4626_ROUNDTRIP_INVARIANT_H() public {
        // @audit-issue withdraw(a) >= deposit(a), withdraw and deposit the same amount of assets should lead to less minted shares on deposits than shares withdrawn
        // Current example: MintedShares = 432630000, RedeemedShares = 2351250
        Tester.donateUnderlyingToSilo(332, 7);
        Tester.submitCap(194372896, 255);
        _delay(318197);
        Tester.borrow(10820036174637966842933729450133966548961359954547416409062804080542, 0, 0);
        _delay(291190);
        Tester.submitCap(1421118, 0);
        Tester.acceptCap(3);
        _delay(626639);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(27);
        Tester.assert_ERC4626_MINT_INVARIANT_C();
        Tester.donateUnderlyingToSilo(2977, 27);
        Tester.assert_ERC4626_WITHDRAW_INVARIANT_C();
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_C(23882);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_C(33035);
        Tester.mintVault(197, 1);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_H(4370000);
    }

    function test_replay_assert_ERC4626_ROUNDTRIP_INVARIANT_G() public {
        // @audit-issue  mint(withdraw(a)) >= a,
        // Current example: assets required to mint 1, initial assets 2, since 1 < 2 breaks the invariant above
        Tester.submitCap(3882, 3);
        _delay(621798);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.mintVault(1, 0);
        Tester.donateUnderlyingToSilo(1, 3);
        Tester.assert_ERC4626_ROUNDTRIP_INVARIANT_G(2);
    }

    // ACCOUNTING

    function test_replay_2depositVault() public {
        // @audit-issue if underlying vault is open to donations, like in this case IdleVault, the protocol leaks assets since it deposits without receiving shares
        Tester.submitCap(10000000000000000, 3);
        _delay(605468);
        Tester.acceptCap(3);
        Tester.donateUnderlyingToSilo(640888064235293807253551779896804801047568146457797418729975, 3);
        Tester.setSupplyQueue(11);

        console.log("==========");
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        console.log("==========");

        Tester.depositVault(1, 0);

        console.log("==========");
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        console.log("==========");

        Tester.depositVault(1, 0);
    }

    function test_replay_2mintVault() public {
        // @audit-issue if underlying vault is open to donations, like in this case IdleVault, the protocol leaks assets since it deposits without receiving shares
        // Same case than test_replay_2depositVault
        Tester.submitCap(1, 3);
        _delay(626050);
        Tester.donateUnderlyingToSilo(1, 3);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.assert_ERC4626_DEPOSIT_INVARIANT_C();
        Tester.mintVault(1, 0);
    }

    function test_replay_reallocateTo() public {
        // @audit-issue when reallocating, due to rounding and the use of withdraw instead of redeem, assets are lost in the vault without the protocol owning shares for those assets
        // ACCOUNTING BEFORE reallocating:  MARKET 1 (1000 shares, 2 assets), MARKET 2 (0 shares, 0 assets)
        // reallocating 1 asset from MARKET 1 to MARKET 2
        // ACCOUNTING BEFORE reallocating:  MARKET 1 (0 shares, 1 assets lost in the market), MARKET 2 (1000 shares, 1 assets)
        // This is due to SIlos not following the ERC4626 spec fully, convertToShares is meant to round alway down however in Silo's DEPOSIT_TO_ASSETS rounds to ceiling,
        // Metamorpho round down for all shares to assets conversions
        // Assuming silo codebase cannot be changed Silo vault could rely on previewRedeem function instead
        Tester.submitCap(1, 1);
        _delay(611025);
        Tester.submitCap(1, 0);
        Tester.acceptCap(1);
        _delay(624208);
        Tester.acceptCap(0);
        Tester.setSupplyQueue(12);
        Tester.deposit(46106, 0, 3);
        Tester.mintVault(1, 0);
        console.log("============");
        Tester.borrowSameAsset(33988, 0, 3);
        _delay(8657);
        _logWithdrawalQueue();
        Tester.setFlowCaps(
            [
                FlowCaps(8073, 1),
                FlowCaps(12041, 0),
                FlowCaps(133, 0),
                FlowCaps(10762493815665137267589636233636, 20295620084798062581032678405)
            ]
        );

        Tester.reallocateTo(5, [uint128(95170), uint128(371), uint128(5173979839362585723010800758195946)]);
        console.log("defaultVarsBefore.totalAssets: ", defaultVarsBefore.totalAssets);
        console.log("defaultVarsBefore.totalSupply: ", defaultVarsBefore.totalSupply);
        console.log("defaultVarsAfter.totalAssets: ", defaultVarsAfter.totalAssets);
        console.log("defaultVarsAfter.totalSupply: ", defaultVarsAfter.totalSupply);
        _logWithdrawalQueue();
    }

    function test_replay_2withdrawVault() public {
        //@audit-issue Similar case to test_replay_2depositVault, 1 asset is deposited in IdleVault but no shares are minted, however lastTotalAssets accounts 1 asset
        Tester.donateUnderlyingToSilo(1822, 3);
        Tester.submitCap(1, 3);
        _delay(611219);
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.totalSupply(): ", vault.totalSupply());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        Tester.acceptCap(3);
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.totalSupply(): ", vault.totalSupply());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        Tester.setSupplyQueue(11);
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.totalSupply(): ", vault.totalSupply());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        Tester.assert_ERC4626_MINT_INVARIANT_C();
        console.log("vault.totalAssets(): ", vault.totalAssets());
        console.log("vault.totalSupply(): ", vault.totalSupply());
        console.log("vault.lastTotalAssets(): ", vault.lastTotalAssets());
        Tester.withdrawVault(0, 0);
    }

    function test_replay_assert_INV_ACCOUNTING_B() public {// TODO check this property
        Tester.donateUnderlyingToSilo(3456838271434152511590211646958305458300539680628471060073068582, 3);
        Tester.submitCap(1, 3);
        _delay(605654);
        Tester.acceptCap(3);
        Tester.setSupplyQueue(11);
        Tester.assert_ERC4626_MINT_INVARIANT_C();
        Tester.assert_INV_ACCOUNTING_B(1);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                 BROKEN INVARIANTS REPLAY                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        RANDOM TESTS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Fast forward the time and set up an actor,
    /// @dev Use for ECHIDNA call-traces
    function _delay(uint256 _seconds) internal {
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Set up an actor
    function _setUpActor(address _origin) internal {
        actor = actors[_origin];
    }

    /// @notice Set up an actor and fast forward the time
    /// @dev Use for ECHIDNA call-traces
    function _setUpActorAndDelay(address _origin, uint256 _seconds) internal {
        actor = actors[_origin];
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Set up a specific block and actor
    function _setUpBlockAndActor(uint256 _block, address _user) internal {
        vm.roll(_block);
        actor = actors[_user];
    }

    /// @notice Set up a specific timestamp and actor
    function _setUpTimestampAndActor(uint256 _timestamp, address _user) internal {
        vm.warp(_timestamp);
        actor = actors[_user];
    }
}
