// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

library VeSiloContracts {
    // smart contracts list
    string public constant VOTING_ESCROW = "VotingEscrow.vy";
    string public constant VE_BOOST = "VeBoostV2.vy";
    string public constant TIMELOCK_CONTROLLER = "TimelockController.sol";
    string public constant SILO_GOVERNOR = "SiloGovernor.sol";
    string public constant GAUGE_CONTROLLER = "GaugeController.vy";
    string public constant SILO_LIQUIDITY_GAUGE = "SiloLiquidityGauge.vy";
    string public constant LIQUIDITY_GAUGE_FACTORY = "LiquidityGaugeFactory.sol";
    string public constant MAINNET_BALANCER_MINTER = "MainnetBalancerMinter.sol";
    string public constant BALANCER_TOKEN_ADMIN = "BalancerTokenAdmin.sol";
    string public constant VOTING_ESCROW_REMAPPER = "VotingEscrowRemapper.sol";
    string public constant CHILD_CHAIN_GAUGE = "ChildChainGauge.vy";
    string public constant CHILD_CHAIN_GAUGE_FACTORY = "ChildChainGaugeFactory.sol";
    string public constant L2_BALANCER_PSEUDO_MINTER = "L2BalancerPseudoMinter.sol";
    string public constant VOTING_ESCROW_DELEGATION_PROXY = "VotingEscrowDelegationProxy.sol";
    string public constant NULL_VOTING_ESCROW = "NullVotingEscrow.sol";
    string public constant FEE_DISTRIBUTOR = "FeeDistributor.sol";
    string public constant FEE_SWAPPER = "FeeSwapper.sol";
    string public constant GAUGE_ADDER = "GaugeAdder.sol";
    string public constant CCIP_GAUGE_CHECKPOINTER = "CCIPGaugeCheckpointer.sol";
    string public constant STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR = "StakelessGaugeCheckpointerAdaptor.sol";
    string public constant UNISWAP_SWAPPER = "UniswapSwapper.sol";
    string public constant VE_SILO_DELEGATOR_VIA_CCIP = "VeSiloDelegatorViaCCIP.sol";
    string public constant VOTING_ESCROW_CCIP_REMAPPER = "VotingEscrowCCIPRemapper.sol";
    string public constant VOTING_ESCROW_CHILD_CHAIN = "VotingEscrowChildChain.sol";
    string public constant SMART_WALLET_CHECKER = "SmartWalletChecker.sol";
}
