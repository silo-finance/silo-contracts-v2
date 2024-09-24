// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {RevertBytes} from "silo-core/contracts/lib/RevertBytes.sol";

/**
    forge test -vv --mc ReverBytestLibTest
 */
contract ReverBytestLibTest is Test {
    uint256 constant A = 1;
    uint256 constant B = 2;

    string constant public CUSTOM_ERR = "custom error message";

    bytes public errMsg;

    error CustomError1(uint256 a, uint256 b);

    function setUp() public {
        errMsg = abi.encodeWithSelector(CustomError1.selector, A, B);
    }

    /**
        forge test -vv --mt test_RevertBytes_errorMsgRevert
    */
    function test_RevertBytes_errorMsgRevert() public {
        vm.expectRevert(abi.encodeWithSelector(CustomError1.selector, A, B));
        RevertBytes.revertBytes(errMsg, CUSTOM_ERR);
    }

    /**
        forge test -vv --mt test_RevertBytes_customErrorRevert
    */
    function test_RevertBytes_customErrorRevert() public {
        bytes memory emptyErrMsg;

        vm.expectRevert(bytes(CUSTOM_ERR));
        RevertBytes.revertBytes(emptyErrMsg, CUSTOM_ERR);
    }
}
