// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {Math} from "openzeppelin-contracts/utils/math/Math.sol";

import {ISiloConfig} from "./interfaces/ISiloConfig.sol";
import {IInterestRateModelV2} from "./interfaces/IInterestRateModelV2.sol";
import {ISilo} from "./interfaces/ISilo.sol";

import {IBalancerMinter} from "./interfaces/IBalancerMinter.sol";
import {ISiloLiquidityGauge} from "./interfaces/ISiloLiquidityGauge.sol";

import "./lib/SolverLib.sol";

/// @notice MetaSilo: An ERC-4626 compliant single asset vault that dynamically lends to multiple silos.
/// @notice This contract handles multiple rewards, which can be claimed by the depositors.

contract MetaSilo is ERC4626, Ownable {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    bool public isEmergency;
    address public constant SILO = 0x6f80310CA7F2C654691D1383149Fa1A57d8AB1f8;
    address[] public silos;
    address[] public removedSilos;
    mapping(address => address) public gauge;

    struct RewardInfo {
        uint8 rewardDecimals;
        uint256 index;
        address gauge;
    }

    ERC20[] public rewardTokens;
    mapping(ERC20 => RewardInfo) public rewardInfos;
    mapping(address => mapping(ERC20 => uint256)) public accruedRewards;
    mapping(address => mapping(ERC20 => uint256)) internal _userIndex;
    IBalancerMinter public balancerMinter;

    constructor(ERC20 _asset, string memory _name, string memory _symbol, address _balancerMinter)
        ERC4626(_asset, _name, _symbol)
    {
        balancerMinter = IBalancerMinter(_balancerMinter);
    }

    /*//////////////////////////////////////////////////////////////
                        OVERRIDE FROM SOLMATE
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver)
        public
        override
        accrueRewards(receiver)
        returns (uint256 shares)
    {
        require(isEmergency == false, "EMERGENCY_MODE");
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
        _afterDeposit(assets);
    }

    function mint(uint256 shares, address receiver) public override accrueRewards(receiver) returns (uint256 assets) {
        require(isEmergency == false, "EMERGENCY_MODE");
        assets = previewMint(shares);
        asset.safeTransferFrom(msg.sender, address(this), assets);
        _mint(receiver, shares);
        emit Deposit(msg.sender, receiver, assets, shares);
        _afterDeposit(assets);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        accrueRewards(receiver)
        returns (uint256 shares)
    {
        shares = previewWithdraw(assets);
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }
        _beforeWithdraw(assets);
        _burn(owner, shares);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        asset.safeTransfer(receiver, assets);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        override
        accrueRewards(receiver)
        returns (uint256 assets)
    {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender];
            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");
        _beforeWithdraw(assets);
        _burn(owner, shares);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        asset.safeTransfer(receiver, assets);
    }

    function totalAssets() public view override returns (uint256) {
        uint256 totalFromSilos;
        for (uint256 i = 0; i < silos.length; i++) {
            ISilo silo = ISilo(silos[i]);
            totalFromSilos += silo.convertToAssets(silo.balanceOf(address(this)));
        }
        return asset.balanceOf(address(this)) + totalFromSilos;
    }

    /*//////////////////////////////////////////////////////////////
                    METASILO SPECIFIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function harvest() public {
        _harvestRewards();
    }

    function _harvestRewards() internal {
        ERC20 siloReward = ERC20(SILO);
        uint256 siloBalanceBefore = siloReward.balanceOf(address(this));
        for (uint256 i = 0; i < silos.length; i++) {
            if (gauge[silos[i]] != address(0)) {
                balancerMinter.mintFor(gauge[silos[i]], address(this));
            }
        }
        _accrueRewards(siloReward, siloReward.balanceOf(address(this)) - siloBalanceBefore);
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            ERC20 reward = rewardTokens[i];
            if (reward == ERC20(SILO)) continue;
            RewardInfo memory rewards = rewardInfos[reward];
            uint256 balanceBefore = reward.balanceOf(address(this));
            ISiloLiquidityGauge(rewards.gauge).claim_rewards(address(this), address(this));
            _accrueRewards(reward, reward.balanceOf(address(this)) - balanceBefore);
        }
    }

    function reallocateManual(uint256[] memory proposed) public onlyOwner {
        _reallocate(proposed);
    }

    function reallocateWithSolver() public {
        _reallocate(_solveDistribution(totalAssets()));
    }

    function _reallocate(uint256[] memory proposed) internal {
        for (uint256 i = 0; i < silos.length; i++) {
            uint256 current = _getSiloDeposit(silos[i]);
            if (current > proposed[i]) {
                uint256 amount = current - proposed[i];
                _withdrawFromSilo(silos[i], amount);
            }
        }
        uint256 remaining = totalAssets();
        for (uint256 i = 0; i < silos.length; i++) {
            uint256 amountToDeposit = proposed[i] - _getSiloDeposit(silos[i]);
            if (amountToDeposit > 0) {
                _depositToSilo(silos[i], Math.min(remaining, amountToDeposit));
                remaining -= amountToDeposit;
            }
            if (remaining == 0) {
                break;
            }
        }
    }

    function _solveDistribution(uint256 _total) internal returns (uint256[] memory) {
        (uint256[] memory uopt, uint256[] memory ucrit) = _getConfig();
        return SolverLib._solver(_getBorrowAmounts(), _getDepositAmounts(), uopt, ucrit, _total);
    }

    function setEmergency(bool _isEmergency) public onlyOwner {
        isEmergency = _isEmergency;
    }

    function addSilo(address _siloAddress, address _gaugeAddress) public onlyOwner {
        for (uint256 i = 0; i < silos.length; i++) {
            require(silos[i] != _siloAddress, "SILO_ALREADY_ADDDED");
        }
        silos.push(_siloAddress);
        if (_gaugeAddress != address(0)) gauge[_siloAddress] = _gaugeAddress;
    }

    function addMultipleSilos(address[] memory _siloAddresses, address[] memory _gaugeAddresses) external onlyOwner {
        for (uint256 i = 0; i < _siloAddresses.length; i++) {
            for (uint256 j = 0; j < silos.length; j++) {
                require(_siloAddresses[i] != silos[j], "SILO_ALREADY_ADDDED");
            }
            silos.push(_siloAddresses[i]);
            if (_gaugeAddresses[i] != address(0)) gauge[_siloAddresses[i]] = _gaugeAddresses[i];
        }
    }

    function removeSilo(address _siloAddress) public onlyOwner {
        _withdrawFromSilo(_siloAddress, type(uint256).max);
        for (uint256 i = 0; i < silos.length; i++) {
            if (silos[i] == _siloAddress) {
                silos[i] = silos[silos.length - 1];
                silos.pop();
                break;
            }
        }
        if (ISilo(_siloAddress).balanceOf(address(this)) > 0) {
            removedSilos.push(_siloAddress);
        }
    }

    function withdrawFromRemovedSilo(address _siloAddress) public onlyOwner {
        for (uint256 i = 0; i < removedSilos.length; i++) {
            if (removedSilos[i] == _siloAddress) {
                _withdrawFromSilo(_siloAddress, type(uint256).max);
                if (ISilo(_siloAddress).balanceOf(address(this)) == 0) {
                    removedSilos[i] = removedSilos[removedSilos.length - 1];
                    removedSilos.pop();
                }
                break;
            }
        }
    }

    function _getSiloDeposit(address _siloAddress) internal returns (uint256) {
        ISilo silo = ISilo(_siloAddress);
        return silo.convertToAssets(silo.balanceOf(address(this)));
    }

    function _depositToSilo(address _siloAddress, uint256 _amount) internal {
        ISilo(_siloAddress).deposit(_amount, address(this));
    }

    function _getDepositAmounts() internal returns (uint256[] memory) {
        uint256 numSilos = silos.length;
        uint256[] memory depositAmounts = new uint256[](numSilos);
        for (uint256 i = 0; i < numSilos; i++) {
            address silo = silos[i];
            depositAmounts[i] = ISilo(silo).getCollateralAssets();
        }
        return depositAmounts;
    }

    function _getBorrowAmounts() internal returns (uint256[] memory) {
        uint256 numSilos = silos.length;
        uint256[] memory borrowAmounts = new uint256[](numSilos);
        for (uint256 i = 0; i < numSilos; i++) {
            address silo = silos[i];
            borrowAmounts[i] = ISilo(silo).getDebtAssets();
        }
        return borrowAmounts;
    }

    function _getConfig() internal returns (uint256[] memory uopt, uint256[] memory ucrit) {
        uint256 numSilos = silos.length;
        uopt = new uint256[](numSilos);
        ucrit = new uint256[](numSilos);

        for (uint256 i = 0; i < numSilos; i++) {
            ISilo silo = ISilo(silos[i]);
            ISiloConfig siloConfig = silo.config();
            ISiloConfig.ConfigData memory configData = siloConfig.getConfig(address(silo));
            IInterestRateModelV2.ConfigWithState memory modelConfig =
                IInterestRateModelV2(configData.interestRateModel).getConfig(address(silo));

            uopt[i] = uint256(modelConfig.uopt);
            ucrit[i] = uint256(modelConfig.ucrit);
        }
        return (uopt, ucrit);
    }

    function _withdrawFromSilo(address _siloAddress, uint256 _amount) internal returns (uint256 _withdrawn) {
        ISilo silo = ISilo(_siloAddress);
        uint256 _availableToWithdraw = silo.maxWithdraw(address(this));
        return silo.withdraw(Math.min(_amount, _availableToWithdraw), address(this), address(this));
    }

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

    function addRewardToken(ERC20 rewardToken, address _gauge, uint8 _rewardDecimals) external onlyOwner {
        rewardTokens.push(rewardToken);
        rewardInfos[rewardToken] = RewardInfo({rewardDecimals: _rewardDecimals, index: 0, gauge: _gauge});
    }

    modifier accrueRewards(address _receiver) {
        ERC20[] memory _rewardTokens = rewardTokens;
        for (uint8 i; i < _rewardTokens.length; i++) {
            ERC20 rewardToken = _rewardTokens[i];
            RewardInfo memory rewards = rewardInfos[rewardToken];
            _accrueUser(_receiver, rewardToken);
        }
        _;
    }

    function _accrueUser(address _user, ERC20 _rewardToken) internal {
        RewardInfo memory rewards = rewardInfos[_rewardToken];
        uint256 oldIndex = _userIndex[_user][_rewardToken];
        uint256 deltaIndex = rewards.index - oldIndex;
        uint256 supplierDelta = maxWithdraw(_user).mulDivDown(deltaIndex, uint256(1e18));
        _userIndex[_user][_rewardToken] = rewards.index;
        accruedRewards[_user][_rewardToken] += supplierDelta;
    }

    function _accrueRewards(ERC20 _rewardToken, uint256 accrued) internal {
        RewardInfo memory rewards = rewardInfos[_rewardToken];
        uint256 supplyTokens = _rewardToken.totalSupply();
        if (supplyTokens != 0) {
            uint256 deltaIndex = accrued.mulDivDown(uint256(10 ** rewards.rewardDecimals), supplyTokens);
            rewards.index += deltaIndex;
        }
    }

    function claimRewards() external accrueRewards(msg.sender) {
        address user = address(msg.sender);
        for (uint8 i; i < rewardTokens.length; i++) {
            uint256 rewardAmount = accruedRewards[user][rewardTokens[i]];
            if (rewardAmount == 0) continue;
            accruedRewards[user][rewardTokens[i]] = 0;
            rewardTokens[i].safeTransfer(user, rewardAmount);
        }
    }
}
