// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {SiloERC4626LibWithReentrancyIssue} from "./SiloERC4626LibWithReentrancyIssue.sol";

contract SiloERC4626LibConsumerVulnerable {
    uint256 public constant INITIAL_TOTAL = 100;

    mapping(ISilo.AssetType => ISilo.Assets) internal _total;

    constructor() {
        _total[ISilo.AssetType.Collateral].assets = INITIAL_TOTAL;
    }

    function deposit(
        address _token,
        address _depositor,
        uint256 _assets,
        uint256 _shares,
        address _receiver,
        IShareToken _collateralShareToken
    ) public {
        SiloERC4626LibWithReentrancyIssue.deposit(
            _token,
            _depositor,
            _assets,
            _shares,
            _receiver,
            _collateralShareToken,
            _total[ISilo.AssetType.Collateral]
        );
    }

    function getTotalCollateral() public view returns (uint256) {
        return _total[ISilo.AssetType.Collateral].assets;
    }
}
