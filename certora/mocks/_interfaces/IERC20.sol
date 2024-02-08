// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IERC20 {
    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);
}
