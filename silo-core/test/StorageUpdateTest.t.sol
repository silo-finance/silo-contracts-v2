// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

interface ISomeSilo {
    function accrueInterest() external;
}

contract ConfigContract {
    function callContract(ISomeSilo _contractToCall) external {
        _contractToCall.accrueInterest();
    }
}

/*
    forge test -vv --ffi --mc StorageUpdateTest

    this test is to test obvious, that storage accessed by pointer can return modified value
*/
contract StorageUpdateTest is ISomeSilo, Test {
    uint256 constant internal _INDEX = 1;

    mapping (uint256 => ISilo.Assets) internal _total;
    ConfigContract internal _config;

    function setUp() external {
        _config = new ConfigContract();
    }

    // this is
    function accrueInterest() external {
        _total[_INDEX].assets++;
    }

    /*
    forge test -vv --ffi --mt test_workingWithStoragePointers
    */
    function test_workingWithStoragePointers() public {
        ISilo.Assets storage pointer = _total[_INDEX];

        uint256 valueBefore = pointer.assets;

        // eg. from silo, we are calling SiloConfig and it will accrue interest that changes _totals
        _config.callContract(this);

        assertTrue(valueBefore != pointer.assets, "storage changed by config and we have latest value");
    }

    /*
    forge test -vv --ffi --mt test_keccak
    */
    function test_keccak() public {
        emit log_named_bytes32("keccak256", keccak256(abi.encode(uint256(keccak256("silo.storage.ShareToken")) - 1)) & ~bytes32(uint256(0xff)));
    }
}
