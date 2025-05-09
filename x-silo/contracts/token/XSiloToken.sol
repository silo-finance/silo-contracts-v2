// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC4626, ERC20, IERC20} from "openzeppelin5/token/ERC20/extensions/ERC4626.sol";
import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";


contract XSiloToken is ERC4626 {

    constructor(address _asset)
        ERC4626(IERC20(_asset))
        ERC20(string.concat('x', TokenHelper.symbol(_asset)), string.concat('x', TokenHelper.symbol(_asset)))
    {
    }
}