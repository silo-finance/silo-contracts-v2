// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {IERC3156FlashLender} from "silo-core/contracts/interfaces/IERC3156FlashLender.sol";

import {ISilo, IERC3156FlashLender} from "silo-core/contracts/interfaces/ISilo.sol";
import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";
import {Silo} from "silo-core/contracts/Silo.sol";
import {Actions} from "silo-core/contracts/lib/Actions.sol";

import {SiloLittleHelper} from "../../_common/SiloLittleHelper.sol";
import {FlashLoanReceiverWithInvalidResponse} from "../../_mocks/FlashLoanReceiverWithInvalidResponse.sol";
import {Gas} from "../../gas/Gas.sol";

bytes32 constant FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

address constant USER = address(0x12345);
address constant BORROWER = address(0xabcde);

contract HackProtected is Test {
    function bytesToUint256(bytes memory input) public pure returns (uint256 output) {
        assembly {
            output := mload(add(input, 32))
        }
    }

    function onFlashLoan(address _initiator, address _token, uint256, uint256, bytes calldata)
        external
        returns (bytes32)
    {
        ISilo silo = ISilo(msg.sender);

        assertEq(IERC20(_token).balanceOf(address(silo)), 1e18, "protected deposit left in silo");

        assertEq(silo.maxWithdraw(address(this)), 1e18, "contract must have assets to withdraw");
        silo.withdraw(1, address(this), address(this));

        assertTrue(false, "withdraw should revert and we should not got here");

        return FLASHLOAN_CALLBACK;
    }
}

/*
    forge test -vv --ffi --mc FlashloanProtectedTest
*/
contract FlashloanProtectedTest is SiloLittleHelper, Test {
    ISiloConfig siloConfig;

    function setUp() public {

        siloConfig = _setUpLocalFixture();

        _deposit(1e18, USER);
        _deposit(1e18, USER, ISilo.CollateralType.Protected);
    }

    /*
    forge test -vv --ffi --mt test_flashLoanProtected
    */
    function test_flashLoanProtected() public {
        HackProtected receiver = new HackProtected();

        _deposit(1e18, address(receiver));

        uint256 maxFlashloan = silo0.maxFlashLoan(address(token0));

        vm.expectRevert(ISilo.ProtectedProtection.selector);
        silo0.flashLoan(IERC3156FlashBorrower(address(receiver)), address(token0), maxFlashloan, "");
    }
}
