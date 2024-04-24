// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {ClonesUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import {SiloERC4626Lib, SiloMathLib} from "silo-core/contracts/lib/SiloERC4626Lib.sol";
import {Hook} from "silo-core/contracts/lib/Hook.sol";
import {ShareDebtToken, IShareToken} from "silo-core/contracts/utils/ShareDebtToken.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IHookReceiver} from "silo-core/contracts/utils/hook-receivers/interfaces/IHookReceiver.sol";

import {HookReceiverMock} from "../_mocks/HookReceiverMock.sol";
import {SiloMock} from "../_mocks/SiloMock.sol";
import {SiloConfigMock} from "../_mocks/SiloConfigMock.sol";

contract Token {
    uint8 public immutable decimals;

    constructor(uint8 _decimals) {
        decimals = _decimals;
    }
}

/*
forge test -vv --mc ShareTokenTest
*/
contract ShareTokenTest is Test {
    ShareDebtToken sToken;
    SiloMock silo;
    SiloConfigMock siloConfig;
    HookReceiverMock hookReceiver;
    address owner;

    function setUp() public {
        sToken = ShareDebtToken(ClonesUpgradeable.clone(address(new ShareDebtToken())));
        silo = new SiloMock(address(0));
        siloConfig = new SiloConfigMock(address(0));
        hookReceiver = new HookReceiverMock(makeAddr("HookReceiver"));
        owner = makeAddr("Owner");
    }

    function config() external view returns (address) {
        return siloConfig.ADDRESS();
    }

    /*
    forge test -vv --mt test_ShareToken_decimals
    */
    function test_ShareToken_decimals() public {
        uint8 decimals = 8;
        Token token = new Token(decimals);

        ISiloConfig.ConfigData memory configData;
        configData.token = address(token);

        silo.configMock(siloConfig.ADDRESS());
        siloConfig.getConfigMock(silo.ADDRESS(), configData);

        sToken.initialize(ISilo(silo.ADDRESS()));

        assertEq(10 ** (sToken.decimals() - token.decimals()), SiloMathLib._DECIMALS_OFFSET_POW, "expect valid offset");
    }

    /*
    forge test -vv --mt test_HookReturnCode_notRevertWhenNoHook
    */
    function test_HookReturnCode_notRevertWhenNoHook() public {
        sToken.initialize(ISilo(address(this)));
        sToken.mint(owner, owner, 1);
    }

    /*
    forge test -vv --mt test_HookReturnCode_notRevertWhenHookCallFail
    */
    function test_HookReturnCode_notRevertWhenHookCallFail() public {
        sToken.initialize(ISilo(address(this)));
        sToken.mint(owner, owner, 1); // no mocking for hook call
    }

    /*
    forge test -vv --mt test_HookReturnCode_notRevertOnCode0
    */
    function test_HookReturnCode_notRevertOnCode0() public {
        sToken.initialize(ISilo(address(this)));
        uint256 amount = 1;

        _afterTokenTransferMockOnMint(amount, Hook.RETURN_CODE_SUCCESS);

        sToken.mint(owner, owner, amount);
    }

    /*
    forge test -vv --mt test_HookReturnCode_revertOnRequest
    TODO
    */
//    function test_HookReturnCode_revertOnRequest() public {
//        sToken.initialize(ISilo(address(this)));
//        uint256 amount = 1;
//
//        _afterTokenTransferMockOnMint(amount, Hook.RETURN_CODE_REQUEST_TO_REVERT_TX);
//
//        vm.expectRevert(IHookReceiver.RevertRequestFromHook.selector);
//        sToken.mint(owner, owner, amount);
//    }

    function _afterTokenTransferMockOnMint(uint256 _amount, uint256 _hookReturnCode) public {
        uint256 balance = sToken.balanceOf(owner);

        hookReceiver.afterTokenTransferMock(
            address(0), // zero address for mint
            0, // initial total supply 0
            owner,
            balance + _amount, // owner balance after
            sToken.totalSupply() + _amount, // total supply after mint
            _amount,
            _hookReturnCode
        );
    }
}
