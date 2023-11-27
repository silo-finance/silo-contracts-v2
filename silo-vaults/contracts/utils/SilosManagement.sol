// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

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

import {SolverLib} from "./lib/SolverLib.sol";
import {MetaSiloERC4626} from "./utils/MetaSiloERC4626.sol";


abstract contract SilosManagement is Ownable {
    /// @param active
    struct SiloData {
        address silo;
        address gauge;
        bool active;
        bool withdrawPending;
    }

    // TODO maybe struct with other variables used by whole SiloMEta to lower gas? go back to it at the end
    uint256 siloMapIndex;

    // TODO LP => data, where LP is 0, 1, 2,...
    // using LP we can easily iterate, challange is to no have duplicates,
    // but if this is ownable, then we can check offchain OR if we relly want, iterate when adding
    mapping(uint256 => SiloData) public siloMap;


    // TODO consider mapping, but first let's build full functionality
    address[] public silos;
    address[] public removedSilos;

    // silo => gauge
    mapping(address => address) public gauges;

    error SiloAlreadyAdded();

    event SiloAdded(address silo, address balancerMinter);
    event SiloRemoved(address silo);
    event WithdrawPending(address silo);

    function siloExists(address _siloAddress) external view returns (bool exist) {
        for (uint256 i; i < nextLp; i++) {
            if (siloMap[i].silo != address(0)) return true;
        }
    }

    /**
     * @notice Allows owner to add a single silo
     * @param _siloAddress Address of the silo
     * @param _gaugeAddress Address of the associated balancerMinter
     */
    function addSilo(address _siloAddress, address _gaugeAddress) public onlyOwner {
        _addSilo(_siloAddress, _gaugeAddress);
    }

    /**
     * @notice Allows owner to add multiple silos
     * @param _siloAddresses Array of silo addresses
     * @param _gaugeAddresses Array of associated balancerMinter addresses
     */
    function addMultipleSilos(address[] calldata _siloAddresses, address[] calldata _gaugeAddresses) external onlyOwner {
        for (uint256 i = 0; i < _silos.length;) {
            _addSilo(_siloAddresses[i], _gaugeAddresses[i]);
            unchecked { i++; }
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
        uint256 index = -1; // TODO

        for (uint256 i = 0; i < silos.length; i++) {
            if (silos[i] == _siloAddress) {
                // Move last element to index
                silos[index] = silos[silos.length - 1];
                // Reduce length
                silos.pop();
                break;
            }
        }

        // Track removed silo if not emptied
        if (ISilo(_siloAddress).balanceOf(address(this)) > 0) {
            removedSilos.push(_siloAddress);
        }

        emit SiloRemoved(_siloAddress);
    }

    function _addSilo(address _siloAddress, address _gaugeAddress) internal {
        // TODO does every silo have gauge?
        if (gauges[_siloAddress] != address(0)) revert SiloAlreadyAdded();

        silos.push(_siloAddress);
        gauges[_siloAddress] = _gaugeAddress;

        emit SiloAdded(_siloAddress, _balancerMinterAddress);
    }

    // @todo: function to handle removedSilos when it's empty
    // @todo: owner function to manually withdraw from removeSilos

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
            D[i] = ISilo(silo).getCollateralAssets();
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
            B[i] = ISilo(silo).getDebtAssets();
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
}
