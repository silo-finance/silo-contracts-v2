// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";
import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {IERC20} from "openzeppelin5/interfaces/IERC20.sol";

import {
    IFixedInterestRateModel
} from "silo-core/contracts/interestRateModel/fixedInterestRateModel/interfaces/IFixedInterestRateModel.sol";

import {
    IFixedInterestRateModelConfig
} from "silo-core/contracts/interestRateModel/fixedInterestRateModel/interfaces/IFixedInterestRateModelConfig.sol";

/// @title FixedInterestRateModel
/// @notice This model is used in FIRM markets. Interest rate is constant and set on deployment. FixedInterestRateModel
/// receives collateral share tokens from hook and transfers these tokens to FIRM vault on interest accrual.
/// More details TODO link for repository docs.
// TODO Natspec
contract FixedInterestRateModel is Initializable, IFixedInterestRateModel {
    IFixedInterestRateModelConfig public irmConfig;
    uint256 public lastUpdateTimestamp;

    function initialize(address _irmConfig) external initializer virtual {
        require(_irmConfig != address(0), ZeroConfig());
        irmConfig = IFixedInterestRateModelConfig(_irmConfig);
        emit Initialized(_irmConfig);
    }

    function getCompoundInterestRateAndUpdate(
        uint256 _collateralAssets,
        uint256 _debtAssets,
        uint256 _interestRateTimestamp
    )
        external
        virtual
        returns (uint256 rcomp)
    {
        accrueInterest();
        return 0;
    }

    function accrueInterest() public virtual returns (uint256 interest) {

    }

    function getCompoundInterestRate(address, uint256) external view virtual returns (uint256 rcomp) {
        return 0;
    }

    function getCurrentInterestRateDepositor(address _silo, uint256 _blockTimestamp)
        external
        view
        virtual
        returns (uint256 rcur)
    {
        IFixedInterestRateModel.Config memory config = irmConfig.getConfig();
        uint256 sharesBalance = IERC4626(config.firmVault).totalAssets();
        uint256 interestTimeDelta = Math.max(block.timestamp, config.maturityTimestamp) - lastUpdateTimestamp;

    }

    function getCurrentInterestRate(address _silo, uint256 _blockTimestamp) external view virtual returns (uint256 rcur) {
        IFixedInterestRateModel.Config memory config = irmConfig.getConfig();
        return block.timestamp < config.maturityTimestamp ? config.apr : 0;
    }

    function decimals() external view virtual returns (uint256) {
        return 18;
    }
}
