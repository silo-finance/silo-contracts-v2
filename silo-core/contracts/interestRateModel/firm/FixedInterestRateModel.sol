// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/interfaces/IERC20.sol";

import {
    IFixedInterestRateModel
} from "silo-core/contracts/interestRateModel/firm/interfaces/IFixedInterestRateModel.sol";

import {
    IFixedInterestRateModelConfig
} from "silo-core/contracts/interestRateModel/firm/interfaces/IFixedInterestRateModelConfig.sol";

/// @title FixedInterestRateModel
/// @notice This model is used in FIRM markets. Interest rate is constant and set on deployment. FixedInterestRateModel
/// receives collateral share tokens from hook and transfers these tokens to FIRM vault on interest accrual.
/// More details TODO link for repository docs.
// TODO Natspec
contract FixedInterestRateModel is Initializable, IFixedInterestRateModel {
    using SafeERC20 for IERC20;

    uint256 public constant decimals = 18;
    uint256 public constant DP = 10 ** decimals;
    uint256 public constant RCUR_LIMIT = 2_500 * DP / 100; // 2,500% per year
    IFixedInterestRateModelConfig public irmConfig;
    uint256 public lastUpdateTimestamp;

    function initialize(address _irmConfig) external initializer virtual {
        require(_irmConfig != address(0), ZeroConfig());
        irmConfig = IFixedInterestRateModelConfig(_irmConfig);
        emit Initialized(_irmConfig);
    }

    function getCompoundInterestRateAndUpdate(
        uint256,
        uint256,
        uint256
    )
        external
        virtual
        returns (uint256 rcomp)
    {
        accrueInterest();
        return 0;
    }

    function getCompoundInterestRate(address _silo, uint256) external view virtual returns (uint256 rcomp) {
        IFixedInterestRateModel.Config memory config = irmConfig.getConfig();
        require(_silo == config.silo, InvalidSilo());
        return 0;
    }

    function getCurrentInterestRateDepositor(address _silo, uint256 _blockTimestamp)
        external
        view
        virtual
        returns (uint256 rcur)
    {
        IFixedInterestRateModel.Config memory config = irmConfig.getConfig();
        require(_silo == config.silo, InvalidSilo());
        uint256 vaultBalance = IERC20(config.shareToken).balanceOf(config.firmVault);
        uint256 interestTimeDelta = Math.max(_blockTimestamp, config.maturityTimestamp) - lastUpdateTimestamp;

        rcur = IERC20(config.shareToken).balanceOf(address(this)) * DP * 365 days / (interestTimeDelta * vaultBalance);
        rcur = Math.min(rcur, RCUR_LIMIT);
    }

    function getCurrentInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        virtual
        returns (uint256 rcur)
    {
        IFixedInterestRateModel.Config memory config = irmConfig.getConfig();
        require(_silo == config.silo, InvalidSilo());
        return _blockTimestamp < config.maturityTimestamp ? config.apr : 0;
    }

    function accrueInterest() public virtual returns (uint256 interest) {
        interest = accrueInterestView(block.timestamp);
        lastUpdateTimestamp = block.timestamp;
        IFixedInterestRateModel.Config memory config = irmConfig.getConfig();
        if (interest > 0) IERC20(config.shareToken).safeTransfer(config.firmVault, interest);
    }

    function accrueInterestView(uint256 _blockTimestamp) public view virtual returns (uint256 interest) {
        if (_blockTimestamp == lastUpdateTimestamp) return 0;
        IFixedInterestRateModel.Config memory config = irmConfig.getConfig();
        uint256 totalInterestToDistribute = IERC20(config.shareToken).balanceOf(address(this));
        if (totalInterestToDistribute == 0) return 0;

        if (_blockTimestamp >= config.maturityTimestamp) {
            interest = totalInterestToDistribute;
        } else {
            uint256 accruedInterestTimeDelta = _blockTimestamp - lastUpdateTimestamp;
            uint256 interestTimeDelta = config.maturityTimestamp - lastUpdateTimestamp;
            interest = totalInterestToDistribute * accruedInterestTimeDelta / interestTimeDelta;
        }

        interest = capInterest(interest, _blockTimestamp);
    }

    function capInterest(uint256 _interest, uint256 _blockTimestamp) public view returns (uint256 cappedInterest) {
        IFixedInterestRateModel.Config memory config = irmConfig.getConfig();
        uint256 vaultBalance = IERC20(config.shareToken).balanceOf(config.firmVault);
        uint256 accruedInterestTimeDelta = _blockTimestamp - lastUpdateTimestamp;
        uint256 maxInterest = RCUR_LIMIT * vaultBalance * accruedInterestTimeDelta / (365 days * DP);
        cappedInterest = Math.min(_interest, maxInterest);
    }
}
