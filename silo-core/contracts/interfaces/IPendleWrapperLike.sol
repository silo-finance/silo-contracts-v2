// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IPendleWrapperLike {
    function wrap(address _receiver, uint256 _netLpIn) external;
    function unwrap(address _receiver, uint256 _netWrapIn) external;
    function LP() external view returns (address);
}
