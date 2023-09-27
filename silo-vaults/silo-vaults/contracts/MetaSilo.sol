// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import {
    ERC4626Upgradeable,
    ERC20Upgradeable,
    IERC20Upgradeable as IERC20,
    IERC20MetadataUpgradeable as IERC20Metadata,
    ContextUpgradeable
} from "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {MathUpgradeable as Math} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeERC20Upgradeable as SafeERC20} from
    "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";

import {ISilo} from "silo-core/contracts/Silo.sol";
import {ISiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {InterestRateModelV2} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";

import "./lib/SolverLib.sol";
import {SiloManager} from "./manager/SiloManager.sol";
import {RewardsManager} from "./manager/RewardsManager.sol";

/**
 * @title MetaSilo
 * @notice An ERC4626 compliant single asset vault that dynamically lends to multiple silos.
 * @notice This contract handles multiple rewards, which can be claimed by the depositors.
 */
contract MetaSilo is ERC4626Upgradeable, SiloManager, RewardsManager {
    using SafeERC20 for IERC20;
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;
    using Math for uint256;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /// Errors
    error ZeroAddressTransfer(address from, address to);
    error InsufficentBalance();
    error DepositNotAllowedEmergency();

    /**
     * @notice Initialize a new MetaSilo contract.
     * @param _asset The native asset to be deposited.
     * @param _nameParam Name of the contract.
     * @param _symbolParam Symbol of the contract.
     * @param _owner Owner of the contract.
     * @param _balancerMinter balancerMinter contract.
     */
    function initialize(
        IERC20 _asset,
        string calldata _nameParam,
        string calldata _symbolParam,
        address _owner,
        address _balancerMinter
    ) external initializer {
        __ERC4626_init(IERC20Metadata(address(_asset)));
        _name = _nameParam;
        _symbol = _symbolParam;
        _decimals = IERC20Metadata(address(_asset)).decimals();
        _RewardManager_init(_balancerMinter);
    }

    function name() public view override(ERC20Upgradeable, IERC20Metadata) returns (string memory) {
        return _name;
    }

    function symbol() public view override(ERC20Upgradeable, IERC20Metadata) returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /*//////////////////////////////////////////////////////////////
                    ERC4626 MUTATIVE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 _amount) external returns (uint256) {
        return deposit(_amount, msg.sender);
    }

    function mint(uint256 _amount) external returns (uint256) {
        return mint(_amount, msg.sender);
    }

    function withdraw(uint256 _amount) external returns (uint256) {
        return withdraw(_amount, msg.sender, msg.sender);
    }

    function redeem(uint256 _amount) external returns (uint256) {
        return redeem(_amount, msg.sender, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        ERC4626 OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @notice This fct returns the amount of shares needed by the vault for the amount of assets provided.
    function _convertToShares(uint256 assets, Math.Rounding) internal view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : assets.mulDivDown(supply, _nav());
    }

    /// @notice This fct returns the amount of assets needed by the vault for the amount of shares provided.
    function _convertToAssets(uint256 shares, Math.Rounding) internal view override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : shares.mulDivDown(_nav(), supply);
    }

    /// @notice Internal deposit fct used by `deposit()` and `mint()`. Accrues rewards for `caller` and `receiver`.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        override
        accrueRewards(caller, receiver)
    {
        if (isEmergency) revert DepositNotAllowedEmergency();
        IERC20(asset()).safeTransferFrom(caller, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(caller, receiver, assets, shares);
        _afterDeposit(assets);
    }

    /// @notice Internal withdraw fct used by `withdraw()` and `redeem()`. Accrues rewards for `caller` and `receiver`.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
        accrueRewards(owner, receiver)
    {
        if (caller != owner) {
            _approve(owner, msg.sender, allowance(owner, msg.sender) - shares);
        }
        _beforeWithdraw(shares);
        _burn(owner, shares);
        emit Withdraw(caller, receiver, owner, assets, shares);
        IERC20(asset()).safeTransfer(receiver, assets);
    }

    /// @notice Internal transfer fct used by `transfer()` and `transferFrom()`. Accrues rewards for `from` and `to`.
    function _transfer(address from, address to, uint256 amount) internal override accrueRewards(from, to) {
        if (from == address(0) || to == address(0)) {
            revert ZeroAddressTransfer(from, to);
        }
        uint256 fromBalance = balanceOf(from);
        if (fromBalance < amount) revert InsufficentBalance();
        _burn(from, amount);
        _mint(to, amount);
        emit Transfer(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                    ALLOCATION / HARVEST LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Logic to allocate funds to silo after a deposit to MetaSilo.
     * @notice We default to allocating to the highest utilization silo.
     * @dev Sets a default silo to deposit to, in case all silos are empty.
     * @param _amount amount to be deposited.
     */
    function _afterDeposit(uint256 _amount) internal {
        uint256 highest = 0;
        address highestUtilSilo = silos[0];

        for (uint256 i = 0; i < silos.length; i++) {
            ISilo silo = ISilo(silos[i]);
            uint256 util = (silo.getCollateralAssets() * 1e18) / silo.getDebtAssets();

            if (util > highest) {
                highest = util;
                highestUtilSilo = silos[i];
            }
        }

        _depositToSilo(highestUtilSilo, _amount);
    }

    /**
     * @notice Logic to withdraw funds from silos prior to user withdrawal.
     * @notice Withdraw from the lowest util vault, until we have the full amount withdrawn.
     * @dev Sets a default silo to withdraw from, in case all silos have 0 util.
     * @param _amount amount to be withdrawn.
     */
    function _beforeWithdraw(uint256 _amount) internal returns (uint256 _withdrawn) {
        uint256 amountWithdrawn = 0;
        uint256 j = 0;

        while (amountWithdrawn < _amount) {
            uint256 lowest = 100;
            address lowestUtilSilo = silos[0];

            for (uint256 i = 0; i < silos.length; i++) {
                ISilo silo = ISilo(silos[i]);
                uint256 util = (silo.getCollateralAssets() * 1e18) / silo.getDebtAssets();
                if (util < lowest) {
                    lowest = util;
                    lowestUtilSilo = silos[i];
                }
            }

            amountWithdrawn += _withdrawFromSilo(address(silos[j]), _amount - amountWithdrawn);

            j++;
            if (j >= 5) return amountWithdrawn;
        }
    }

    /**
     * @notice Harvest logic for Meta Silo.
     */
    function harvest() public {
        _harvestRewards();
    }

    /**
     * @notice Manually reallocate funds across silos.
     * @dev Only callable by owner.
     * @param proposed Proposed deposit amounts for each silo.
     */
    function reallocateManual(uint256[] memory proposed) public onlyOwner {
        _reallocate(proposed);
    }

    /**
     * @notice Automatically reallocate funds across silos.
     * @dev Calls internal solver to calculate optimal distribution.
     * @dev Only callable by owner.
     */
    function reallocateWithSolver() public onlyOwner {
        _reallocate(_solveDistribution(_nav()));
    }

    /**
     * @notice Reallocates funds between silos based on proposed allocation.
     * @param proposed Array of proposed deposit amounts for each silo.
     */
    function _reallocate(uint256[] memory proposed) internal {
        uint256 total = _nav();

        for (uint256 i = 0; i < silos.length; i++) {
            uint256 current = _getSiloDeposit(silos[i]);

            if (current > proposed[i]) {
                uint256 amount = current - proposed[i];
                _withdrawFromSilo(silos[i], amount);
            }
        }

        uint256 remaining = total;

        for (uint256 i = 0; i < silos.length; i++) {
            uint256 amount = proposed[i] - _getSiloDeposit(silos[i]);

            if (amount > 0) {
                _depositToSilo(silos[i], Math.min(remaining, amount));
                remaining -= amount;
            }

            if (remaining == 0) {
                break;
            }
        }
    }

    /**
     * @notice Helper to calculate optimal deposit distribution.
     * @param _total Total assets to distribute.
     * @return Array of proposed deposit amounts for each silo.
     */
    function _solveDistribution(uint256 _total) internal returns (uint256[] memory) {
        (uint256[] memory uopt, uint256[] memory ucrit) = _getConfig();
        return SolverLib.solver(_getBorrowAmounts(), _getDepositAmounts(), uopt, ucrit, _total);
    }

    /**
     * @notice Function to retreive the net asset value of the Meta Silo.
     * @notice This excludes non-native token rewards, that are accrued separately in accruedRewards.
     * @dev nav() sums the asset balances of all Silos, but doesn't validate they still have funds or are solvent.
     * @return net asset value of the MetaSilo, excluding rewards.
     */
    function _nav() internal view returns (uint256) {
        uint256 totalFromSilos = 0;

        for (uint256 i = 0; i < silos.length; i++) {
            address _siloAddress = silos[i];
            ISilo silo = ISilo(_siloAddress);
            totalFromSilos += silo.convertToAssets(silo.shareBalanceOf(address(this)));
        }

        return totalAssets() + totalFromSilos;
    }

    /**
     * @notice Get the current Net Asset Value (NAV) of the vault.
     * @return nav The NAV excluding external reward balances.
     */
    function nav() external view returns (uint256) {
        return _nav();
    }

    /// @dev ERC4626Upgradeable forces child contracts to implement this function.
    function _msgSender() internal view override(Context, ContextUpgradeable) returns (address) {
        return msg.sender;
    }

    /// @dev ERC4626Upgradeable forces child contracts to implement this function.
    function _msgData() internal view override(Context, ContextUpgradeable) returns (bytes calldata) {
        return msg.data;
    }
}
