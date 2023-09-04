// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import {IERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {IFeeSwap} from "./IFeeSwap.sol";

interface IFeeSwapper {
    struct SwapperConfigInput {
        IERC20 asset;
        IFeeSwap swap;
    }

    function swapFeesAndDeposit(address[] memory _assets) external;

    /// @notice Deposit into SILO-80%/WEH-20% Balancer pool
    function joinBalancerPool() external;

    /// @notice Deposit 80%/20% pool LP tokens in the `FeeDistributor`
    /// @param _amount Amount to be deposited into the `FeeDistributor`.
    /// If `uint256` max the current balance of the `FeeSwapper` will be deposited.
    function depositLPTokens(uint256 _amount) external;

    /// @notice Swap all provided assets into WETH
    /// @param _assets A list of the asset to swap
    function swapFees(address[] memory _assets) external;

    /// @notice Configure swappers
    /// @param _inputs Swappers configurations
    function setSwappers(SwapperConfigInput[] memory _inputs) external;
}
