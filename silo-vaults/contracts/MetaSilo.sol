// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.18;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeTransferLib} from "@solmate/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";

import {ISilo} from "@silo/silo-contracts-v2/silo-core/contracts/Silo.sol";

import "./lib/SolverLib.sol";
import {SiloManager} from "./manager/SiloManager.sol";
import {RewardsManager} from "./manager/RewardsManager.sol";
import {HarvestManager} from "./manager/HarvestManager.sol";

/// @notice MetaSilo: An ERC-4626 compliant single asset vault that dynamically lends to multiple silos.
/// @notice This contract handles multiple rewards, which can be claimed by the depositors.

contract MetaSilo is ERC20, SiloManager, RewardsManager, HarvestManager {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using Math for uint256;

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);

    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    ERC20 public immutable asset;

    constructor(ERC20 _asset, string memory _name, string memory _symbol, address _balancerMinter)
        ERC20(_name, _symbol, _asset.decimals())
    {
        asset = _asset;
        _setBalancerMinter(_balancerMinter);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(uint256 assets, address receiver) public accrueRewards(receiver) returns (uint256 shares) {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");

        require(isEmergency == false, "EMERGENCY_MODE");

        // Need to transfer before minting or ERC-777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        _afterDeposit(assets);
    }

    function mint(uint256 shares, address receiver) public accrueRewards(receiver) returns (uint256 assets) {
        require(isEmergency == false, "EMERGENCY_MODE");

        // No need to check for rounding error, previewMint rounds up.
        assets = previewMint(shares);

        // Need to transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        _afterDeposit(assets);
    }

    function withdraw(uint256 assets, address receiver, address owner)
        public
        accrueRewards(receiver)
        returns (uint256 shares)
    {
        // No need to check for rounding error, previewWithdraw rounds up.
        shares = previewWithdraw(assets);

        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        _beforeWithdraw(assets);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    function redeem(uint256 shares, address receiver, address owner)
        public
        accrueRewards(receiver)
        returns (uint256 assets)
    {
        if (msg.sender != owner) {
            uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
        }

        // Check for rounding error since we round down in previewRedeem.
        require((assets = previewRedeem(shares)) != 0, "ZERO_ASSETS");

        _beforeWithdraw(assets);

        _burn(owner, shares);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);

        asset.safeTransfer(receiver, assets);
    }

    /*//////////////////////////////////////////////////////////////
                            ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? assets : assets.mulDivDown(supply, _nav());
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? shares : shares.mulDivDown(_nav, supply);
    }

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? shares : shares.mulDivUp(_nav(), supply);
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply;
        return supply == 0 ? assets : assets.mulDivUp(supply, _nav());
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    function _nav() internal view returns (uint256) {
        uint256 totalFromSilos;

        for (uint256 i = 0; i < silos.length; i++) {
            ISilo silo = ISilo(silos[i]);
            totalFromSilos += silo.convertToAssets(silo.balanceOf(address(this)));
        }

        return totalAssets() + totalFromSilos;
    }

    function nav() external view returns (uint256) {
        return _nav();
    }

    /*//////////////////////////////////////////////////////////////
                     DEPOSIT/WITHDRAWAL LIMIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function maxDeposit(address) public view returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        return convertToAssets(balanceOf[owner]);
    }

    function maxRedeem(address owner) public view returns (uint256) {
        return balanceOf[owner];
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

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
}
