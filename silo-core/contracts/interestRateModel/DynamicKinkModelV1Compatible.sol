// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {SafeCast} from "openzeppelin5/utils/math/SafeCast.sol";

import {DynamicKinkModelV1} from "./DynamicKinkModelV1.sol";
import {IInterestRateModelV2Config} from "../interfaces/IInterestRateModelV2Config.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {ISilo} from "../interfaces/ISilo.sol";

/// @title DynamicKinkModelV1
/// @notice Refer to Silo DynamicKinkModelV1 paper for more details.
/// @custom:security-contact security@silo.finance
contract DynamicKinkModelV1Compatible is DynamicKinkModelV1, IInterestRateModel {
    /// @notice Emitted on config init
    /// @param config config struct for asset in Silo
    event Initialized(address indexed config);

    // function initialize(address _irmConfig) external virtual {
    //     // TODO - looks like code is very old and we need to rebase
    //     // require(_irmConfig != address(0), AddressZero());
    //     // require(address(irmConfig) == address(0), AlreadyInitialized());

    //     // irmConfig = IInterestRateModelV2Config(_irmConfig); TODO

    //     emit Initialized(_irmConfig);
    // }

    /// @dev this method creates 1:1 link between silo and config
    function connect(address _configAddress) external virtual {
        // TODO
        // if (address(getSetup[msg.sender].config) != address(0)) revert AlreadyConnected();

        // getSetup[msg.sender].config = IInterestRateModelV2Config(_configAddress);
        // emit Initialized(msg.sender, _configAddress);
    }

    function decimals() external view returns (uint256) {
        return 18;
    }

    /// @inheritdoc IInterestRateModel
    function getCompoundInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        virtual
        override
        returns (uint256 rcomp)
    {
        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData();

        (int256 rcompInt,,,) = compoundInterestRate({
            _setup: getSetup[_silo],
            _t0: SafeCast.toInt256(data.interestRateTimestamp),
            _t1: SafeCast.toInt256(block.timestamp),
            _u: 0, // TODO calculate/get current utilization - but why we need this if we gave deposits and borrows?
            _totalDeposits: SafeCast.toInt256(data.collateralAssets),
            _totalBorrowAmount: SafeCast.toInt256(data.debtAssets)
        });

        rcomp = SafeCast.toUint256(rcompInt);
    }

    function getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    )
        external
        returns (uint256 rcomp) 
    {
        // assume that caller is Silo
        address silo = msg.sender;

        Setup storage currentSetup = getSetup[silo];

        (int256 rcompInt, int256 k, bool didCap, bool didOverflow) = compoundInterestRate({
            _setup: currentSetup,
            _t0: SafeCast.toInt256(_interestRateTimestamp),
            _t1: SafeCast.toInt256(block.timestamp),
            _u: 0, // TODO calculate/get current utilization - but why we need this if we gave deposits and borrows?
            _totalDeposits: SafeCast.toInt256(_collateralAssets),
            _totalBorrowAmount: SafeCast.toInt256(_debtAssets)
        });

        rcomp = SafeCast.toUint256(rcompInt);

        // currentSetup.initialized = true;

        // TODO do we need cap? check if already applied in compoundInterestRate
        // TODO what we need to store?

        // currentSetup.ri = ri > type(int112).max
        //     ? type(int112).max
        //     : ri < type(int112).min ? type(int112).min : int112(ri);

        // currentSetup.Tcrit = Tcrit > type(int112).max
        //     ? type(int112).max
        //     : Tcrit < type(int112).min ? type(int112).min : int112(Tcrit);
    }

    function getCurrentInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        returns (uint256 rcur)
    {
        ISilo.UtilizationData memory data = ISilo(_silo).utilizationData();

        (int256 rcur,,) = currentInterestRate({
            _setup: getSetup[_silo],
            _t0: SafeCast.toInt256(data.interestRateTimestamp),
            _t1: SafeCast.toInt256(_blockTimestamp),
            _u: 0, // TODO caluslate/get current utilization - but why we need this if we gave deposits and borrows?
            _totalDeposits: SafeCast.toInt256(data.collateralAssets),
            _totalBorrowAmount: SafeCast.toInt256(data.debtAssets)
        });
    }
}
