// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract TokenDecimalsOnlyMock {
    // solhint-disable-next-line immutable-vars-naming
   uint8 public immutable decimals;

   constructor(uint8 _decimals) {
       decimals = _decimals;
   }
}
