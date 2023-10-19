// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {CountersUpgradeable} from "openzeppelin-contracts-upgradeable/utils/CountersUpgradeable.sol";
import {ClonesUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import {IShareToken} from "./interfaces/IShareToken.sol";
import {IHookReceiver} from "./interfaces/IHookReceiver.sol";
import {ISiloFactory} from "./interfaces/ISiloFactory.sol";
import {ISiloConfig, SiloConfig} from "./SiloConfig.sol";
import {ISilo, Silo} from "./Silo.sol";

contract SiloFactory is ISiloFactory, ERC721Upgradeable, OwnableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /// @dev 1e4 == 100%
    uint256 private constant _BASIS_POINTS = 1e4;

    /// @dev max fee is 40%, 1e4 == 100%
    uint256 public constant MAX_FEE_IN_BP = 0.4e4;

    CountersUpgradeable.Counter private _siloId;

    /// @dev denominated in basis points. 10000 == 100%.
    uint256 public daoFeeInBp;
    /// @dev denominated in basis points. 10000 == 100%.
    uint256 public maxDeployerFeeInBp;
    /// @dev denominated in basis points. 10000 == 100%.
    uint256 public maxFlashloanFeeInBp;
    /// @dev denominated in basis points. 10000 == 100%.
    uint256 public maxLiquidationFeeInBp;

    address public daoFeeReceiver;

    address public siloImpl;
    address public shareCollateralTokenImpl;
    address public shareDebtTokenImpl;

    mapping(uint256 id => address[2] silos) private _idToSilos;
    mapping(address silo => uint256 id) public siloToId;

    function initialize(
        address _siloImpl,
        address _shareCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _daoFeeInBp,
        address _daoFeeReceiver
    ) external virtual initializer {
        __ERC721_init("Silo Finance Fee Receiver", "feeSILO");
        __Ownable_init();

        // start IDs from 1
        _siloId.increment();

        if (_siloImpl == address(0) || _shareCollateralTokenImpl == address(0) || _shareDebtTokenImpl == address(0)) {
            revert ZeroAddress();
        }

        siloImpl = _siloImpl;
        shareCollateralTokenImpl = _shareCollateralTokenImpl;
        shareDebtTokenImpl = _shareDebtTokenImpl;

        uint256 _maxDeployerFeeInBp = 0.15e4; // 15% max deployer fee
        uint256 _newMaxFlashloanFeeInBp = 0.15e4; // 15% max flashloan fee
        uint256 _newMaxLiquidationFeeInBp = 0.30e4; // 30% max liquidation fee

        _setDaoFee(_daoFeeInBp);
        _setDaoFeeReceiver(_daoFeeReceiver);

        _setMaxDeployerFee(_maxDeployerFeeInBp);
        _setMaxFlashloanFee(_newMaxFlashloanFeeInBp);
        _setMaxLiquidationFee(_newMaxLiquidationFeeInBp);
    }

    /// @dev share tokens in _configData are overridden so can be set to address(0). Sanity data validation
    ///      is done by SiloConfig.
    /// @param _initData silo initialization data
    function createSilo(ISiloConfig.InitData memory _initData) external virtual returns (ISiloConfig siloConfig) {
        validateSiloInitData(_initData);
        (ISiloConfig.ConfigData memory configData0, ISiloConfig.ConfigData memory configData1) = _copyConfig(_initData);

        uint256 nextSiloId = _siloId.current();
        _siloId.increment();

        configData0.daoFeeInBp = daoFeeInBp;
        configData1.daoFeeInBp = daoFeeInBp;

        _cloneShareTokens(configData0, configData1);

        configData0.silo = ClonesUpgradeable.clone(siloImpl);
        configData1.silo = ClonesUpgradeable.clone(siloImpl);

        siloConfig = ISiloConfig(address(new SiloConfig(nextSiloId, configData0, configData1)));

        ISilo(configData0.silo).initialize(siloConfig, _initData.interestRateModelConfig0);
        ISilo(configData1.silo).initialize(siloConfig, _initData.interestRateModelConfig1);

        _initializeShareTokens(configData0, configData1, _initData);

        siloToId[configData0.silo] = nextSiloId;
        siloToId[configData1.silo] = nextSiloId;
        _idToSilos[nextSiloId] = [configData0.silo, configData1.silo];

        if (_initData.deployer != address(0)) {
            _mint(_initData.deployer, nextSiloId);
        }

        emit NewSilo(configData0.token, configData1.token, configData0.silo, configData1.silo, address(siloConfig));
    }

    function setDaoFee(uint256 _newDaoFee) external virtual onlyOwner {
        _setDaoFee(_newDaoFee);
    }

    function setMaxDeployerFee(uint256 _newMaxDeployerFeeInBp) external virtual onlyOwner {
        _setMaxDeployerFee(_newMaxDeployerFeeInBp);
    }

    function setMaxFlashloanFee(uint256 _newMaxFlashloanFeeInBp) external virtual onlyOwner {
        _setMaxFlashloanFee(_newMaxFlashloanFeeInBp);
    }

    function setMaxLiquidationFee(uint256 _newMaxLiquidationFeeInBp) external virtual onlyOwner {
        _setMaxLiquidationFee(_newMaxLiquidationFeeInBp);
    }

    function setDaoFeeReceiver(address _newDaoFeeReceiver) external virtual onlyOwner {
        _setDaoFeeReceiver(_newDaoFeeReceiver);
    }

    function isSilo(address _silo) external view virtual returns (bool) {
        return siloToId[_silo] != 0;
    }

    function idToSilos(uint256 _id) external view virtual returns (address[2] memory silos) {
        silos = _idToSilos[_id];
    }

    function getNextSiloId() external view virtual returns (uint256) {
        return _siloId.current();
    }

    function getFeeReceivers(address _silo) external view virtual returns (address dao, address deployer) {
        return (daoFeeReceiver, _ownerOf(siloToId[_silo]));
    }

    function validateSiloInitData(ISiloConfig.InitData memory _initData) public view virtual returns (bool) {
        // solhint-disable-previous-line code-complexity
        if (_initData.token0 == _initData.token1) revert SameAsset();
        if (_initData.maxLtv0 == 0 && _initData.maxLtv1 == 0) revert InvalidMaxLtv();
        if (_initData.maxLtv0 > _initData.lt0) revert InvalidMaxLtv();
        if (_initData.maxLtv1 > _initData.lt1) revert InvalidMaxLtv();
        if (_initData.lt0 > _BASIS_POINTS || _initData.lt1 > _BASIS_POINTS) revert InvalidLt();
        if (!_initData.borrowable0 && !_initData.borrowable1) revert NonBorrowableSilo();
        if (_initData.deployerFeeInBp > 0 && _initData.deployer == address(0)) revert InvalidDeployer();
        if (_initData.deployerFeeInBp > maxDeployerFeeInBp) revert MaxDeployerFee();
        if (_initData.flashloanFee0 > maxFlashloanFeeInBp) revert MaxFlashloanFee();
        if (_initData.flashloanFee1 > maxFlashloanFeeInBp) revert MaxFlashloanFee();
        if (_initData.liquidationFee0 > maxLiquidationFeeInBp) revert MaxLiquidationFee();
        if (_initData.liquidationFee1 > maxLiquidationFeeInBp) revert MaxLiquidationFee();

        if (_initData.interestRateModelConfig0 == address(0) || _initData.interestRateModelConfig1 == address(0)) {
            revert InvalidIrmConfig();
        }

        if (_initData.interestRateModel0 == address(0) || _initData.interestRateModel1 == address(0)) {
            revert InvalidIrm();
        }

        return true;
    }

    function _setDaoFee(uint256 _newDaoFee) internal virtual {
        if (_newDaoFee > MAX_FEE_IN_BP) revert MaxFee();

        daoFeeInBp = _newDaoFee;

        emit DaoFeeChanged(_newDaoFee);
    }

    function _setMaxDeployerFee(uint256 _newMaxDeployerFee) internal virtual {
        if (_newMaxDeployerFee >= MAX_FEE_IN_BP) revert MaxFee();

        maxDeployerFeeInBp = _newMaxDeployerFee;

        emit MaxDeployerFeeChanged(_newMaxDeployerFee);
    }

    function _setMaxFlashloanFee(uint256 _newMaxFlashloanFee) internal virtual {
        if (_newMaxFlashloanFee >= MAX_FEE_IN_BP) revert MaxFee();

        maxFlashloanFeeInBp = _newMaxFlashloanFee;

        emit MaxFlashloanFeeChanged(_newMaxFlashloanFee);
    }

    function _setMaxLiquidationFee(uint256 _newMaxLiquidationFee) internal virtual {
        if (_newMaxLiquidationFee >= MAX_FEE_IN_BP) revert MaxFee();

        maxLiquidationFeeInBp = _newMaxLiquidationFee;

        emit MaxLiquidationFeeChanged(_newMaxLiquidationFee);
    }

    function _setDaoFeeReceiver(address _newDaoFeeReceiver) internal virtual {
        if (_newDaoFeeReceiver == address(0)) revert ZeroAddress();

        daoFeeReceiver = _newDaoFeeReceiver;

        emit DaoFeeReceiverChanged(_newDaoFeeReceiver);
    }

    function _cloneShareTokens(
        ISiloConfig.ConfigData memory configData0,
        ISiloConfig.ConfigData memory configData1
    ) internal virtual {
        configData0.protectedShareToken = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        configData0.collateralShareToken = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        configData0.debtShareToken = ClonesUpgradeable.clone(shareDebtTokenImpl);
        configData1.protectedShareToken = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        configData1.collateralShareToken = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        configData1.debtShareToken = ClonesUpgradeable.clone(shareDebtTokenImpl);
    }

    function _initializeShareTokens(
        ISiloConfig.ConfigData memory configData0,
        ISiloConfig.ConfigData memory configData1,
        ISiloConfig.InitData memory _initData
    ) internal virtual {
        // initialize configData0
        IShareToken(configData0.protectedShareToken).initialize(
            ISilo(configData0.silo),
            _initData.protectedHookReceiver0
        );

        IShareToken(configData0.collateralShareToken).initialize(
            ISilo(configData0.silo),
            _initData.collateralHookReceiver0
        );

        IShareToken(configData0.debtShareToken).initialize(
            ISilo(configData0.silo),
            _initData.debtHookReceiver0
        );

        // initialize configData1
        IShareToken(configData1.protectedShareToken).initialize(
            ISilo(configData1.silo),
            _initData.protectedHookReceiver1
        );

        IShareToken(configData1.collateralShareToken).initialize(
            ISilo(configData1.silo),
            _initData.collateralHookReceiver1
        );

        IShareToken(configData1.debtShareToken).initialize(
            ISilo(configData1.silo),
            _initData.debtHookReceiver1
        );
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "//app.silo.finance/silo/";
    }

    function _copyConfig(ISiloConfig.InitData memory _initData)
        internal
        pure
        virtual
        returns (ISiloConfig.ConfigData memory configData0, ISiloConfig.ConfigData memory configData1)
    {
        configData0.deployerFeeInBp = _initData.deployerFeeInBp;
        configData0.token = _initData.token0;
        configData0.solvencyOracle = _initData.solvencyOracle0;
        configData0.maxLtvOracle = _initData.maxLtvOracle0;
        configData0.interestRateModel = _initData.interestRateModel0;
        configData0.maxLtv = _initData.maxLtv0;
        configData0.lt = _initData.lt0;
        configData0.liquidationFee = _initData.liquidationFee0;
        configData0.flashloanFee = _initData.flashloanFee0;
        configData0.borrowable = _initData.borrowable0;

        configData1.deployerFeeInBp = _initData.deployerFeeInBp;
        configData1.token = _initData.token1;
        configData1.solvencyOracle = _initData.solvencyOracle1;
        configData1.maxLtvOracle = _initData.maxLtvOracle1;
        configData1.interestRateModel = _initData.interestRateModel1;
        configData1.maxLtv = _initData.maxLtv1;
        configData1.lt = _initData.lt1;
        configData1.liquidationFee = _initData.liquidationFee1;
        configData1.flashloanFee = _initData.flashloanFee1;
        configData1.borrowable = _initData.borrowable1;
    }
}
