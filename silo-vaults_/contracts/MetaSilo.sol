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

import "./lib/SolverLib.sol";

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

    bool public isEmergency;

    IBalancerMinter public balancerMinter;

    /// Silo
    address[] public silos;
    address[] public removedSilos;
    mapping(address => address) public gauge;

    /// Rewards
    IERC20[] public rewardTokens;

    struct RewardInfo {
        uint64 ONE;
        uint224 index;
        bool exists;
    }

    mapping(IERC20 => RewardInfo) public rewardInfos;
    mapping(address => mapping(IERC20 => uint256)) public userIndex;
    mapping(address => mapping(IERC20 => uint256)) public accruedRewards;

    /// Errors
    error ZeroAddressTransfer(address from, address to);
    error InsufficentBalance();
    error RewardTokenAlreadyAdded(IERC20 rewardToken);
    error DepositNotAllowedEmergency();
    error SiloAlreadyAdded();

    /// Events
    event RewardsClaimed(address indexed user, IERC20 rewardToken, uint256 amount, bool escrowed);
    event SiloAdded(address silo, address balancerMinter);
    event SiloRemoved(address silo);

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
        if (caller != owner) _approve(owner, msg.sender, allowance(owner, msg.sender) - shares);
        _burn(owner, shares);
        emit Withdraw(caller, receiver, owner, assets, shares);
        _beforeWithdraw(assets, receiver);
        IERC20(asset()).safeTransfer(receiver, assets);
    }

    /// @notice Internal transfer fct used by `transfer()` and `transferFrom()`. Accrues rewards for `from` and `to`.
    function _transfer(address from, address to, uint256 amount) internal override accrueRewards(from, to) {
        if (from == address(0) || to == address(0)) revert ZeroAddressTransfer(from, to);
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
            if (rewardAmount == 0) continue; // here we don't want to revert if there is no reward
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
        if (rewardInfos[rewardToken].exists) revert RewardTokenAlreadyAdded(tokenAddress);
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
     * @param _siloAddress address of the silo to be deposited to
     * @param _amount amount of asset to be deposited
     */
    function _depositToSilo(address _siloAddress, uint256 _amount) internal {
        ISilo(_siloAddress).deposit(_amount, address(this));
    }

    /**
     * @notice Deposits from a given silo
     * @param _siloAddress address of the silo to be withdrawn from
     * @param _amount amount of asset to be withdrawn
     */
    function _withdrawFromSilo(address _siloAddress, uint256 _amount) internal returns (uint256 _withdrawn) {
        ISilo silo = ISilo(_siloAddress);
        uint256 _availableToWithdraw = silo.maxWithdraw(address(this));
        return silo.withdraw(Math.min(_amount, _availableToWithdraw), address(this), address(this));
    }

    /**
     * @notice Gets the deposited asset amount for a silo
     * @param _siloAddress The address of the silo
     * @return The underlying deposited asset amount
     */
    function getSiloDeposit(address _siloAddress) public view returns (uint256) {
        ISilo silo = ISilo(_siloAddress);
        return silo.convertToAssets(silo.balanceOf(address(this)));
    }

    /**
     * @notice Gets the available liquid balances for all silos
     * @return An array containing the available liquid balance for each silo
     */
    function _getSiloLiquidBalances() internal returns (uint256[] memory) {
        uint256 numSilos = silos.length;
        uint256[] memory liquidBalances = new uint256[](numSilos);

        for (uint256 i = 0; i < numSilos; i++) {
            address silo = silos[i];

            uint256 availableToWithdraw = ISilo(silo).maxWithdraw(address(this));

            liquidBalances[i] = availableToWithdraw;
        }
        return liquidBalances;
    }

    /**
     * @notice Fetches the deposit amounts for each silo
     * @return An array containing the deposit amount for each silo
     */
    function _getDepositAmounts() internal returns (uint256[] memory) {
        uint256 numSilos = silos.length;
        uint256[] memory D = new uint256[](numSilos);

        for (uint256 i = 0; i < numSilos; i++) {
            address silo = silos[i];
            D[i] = ISilo(silo).getAssets(ISilo.AssetType.Collateral);
        }
        return D;
    }

    /**
     * @notice Fetches the BORROW amounts for each silo
     * @return An array containing the BORROW amount for each silo
     */
    function _getBorrowAmounts() internal returns (uint256[] memory) {
        uint256 numSilos = silos.length;
        uint256[] memory B = new uint256[](numSilos);

        for (uint256 i = 0; i < numSilos; i++) {
            address silo = silos[i];
            B[i] = ISilo(silo).getAssets(ISilo.AssetType.Debt);
        }
        return B;
    }

    /**
     * @notice Fetches the utilization configurations for all silos
     * @return The optimal and critical utilization percentages for each silo
     */
    function _getUtilizations() internal returns (uint256[] memory uopt, uint256[] memory ucrit) {
        uint256 numSilos = silos.length;
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
                            OWNER FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows owner to add a single silo
     * @param _siloAddress Address of the silo
     * @param _gaugeAddress Address of the associated balancerMinter
     */
    function addSilo(address _siloAddress, address _gaugeAddress) public onlyOwner {
        for (uint256 i = 0; i < silos.length; i++) {
            if (silos[i] != _silo) revert SiloAlreadyAdded();
        }
        silos.push(_siloAddress);
        gauge[_siloAddress] = _gaugeAddress;
        emit SiloAdded(_siloAddress, _balancerMinterAddress);
    }

    /**
     * @notice Allows owner to add multiple silos
     * @param _siloAddresses Array of silo addresses
     * @param _gaugeAddresses Array of associated balancerMinter addresses
     */
    function addMultipleSilos(address[] memory _siloAddresses, address[] memory _gaugeAddresses) external onlyOwner {
        for (uint256 i = 0; i < _silos.length; i++) {
            for (uint256 i = 0; i < silos.length; i++) {
                if (silos[i] != _silo) revert SiloAlreadyAdded();
            }
            silos.push(_silos[i]);
            gauge[_silos[i]] = _gauges[i];
            emit SiloAdded(_silos[i], _balancerMinters[i]);
        }
    }

    /**
     * @notice Allows owner to remove a silo
     * @dev If full withdrawal from that silo is not possible, we add it to removedSilos array
     * @param _siloAddress Address of silo to remove
     */
    function removeSilo(address _siloAddress) public onlyOwner {
        // Withdraw all available funds
        _withdrawFromSilo(silos[_siloAddress], type(uint256).max);

        // Find index of silo in array
        uint256 index = -1;
        for (uint256 i = 0; i < silos.length; i++) {
            if (silos[i] == _siloAddress) {
                index = i;
                break;
            }
        }

        // Remove from array
        if (index >= 0) {
            // Move last element to index
            silos[index] = silos[silos.length - 1];
            // Reduce length
            silos.pop();
        }

        // Track removed silo if not emptied
        if (ISilo(_siloAddress).balanceOf(address(this)) > 0) {
            removedSilos.push(_siloAddress);
        }

        emit SiloRemoved(_siloAddress);
    }

    // @todo: function to handle removedSilos when it's empty
    // @todo: owner function to manually withdraw from removeSilos

    /**
    * @notice Manually reallocate funds across silos 
    * @dev Only callable by owner
    * @param proposed Proposed deposit amounts for each silo
    */
    function reallocateManual(uint256[] memory proposed) public onlyOwner {
        _reallocate(proposed);
    }

    /**
    * @notice Automatically reallocate funds across silos
    * @dev Calls internal solver to calculate optimal distribution
    * @dev Only callable by owner
    */
    function reallocateWithSolver() public onlyOwner {
        _reallocate(_solveDistribution(_nav()));
    }

    /**
     * @notice Allows owner to set emergency, which restrict new deposits
     * @param _isEmergency Bool to indicate if emergency is activated
     */
    function setEmergency(bool _isEmergency) public onlyOwner {
        isEmergency = _isEmergency;
    }

    /*//////////////////////////////////////////////////////////////
                    ALLOCATION / HARVEST LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice logic to allocate funds to silo after a deposit to MetaSilo
     * @notice We default to allocating to the highest utilization silo.
     * @param _amount amount to be deposited
     */
    function _afterDeposit(uint256 _amount) internal {
        uint256 highest = 0;
        address highestUtilSilo;

        for (uint256 i = 0; i < silos.length; i++) {
            ISilo silo = ISilo(silos[i]);
            uint256 util = silo.getAssets(ISilo.AssetType.Collateral) * 1e18 / silo.getAssets(ISilo.AssetType.Debt);

            if (util > highest) {
                highest = util;
                highestUtilSilo = silos[i];
            }
        }

        _depositToSilo(highestUtilSilo, _amount);
    }

    /**
     * @notice logic to free-up funds before withdraw from MetaSilo
     * @param _amount amount to be withdrawn
     * @return amount that was freed-up
     */
    function _beforeWithdraw(uint256 _amount) internal returns (uint256 _withdrawn) {
        /// @todo: decide if we want to attempt withdrawing from removed silos

        uint256 amountWithdrawn = 0;
        uint256 j = 0;

        /// @notice: withdraw from the lowest util vault, until we have the full amount withdrawn
        while (amountWithdrawn < _amount) {
            uint256 lowest = uint256(-1);
            address lowestUtilSilo;

            for (uint256 i = 0; i < silos.length; i++) {
                ISilo silo = ISilo(silos[i]);
                uint256 util = silo.getAssets(ISilo.AssetType.Collateral) * 1e18 / silo.getAssets(ISilo.AssetType.Debt);
                if (util < lowest) {
                    lowest = util;
                    lowestUtilSilo = silos[i];
                }
            }

            amountWithdrawn = amountWithdrawn.add(_withdrawFromSilo(_amount - amountWithdrawn));
            j++;
            if (j >= 5) return amountWithdrawn;
            /// @notice: dont want infinite loop
        }
    }

    /**
     * @notice Claims pending rewards and update accounting
     */
    function _claimRewardsFromSilos() internal {
        /// @todo: clarify multiple rewards per gauge?
        // for (uint256 i = 0; i < rewardTokens.length; i++) {
        //     IERC20 reward = rewardTokens[i];
        //     balancerMinter.mintFor(gauge[silo], address(this));
        //     // Cache RewardInfo
        //     RewardInfo memory rewards = rewardInfos[rewardToken];
        //     // Update the index of rewardInfo before updating the rewardInfo
        //     _accrueRewards(rewardToken, amount);
        //     rewardsEarned[reward] += amount;
        // }
    }

    /**
     * @notice harvest logic for Meta Silo
     * @notice harvests rewards from all silos and rebalance allocation
     */
    function harvest() public {
        // @todo: check if we want it to be callable by anyone?
        // loop for all silos
        _claimRewardsFromSilos();
    }

    /**
     * @dev Reallocates funds across active silos based on proposed distribution
     * @param proposed Array of proposed deposit amounts for each silo
     * @return Amount remaining after reallocation
     */
    function _reallocate(uint256[] memory proposed) internal {
        uint256 total = _nav();

        // First withdraw from silos where current > proposed
        for (uint256 i = 0; i < silos.length; i++) {
            uint256 current = getSiloDeposit(silos[i]);

            if (current > proposed[i]) {
                uint256 amount = current - proposed[i];
                _withdrawFromSilo(silos[i], amount);
            }
        }

        // Now deposit to silos up to proposed amounts
        uint256 remaining = total;

        for (uint256 i = 0; i < silos.length; i++) {
            uint256 amount = proposed[i] - getSiloDeposit(silos[i]);

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
    * @dev Helper to calculate optimal deposit distribution 
    * @param _total Total assets to distribute
    * @return Array of proposed deposit amounts for each silo
    */
    function _solveDistribution(uint256 _total) internal returns (uint256[] memory) {
        (uint256[] memory uopt, uint256[] memory ucrit) = getUtilizations();
        return SolverLib.solver(getBorrowAmounts(), getDepositAmounts(), uopt, ucrit, _total);
    }

    /**
    * @notice Get the current Net Asset Value (NAV) of the vault
    * @return nav The NAV excluding external reward balances
    */
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
            address _siloAddress = activeSilos[i];
            ISilo silo = ISilo(siloAddress);
            totalFromSilos += silo.convertToAssets(silo.balanceOf(address(this)));
        }

        return asset.balanceOf(address(this)) + totalFromSilos;
    }
}
