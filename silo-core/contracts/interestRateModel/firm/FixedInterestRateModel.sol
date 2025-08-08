// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Math} from "openzeppelin5/utils/math/Math.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/interfaces/IERC20.sol";
import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";

import {
    IFixedInterestRateModelConfig
} from "silo-core/contracts/interestRateModel/firm/interfaces/IFixedInterestRateModelConfig.sol";

import {
    IFixedInterestRateModel
} from "silo-core/contracts/interestRateModel/firm/interfaces/IFixedInterestRateModel.sol";

/// @title FixedInterestRateModel
/// @notice This model is used in FIRM markets. Interest rate is constant and set on deployment. FixedInterestRateModel
/// receives collateral share tokens from hook and transfers these tokens to FIRM vault on interest accrual.
/// More details TODO link for repository docs.
// TODO Natspec
contract FixedInterestRateModel is Initializable, IFixedInterestRateModel {
    using SafeERC20 for IERC20;

    uint256 public constant decimals = 18; // solhint-disable-line const-name-snakecase
    uint256 public constant DP = 10 ** decimals;

    IFixedInterestRateModelConfig public irmConfig;
    uint256 public lastUpdateTimestamp;

    function initialize(address _irmConfig) external initializer virtual {
        require(_irmConfig != address(0), ZeroConfig());
        irmConfig = IFixedInterestRateModelConfig(_irmConfig);
        lastUpdateTimestamp = block.timestamp;
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

        uint256 distributeToTimestamp = Math.max(_blockTimestamp, config.maturityTimestamp);
        if (distributeToTimestamp <= lastUpdateTimestamp) return 0;
        uint256 interestTimeDelta = distributeToTimestamp - lastUpdateTimestamp;

        uint256 vaultBalance = config.shareToken.balanceOf(config.firmVault);
        if (vaultBalance == 0) return 0;

        rcur = config.shareToken.balanceOf(address(this)) * DP * 365 days / (interestTimeDelta * vaultBalance);
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
        IFixedInterestRateModel.Config memory config = irmConfig.getConfig();
        interest = _pendingAccrueInterest(config, block.timestamp);
        lastUpdateTimestamp = block.timestamp;
        if (interest > 0) config.shareToken.safeTransfer(config.firmVault, interest);
    }

    function pendingAccrueInterest(uint256 _blockTimestamp) public view virtual returns (uint256 interest) {
        return _pendingAccrueInterest(irmConfig.getConfig(), _blockTimestamp);
    }

    function _pendingAccrueInterest(
        IFixedInterestRateModel.Config memory _config,
        uint256 _blockTimestamp
    ) internal view virtual returns (uint256 interest) {
        if (_blockTimestamp <= lastUpdateTimestamp) return 0;

        uint256 totalInterestToDistribute = _config.shareToken.balanceOf(address(this));
        if (totalInterestToDistribute == 0) return 0;

        if (_blockTimestamp >= _config.maturityTimestamp) {
            interest = totalInterestToDistribute;
        } else {
            uint256 accruedInterestTimeDelta = _blockTimestamp - lastUpdateTimestamp;
            uint256 interestTimeDelta = _config.maturityTimestamp - lastUpdateTimestamp;
            interest = totalInterestToDistribute * accruedInterestTimeDelta / interestTimeDelta;
        }
    }
}
