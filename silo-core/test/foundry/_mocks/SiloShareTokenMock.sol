// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {ERC20Mock} from "openzeppelin5/mocks/token/ERC20Mock.sol";

contract SiloShareTokenMock is ERC20Mock {
    function mint(address _to, address, uint256 _amount) public {
        _mint(_to, _amount);
    }
}
