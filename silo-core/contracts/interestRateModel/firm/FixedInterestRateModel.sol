// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Initializable} from "openzeppelin5/proxy/utils/Initializable.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin5/interfaces/IERC20.sol";

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

    uint256 public constant decimals = 18;
    uint256 public constant DP = 10 ** decimals;
    uint256 public constant RCUR_LIMIT = 2_500 * DP / 100; // 2,500% per year

    // solhint-disable var-name-mixedcase
    uint256 public immutable APR;
    uint256 public immutable MATURITY_TIMESTAMP;
    address public immutable FIRM_VAULT;
    IERC20 public immutable SHARE_TOKEN;
    address public immutable SILO;
    // solhint-enable var-name-mixedcase

    uint256 public lastUpdateTimestamp;

    constructor(InitConfig memory _config) {
        require(_config.apr < RCUR_LIMIT, InvalidAPR());
        require(_config.maturityTimestamp > block.timestamp, InvalidMaturityTimestamp());
        APR = _config.apr;
        MATURITY_TIMESTAMP = _config.maturityTimestamp;
        FIRM_VAULT = _config.firmVault;
        SHARE_TOKEN = _config.shareToken;
        SILO = _config.silo;

        lastUpdateTimestamp = block.timestamp;
    }

    /// @dev for compatibility with IInterestRateModel interface.
    function initialize(address) external virtual {}

    function getCompoundInterestRateAndUpdate(
        uint256,
        uint256,
        uint256
    )
        external
        virtual
        returns (uint256 rcomp)
    {
        require(msg.sender == SILO, OnlySilo());
        accrueInterest();
        return 0;
    }

    function getCompoundInterestRate(address _silo, uint256) external view virtual returns (uint256 rcomp) {
        require(_silo == SILO, InvalidSilo());
        return 0;
    }

    function getCurrentInterestRateDepositor(address _silo, uint256 _blockTimestamp)
        external
        view
        virtual
        returns (uint256 rcur)
    {
        require(_silo == SILO, InvalidSilo());
        uint256 vaultBalance = SHARE_TOKEN.balanceOf(FIRM_VAULT);
        uint256 interestTimeDelta = Math.max(_blockTimestamp, MATURITY_TIMESTAMP) - lastUpdateTimestamp;

        rcur = SHARE_TOKEN.balanceOf(address(this)) * DP * 365 days / (interestTimeDelta * vaultBalance);
        rcur = Math.min(rcur, RCUR_LIMIT);
    }

    function getCurrentInterestRate(address _silo, uint256 _blockTimestamp)
        external
        view
        virtual
        returns (uint256 rcur)
    {
        require(_silo == SILO, InvalidSilo());
        return _blockTimestamp < MATURITY_TIMESTAMP ? APR : 0;
    }

    function getConfig() external view virtual returns (InitConfig memory config) {
        config = InitConfig({
            apr: APR,
            maturityTimestamp: MATURITY_TIMESTAMP,
            firmVault: FIRM_VAULT,
            shareToken: SHARE_TOKEN,
            silo: SILO
        });
    }

    function accrueInterest() public virtual returns (uint256 interest) {
        interest = accrueInterestView(block.timestamp);
        lastUpdateTimestamp = block.timestamp;
        if (interest > 0) SHARE_TOKEN.safeTransfer(FIRM_VAULT, interest);
    }

    function accrueInterestView(uint256 _blockTimestamp) public view virtual returns (uint256 interest) {
        if (_blockTimestamp == lastUpdateTimestamp) return 0;
        uint256 totalInterestToDistribute = SHARE_TOKEN.balanceOf(address(this));
        if (totalInterestToDistribute == 0) return 0;

        if (_blockTimestamp >= MATURITY_TIMESTAMP) {
            interest = totalInterestToDistribute;
        } else {
            uint256 accruedInterestTimeDelta = _blockTimestamp - lastUpdateTimestamp;
            uint256 interestTimeDelta = MATURITY_TIMESTAMP - lastUpdateTimestamp;
            interest = totalInterestToDistribute * accruedInterestTimeDelta / interestTimeDelta;
        }

        interest = capInterest(interest, _blockTimestamp);
    }

    function capInterest(uint256 _interest, uint256 _blockTimestamp) public view returns (uint256 cappedInterest) {
        uint256 vaultBalance = SHARE_TOKEN.balanceOf(FIRM_VAULT);
        uint256 accruedInterestTimeDelta = _blockTimestamp - lastUpdateTimestamp;
        uint256 maxInterest = RCUR_LIMIT * vaultBalance * accruedInterestTimeDelta / (365 days * DP);
        cappedInterest = Math.min(_interest, maxInterest);
    }
}
