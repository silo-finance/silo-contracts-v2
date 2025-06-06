// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {MintableToken} from "../../_common/MintableToken.sol";

contract WETH {
    MintableToken immutable wrapped;

    constructor(MintableToken _wrapped) {
        wrapped = _wrapped;
    }

    function deposit() payable external {
        wrapped.mint(msg.sender, msg.value);
    }
}
