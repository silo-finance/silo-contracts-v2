// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {CountersUpgradeable} from "openzeppelin-contracts-upgradeable/utils/CountersUpgradeable.sol";
import {ClonesUpgradeable} from "openzeppelin-contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Upgradeable} from "openzeppelin-contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import {IShareToken} from "./interface/IShareToken.sol";
import {IHookReceiver} from "./interface/IHookReceiver.sol";
import {ISiloConfig, SiloConfig} from "./SiloConfig.sol";
import {ISilo, Silo} from "./Silo.sol";

contract SiloFactory is Initializable, OwnableUpgradeable, ERC721Upgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    /// @dev 1e18 == 100%
    uint256 private constant _ONE = 1e18;

    /// @dev max dao fee is 30%, 1e18 == 100%
    uint256 public constant MAX_DAO_FEE = 0.5e18;

    CountersUpgradeable.Counter private _siloId;
    CountersUpgradeable.Counter private _tokenIdTracker;

    uint256 public daoFee;
    uint256 public maxDeployerFee;

    address public daoFeeReceiver;

    address public siloImpl;
    address public shareCollateralTokenImpl;
    address public shareDebtTokenImpl;

    mapping(uint256 id => address[2] silos) public idToSilo;
    mapping(address silo => uint256 id) public siloToId;

    event NewSilo(address indexed token0, address indexed token1, address silo0, address silo1, address siloConfig);

    event DaoFeeChanged(uint256 daoFee);
    event MaxDeployerFeeChanged(uint256 maxDeployerFee);
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

    function initialize(
        address _siloImpl,
        address _shareCollateralTokenImpl,
        address _shareDebtTokenImpl,
        uint256 _daoFee,
        address _daoFeeReceiver
    ) external initializer {
        __ERC721_init("Silo Finance Fee Receiver", "feeSILO");

        if (_siloImpl == address(0) || _shareCollateralTokenImpl == address(0) || _shareDebtTokenImpl == address(0)) {
            revert ZeroAddress();
        }

        siloImpl = _siloImpl;
        shareCollateralTokenImpl = _shareCollateralTokenImpl;
        shareDebtTokenImpl = _shareDebtTokenImpl;

        uint256 _maxDeployerFee = 0.15e18; // 15% max deployer fee

        _setDaoFee(_daoFee);
        _setMaxDeployerFee(_maxDeployerFee);
        _setDaoFeeReceiver(_daoFeeReceiver);
    }

    /// @dev share tokens in _configData are overridden so can be set to address(0). Sanity data validation
    ///      is done by SiloConfig.
    /// @param _initData silo initialization data
    function createSilo(ISiloConfig.InitData memory _initData) external returns (ISiloConfig siloConfig) {
        _validateSiloInitData(_initData, maxDeployerFee);
        ISiloConfig.ConfigData memory configData = _copyConfig(_initData);

        uint256 nextSiloId = _siloId.current();
        _siloId.increment();

        configData.daoFee = daoFee;

        configData.protectedShareToken0 = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        configData.collateralShareToken0 = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        configData.debtShareToken0 = ClonesUpgradeable.clone(shareDebtTokenImpl);

        configData.protectedShareToken1 = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        configData.collateralShareToken1 = ClonesUpgradeable.clone(shareCollateralTokenImpl);
        configData.debtShareToken1 = ClonesUpgradeable.clone(shareDebtTokenImpl);

        configData.silo0 = ClonesUpgradeable.clone(siloImpl);
        configData.silo1 = ClonesUpgradeable.clone(siloImpl);

        siloConfig = ISiloConfig(address(new SiloConfig(nextSiloId, configData)));

        ISilo(configData.silo0).initialize(siloConfig);
        ISilo(configData.silo1).initialize(siloConfig);

        IShareToken(configData.protectedShareToken0).initialize(
            ISilo(configData.silo0), _initData.protectedHookReceiver0
        );
        IShareToken(configData.collateralShareToken0).initialize(
            ISilo(configData.silo0), _initData.collateralHookReceiver0
        );
        IShareToken(configData.debtShareToken0).initialize(ISilo(configData.silo0), _initData.debtHookReceiver0);
        IShareToken(configData.protectedShareToken1).initialize(
            ISilo(configData.silo1), _initData.protectedHookReceiver1
        );
        IShareToken(configData.collateralShareToken1).initialize(
            ISilo(configData.silo1), _initData.collateralHookReceiver1
        );
        IShareToken(configData.debtShareToken1).initialize(ISilo(configData.silo1), _initData.debtHookReceiver1);

        siloToId[configData.silo0] = nextSiloId;
        siloToId[configData.silo1] = nextSiloId;
        idToSilo[nextSiloId] = [configData.silo0, configData.silo1];

        if (_initData.deployer != address(0)) {
            _mint(_initData.deployer, nextSiloId);
        }

        emit NewSilo(configData.token0, configData.token1, configData.silo0, configData.silo1, address(siloConfig));

        return siloConfig;
    }

    function setDaoFee(uint256 _newDaoFee) external onlyOwner {
        _setDaoFee(_newDaoFee);
    }

    function setMaxDeployerFee(uint256 _newMaxDeployerFee) external onlyOwner {
        _setMaxDeployerFee(_newMaxDeployerFee);
    }

    function setDaoFeeReceiver(address _newDaoFeeReceiver) external onlyOwner {
        _setDaoFeeReceiver(_newDaoFeeReceiver);
    }

    function getNextSiloId() external view returns (uint256) {
        return _siloId.current();
    }

    function getFeeReceivers(address _silo) external view returns (address dao, address deployer) {
        return (daoFeeReceiver, _ownerOf(siloToId[_silo]));
    }

    function _setDaoFee(uint256 _newDaoFee) internal {
        if (_newDaoFee > MAX_DAO_FEE) revert MaxFee();

        daoFee = _newDaoFee;

        emit DaoFeeChanged(_newDaoFee);
    }

    function _setMaxDeployerFee(uint256 _newMaxDeployerFee) internal {
        maxDeployerFee = _newMaxDeployerFee;

        emit MaxDeployerFeeChanged(_newMaxDeployerFee);
    }

    function _setDaoFeeReceiver(address _newDaoFeeReceiver) internal {
        if (_newDaoFeeReceiver == address(0)) revert ZeroAddress();

        daoFeeReceiver = _newDaoFeeReceiver;

        emit DaoFeeReceiverChanged(_newDaoFeeReceiver);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "//app.silo.finance/silo/";
    }

    function _copyConfig(ISiloConfig.InitData memory _initData)
        internal
        pure
        returns (ISiloConfig.ConfigData memory configData)
    {
        configData.deployerFee = _initData.deployerFee;
        configData.token0 = _initData.token0;
        configData.ltvOracle0 = _initData.ltvOracle0;
        configData.ltOracle0 = _initData.ltOracle0;
        configData.interestRateModel0 = _initData.interestRateModel0;
        configData.maxLtv0 = _initData.maxLtv0;
        configData.lt0 = _initData.lt0;
        configData.liquidationFee0 = _initData.liquidationFee0;
        configData.borrowable0 = _initData.borrowable0;
        configData.token1 = _initData.token1;
        configData.ltvOracle1 = _initData.ltvOracle1;
        configData.ltOracle1 = _initData.ltOracle1;
        configData.interestRateModel1 = _initData.interestRateModel1;
        configData.maxLtv1 = _initData.maxLtv1;
        configData.lt1 = _initData.lt1;
        configData.liquidationFee1 = _initData.liquidationFee1;
        configData.borrowable1 = _initData.borrowable1;
    }

    // solhint-disable-next-line code-complexity
    function _validateSiloInitData(ISiloConfig.InitData memory _initData, uint256 _maxDeployerFee) internal pure {
        // solhint-disable-line code-complexity
        if (_initData.token0 == _initData.token1) revert SameAsset();
        if (_initData.interestRateModel0 == address(0) || _initData.interestRateModel1 == address(0)) {
            revert InvalidIrm();
        }
        if (_initData.maxLtv0 > _initData.lt0) revert InvalidMaxLtv();
        if (_initData.maxLtv1 > _initData.lt1) revert InvalidMaxLtv();
        if (_initData.maxLtv0 == 0 && _initData.maxLtv1 == 0) revert InvalidMaxLtv();
        if (_initData.lt0 >= _ONE || _initData.lt1 >= _ONE) revert InvalidLt();
        if (!_initData.borrowable0 && !_initData.borrowable1) revert NonBorrowableSilo();
        if (_initData.deployerFee > 0 && _initData.deployer == address(0)) revert InvalidDeployer();
        if (_initData.deployerFee > _maxDeployerFee) revert MaxDeployerFee();
    }
}
