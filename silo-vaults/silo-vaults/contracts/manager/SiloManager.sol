// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import {ISilo, ISiloConfig} from "silo-core/contracts/Silo.sol";
import {InterestRateModelV2, IInterestRateModel} from "silo-core/contracts/interestRateModel/InterestRateModelV2.sol";

import {MathUpgradeable as Math} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

import {IERC20Upgradeable as IERC20} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

abstract contract SiloManager is Ownable {
    address[] public silos;
    address[] public removedSilos;
    mapping(address => address) public gauge;

    bool public isEmergency;
    IBalancerMinter public balancerMinter;

    /// Errors
    error SiloAlreadyAdded();

    /// Events
    event SiloAdded(address silo, address balancerMinter);
    event SiloRemoved(address silo);
    event IsEmergency(bool);

    /**
     * @notice Allows owner to add a single silo.
     * @param _siloAddress Address of the silo.
     * @param _gaugeAddress Address of the associated balancerMinter.
     */
    function addSilo(address _siloAddress, address _gaugeAddress) public onlyOwner {
        for (uint256 i = 0; i < silos.length; i++) {
            if (silos[i] != _siloAddress) revert SiloAlreadyAdded();
        }
        silos.push(_siloAddress);
        gauge[_siloAddress] = _gaugeAddress;
        emit SiloAdded(_siloAddress, _gaugeAddress);
    }

    /**
     * @notice Allows owner to add multiple silos.
     * @param _siloAddresses Array of silo addresses.
     * @param _gaugeAddresses Array of associated balancerMinter addresses.
     */
    function addMultipleSilos(address[] memory _siloAddresses, address[] memory _gaugeAddresses) external onlyOwner {
        for (uint256 i = 0; i < _siloAddresses.length; i++) {
            for (uint256 j = 0; j < silos.length; j++) {
                if (_siloAddresses[i] == silos[j]) revert SiloAlreadyAdded();
            }
            silos.push(_siloAddresses[i]);
            gauge[_siloAddresses[i]] = _gaugeAddresses[i];
            emit SiloAdded(_siloAddresses[i], address(balancerMinter));
        }
    }

    /**
     * @notice Allows owner to remove a silo.
     * @dev If full withdrawal from that silo is not possible, we add it to removedSilos array.
     * @param _siloAddress Address of silo to remove.
     */
    function removeSilo(address _siloAddress) public onlyOwner {
        _withdrawFromSilo(_siloAddress, type(uint256).max);

        for (uint256 i = 0; i < silos.length; i++) {
            if (silos[i] == _siloAddress) {
                silos[i] = silos[silos.length - 1];
                silos.pop();
                break;
            }
        }

        /// @notice Track removed silo if not emptied.
        if (ISilo(_siloAddress).shareBalanceOf(address(this)) > 0) {
            removedSilos.push(_siloAddress);
        }

        emit SiloRemoved(_siloAddress);
    }

    /**
     * @notice Withdraws all funds from a previously removed silo.
     * @param _siloAddress Address of the removed silo to withdraw from.
     * @dev Loops to validate silo is in removedSilos array.
     * @dev Withdraws full share balance for this contract.
     * @dev If fully withdrawn, removes silo from removedSilos.
     */
    function withdrawFromRemovedSilo(address _siloAddress) public onlyOwner {
        for (uint256 i = 0; i < removedSilos.length; i++) {
            if (removedSilos[i] == _siloAddress) {
                _withdrawFromSilo(_siloAddress, type(uint256).max);
                if (ISilo(_siloAddress).shareBalanceOf(address(this)) == 0) {
                    removedSilos[i] = removedSilos[removedSilos.length - 1];
                    removedSilos.pop();
                }
                break;
            }
        }
    }

    /**
     * @notice Allows owner to set emergency, which restrict new deposits.
     * @param _isEmergency Bool to indicate if emergency is activated.
     */
    function setEmergency(bool _isEmergency) public onlyOwner {
        isEmergency = _isEmergency;
        emit SiloRemoved(isEmergency);
    }

    /**
     * @notice Gets the deposited asset amount for a silo.
     * @param _siloAddress The address of the silo.
     * @return The underlying deposited asset amount.
     */
    function _getSiloDeposit(address _siloAddress) internal returns (uint256) {
        ISilo silo = ISilo(_siloAddress);
        return silo.convertToAssets(silo.shareBalanceOf(address(this)));
    }

    /**
     * @notice Deposits to a given silo.
     * @param _siloAddress address of the silo to be deposited to.
     * @param _amount amount of asset to be deposited.
     */
    function _depositToSilo(address _siloAddress, uint256 _amount) internal {
        ISilo(_siloAddress).deposit(_amount, address(this));
    }

    /**
     * @notice Fetches the deposit amounts for each silo.
     * @return An array containing the deposit amount for each silo.
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
     * @notice Fetches the BORROW amounts for each silo.
     * @return An array containing the BORROW amount for each silo.
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
     * @notice Gets optimal and critical utilizations for each silo.
     * @return uopt Array of optimal utilizations for each silo.
     * @return ucrit Array of critical utilizations for each silo.
     */
    function _getConfig() internal returns (uint256[] memory uopt, uint256[] memory ucrit) {
        uint256 numSilos = silos.length;
        uopt = new uint256[](numSilos);
        ucrit = new uint256[](numSilos);

        for (uint256 i = 0; i < numSilos; i++) {
            ISilo silo = ISilo(silos[i]);
            ISiloConfig siloConfig = silo.config();
            ISiloConfig.ConfigData memory configData = siloConfig.getConfig();
            //TODO define what asset to pass as a second param for getConfig
            IERC20 asset = IERC20(address(0));
            IInterestRateModel.ConfigWithState memory modelConfig =
                IInterestRateModel(configData.interestRateModel0).getConfig(address(silo), address(asset));

            uopt[i] = modelConfig.uopt;
            ucrit[i] = modelConfig.ucrit;
        }
        return (uopt, ucrit);
    }

    /**
     * @notice Withdraws from a given silo.
     * @param _siloAddress address of the silo to be withdrawn from.
     * @param _amount amount of asset to be withdrawn.
     */
    function _withdrawFromSilo(address _siloAddress, uint256 _amount) internal returns (uint256 _withdrawn) {
        ISilo silo = ISilo(_siloAddress);
        uint256 _availableToWithdraw = silo.maxWithdraw(address(this));
        return silo.withdraw(Math.min(_amount, _availableToWithdraw), address(this), address(this));
    }
}
