pragma solidity ^0.8.0;

import {CryticIERC4626Internal} from "properties/ERC4626/util/IERC4626Internal.sol";
import {TestERC20Token} from "properties/ERC4626/util/TestERC20Token.sol";

import {Silo, ISilo} from "silo-core/contracts/Silo.sol";
import {ISiloFactory} from "silo-core/contracts/SiloFactory.sol";

contract SiloInternal is Silo, CryticIERC4626Internal {
    constructor(ISiloFactory _siloFactory) Silo(_siloFactory) {
        factory = _siloFactory;
    }

    function recognizeProfit(uint256 profit) public {
        address _asset = sharedStorage.siloConfig.getAssetForSilo(address(this));
        TestERC20Token(address(_asset)).mint(address(this), profit);
        total[uint8(ISilo.AssetType.Collateral)].assets += profit;
    }

    function recognizeLoss(uint256 loss) public {
        address _asset = sharedStorage.siloConfig.getAssetForSilo(address(this));
        TestERC20Token(address(_asset)).burn(address(this), loss);
        total[uint8(ISilo.AssetType.Collateral)].assets -= loss;
    }
}
