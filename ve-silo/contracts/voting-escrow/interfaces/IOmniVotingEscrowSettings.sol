// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

interface IOmniVotingEscrowSettings {
    function setTrustedRemoteAddress(uint16 _remoteChainId, bytes calldata _remoteAddress) external;
}
