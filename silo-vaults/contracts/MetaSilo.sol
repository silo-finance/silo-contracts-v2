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

struct RewardInfo {
  /// @notice scalar for the rewardToken
  uint64 ONE;
  /// @notice The vault's last updated index
  uint224 index;
  /// @notice Exists or not
  bool exists; 
}

/**
 * @title MetaSilo
 * @notice An ERC4626 compliant single asset vault that dynamically lends to multiple silos.
 * @notice This contract handles multiple rewards, which can be claimed by the depositors.
 *
 * https://ethereum.org/en/developers/docs/standards/tokens/erc-4626/
 * Based on Popcorn MultiRewardStaking and fei flywheel-v2 implementations.
 */
contract MetaSilo is ERC4626Upgradeable, Ownable {
    using SafeERC20 for IERC20;
    using SafeCastLib for uint256;
    using FixedPointMathLib for uint256;
    using Math for uint256;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @notice Initialize a new MetaSilo contract.
     * @param _asset The native asset to be deposited.
     * @param _nameParam Name of the contract.
     * @param _symbolParam Symbol of the contract.
     * @param _owner Owner of the contract.
     */
    function initialize(IERC20 _asset, string calldata _nameParam, string calldata _symbolParam, address _owner) external initializer {
        __ERC4626_init(IERC20Metadata(address(_asset)));
        __Owned_init(_owner);

        _name = _nameParam;
        _symbol = _symbolParam;
        _decimals = IERC20Metadata(address(_asset)).decimals();

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

    error ZeroAddressTransfer(address from, address to);
    error InsufficentBalance();


    /// @notice This function returns the amount of shares that would be exchanged by the vault for the amount of assets provided.
    function _convertToShares(uint256 assets, Math.Rounding) internal pure override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : assets.mulDivDown(supply, _nav());
    }

    /// @notice This function returns the amount of assets that would be exchanged by the vault for the amount of shares provided.
    function _convertToAssets(uint256 shares, Math.Rounding) internal pure override returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : shares.mulDivDown(_nav(), supply);
    }

    /// @notice Internal deposit function used by `deposit()` and `mint()`. Accrues rewards for the `caller` and `receiver`.
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares)
        internal
        override
        accrueRewards(caller, receiver)
    {
        IERC20(asset()).safeTransferFrom(caller, address(this), assets);

        _mint(receiver, shares);

        //@todo: do we want to rebalance on deposit, or wait for harvest to allocate?

        emit Deposit(caller, receiver, assets, shares);
    }

    /// @notice Internal withdraw function used by `withdraw()` and `redeem()`. Accrues rewards for the `caller` and `receiver`.
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
        accrueRewards(owner, receiver)
    {
        if (caller != owner) {
            _approve(owner, msg.sender, allowance(owner, msg.sender) - shares);
        }

        // @todo: logic to withdraw from silo
        // decide if we want to rebalance on withdrawal

        _burn(owner, shares);
        IERC20(asset()).safeTransfer(receiver, assets);

        emit Withdraw(caller, receiver, owner, assets, shares);
    }

    /// @notice Internal transfer function used by `transfer()` and `transferFrom()`. Accrues rewards for `from` and `to`.
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

    event RewardsClaimed(address indexed user, IERC20 rewardToken, uint256 amount, bool escrowed);

    error ZeroRewards(IERC20 rewardToken);

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

    IERC20[] public rewardTokens;

    // rewardToken -> RewardInfo
    mapping(IERC20 => RewardInfo) public rewardInfos;
    // user => rewardToken -> rewardsIndex
    mapping(address => mapping(IERC20 => uint256)) public userIndex;
    // user => rewardToken -> accruedRewards
    mapping(address => mapping(IERC20 => uint256)) public accruedRewards;

    error RewardTokenAlreadyExist(IERC20 rewardToken);
    error RewardTokenDoesntExist(IERC20 rewardToken);
    error ZeroAmount();
    error NotSubmitter(address submitter);
    error RewardsAreDynamic(IERC20 rewardToken);
    error InvalidConfig();

    /**
     * @notice Allows owner to add a reward token to Meta Silo
     * @dev Reward token must be an ERC20
     * @param tokenAddress address of the reward token
     */
    function addRewardToken(address tokenAddress) external onlyOwner {
        IERC20 rewardToken = IERC20(tokenAddress);
        require(!rewardInfos[rewardToken].exists, "REWARD_TOKEN_ALREADY_ADDED");
        
        rewardInfos[rewardToken] = RewardInfo({
            decimals: uint8(rewardToken.decimals()),
            exists: true
        });
        rewardTokens.push(rewardToken);
    }

    // @todo: may not be required (public array with solc 0.8)
    // function getAllRewardsTokens() external view returns (IERC20[] memory) {
    //     return rewardTokens;
    // }

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

            // If a deposit/withdraw operation gets called for another user we should accrue for both of them to avoid potential issues like in the Convex-Vulnerability
            if (_receiver != _caller) _accrueUser(_caller, rewardToken);
        }
        _;
    }

    /// @notice Accrue global rewards for a rewardToken
    function _accrueRewards(IERC20 _rewardToken, uint256 accrued) internal {
        uint256 supplyTokens = totalSupply();
        if (supplyTokens != 0) {
            uint224 deltaIndex = accrued.mulDiv(
                uint256(10 ** decimals()),
                supplyTokens,
                Math.Rounding.Down
            ).safeCastTo224();

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

    // @todo: Some reentrancy concerns on the silo interactions. Should use checks-effects-interactions pattern.

    mapping(address => bool) public silos;

    IERC20[] public siloList;

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
     * @notice Withdraws to a given silo
     * @param _silo address of the silo to be withdrawn from
     * @param _amount amount of asset to be withdrawn
     */ 
    function _withdrawFromSilo(address _silo, uint256 _amount) internal {
        require(silos[_silo], "SILO_NOT_FOUND");
        ISilo(_silo).deposit(_amount, address(this), address(this));
    }

    function _claimRewardsFromSilos() internal {
        // Claim each reward from platform
        for (uint i = 0; i < rewardTokens.length; i++) {
            IERC20 reward = rewardTokens[i];
            // @todo: claim rewards from each silo
            // Cache RewardInfo
            // RewardInfo memory rewards = rewardInfos[rewardToken];
            // Update the index of rewardInfo before updating the rewardInfo
            // _accrueRewards(rewardToken, amount);
            // rewardsEarned[reward] += amount;
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
        siloList.push(_silo);
    }

    /**
     * @notice Allows owners to remove a silo
     * @dev Allocation to Silo will be withdrawn before removing Silo
     * @param _silo address of the silo to be removed   
     */ 
    function removeSilo(address _silo) public onlyOwner {
        require(silos[_silo], "SILO_NOT_FOUND");
        // @todo: logic to withdraw all assets from this silo
        // @todo: need to consider illiquid scenario
        delete silos[_silo];
    }

    /// @notice View functions to return the number of Silos attached to Meta Silo
    function numSilos() public view returns (uint256) {
        return siloList.length;
    }

    /*//////////////////////////////////////////////////////////////
                      HARVEST LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice harvest logic for Meta Silo
     * @notice harvests rewards from all silos and rebalance allocation
     */ 

    function harvest() external {
        claimRewardsFromSilos();
    }

    function rebalance() internal {
        // @todo: rebalance logic
        // what's the amount to allocate optimally?
        // 
    }

    function nav() external view returns (uint256) {
        return _nav();
    }

    /**
     * @notice Function to retreive the net asset value of the Meta Silo
     * @notice This excludes non-native token rewards, that are accrued separately in accruedRewards
     */ 
    function _nav() internal returns (uint256) {
        uint256 totalFromSilos = 0;

        for (uint256 i = 0; i < siloList.length; i++) {
            address _silo = siloList[i];
            // ISilo silo = ISilo(siloAddress);
            // totalFromSilos += silo.balanceOf(address(this)); // @todo: check silo interface to retreive deposited balance
        }

        return asset.balanceOf(address(this)) + totalFromSilos;
    }

}
