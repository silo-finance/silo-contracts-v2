// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {SafeERC20Upgradeable as SafeERC20} from
    "openzeppelin-contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {
    ERC4626Upgradeable,
    ERC20Upgradeable,
    IERC20Upgradeable as IERC20,
    IERC20MetadataUpgradeable as IERC20Metadata
} from "openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {MathUpgradeable as Math} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {ISilo} from "../../silo-core/contracts/Silo.sol";
import {ISiloConfig} from "../../silo-core/contracts/SiloConfig.sol";
import {IBalancerMinter} from "../../ve-silo/contracts/silo-tokens-minter/BalancerMinter.sol";

struct RewardInfo {
    uint64 ONE;
    /// @dev scalar for the rewardToken
    uint224 index;
    /// @dev The vault's last updated index
    bool exists;
}
/// @dev Exists or not

/**
 * @title MetaSilo
 * @notice An ERC4626 compliant single asset vault that dynamically lends to multiple silos.
 * @notice This contract handles multiple rewards, which can be claimed by the depositors.
 */
contract MetaSilo is ERC4626Upgradeable, Ownable {
    using SafeERC20 for IERC20;
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;
    using Math for uint256;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 constant P = 10;

    IBalancerMinter public balancerMinter;

    IERC20[] public rewardTokens;
    IERC20[] public activeSilos;
    IERC20[] public removedSilos;

    mapping(IERC20 => RewardInfo) public rewardInfos;
    mapping(address => mapping(IERC20 => uint256)) public userIndex;
    mapping(address => mapping(IERC20 => uint256)) public accruedRewards;
    mapping(address => bool) public silos;

    error RewardTokenAlreadyExist(IERC20 rewardToken);
    error RewardTokenDoesntExist(IERC20 rewardToken);
    error ZeroAmount();
    error NotSubmitter(address submitter);
    error RewardsAreDynamic(IERC20 rewardToken);
    error InvalidConfig();
    error ZeroAddressTransfer(address from, address to);
    error InsufficentBalance();
    error ZeroRewards(IERC20 rewardToken);

    event RewardsClaimed(address indexed user, IERC20 rewardToken, uint256 amount, bool escrowed);

    /**
     * @notice Initialize a new MetaSilo contract.
     * @param _asset The native asset to be deposited.
     * @param _nameParam Name of the contract.
     * @param _symbolParam Symbol of the contract.
     * @param _owner Owner of the contract.
     * @param _balancerMinter Gauge contract.
     */
    function initialize(
        IERC20 _asset,
        string calldata _nameParam,
        string calldata _symbolParam,
        address _owner,
        address _balancerMinter
    ) external initializer {
        __ERC4626_init(IERC20Metadata(address(_asset)));
        __Owned_init(_owner);

        _name = _nameParam;
        _symbol = _symbolParam;
        _decimals = IERC20Metadata(address(_asset)).decimals();
        balancerMinter = IBalancerMinter(_balancerMinter);
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
    function _convertToShares(uint256 assets, Math.Rounding) internal pure override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : assets.mulDivDown(supply, _nav());
    }

    /// @notice This fct returns the amount of assets needed by the vault for the amount of shares provided.
    function _convertToAssets(uint256 shares, Math.Rounding) internal pure override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : shares.mulDivDown(_nav(), supply);
    }

    /// @notice Internal deposit fct used by `deposit()` and `mint()`. Accrues rewards for `caller` and `receiver`.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        override
        accrueRewards(caller, receiver)
    {
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

        _burn(owner, shares);

        emit Withdraw(caller, receiver, owner, assets, shares);

        _beforeWithdraw(assets, receiver);
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
                            CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Claim rewards for a user in any amount of rewardTokens.
     * @param user User for which rewards should be claimed.
     * @param _rewardTokens Array of rewardTokens for which rewards should be claimed.
     * @dev This function will revert if any of the rewardTokens have zero rewards accrued.
     */
    function claimRewards(address user, IERC20[] memory _rewardTokens) external accrueRewards(msg.sender, user) {
        for (uint8 i; i < _rewardTokens.length; i++) {
            uint256 rewardAmount = accruedRewards[user][_rewardTokens[i]];

            if (rewardAmount == 0) revert ZeroRewards(_rewardTokens[i]);

            accruedRewards[user][_rewardTokens[i]] = 0;
            _rewardTokens[i].transfer(user, rewardAmount);
            emit RewardsClaimed(user, _rewardTokens[i], rewardAmount, false);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    REWARDS MANAGEMENT LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows owner to add a reward token to Meta Silo
     * @dev Reward token must be an ERC20
     * @param tokenAddress address of the reward token
     */
    function addRewardToken(address tokenAddress) external onlyOwner {
        IERC20 rewardToken = IERC20(tokenAddress);
        require(!rewardInfos[rewardToken].exists, "REWARD_TOKEN_ALREADY_ADDED");

        rewardInfos[rewardToken] = RewardInfo({decimals: uint8(rewardToken.decimals()), exists: true});
        rewardTokens.push(rewardToken);
    }

    /*//////////////////////////////////////////////////////////////
                      REWARDS ACCRUAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Accrue rewards for up to 2 users for all available reward tokens.
    modifier accrueRewards(address _caller, address _receiver) {
        IERC20[] memory _rewardTokens = rewardTokens;
        for (uint8 i; i < _rewardTokens.length; i++) {
            IERC20 rewardToken = _rewardTokens[i];
            RewardInfo memory rewards = rewardInfos[rewardToken];
            _accrueUser(_receiver, rewardToken);

            /// @notice If a deposit/withdraw is called for another user we should accrue for both of them
            if (_receiver != _caller) _accrueUser(_caller, rewardToken);
        }
        _;
    }

    /// @notice Accrue global rewards for a rewardToken
    function _accrueRewards(IERC20 _rewardToken, uint256 accrued) internal {
        uint256 supplyTokens = totalSupply();
        if (supplyTokens != 0) {
            uint224 deltaIndex =
                accrued.mulDiv(uint256(10 ** decimals()), supplyTokens, Math.Rounding.Down).safeCastTo224();

            rewardInfos[_rewardToken].index += deltaIndex;
        }
    }

    /// @notice Sync a user's rewards for a rewardToken with the global reward index for that token
    function _accrueUser(address _user, IERC20 _rewardToken) internal {
        RewardInfo memory rewards = rewardInfos[_rewardToken];

        uint256 oldIndex = userIndex[_user][_rewardToken];

        // If user hasn't yet accrued rewards, grant rewards from the strategy beginning if they have a balance
        // Zero balances will have no effect other than syncing to global index
        uint256 deltaIndex = oldIndex == 0 ? rewards.index - rewards.ONE : rewards.index - oldIndex;

        // Accumulate rewards by multiplying user tokens by rewardsPerToken index and adding on unclaimed
        uint256 supplierDelta = balanceOf(_user).mulDiv(deltaIndex, uint256(10 ** decimals()), Math.Rounding.Down);

        userIndex[_user][_rewardToken] = rewards.index;
        accruedRewards[_user][_rewardToken] += supplierDelta;
    }

    /*//////////////////////////////////////////////////////////////
                      SILO FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits to a given silo
     * @param _silo address of the silo to be deposited to
     * @param _amount amount of asset to be deposited
     */
    function _depositToSilo(address _silo, uint256 _amount) internal {
        require(silos[_silo], "SILO_NOT_FOUND");
        ISilo(_silo).deposit(_amount, address(this));
    }

    /**
     * @notice Deposits from a given silo
     * @param _silo address of the silo to be withdrawn from
     * @param _amount amount of asset to be withdrawn
     */
    function _withdrawFromSilo(address _silo, uint256 _amount) internal returns (uint256 _withdrawn) {
        require(silos[_silo], "SILO_NOT_FOUND");
        uint256 _availableToWithdraw = ISilo(_silo).maxWithdraw(address(this));
        return ISilo(_silo).withdraw(Math.min(_amount, _availableToWithdraw), address(this), address(this));
    }

    /**
     * @notice logic to allocate funds to silo after a deposit to MetaSilo
     * @param _amount amount to be deposited
     */
    function _afterDeposit(uint256 _amount) internal {
        // @todo: determine deposit logic
        // uint256 highest = 0;
        // address highestUtilSilo;

        // for (uint256 i = 0; i < activeSilos.length; i++) {
        //     if (silos[_silo] = true) {
        //         uint256 util = ISilo(_silo).getCollateralAssets() * 10_000 / ISilo(_silo).getDebtAssets();
        //         if (util > highest) {
        //             highest = util;
        //             highestUtilSilo = silos[i];
        //         }
        //     }
        // }
        // _depositToSilo(highestUtilSilo, _amount);
    }

    /**
     * @notice logic to free-up funds before withdraw from MetaSilo
     * @param _amount amount to be withdrawn
     * @return amount that was freed-up
     */
    function _beforeWithdraw(uint256 _amount) internal returns (uint256 _withdrawn) {
        // @todo: determine withdrawal logic
        // if (activeSilos.length == 0) {
        //     return 0;
        // }

        // /// @notice: if we have silos that were removed but still holding assets, withdraw as much as possible here
        // for (uint256 i = 0; i < activeSilos.length; i++) {
        //     if (silos[i] = false) {
        //         _withdrawFromSilo(silos[i], type(uint256).max);
        //         /// if removed silo is empty, call deleteSilo
        //         // if (ISilo(_silo).balanceOf(address(this) == 0)) {
        //         //     deleteSilo(silos[i]);
        //         // }
        //     }
        // }

        // uint256 amountWithdrawn = 0;
        // uint256 j = 0;
        // /// @note: number of loops

        // /// @notice: withdraw from the lowest util vault, until we have the full amount withdrawn
        // while (amountWithdrawn < _amount) {
        //     uint256 lowest = uint256(-1);
        //     address lowestUtilSilo;
        //     for (uint256 i = 0; i < activeSilos.length; i++) {
        //         if (silos[_silo] = true) {
        //             uint256 util = ISilo(_silo).getCollateralAssets() * 10_000 / ISilo(_silo).getDebtAssets();
        //             if (util < lowest) {
        //                 lowest = util;
        //                 lowestUtilSilo = silos[i];
        //             }
        //         }
        //     }
        //     amountWithdrawn = amountWithdrawn.add(_withdrawFromSilo(_amount - amountWithdrawn));
        //     j++;

        //     if (j >= 5) {
        //         /// @notice: dont want infinite loop
        //         return amountWithdrawn;
        //     }
        // }
    }

    /**
     * @notice Claims pending rewards and update accounting
     */
    function _claimRewardsFromSilos() internal {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            IERC20 reward = rewardTokens[i];
            // @todo: fetch gauge address
            balancerMinter.mintFor(gauge, address(this));
            // Cache RewardInfo
            RewardInfo memory rewards = rewardInfos[rewardToken];
            // Update the index of rewardInfo before updating the rewardInfo
            _accrueRewards(rewardToken, amount);
            rewardsEarned[reward] += amount;
        }
    }

    /**
     * @notice Allows owners to add a silo
     * @param _silo address of the silo to be added
     */
    function addSilo(address _silo) public onlyOwner {
        require(_silo != address(0), "ZERO_ADDRESS");
        require(!silos[_silo], "SILO_EXISTS");
        silos[_silo] = true;
        activeSilos.push(_silo);
    }

    /**
     * @notice Allows owners to remove a silo
     * @dev Calling this doesn't actually delete the silo from the mapping. It just sets it to false.
     * @dev This keeps storage cluttered with inactive Silos. The mapping should be deleted in deleteSilo().
     * @param _silo address of the silo to be removed
     */
    function removeSilo(address _silo) public onlyOwner {
        require(silos[_silo], "SILO_NOT_FOUND");
        delete silos[_silo];
        _withdrawFromSilo(_silo, getSiloDeposit());
        /// @notice: withdraw as much as possible from Silo
        if (getSiloDeposit = !0) {
            removedSilos.push(_silo);
        }
    }

    function deleteEmptySilo(address _silo) public onlyOwner {
        // @todo: function to remove a silo from removedSilos array once its empty
        // require(silos[_silo], "SILO_NOT_FOUND");
        // require(ISilo(silos[i]).balanceOf(address(this)) == 0, "SILO NOT EMPTY");
        // removedSilos.push(_silo);
    }

    /**
     * @notice View functions to return the number of Silos attached to Meta Silo
     * @return number of activeSilos
     */
    function numActiveSilos() public view returns (uint256) {
        return activeSilos.length;
    }

    /**
     * @notice Gets the deposited asset amount for a silo
     * @param silo The address of the silo
     * @return The underlying deposited asset amount
     */
    function getSiloDeposit(address silo) public view returns (uint256) {
        require(silos[silo], "Invalid silo");
        ISilo siloContract = ISilo(silo);
        return siloContract.convertToAssets(siloContract.balanceOf(address(this)));
    }

    /**
     * @notice Gets the available liquid balances for all silos
     * @return An array containing the available liquid balance for each silo
     */
    function getSiloLiquidBalances() public view returns (uint256[] memory) {
        uint256 numSilos = activeSilos.length;
        uint256[] memory liquidBalances = new uint256[](numSilos);

        for (uint256 i = 0; i < numSilos; i++) {
            address silo = activeSilos[i];

            uint256 availableToWithdraw = ISilo(silo).maxWithdraw(address(this));

            liquidBalances[i] = availableToWithdraw;
        }
        return liquidBalances;
    }

    /**
     * @notice Fetches the deposit amounts for each silo
     * @return An array containing the deposit amount for each silo
     */
    function getDepositAmounts() public view returns (uint256[] memory) {
        uint256 numSilos = activeSilos.length;
        uint256[] memory D = new uint256[](numSilos);

        for (uint256 i = 0; i < numSilos; i++) {
            address silo = activeSilos[i];
            D[i] = ISilo(silo).balanceOf(address(this));
        }
        return D;
    }

    /**
     * @notice Fetches the utilization configurations for all silos
     * @return The optimal and critical utilization percentages for each silo
     */
    function getUtilizations() public view returns (uint256[] memory uopt, uint256[] memory ucrit) {
        uint256 numSilos = activeSilos.length;
        uopt = new uint256[](numSilos);
        ucrit = new uint256[](numSilos);

        for (uint256 i = 0; i < numSilos; i++) {
            address silo = activeSilos[i];
            ISiloConfig config = ISilo(silo).config();
            (uopt[i], ucrit[i]) = config.getUtilizationConfig(silo);
        }
        return (uopt, ucrit);
    }

    /*//////////////////////////////////////////////////////////////
                      HARVEST LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice harvest logic for Meta Silo
     * @notice harvests rewards from all silos and rebalance allocation
     */
    function harvest() public {
        claimRewardsFromSilos();
        _reallocate(_solveDistribution(_nav())); // @todo: need to remove potential funds stuck in a removed silo
    }

    /**
     * @dev Reallocates funds across active silos based on proposed distribution
     * @param proposed Array of proposed deposit amounts for each silo
     * @return Amount remaining after reallocation
     */
    function _reallocate(uint256[] memory proposed) internal {
        uint256 total = _nav();

        // First withdraw from silos where current > proposed
        for (uint256 i = 0; i < activeSilos.length; i++) {
            uint256 current = getSiloDeposit(activeSilos[i]);

            if (current > proposed[i]) {
                uint256 amount = current - proposed[i];
                _withdrawFromSilo(activeSilos[i], amount);
            }
        }

        // Now deposit to silos up to proposed amounts
        uint256 remaining = total;

        for (uint256 i = 0; i < activeSilos.length; i++) {
            uint256 amount = proposed[i] - getSiloDeposit(activeSilos[i]);

            if (amount > 0) {
                _depositToSilo(activeSilos[i], Math.min(remaining, amount));
                remaining -= amount;
            }

            if (remaining == 0) {
                break;
            }
        }

        // Deposit any remainder to highest utilization
        // @todo: _depositToHighestUtil(remaining);
    }

    /*//////////////////////////////////////////////////////////////
                            SOLVER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Calculates a normalized utilization factor for a silo.
    /// @param u Current utilization of the silo (e.g., 75 represents 75%).
    /// @param uopt Optimal utilization percentage for the silo.
    /// @param ucrit Critical utilization percentage for the silo.
    /// @return Normalized utilization factor for the silo based on its current, optimal, and critical utilizations.
    function _factor(uint256 u, uint256 uopt, uint256 ucrit) internal pure returns (uint256) {
        if (u < uopt) {
            return u / uopt;
        } else if (u < ucrit) {
            return 1 + (u - uopt) / (ucrit - uopt);
        } else {
            return 2 + (u - ucrit) / (1 - ucrit);
        }
    }

    /// @dev Calculates the silo size based on the normalized utilization factor.
    /// @param f Target utilization factor
    /// @param B Current borrow amount of the silo.
    /// @param D Current deposit amount of the silo
    /// @param uopt Optimal utilization percentage for the silo.
    /// @param ucrit Critical utilization percentage for the silo.
    /// @return Amount of additional deposit needed beyond depositAmount to reach utilization factor f
    function _unfactor(uint256 f, uint256 B, uint256 D, uint256 uopt, uint256 ucrit) internal pure returns (uint256) {
        if (f < 1) {
            return B / (f * uopt) - D;
        } else if (f < 2) {
            return B / (uopt + (f - 1) * (ucrit - uopt)) - D;
        } else {
            return B / (ucrit + (f - 2) * (1 - ucrit)) - D;
        }
    }

    /// @dev Redistributes deposits across silos to optimize utilization
    /// @param B Array of current borrow amounts for each silo
    /// @param D Array of current deposit amounts for each silo
    /// @param uopt Array of optimal utilization percentages for each silo
    /// @param ucrit Array of critical utilization percentages for each silo
    /// @param Stot Total amount to distribute across silos
    /// @return Array of optimized deposit amounts for each silo
    function _solver(
        uint256[] memory B,
        uint256[] memory D,
        uint256[] memory uopt,
        uint256[] memory ucrit,
        uint256 Stot
    ) internal pure returns (uint256[] memory) {
        uint256 N = B.length;
        uint256[] memory basket = new uint[](N);
        uint256[] memory cnt = new uint[](P+2);
        uint256[] memory ind = new uint[](N);
        uint256[] memory S = new uint[](N);
        uint256[] memory dS = new uint[](N);

        // Calculate basket for each silo
        for (uint256 i = 0; i < N; i++) {
            uint256 f = factor(B[i] / D[i], uopt[i], ucrit[i]);
            if (f > 2) {
                basket[i] = 0;
                cnt[1]++;
            } else if (f > 1) {
                basket[i] = (2 - f) * P;
                cnt[basket[i] + 1]++;
            } else {
                basket[i] = P + 1;
            }
        }

        // Calculate cumulative counts
        for (uint256 k = 2; k <= P + 1; k++) {
            cnt[k] += cnt[k - 1];
        }

        // Calculate index array
        for (uint256 i = 0; i < N; i++) {
            ind[cnt[basket[i]]] = i;
            cnt[basket[i]]++;
        }

        // Redistribute deposits
        uint256 Ssum = 0;
        for (uint256 k = 0; k <= P; k++) {
            uint256 jk = cnt[k];
            uint256 f = 2 - k / P; // target factor

            uint256 dSsum = 0;
            for (uint256 j = 0; j < jk; j++) {
                uint256 i = ind[j];
                dS[i] = unfactor(f, B[i], D[i] + S[i], uopt[i], ucrit[i]);
                dSsum += dS[i];
            }

            uint256 scale = Math.min(1, (Stot - Ssum) / dSsum);
            for (uint256 j = 0; j < jk; j++) {
                uint256 i = ind[j];
                S[i] += dS[i] * scale;
            }

            Ssum += dSsum * scale;
            if (scale < 1) {
                break;
            }
        }

        // Distribute remaining
        if (Ssum < Stot) {
            /// @todo: decide how to allowcate remaining funds after looping through the baskets
        }

        return S;
    }

    // Helper to pass all params to _solver
    function _solveDistribution(uint256 _total) internal returns (uint256[] memory) {
        (uint256[] memory uopt, uint256[] memory ucrit) = getUtilizations();
        return _solver(getBorrowAmounts(), getDepositAmounts(), uopt, ucrit, _total);
    }

    function nav() external view returns (uint256) {
        return _nav();
    }

    /**
     * @notice Function to retreive the net asset value of the Meta Silo
     * @notice This excludes non-native token rewards, that are accrued separately in accruedRewards
     * @return net asset value of the MetaSilo, excluding rewards
     */
    function _nav() internal returns (uint256) {
        // @todo: The nav() calculation sums the asset balances of all Silos, but doesn't validate those Silos still have funds or are solvent
        uint256 totalFromSilos = 0;

        for (uint256 i = 0; i < activeSilos.length; i++) {
            address _silo = activeSilos[i];
            ISilo silo = ISilo(siloAddress);
            totalFromSilos += silo.convertToAssets(silo.balanceOf(address(this)));
        }

        return asset.balanceOf(address(this)) + totalFromSilos;
    }
}
