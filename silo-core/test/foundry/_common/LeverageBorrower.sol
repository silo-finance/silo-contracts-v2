// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ILeverageBorrower} from "silo-core/contracts/interfaces/ILeverageBorrower.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";

contract LeverageBorrower is ILeverageBorrower {
    bytes32 public constant LEVERAGE_CALLBACK = keccak256("ILeverageBorrower.onLeverage");

    function onLeverage(address, address _borrower, address, uint256, bytes calldata _data)
        external
        returns (bytes32)
    {
        (address collateralSilo, address collateralAsset, uint256 collateralAssets) =
            abi.decode(_data, (address, address, uint256));

        IERC20Upgradeable(collateralAsset).approve(collateralSilo, collateralAssets);
        ISilo(collateralSilo).deposit(collateralAssets, _borrower);

        return LEVERAGE_CALLBACK;
    }
}
