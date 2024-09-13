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

pragma solidity 0.8.24;

import {IGaugeAdder, ILiquidityGaugeFactory, IGaugeController} from "../interfaces/IGaugeAdder.sol";

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ReentrancyGuard} from "openzeppelin5/utils/ReentrancyGuard.sol";

// solhint-disable ordering

contract GaugeAdder is IGaugeAdder, Ownable2Step, ReentrancyGuard {
    // This is the gauge type as used in the GaugeController for Ethereum gauges,
    // which we'll use for all gauges of all networks.
    int128 private constant _ETHEREUM_GAUGE_CONTROLLER_TYPE = 0;

    IGaugeController private immutable _gaugeController;

    // Registered gauge types. Append-only.
    string[] private _gaugeTypes;

    // Mapping from gauge type to address of approved factory for that type
    mapping(string => ILiquidityGaugeFactory) private _gaugeTypeFactory;

    constructor(IGaugeController gaugeController) Ownable(msg.sender)
    {
        _gaugeController = gaugeController;
    }

    modifier withValidGaugeType(string memory gaugeType) {
        require(_isValidGaugeType(gaugeType), "Invalid gauge type");
        _;
    }

    /// @inheritdoc IGaugeAdder
    function getGaugeController() external view override returns (IGaugeController) {
        return _gaugeController;
    }

    /// @inheritdoc IGaugeAdder
    function getGaugeTypes() external view override returns (string[] memory) {
        return _gaugeTypes;
    }

    /// @inheritdoc IGaugeAdder
    function getGaugeTypeAtIndex(uint256 index) external view override returns (string memory) {
        return _gaugeTypes[index];
    }

    /// @inheritdoc IGaugeAdder
    function getGaugeTypesCount() external view override returns (uint256) {
        return _gaugeTypes.length;
    }

    /// @inheritdoc IGaugeAdder
    function isValidGaugeType(string memory gaugeType) external view override returns (bool) {
        return _isValidGaugeType(gaugeType);
    }

    /// @inheritdoc IGaugeAdder
    function getFactoryForGaugeType(string memory gaugeType)
        external
        view
        override
        withValidGaugeType(gaugeType)
        returns (ILiquidityGaugeFactory)
    {
        return _gaugeTypeFactory[gaugeType];
    }

    /// @inheritdoc IGaugeAdder
    function isGaugeFromValidFactory(address gauge, string memory gaugeType)
        external
        view
        override
        withValidGaugeType(gaugeType)
        returns (bool)
    {
        return _isGaugeFromValidFactory(gauge, gaugeType);
    }

    // Admin Functions

    /// @inheritdoc IGaugeAdder
    function addGaugeType(string memory gaugeType) external override onlyOwner {
        require(bytes(gaugeType).length > 0, "Gauge type cannot be empty");
        require(!_isValidGaugeType(gaugeType), "Gauge type already added");

        _gaugeTypes.push(gaugeType);

        emit GaugeTypeAdded(gaugeType, gaugeType);
    }

    /// @inheritdoc IGaugeAdder
    function addGauge(address gauge, string memory gaugeType)
        external
        override
        onlyOwner
        withValidGaugeType(gaugeType)
    {
        _addGauge(gauge, gaugeType);
    }

    /// @inheritdoc IGaugeAdder
    function setGaugeFactory(ILiquidityGaugeFactory factory, string memory gaugeType)
        external
        override
        onlyOwner
        withValidGaugeType(gaugeType)
    {
        // Sanity check that calling `isGaugeFromFactory` won't revert
        require(
            (factory == ILiquidityGaugeFactory(address(0))) || (!factory.isGaugeFromFactory(address(0))),
            "Invalid factory implementation"
        );

        _gaugeTypeFactory[gaugeType] = factory;

        emit GaugeFactorySet(gaugeType, gaugeType, factory);
    }

    // Internal functions

    function _isGaugeFromValidFactory(address gauge, string memory gaugeType) internal view returns (bool) {
        ILiquidityGaugeFactory gaugeFactory = _gaugeTypeFactory[gaugeType];
        return gaugeFactory == ILiquidityGaugeFactory(address(0)) ? false : gaugeFactory.isGaugeFromFactory(gauge);
    }

    /**
     * @dev Adds `gauge` to the GaugeController with type `gaugeType` and an initial weight of zero
     */
    function _addGauge(address gauge, string memory gaugeType) private {
        require(_isGaugeFromValidFactory(gauge, gaugeType), "Invalid gauge");

        // `_gaugeController` enforces that duplicate gauges may not be added so we do not need to check here.
        _gaugeController.add_gauge(gauge, _ETHEREUM_GAUGE_CONTROLLER_TYPE);
    }

    function _isValidGaugeType(string memory gaugeType) internal view returns (bool) {
        bytes32 gaugeTypeHash = keccak256(abi.encodePacked(gaugeType));
        for (uint256 i = 0; i < _gaugeTypes.length; ++i) {
            if (gaugeTypeHash == keccak256(abi.encodePacked(_gaugeTypes[i]))) {
                return true;
            }
        }

        return false;
    }
}
