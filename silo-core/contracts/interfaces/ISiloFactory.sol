// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

import {IERC721Upgradeable} from "openzeppelin-contracts-upgradeable/interfaces/IERC721Upgradeable.sol";
import {ISiloConfig} from "./ISiloConfig.sol";

interface ISiloFactory is IERC721Upgradeable {
    event NewSilo(address indexed token0, address indexed token1, address silo0, address silo1, address siloConfig);
    event DaoFeeChanged(uint256 daoFeeInBp);
    event MaxDeployerFeeChanged(uint256 maxDeployerFeeInBp);
    event MaxFlashloanFeeChanged(uint256 maxFlashloanFee);
    event MaxLiquidationFeeChanged(uint256 maxLiquidationFee);
    event DaoFeeReceiverChanged(address daoFeeReceiver);

    error ZeroAddress();
    error MaxFee();
    error SameAsset();
    error InvalidIrm();
    error InvalidMaxLtv();
    error InvalidMaxLt();
    error InvalidLt();
    error InvalidDeployer();
    error NonBorrowableSilo();
    error MaxDeployerFee();
    error MaxFlashloanFee();
    error MaxLiquidationFee();
    error InvalidIrmConfig();
    error InvalidFee();

    function initialize(
        address _siloImpl,
        address _shareCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _daoFeeInBp,
        address _daoFeeReceiver
    ) external;

    /// @dev share tokens in _configData are overridden so can be set to address(0). Sanity data validation
    ///      is done by SiloConfig.
    /// @param _initData silo initialization data
    function createSilo(ISiloConfig.InitData memory _initData) external returns (ISiloConfig siloConfig);

    function setDaoFee(uint256 _newDaoFeeInBp) external;
    function setDaoFeeReceiver(address _newDaoFeeReceiver) external;
    function setMaxDeployerFee(uint256 _newMaxDeployerFeeInBp) external;
    function setMaxFlashloanFee(uint256 _newMaxFlashloanFeeInBp) external;
    function setMaxLiquidationFee(uint256 _newMaxLiquidationFeeInBp) external;

    function daoFeeInBp() external view returns (uint256);
    function maxDeployerFeeInBp() external view returns (uint256);
    function maxFlashloanFeeInBp() external view returns (uint256);
    function maxLiquidationFeeInBp() external view returns (uint256);
    function daoFeeReceiver() external view returns (address);
    function siloImpl() external view returns (address);
    function shareCollateralTokenImpl() external view returns (address);
    function shareDebtTokenImpl() external view returns (address);

    function idToSilos(uint256 _id) external view returns (address[2] memory);
    function siloToId(address _silo) external view returns (uint256);

    function isSilo(address _silo) external view returns (bool);
    function getNextSiloId() external view returns (uint256);
    function getFeeReceivers(address _silo) external view returns (address dao, address deployer);

    function validateSiloInitData(ISiloConfig.InitData memory _initData) external view returns (bool);
}
