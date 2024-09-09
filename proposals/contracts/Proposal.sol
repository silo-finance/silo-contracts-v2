// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {IProposal} from "proposals/contracts/interfaces/IProposal.sol";
import {IProposalEngine} from "proposals/contracts/interfaces/IProposalEngine.sol";
import {ProposalEngineLib} from "./ProposalEngineLib.sol";
import {GaugeAdderProposer} from "./proposers/ve-silo/GaugeAdderProposer.sol";
import {GaugeControllerProposer} from "./proposers/ve-silo/GaugeControllerProposer.sol";
import {CCIPGaugeCheckpointerProposer} from "./proposers/ve-silo/CCIPGaugeCheckpointerProposer.sol";
import {FeeDistributorProposer} from "./proposers/ve-silo/FeeDistributorProposer.sol";
import {SmartWalletCheckerProposer} from "./proposers/ve-silo/SmartWalletCheckerProposer.sol";
import {VeSiloDelegatorViaCCIPProposer} from "./proposers/ve-silo/VeSiloDelegatorViaCCIPProposer.sol";
import {VotingEscrowDelegationProxyProposer} from "./proposers/ve-silo/VotingEscrowDelegationProxyProposer.sol";
import {VotingEscrowCCIPRemapperProposer} from "./proposers/ve-silo/VotingEscrowCCIPRemapperProposer.sol";
import {SiloFactoryProposer} from "./proposers/ve-silo/SiloFactoryProposer.sol";
import {BalancerTokenAdminProposer} from "./proposers/ve-silo/BalancerTokenAdminProposer.sol";
import {LiquidityGaugeFactoryProposer} from "./proposers/ve-silo/LiquidityGaugeFactoryProposer.sol";

import {
    StakelessGaugeCheckpointerAdaptorProposer
} from "./proposers/ve-silo/StakelessGaugeCheckpointerAdaptorProposer.sol";


/// @notice Abstract contract for proposal
/// @dev Any proposal should be derived from this contract
abstract contract Proposal is IProposal {
    /// @notice The proposal engine contract
    IProposalEngine public constant ENGINE = IProposalEngine(ProposalEngineLib._ENGINE_ADDR);

    GaugeAdderProposer public gaugeAdder;
    GaugeControllerProposer public gaugeController;
    CCIPGaugeCheckpointerProposer public ccipGaugeCheckpointer;
    StakelessGaugeCheckpointerAdaptorProposer public stakelessGaugeCheckpointerAdaptor;
    FeeDistributorProposer public feeDistributor;
    SmartWalletCheckerProposer public smartWalletChecker;
    VeSiloDelegatorViaCCIPProposer public veSiloDelegatorViaCCIP;
    VotingEscrowDelegationProxyProposer public votingEscrowDelegationProxy;
    VotingEscrowCCIPRemapperProposer public votingEscrowCCIPRemapper;
    SiloFactoryProposer public siloFactory;
    BalancerTokenAdminProposer public balancerTokenAdmin;
    LiquidityGaugeFactoryProposer public liquidityGaugeFactory;

    /// @notice The id of the proposed proposal
    uint256 private _proposalId;

    constructor() {
        ProposalEngineLib.initializeEngine();
        _initializeProposers();
    }

    /// @inheritdoc IProposal
    function getTargets() external view returns (address[] memory targets) {
        targets = ENGINE.getTargets(address(this));
    }

    /// @inheritdoc IProposal
    function getValues() external view returns (uint256[] memory values) {
        values = ENGINE.getValues(address(this));
    }

    /// @inheritdoc IProposal
    function getCalldatas() external view returns (bytes[] memory calldatas) {
        calldatas = ENGINE.getCalldatas(address(this));
    }

    /// @inheritdoc IProposal
    function getProposalId() external view returns (uint256 proposalId) {
        proposalId = _proposalId;
    }

    /// @inheritdoc IProposal
    function getDescription() external view returns (string memory description) {
        description = ENGINE.getDescription(address(this));
    }

    /// @notice Set the proposer private key in `ENGINE` contract
    /// @dev Designed to be used in tests
    /// @param _voterPK The private key of the proposer
    /// @return proposal The proposal
    function setProposerPK(uint256 _voterPK) public returns (Proposal) {
        ENGINE.setProposerPK(_voterPK);

        return this;
    }

    /// @notice Propose a proposal via `ENGINE` contract
    /// @param _proposalDescription The description of the proposal
    /// @return proposalId The id of the proposed proposal
    function proposeProposal(string memory _proposalDescription) public returns (uint256 proposalId) {
        proposalId = ENGINE.proposeProposal(_proposalDescription);
        _proposalId = proposalId;
    }

    function run() public virtual returns (uint256 propopsalId) {}

    function _initializeProposers() internal virtual {
        initGaugeAdder();
        initGaugeController();
        initCCIPGaugeCheckpointer();
        initStakelessGaugeCheckpointerAdaptor();
        initFeeDistributor();
        initSmartWalletChecker();
        initVeSiloDelegatorViaCCIP();
        initVotingEscrowDelegationProxy();
        initVotingEscrowCCIPRemapper();
        initSiloFactory();
        initBalancerTokenAdmin();
        initLiquidityGaugeFactory();
    }

    function initLiquidityGaugeFactory() public returns (Proposal proposal) {
        liquidityGaugeFactory = new LiquidityGaugeFactoryProposer({_proposal: address(this)});
        proposal = this;
    }
    
    function initGaugeAdder() public returns (Proposal proposal) {
        gaugeAdder = new GaugeAdderProposer({_proposal: address(this)});
        proposal = this;
    }

    function initGaugeController() public returns (Proposal proposal) {
        gaugeController = new GaugeControllerProposer({_proposal: address(this)});
        proposal = this;
    }

    function initCCIPGaugeCheckpointer() public returns (Proposal proposal) {
        ccipGaugeCheckpointer = new CCIPGaugeCheckpointerProposer({_proposal: address(this)});
        proposal = this;
    }

    function initStakelessGaugeCheckpointerAdaptor() public returns (Proposal proposal) {
        stakelessGaugeCheckpointerAdaptor = new StakelessGaugeCheckpointerAdaptorProposer({_proposal: address(this)});
        proposal = this;
    }

    function initFeeDistributor() public returns (Proposal proposal) {
        feeDistributor = new FeeDistributorProposer({_proposal: address(this)});
        proposal = this;
    }

    function initSmartWalletChecker() public returns (Proposal proposal) {
        smartWalletChecker = new SmartWalletCheckerProposer({_proposal: address(this)});
        proposal = this;
    }

    function initVeSiloDelegatorViaCCIP() public returns (Proposal proposal) {
        veSiloDelegatorViaCCIP = new VeSiloDelegatorViaCCIPProposer({_proposal: address(this)});
        proposal = this;
    }

    function initVotingEscrowDelegationProxy() public returns (Proposal proposal) {
        votingEscrowDelegationProxy = new VotingEscrowDelegationProxyProposer({_proposal: address(this)});
        proposal = this;
    }

    function initVotingEscrowCCIPRemapper() public returns (Proposal proposal) {
        votingEscrowCCIPRemapper = new VotingEscrowCCIPRemapperProposer({_proposal: address(this)});
        proposal = this;
    }

    function initSiloFactory() public returns (Proposal proposal) {
        siloFactory = new SiloFactoryProposer({_proposal: address(this)});
        proposal = this;
    }

    function initBalancerTokenAdmin() public returns (Proposal proposal) {
        balancerTokenAdmin = new BalancerTokenAdminProposer({_proposal: address(this)});
        proposal = this;
    }
}
