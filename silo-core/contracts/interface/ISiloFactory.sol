// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.17;

import "openzeppelin-contracts-upgradeable/contracts/interfaces/IERC721Upgradeable.sol";

interface ISiloFactory is IERC721Upgradeable {
    function isSilo(address silo) external view returns (bool);
    function listSilos(address token0, address token1) external view returns (uint256[] memory ids);
    function daoFee() external view returns (uint256);
    function deployerFee() external view returns (uint256);
    function feeDistributor() external view returns (uint256);
    function getFee() external view returns (uint256 totalFee);

    function createSilo(
        address[2] calldata assets,
        address[4] calldata oracles,
        address[2] calldata interestRateModel,
        uint256[2] calldata maxLtv,
        uint256[2] calldata lt,
        bool[2] memory _borrowable
    ) external view returns (address silo, uint256 siloId);

    function setFees(uint256 daoFee, uint256 deployerFee) external;
    function claimFees(address silo) external returns (uint256[2] memory fees);
    function getNotificationReceiver(address silo) external returns (address notificationReceiver);
}
