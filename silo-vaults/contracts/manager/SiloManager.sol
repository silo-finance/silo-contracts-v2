// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Math} from "openzeppelin-contracts/utils/math/Math.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

import {ISiloConfig} from ".././interfaces/ISiloConfig.sol";
import {ISilo} from ".././interfaces/ISilo.sol";
import {IInterestRateModel} from ".././interfaces/IInterestRateModel.sol";

abstract contract SiloManager is Ownable {
    address[] public silos;
    address[] public removedSilos;
    mapping(address => address) public gauge;

    bool public isEmergency;

    event IsEmergency(bool);

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

        /// @notice Track removed silo if not emptied.
        if (ISilo(_siloAddress).shareBalanceOf(address(this)) > 0) {
            removedSilos.push(_siloAddress);
        }

    }

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

    function _getSiloDeposit(address _siloAddress) internal returns (uint256) {
        ISilo silo = ISilo(_siloAddress);
        return silo.convertToAssets(silo.shareBalanceOf(address(this)));
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

    function _getConfig() internal returns (int256[] memory uopt, int256[] memory ucrit) {
        uint256 numSilos = silos.length;
        uopt = new int256[](numSilos);
        ucrit = new int256[](numSilos);

        for (uint256 i = 0; i < numSilos; i++) {
            ISilo silo = ISilo(silos[i]);
            ISiloConfig siloConfig = silo.config();
            ISiloConfig.ConfigData memory configData = siloConfig.getConfig(address(silo));
            IInterestRateModel.ConfigWithState memory modelConfig =
                IInterestRateModel(configData.interestRateModel).getConfig(address(silo));
                
            uopt[i] = modelConfig.uopt;
            ucrit[i] = modelConfig.ucrit;
        }
        return (uopt, ucrit);
    }

    function _withdrawFromSilo(address _siloAddress, uint256 _amount) internal returns (uint256 _withdrawn) {
        ISilo silo = ISilo(_siloAddress);
        uint256 _availableToWithdraw = silo.maxWithdraw(address(this));
        return silo.withdraw(Math.min(_amount, _availableToWithdraw), address(this), address(this));
    }
}
