// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

interface IPendleMarketV3Like {
    function readTokens() external view returns (address _SY, address _PT, address _YT);
}
