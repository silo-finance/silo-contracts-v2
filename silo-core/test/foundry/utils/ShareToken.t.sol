// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {SiloMathLib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {ShareDebtToken} from "silo-core/contracts/utils/ShareDebtToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";

import {HookReceiverMock} from "../_mocks/HookReceiverMock.sol";
import {SiloMock} from "../_mocks/SiloMock.sol";
import {MintableToken as Token} from "../_common/MintableToken.sol";
import {SiloConfigMock} from "../_mocks/SiloConfigMock.sol";

// solhint-disable func-name-mixedcase
// FOUNDRY_PROFILE=core-test forge test -vv --mc ShareTokenTest
contract ShareTokenTest is Test {
    uint256 constant internal _DEBT_TOKE_BEFORE_ACTION = 0;
    uint256 constant internal _DEBT_TOKE_AFTER_ACTION = Hook.DEBT_TOKEN | Hook.SHARE_TOKEN_TRANSFER;

    ShareDebtToken public sToken;
    SiloMock public silo;
    SiloConfigMock public siloConfig;
    HookReceiverMock public hookReceiverMock;
    address public owner;

    function setUp() public {
        sToken = ShareDebtToken(Clones.clone(address(new ShareDebtToken())));
        silo = new SiloMock(address(0));
        siloConfig = new SiloConfigMock(address(0));
        hookReceiverMock = new HookReceiverMock(address(0));
        owner = makeAddr("Owner");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt test_ShareToken_decimals
    function test_ShareToken_decimals() public {
        uint8 decimals = 8;
        Token token = new Token(decimals);

        ISiloConfig.ConfigData memory configData;
        configData.token = address(token);

        silo.configMock(siloConfig.ADDRESS());
        siloConfig.getConfigMock(silo.ADDRESS(), configData);

        sToken.initialize(ISilo(silo.ADDRESS()), address(0), uint24(Hook.DEBT_TOKEN));

        // offset for the debt token is 1
        assertEq(sToken.decimals(), token.decimals(), "expect valid decimals");
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt test_notRevertWhenNoHook
    function test_notRevertWhenNoHook() public {
        silo.configMock(siloConfig.ADDRESS());
        sToken.initialize(ISilo(silo.ADDRESS()), address(0), uint24(Hook.DEBT_TOKEN));

        vm.prank(silo.ADDRESS());
        sToken.mint(owner, owner, 1);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt test_hookCall
    function test_hookCall() public {
        address siloAddr = silo.ADDRESS();

        silo.configMock(siloConfig.ADDRESS());
        address hookAddr = hookReceiverMock.ADDRESS();

        sToken.initialize(ISilo(siloAddr), hookAddr, uint24(Hook.DEBT_TOKEN));

        vm.prank(siloAddr);
        sToken.synchronizeHooks(
            uint24(_DEBT_TOKE_BEFORE_ACTION),
            uint24(_DEBT_TOKE_AFTER_ACTION)
        );

        uint256 amount = 1;

        _afterTokenTransferMockOnMint(amount);

        vm.prank(siloAddr);
        sToken.mint(owner, owner, amount);
    }

    // FOUNDRY_PROFILE=core-test forge test -vvv --mt test_descreaseAllowance
    function test_descreaseAllowance() public {
        uint256 allowance = 100e18;
        address recipient = makeAddr("Recipient");
        address siloAddr = silo.ADDRESS();

        silo.configMock(siloConfig.ADDRESS());
        siloConfig.reentrancyGuardEnteredMock(false);
        address hookAddr = hookReceiverMock.ADDRESS();
        sToken.initialize(ISilo(siloAddr), hookAddr, uint24(Hook.DEBT_TOKEN));

        vm.prank(recipient);
        sToken.increaseReceiveAllowance(owner, allowance);

        assertEq(sToken.receiveAllowance(owner, recipient), allowance, "expect valid allowance");

        // decrease in value more than allowed
        vm.prank(recipient);
        sToken.decreaseReceiveAllowance(owner, type(uint256).max);

        assertEq(sToken.receiveAllowance(owner, recipient), 0, "expect have no allowance");
    }

    function _afterTokenTransferMockOnMint(uint256 _amount) internal {
        uint256 balance = sToken.balanceOf(owner);

        hookReceiverMock.afterTokenTransferMock( // solhint-disable-line func-named-parameters
                silo.ADDRESS(),
                _DEBT_TOKE_AFTER_ACTION,
                address(0), // zero address for mint
                0, // initial total supply 0
                owner,
                balance + _amount, // owner balance after
                sToken.totalSupply() + _amount, // total supply after mint
                _amount
        );
    }
}
