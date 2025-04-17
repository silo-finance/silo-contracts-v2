// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {CryticIERC4626Internal} from "properties/ERC4626/util/IERC4626Internal.sol";
import {TestERC20Token} from "properties/ERC4626/util/TestERC20Token.sol";

import {Silo, ISilo} from "silo-core/contracts/Silo.sol";
import {ISiloFactory} from "silo-core/contracts/SiloFactory.sol";
import {ShareTokenLib} from "silo-core/contracts/lib/ShareTokenLib.sol";
import {SiloStorageLib} from "silo-core/contracts/lib/SiloStorageLib.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";

contract SiloInternal is Silo, CryticIERC4626Internal {
    constructor(ISiloFactory _siloFactory) Silo(_siloFactory) {
        factory = _siloFactory;
    }

    function _$() internal pure returns (ISilo.SiloStorage storage) {
        return SiloStorageLib.getSiloStorage();
    }

    function recognizeProfit(uint256 profit) public {
        IShareToken.ShareTokenStorage storage _sharedStorage = ShareTokenLib.getShareTokenStorage();

        address _asset = _sharedStorage.siloConfig.getAssetForSilo(address(this));
        TestERC20Token(address(_asset)).mint(address(this), profit);
        _$().totalAssets[ISilo.AssetType.Collateral] += profit;
    }

    function recognizeLoss(uint256 loss) public {
        IShareToken.ShareTokenStorage storage _sharedStorage = ShareTokenLib.getShareTokenStorage();

        address _asset = _sharedStorage.siloConfig.getAssetForSilo(address(this));
        TestERC20Token(address(_asset)).burn(address(this), loss);
        _$().totalAssets[ISilo.AssetType.Collateral] -= loss;
    }
}
