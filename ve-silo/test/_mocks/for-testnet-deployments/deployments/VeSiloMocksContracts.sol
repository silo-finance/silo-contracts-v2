// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6 <0.9.0;

import {VeSiloMocksContracts} from "./VeSiloMocksContracts.sol";

library VeSiloMocksContracts {
    string public constant CCIP_GAUGE_FACTORY_ANY_CHAIN = "CCIPGaugeFactoryAnyChain.sol";
    string public constant CCIP_GAUGE_WITH_MOCKS = "CCIPGaugeWithMocks.sol";
    string public constant CCIP_ROUTER_CLIENT_LIKE = "CCIPRouterClientLike.sol";
    string public constant CCIP_ROUTER_RECEIVER_LIKE = "CCIPRouterReceiverLike.sol";
    string public constant LINK_TOKEN_LIKE = "LINKTokenLike.sol";
    string public constant SILO_TOKEN_LIKE = "SILOTokenLike.sol";
}
