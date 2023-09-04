// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {AddressesCollection} from "silo-foundry-utils/networks/addresses/AddressesCollection.sol";
import {Deployer} from "silo-foundry-utils/deployer/Deployer.sol";

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
    string public constant OMNI_VOTING_ESCROW = "OmniVotingEscrow.sol";
    string public constant OMNI_VOTING_ESCROW_ADAPTER = "OmniVotingEscrowAdaptor.sol";
    string public constant OMNI_VOTING_ESCROW_CHILD = "OmniVotingEscrowChild.sol";
    string public constant VOTING_ESCROW_REMAPPER = "VotingEscrowRemapper.sol";
    string public constant CHILD_CHAIN_GAUGE = "ChildChainGauge.vy";
    string public constant CHILD_CHAIN_GAUGE_FACTORY = "ChildChainGaugeFactory.sol";
    string public constant CHILD_CHAIN_GAUGE_REGISTRY = "ChildChainGaugeRegistry.sol";
    string public constant CHILD_CHAIN_GAUGE_CHECKPOINTER = "ChildChainGaugeCheckpointer.sol";
    string public constant L2_BALANCER_PSEUDO_MINTER = "L2BalancerPseudoMinter.sol";
    string public constant VOTING_ESCROW_DELEGATION_PROXY = "VotingEscrowDelegationProxy.sol";
    string public constant L2_LAYER_ZERO_BRIDGE_FORWARDER = "L2LayerZeroBridgeForwarder.sol";
    string public constant NULL_VOTING_ESCROW = "NullVotingEscrow.sol";
    string public constant ARBITRUM_ROOT_GAUGE = "ArbitrumRootGauge.sol";
    string public constant ARBITRUM_ROOT_GAUGE_FACTORY = "ArbitrumRootGaugeFactory.sol";
    string public constant FEE_DISTRIBUTOR = "FeeDistributor.sol";
    string public constant FEE_SWAPPER = "FeeSwapper.sol";
    string public constant GAUGE_ADDER = "GaugeAdder.sol";
    string public constant STAKELESS_GAUGE_CHECKPOINTER = "StakelessGaugeCheckpointer.sol";
    string public constant STAKELESS_GAUGE_CHECKPOINTER_ADAPTOR = "StakelessGaugeCheckpointerAdaptor.sol";
    string public constant UNISWAP_SWAPPER = "UniswapSwapper.sol";
}

contract VeSiloAddresses is AddressesCollection {
    string constant public ARBITRUM_GATEWAY_ROUTER = "Arbitrum gateway router";
    string constant public WETH = "WETH";
    string constant public BALANCER_VAULT = "Balancer Vault";
    string constant public UNISWAP_ROUTER = "Uniswap router";
    string constant public SNX = "Token(SNX)";
    string constant public USDC = "Token(USDC)";
    string constant public SNX_USDC_UNIV3_POOL = "SNX/USDC UniswapV3 pool";
    string constant public USDC_ETH_UNI_POOL = "USDC/ETH Uniswap pool";

    constructor() {
        _ethereumAddresses();
    }

    function _ethereumAddresses() internal {
        uint256 chainId = getChain(MAINNET_ALIAS).chainId;
        setAddress(chainId, ARBITRUM_GATEWAY_ROUTER, 0xC840838Bc438d73C16c2f8b22D2Ce3669963cD48);
        setAddress(chainId, WETH, 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        setAddress(chainId, BALANCER_VAULT, 0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        setAddress(chainId, UNISWAP_ROUTER, 0xE592427A0AEce92De3Edee1F18E0157C05861564);
        setAddress(chainId, SNX, 0xC011a73ee8576Fb46F5E1c5751cA3B9Fe0af2a6F);
        setAddress(chainId, USDC, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        setAddress(chainId, SNX_USDC_UNIV3_POOL, 0x020C349A0541D76C16F501Abc6B2E9c98AdAe892);
        setAddress(chainId, USDC_ETH_UNI_POOL, 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);
    }
}

contract CommonDeploy is Deployer, VeSiloAddresses {
    // Common variables
    string internal constant _FORGE_OUT_DIR = "cache/foundry/out/ve-silo";
    string internal constant _DEPLOYMENTS_SUB_DIR = "ve-silo";

    error UnsopportedNetworkForDeploy(string networkAlias);

    function _forgeOutDir() internal pure override virtual returns (string memory) {
        return _FORGE_OUT_DIR;
    }

    function _deploymentsSubDir() internal pure override virtual returns (string memory) {
        return _DEPLOYMENTS_SUB_DIR;
    }
}
