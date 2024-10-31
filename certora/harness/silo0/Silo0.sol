// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {SiloLendingLib} from "silo-core/contracts/lib/SiloLendingLib.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {SiloHarness} from "../SiloHarness.sol";
import {ISiloFactory} from "silo-core/contracts/interfaces/ISiloFactory.sol";
import {ShareTokenLib} from "silo-core/contracts//lib/ShareTokenLib.sol";
import {SiloERC4626Lib} from "silo-core/contracts//lib/SiloERC4626Lib.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

contract Silo0 is SiloHarness {
    constructor(ISiloFactory _siloFactory) SiloHarness(_siloFactory) {}

    function _accrueInterest_orig() external
        returns (uint256 accruedInterest, ISiloConfig.ConfigData memory configData)
    {
        configData = ShareTokenLib.siloConfig().getConfig(address(this));

        accruedInterest = _accrueInterestForAsset(
            configData.interestRateModel,
            configData.daoFee,
            configData.deployerFee
        );
    }

    
    function _callAccrueInterestForAsset_orig(
        address _interestRateModel,
        uint256 _daoFee,
        uint256 _deployerFee,
        address _otherSilo
    ) external virtual returns (uint256 accruedInterest) {
        if (_otherSilo != address(0) && _otherSilo != address(this)) {
            ISilo(_otherSilo).accrueInterest();
        }

        accruedInterest = SiloLendingLib.accrueInterestForAsset(
            _interestRateModel,
            _daoFee,
            _deployerFee
        );

        if (accruedInterest != 0) emit AccruedInterest(accruedInterest);
    }

    //This is reduandant, there is a config() in silo.sol
/*    function getSiloConfig() external view returns (ISiloConfig) {
        return ShareTokenLib.siloConfig();
    }
*/
    function ERC4626Deposit(
        address _token,
        address _depositor,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        IShareToken _collateralShareToken,
        ISilo.CollateralType _collateralType
    ) external returns (uint256, uint256) {
        return SiloERC4626Lib.deposit(
            _token,
            _depositor,
            _assets,
            _shares,
            _receiver,
            _collateralShareToken,
            _collateralType
        );
    }
}
