// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0;

import {IERC721Upgradeable} from "openzeppelin-contracts-upgradeable/interfaces/IERC721Upgradeable.sol";

interface ISiloFactory is IERC721Upgradeable {
    function isSilo(address silo) external view returns (bool);
    function listSilos(address token0, address token1) external view returns (uint256[] memory ids);
    function daoFee() external view returns (uint256);
    function deployerFee() external view returns (uint256);
    function feeDistributor() external view returns (uint256);
    function getFee() external view returns (uint256 totalFee);

    // solhint-disable ordering

    function createSilo(
        address[2] calldata assets,
        address[4] calldata oracles,
        address[2] calldata interestRateModel,
        uint256[2] calldata maxLtv,
        uint256[2] calldata lt,
        bool[2] memory _borrowable
    ) external returns (address silo, uint256 siloId);

    function setFees(uint256 daoFee, uint256 deployerFee) external;
    function claimFees(address silo) external returns (uint256[2] memory fees);
    function getNotificationReceiver(address silo) external returns (address notificationReceiver);
    function getFeeReceivers(address _silo) external view returns (address dao, address deployer);
}
