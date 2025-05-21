// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISilo, IERC3156FlashLender} from "silo-core/contracts/interfaces/ISilo.sol";
import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";

import {ISilo, IERC4626, IERC3156FlashLender} from "./ISilo.sol";
import {IShareToken} from "./IShareToken.sol";

import {IERC3156FlashBorrower} from "./IERC3156FlashBorrower.sol";
import {ISiloConfig} from "./ISiloConfig.sol";
import {ISiloFactory} from "./ISiloFactory.sol";
import {ISiloOracle} from "./ISiloOracle.sol";

import {IZeroExSwapModule} from "../interfaces/IZeroExSwapModule.sol";

interface ISiloLeverage {
    /// @param flashDebtLender address from where contract will get flashloan
    /// @param token token address
    /// @param amount flash amount
    struct FlashArgs {
        address flashDebtLender;
        address token;
        uint256 amount;
    }

    /// @param amount raw deposit amount (without flashloan amount)
    struct DepositArgs {
        ISilo silo;
        uint256 amount;
        ISilo.CollateralType collateralType;
        address receiver;
    }

    error FlashloanFailed();
    error InvalidFlashloanLender();

    /// @dev It can revert when:
    /// - amount is so hi we can not calculate fee
    function leverage(
        FlashArgs calldata _flashArgs,
        IZeroExSwapModule.SwapArgs calldata _swapArgs,
        DepositArgs calldata _depositArgs,
        ISilo _borrowSilo
    ) external returns (uint256 multiplier);

//
//    function closeLeverage(
//        ISilo _silo,
//        ISilo.CollateralType _collateralType,
//        IERC3156FlashLender _flashloanLender
//    ) external view virtual override returns (ISilo);
//
//    function onFlashLoan(address _initiator, address _token, uint256 _amount, uint256 _fee, bytes calldata _data)
//        external
//        returns (bytes32);
}
