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

pragma solidity 0.8.21;

import {Client} from "chainlink-ccip/v0.8/ccip/libraries/Client.sol";

import {IStakelessGaugeCheckpointerAdaptor}
    from "ve-silo/contracts/gauges/interfaces/IStakelessGaugeCheckpointerAdaptor.sol";
import {IGaugeAdder} from "../interfaces/IGaugeAdder.sol";
import {IGaugeController} from "../interfaces/IGaugeController.sol";
import {ICCIPGauge} from "../interfaces/ICCIPGauge.sol";
import {ICCIPGaugeCheckpointer} from "../interfaces/ICCIPGaugeCheckpointer.sol";

import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {Ownable2Step} from "openzeppelin-contracts/access/Ownable2Step.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {GaugeAdder} from "../gauge-adder/GaugeAdder.sol";

/**
 * @title Stakeless CCIP Gauge Checkpointer
 * @notice Implements ICCIPGaugeCheckpointer; refer to it for API documentation.
 */
contract CCIPGaugeCheckpointer is ICCIPGaugeCheckpointer, ReentrancyGuard, Ownable2Step {
    using EnumerableSet for EnumerableSet.AddressSet;
    
    // solhint-disable var-name-mixedcase
    address public immutable LINK;
    IStakelessGaugeCheckpointerAdaptor public immutable CHECKPOINTER_ADAPTOR;
    IGaugeAdder public immutable GAUGE_ADDER;
    IGaugeController public immutable GAUGE_CONTROLLER;
    // solhint-enable var-name-mixedcase
    mapping(string => EnumerableSet.AddressSet) private _gauges;

    error NotEnougtFundsToPayFees(
        uint256 fees,
        uint256 balance,
        ICCIPGauge.PayFeesIn payFeesIn
    );

    modifier withValidGaugeType(string memory gaugeType) {
        require(GAUGE_ADDER.isValidGaugeType(gaugeType), "Invalid gauge type");
        _;
    }

    constructor(
        IGaugeAdder _gaugeAdder,
        IStakelessGaugeCheckpointerAdaptor _checkpointerAdaptor,
        address _linkToken
    ) {
        GAUGE_ADDER = _gaugeAdder;
        CHECKPOINTER_ADAPTOR = _checkpointerAdaptor;
        GAUGE_CONTROLLER = _gaugeAdder.getGaugeController();
        LINK = _linkToken;
    }

    receive() external payable {
        require(msg.sender == address(CHECKPOINTER_ADAPTOR), "Only checkpoint adaptor");
    }

    function checkpointGaugesAboveRelativeWeight(
        uint256 minRelativeWeight,
        ICCIPGauge.PayFeesIn payFeesIn
    ) external payable override nonReentrant {
        uint256 currentPeriod = _roundDownBlockTimestamp();

        string[] memory gaugeTypes = GAUGE_ADDER.getGaugeTypes();
        for (uint256 i = 0; i < gaugeTypes.length; ++i) {
            _checkpointGauges(gaugeTypes[i], minRelativeWeight, currentPeriod, payFeesIn);
        }

        _returnLeftoverEthIfAny();
    }

    /// @inheritdoc ICCIPGaugeCheckpointer
    function checkpointGaugesOfTypeAboveRelativeWeight(
        string calldata gaugeType,
        uint256 minRelativeWeight,
        ICCIPGauge.PayFeesIn payFeesIn
    )
        external
        payable
        override
        nonReentrant
        withValidGaugeType(gaugeType)
    {
        uint256 currentPeriod = _roundDownBlockTimestamp();

        _checkpointGauges(gaugeType, minRelativeWeight, currentPeriod, payFeesIn);

        _returnLeftoverEthIfAny();
    }

    /// @inheritdoc ICCIPGaugeCheckpointer
    function checkpointSingleGauge(
        string calldata gaugeType,
        ICCIPGauge gauge,
        ICCIPGauge.PayFeesIn payFeesIn
    ) external payable override nonReentrant {
        require(_gauges[gaugeType].contains(address(gauge)), "Gauge was not added to the checkpointer");

        _checkpointGauge(gauge, payFeesIn);

        _returnLeftoverEthIfAny();
    }

    /// @inheritdoc ICCIPGaugeCheckpointer
    function checkpointMultipleGauges(
        string[] calldata gaugeTypes,
        ICCIPGauge[] calldata gauges,
        ICCIPGauge.PayFeesIn payFeesIn
    )
        external
        payable
        override
        nonReentrant
    {
        require(gaugeTypes.length == gauges.length, "Mismatch between gauge types and addresses");
        require(gauges.length > 0, "No gauges to checkpoint");

        uint256 length = gauges.length;
        for (uint256 i = 0; i < length; ++i) {
            require(_gauges[gaugeTypes[i]].contains(address(gauges[i])), "Gauge was not added to the checkpointer");

            _checkpointGauge(gauges[i], payFeesIn);
        }

        _returnLeftoverEthIfAny();
    }

    /// @inheritdoc ICCIPGaugeCheckpointer
    function addGaugesWithVerifiedType(string calldata gaugeType, ICCIPGauge[] calldata gauges)
        external
        override
        withValidGaugeType(gaugeType)
        onlyOwner
    {
        // This is a permissioned call, so we can assume that the gauges' type matches the given one.
        // Therefore, we indicate `_addGauges` not to verify the gauge type.
        _addGauges(gaugeType, gauges, true);
    }

    /// @inheritdoc ICCIPGaugeCheckpointer
    function addGauges(string calldata gaugeType, ICCIPGauge[] calldata gauges)
        external
        override
        withValidGaugeType(gaugeType)
    {
        // Since everyone can call this method, the type needs to be verified in the internal `_addGauges` method.
        _addGauges(gaugeType, gauges, false);
    }

    /// @inheritdoc ICCIPGaugeCheckpointer
    function removeGauges(string calldata gaugeType, ICCIPGauge[] calldata gauges)
        external
        override
        withValidGaugeType(gaugeType)
    {
        EnumerableSet.AddressSet storage gaugesForType = _gauges[gaugeType];

        for (uint256 i = 0; i < gauges.length; i++) {
            // Gauges added must come from a valid factory and exist in the controller, and they can't be removed from
            // them. Therefore, the only required check at this point is whether the gauge was killed.
            ICCIPGauge gauge = gauges[i];
            require(gauge.is_killed(), "Gauge was not killed");
            require(gaugesForType.remove(address(gauge)), "Gauge was not added to the checkpointer");

            emit ICCIPGaugeCheckpointer.GaugeRemoved(gauge, gaugeType, gaugeType);
        }
    }

    /// @inheritdoc ICCIPGaugeCheckpointer
    function hasGauge(string calldata gaugeType, ICCIPGauge gauge)
        external
        view
        override
        withValidGaugeType(gaugeType)
        returns (bool)
    {
        return _gauges[gaugeType].contains(address(gauge));
    }

    /// @inheritdoc ICCIPGaugeCheckpointer
    function getTotalGauges(string calldata gaugeType)
        external
        view
        override
        withValidGaugeType(gaugeType)
        returns (uint256)
    {
        return _gauges[gaugeType].length();
    }

    /// @inheritdoc ICCIPGaugeCheckpointer
    function getGaugeAtIndex(string calldata gaugeType, uint256 index)
        external
        view
        override
        withValidGaugeType(gaugeType)
        returns (ICCIPGauge)
    {
        return ICCIPGauge(_gauges[gaugeType].at(index));
    }

    /// @inheritdoc ICCIPGaugeCheckpointer
    function getRoundedDownBlockTimestamp() external view override returns (uint256) {
        return _roundDownBlockTimestamp();
    }

    /// @inheritdoc ICCIPGaugeCheckpointer
    function getTotalBridgeCost(
        uint256 minRelativeWeight,
        string calldata gaugeType,
        ICCIPGauge.PayFeesIn payFeesIn
    )
        external
        view
        override
        returns (uint256 totalCost)
    {
        uint256 currentPeriod = _roundDownBlockTimestamp();
        uint256 totalGauges = _gauges[gaugeType].length();
        EnumerableSet.AddressSet storage gauges = _gauges[gaugeType];

        for (uint256 i = 0; i < totalGauges; ++i) {
            address gauge = gauges.at(i);
            // Skip gauges that are below the threshold.
            if (GAUGE_CONTROLLER.gauge_relative_weight(gauge, currentPeriod) < minRelativeWeight) {
                continue;
            }

            totalCost += _calculateFees(ICCIPGauge(gauge), payFeesIn);
        }
    }

    /// @inheritdoc ICCIPGaugeCheckpointer
    function getGaugeTypes() external view override returns (string[] memory) {
        return GAUGE_ADDER.getGaugeTypes();
    }

    /// @inheritdoc ICCIPGaugeCheckpointer
    function isValidGaugeType(string calldata gaugeType) external view override returns (bool) {
        return GAUGE_ADDER.isValidGaugeType(gaugeType);
    }

    /// @inheritdoc ICCIPGaugeCheckpointer
    function getSingleBridgeCost(
        string memory gaugeType,
        ICCIPGauge gauge,
        ICCIPGauge.PayFeesIn payFeesIn
    ) public view override returns (uint256 fees) {
        require(_gauges[gaugeType].contains(address(gauge)), "Gauge was not added to the checkpointer");

        fees = _calculateFees(gauge, payFeesIn);
    }

    function _addGauges(
        string memory gaugeType,
        ICCIPGauge[] calldata gauges,
        bool isGaugeTypeVerified
    ) internal {
        EnumerableSet.AddressSet storage gaugesForType = _gauges[gaugeType];

        for (uint256 i = 0; i < gauges.length; i++) {
            ICCIPGauge gauge = gauges[i];
            // Gauges must come from a valid factory to be added to the gauge controller, so gauges that don't pass
            // the valid factory check will be rejected by the controller.
            require(GAUGE_CONTROLLER.gauge_exists(address(gauge)), "Gauge was not added to the GaugeController");
            require(!gauge.is_killed(), "Gauge was killed");
            require(gaugesForType.add(address(gauge)), "Gauge already added to the checkpointer");

            // To ensure that the gauge effectively corresponds to the given type, we query the gauge factory registered
            // in the gauge adder for the gauge type.
            // However, since gauges may come from older factories from previous adders, we need to be able to override
            // this check. This way we can effectively still add older gauges to the checkpointer via authorized calls.
            require(
                isGaugeTypeVerified || GAUGE_ADDER.getFactoryForGaugeType(gaugeType).isGaugeFromFactory(address(gauge)),
                "Gauge does not correspond to the selected type"
            );

            emit ICCIPGaugeCheckpointer.GaugeAdded(gauge, gaugeType, gaugeType);
        }
    }

    /**
     * @dev Performs checkpoints for all gauges of the given type whose relative weight is at least the specified one.
     * @param gaugeType Type of the gauges to checkpoint.
     * @param minRelativeWeight Threshold to filter out gauges below it.
     * @param currentPeriod Current block time rounded down to the start of the previous week.
     * This method doesn't check whether the caller transferred enough ETH to cover the whole operation.
     */
    function _checkpointGauges(
        string memory gaugeType,
        uint256 minRelativeWeight,
        uint256 currentPeriod,
        ICCIPGauge.PayFeesIn payFeesIn
    ) internal {
        EnumerableSet.AddressSet storage typeGauges = _gauges[gaugeType];

        uint256 totalTypeGauges = typeGauges.length();
        if (totalTypeGauges == 0) {
            // Return early if there's no work to be done.
            return;
        }

        for (uint256 i = 0; i < totalTypeGauges; ++i) {
            address gauge = typeGauges.at(i);

            // The gauge might need to be checkpointed in the controller to update its relative weight.
            // Otherwise it might be filtered out mistakenly.
            if (GAUGE_CONTROLLER.time_weight(gauge) < currentPeriod) {
                GAUGE_CONTROLLER.checkpoint_gauge(gauge);
            }

            // Skip gauges that are below the threshold.
            if (GAUGE_CONTROLLER.gauge_relative_weight(gauge, currentPeriod) < minRelativeWeight) {
                continue;
            }

            _checkpointGauge(ICCIPGauge(gauge), payFeesIn);
        }
    }

    function _checkpointGauge(ICCIPGauge _gauge, ICCIPGauge.PayFeesIn _payFeesIn) internal {
        uint256 fees = _calculateFees(_gauge, _payFeesIn);

        if (_payFeesIn == ICCIPGauge.PayFeesIn.Native) {
            uint256 balance = address(this).balance;

            if (balance < fees) revert NotEnougtFundsToPayFees(fees, balance, _payFeesIn);

            CHECKPOINTER_ADAPTOR.checkpoint{ value: msg.value }(address(_gauge));
        } else {
            uint256 allowance = IERC20(LINK).allowance(msg.sender, address(this));

            if (allowance < fees) revert NotEnougtFundsToPayFees(fees, allowance, _payFeesIn);

            // transfer `LINK` directly to the `_gauge`
            IERC20(LINK).transferFrom(msg.sender, address(_gauge), fees);

            CHECKPOINTER_ADAPTOR.checkpoint(address(_gauge));
        }
    }

    /**
     * @dev Send back any leftover ETH to the caller if there is an existing balance in the contract.
     */
    function _returnLeftoverEthIfAny() internal {
        // Most gauge types don't need to send value, and this step can be skipped in those cases.
        uint256 remainingBalance = address(this).balance;
        if (remainingBalance > 0) {
            Address.sendValue(payable(msg.sender), remainingBalance);
        }
    }

    function _calculateFees(ICCIPGauge _gauge, ICCIPGauge.PayFeesIn _payFeesIn) internal view returns (uint256 fees) {
        Client.EVM2AnyMessage memory evm2AnyMessage = _gauge.buildCCIPMessage(type(uint128).max, _payFeesIn);
        fees = _gauge.calculateFee(evm2AnyMessage);
    }

    /**
     * @dev Rounds the provided timestamp down to the beginning of the previous week (Thurs 00:00 UTC) with respect
     * to the current block timestamp.
     */
    function _roundDownBlockTimestamp() internal view returns (uint256) {
        // Division by zero or overflows are impossible here.
        // solhint-disable-next-line not-rely-on-time
        return (block.timestamp / 1 weeks - 1) * 1 weeks;
    }
}
