// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {SiloStdLib, ISiloConfig, IShareToken, ISilo} from "./SiloStdLib.sol";
import {IERC3156FlashBorrower} from "../interface/IERC3156FlashBorrower.sol";
import {SiloLendingLib, IERC20Upgradeable} from "./SiloLendingLib.sol";

library SiloFlashloanLib {
    error CallbackFailed();
    error InsufficientRepay();

    function maxFlashLoan(
        address _token,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal view returns (uint256 assets) {
        return SiloStdLib.liquidity(_token, _assetStorage);
    }

    /// @dev Follows https://eips.ethereum.org/EIPS/eip-3156
    function flashloan(
        ISiloConfig _config,
        address _token,
        uint256 _assets,
        IERC3156FlashBorrower _receiver,
        bytes memory _flashloanReceiverData,
        mapping(address => ISilo.AssetStorage) storage _assetStorage
    ) internal returns (uint256 shares) {
        ISiloConfig.ConfigData memory configData = _config.getConfig();

        if (_assets > maxFlashLoan(_token, _assetStorage)) revert SiloLendingLib.NotEnoughLiquidity();
        if (configData.token0 != _token && configData.token1 != _token) revert SiloStdLib.WrongToken();

        IERC20Upgradeable(_token).safeTransferFrom(address(this), address(_receiver), _assets);
        
        bytes32 callbackSuccess = keccak256("ERC3156FlashBorrower.onFlashLoan");
        bytes32 response = _receiver.onFlashLoan(msg.sender, _token, _assets, 0, _flashloanReceiverData);

        if (response != callbackSuccess) revert CallbackFailed();

        uint256 balanceBeforeRepay = IERC20Upgradeable(_token).balanceOf(address(this));
        IERC20Upgradeable(_token).safeTransferFrom(address(_receiver), address(this), _assets);
        uint256 balanceAfterRepay = IERC20Upgradeable(_token).balanceOf(address(this));

        if (balanceAfterRepay - balanceBeforeRepay < _assets) revert InsufficientRepay();

        return true;
    }
}
