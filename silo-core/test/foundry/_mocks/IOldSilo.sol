// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOldSilo {
    function borrow(uint256 _assets, address _receiver, address _borrower, bool _sameAsset)
        external returns (uint256 shares);
}
