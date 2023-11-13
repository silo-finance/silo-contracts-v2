pragma solidity ^0.8.0;

import {DSTest} from "forge-std/Test.sol";
import {Strings} from "openzeppelin-contracts/utils/Strings.sol";

contract Assertions is DSTest {
  using Strings for uint256;

  /// @param a tested value
  /// @param b expected value
  /// @param percent how close tested value must be to expected value in % (1e18 == 100%)
  /// @param err message
  function assertRelativeCloseTo(uint256 a, uint256 b, uint256 percent, string memory err) public {
    uint256 hundredPercent = 1e18;
    uint256 diff = a < b ? b - a : a - b;

    uint256 relativeDiff = diff * hundredPercent / b;

    if (relativeDiff > percent) {
      emit log(string.concat("expect ", a.toString(), " to be close to ", b.toString()));
      emit log(string.concat("difference ", diff.toString()));
    }

    assertLe(relativeDiff, percent, err);
  }
}
