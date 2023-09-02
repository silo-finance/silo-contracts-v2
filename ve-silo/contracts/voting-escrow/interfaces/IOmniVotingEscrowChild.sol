// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IVeSilo} from "./IVeSilo.sol";
import {IVotingEscrow} from "lz_gauges/interfaces/IVotingEscrow.sol";

interface IOmniVotingEscrowChild {
    function lzReceive(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint64 _nonce,
        bytes calldata _payload
    ) external;

    function balanceOf(address _user) external view returns (uint);
    function totalSupply() external view returns (uint);
    function getPointValue(IVotingEscrow.Point memory _point) external view returns (uint);
    function userPoints(address _user)external view returns (IVotingEscrow.Point memory);
}
