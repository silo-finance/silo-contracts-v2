// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {EnumerableSet} from "openzeppelin5/utils/structs/EnumerableSet.sol";

import {IVaultIncentivesModule} from "../interfaces/IVaultIncentivesModule.sol";
import {IIncentivesClaimingLogic} from "../interfaces/IIncentivesClaimingLogic.sol";
import {IIncentivesDistributionSolution} from "../interfaces/IIncentivesDistributionSolution.sol";

/// @title Vault Incentives Module
contract VaultIncentivesModule is IVaultIncentivesModule, Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant INCENTIVES_CLAIMING_LOGIC_PING = keccak256(abi.encode("IncentivesClaimingLogic"));

    EnumerableSet.AddressSet private _markets;
    EnumerableSet.AddressSet private _solutions;

    mapping(address market => address logic) public marketToLogic;

    constructor() Ownable(msg.sender) {}

    /// @inheritdoc IVaultIncentivesModule
    function addIncentivesClaimingLogic(IIncentivesClaimingLogic _logic, address _market) external onlyOwner {
        require(address(_logic) != address(0), AddressZero());
        require(marketToLogic[_market] == address(0), LogicAlreadyAdded());
        require(_logicPassesPing(_logic), FailedToPing());

        _markets.add(_market);
        marketToLogic[_market] = address(_logic);

        emit IncentivesClaimingLogicAdded(_market, address(_logic));
    }

    /// @inheritdoc IVaultIncentivesModule
    function updateIncentivesClaimingLogic(IIncentivesClaimingLogic _logic, address _market) external onlyOwner {
        require(address(_logic) != address(0), AddressZero());
        require(marketToLogic[_market] != address(0), MarketNotConfigured());
        require(_logicPassesPing(_logic), FailedToPing());

        marketToLogic[_market] = address(_logic);

        emit IncentivesClaimingLogicUpdated(_market, address(_logic));
    }

    /// @inheritdoc IVaultIncentivesModule
    function removeIncentivesClaimingLogic(address _market) external onlyOwner {
        require(marketToLogic[_market] != address(0), LogicNotFound());

        _markets.remove(_market);
        delete marketToLogic[_market];

        emit IncentivesClaimingLogicRemoved(_market);
    }

    /// @inheritdoc IVaultIncentivesModule
    function addIncentivesDistributionSolution(IIncentivesDistributionSolution _solution) external onlyOwner {
        require(address(_solution) != address(0), AddressZero());
        require(_solutions.add(address(_solution)), SolutionAlreadyAdded());

        emit IncentivesDistributionSolutionAdded(address(_solution));
    }

    /// @inheritdoc IVaultIncentivesModule
    function removeIncentivesDistributionSolution(IIncentivesDistributionSolution _solution) external onlyOwner {
        require(_solutions.remove(address(_solution)), SolutionNotFound());

        emit IncentivesDistributionSolutionRemoved(address(_solution));
    }

    /// @inheritdoc IVaultIncentivesModule
    function getIncentivesClaimingLogics() external view returns (address[] memory logics) {
        address[] memory markets = _markets.values();

        logics = _getIncentivesClaimingLogics(markets);
    }

    /// @inheritdoc IVaultIncentivesModule
    function getIncentivesClaimingLogics(address[] memory _marketsInput)
        external
        view
        returns (address[] memory logics)
    {
        logics = _getIncentivesClaimingLogics(_marketsInput);
    }

    /// @inheritdoc IVaultIncentivesModule
    function getIncentivesDistributionSolutions() external view returns (address[] memory solutions) {
        solutions = _solutions.values();
    }

    /// @dev Internal function to get the incentives claiming logics for a given market.
    /// @param _marketsInput The markets to get the incentives claiming logics for.
    /// @return logics The incentives claiming logics.
    function _getIncentivesClaimingLogics(address[] memory _marketsInput)
        internal
        view
        returns (address[] memory logics)
    {
        logics = new address[](_marketsInput.length);

        for (uint256 i = 0; i < _marketsInput.length; i++) {
            logics[i] = marketToLogic[_marketsInput[i]];
        }
    }

    /// @dev Internal function to check if the logic passes the ping.
    /// @param _logic The logic to check.
    /// @return passedPing The result of the ping.
    function _logicPassesPing(IIncentivesClaimingLogic _logic) internal view returns (bool passedPing) {
        bytes memory payload = abi.encodeWithSelector(IIncentivesClaimingLogic.incentivesClaimingLogicPing.selector);
        (bool success, bytes memory result) = address(_logic).staticcall(payload);

        passedPing = success && result.length == 32 && abi.decode(result, (bytes32)) == INCENTIVES_CLAIMING_LOGIC_PING;
    }
}
