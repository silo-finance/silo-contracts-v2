// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Clones} from "openzeppelin5/proxy/Clones.sol";

/// @title Deterministic clones library for the silo market deployment.
/// @dev This library is used to deploy deterministic clones of:
/// Silo (SILO_0, SILO_1)
/// ShareProtectedCollateralToken (SHARE_PROTECTED_COLLATERAL_TOKEN_0, SHARE_PROTECTED_COLLATERAL_TOKEN_1)
/// ShareDebtToken (SHARE_DEBT_TOKEN_0, SHARE_DEBT_TOKEN_1)
library CloneDeterministic {
    /// @dev Deterministic salt for Silo0
    bytes32 private constant _SILO_0 = keccak256("create2.salt.Silo0");
    /// @dev Deterministic salt for ShareProtectedCollateralToken Silo0
    bytes32 private constant _SHARE_PROTECTED_COLLATERAL_TOKEN_0 = keccak256(
        "create2.salt.ShareProtectedCollateralToken0"
    );
    /// @dev Deterministic salt for ShareDebtToken Silo0
    bytes32 private constant _SHARE_DEBT_TOKEN_0 = keccak256("create2.salt.ShareDebtToken0");
    /// @dev Deterministic salt for Silo1
    bytes32 private constant _SILO_1 = keccak256("create2.salt.Silo1");
    /// @dev Deterministic salt for ShareProtectedCollateralToken Silo1
    bytes32 private constant _SHARE_PROTECTED_COLLATERAL_TOKEN_1 = keccak256(
        "create2.salt.ShareProtectedCollateralToken1"
    );
    /// @dev Deterministic salt for ShareDebtToken Silo1
    bytes32 private constant _SHARE_DEBT_TOKEN_1 = keccak256("create2.salt.ShareDebtToken1");

    /// @notice Deploys a Silo0 clone.
    /// @param _implementation The Silo implementation to be cloned.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    function silo0(address _implementation, uint256 _siloId) internal returns (address instance) {
        instance = Clones.cloneDeterministic(_implementation, _silo0Salt(_siloId));
    }

    /// @notice Deploys a Silo1 clone.
    /// @param _implementation The Silo implementation to be cloned.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    function silo1(address _implementation, uint256 _siloId) internal returns (address instance) {
        instance = Clones.cloneDeterministic(_implementation, _silo1Salt(_siloId));
    }

    /// @notice Deploys a protected share token clone for the silo0.
    /// @param _implementation The protected share token implementation to be cloned.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    function shareProtectedCollateralToken0(
        address _implementation,
        uint256 _siloId
    )
        internal
        returns (address instance)
    {
        instance = Clones.cloneDeterministic(_implementation, _shareProtectedCollateralToken0Salt(_siloId));
    }

    /// @notice Deploys a debt share token clone for the silo0.
    /// @param _implementation The debt share token implementation to be cloned.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    function shareDebtToken0(address _implementation, uint256 _siloId) internal returns (address instance) {
        instance = Clones.cloneDeterministic(_implementation, _shareDebtToken0Salt(_siloId));
    }

    /// @notice Deploys a protected share token  clone for the silo1.
    /// @param _implementation The protected share token implementation to be cloned.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    function shareProtectedCollateralToken1(
        address _implementation,
        uint256 _siloId
    )
        internal
        returns (address instance)
    {
        instance = Clones.cloneDeterministic(_implementation, _shareProtectedCollateralToken1Salt(_siloId));
    }

    /// @notice Deploys a debt share token clone for the silo1.
    /// @param _implementation The debt share token implementation to be cloned.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    function shareDebtToken1(address _implementation, uint256 _siloId) internal returns (address instance) {
        instance = Clones.cloneDeterministic(_implementation, _shareDebtToken1Salt(_siloId));
    }

    /// @notice Predicts the address of the SiloConfig _SILO0.
    /// @param _siloImpl The Silo implementation address.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    /// @param _deployer The deployer address.
    function predictSilo0Addr(
        address _siloImpl,
        uint256 _siloId,
        address _deployer
    )
        internal
        pure
        returns (address addr)
    {
        addr = Clones.predictDeterministicAddress(_siloImpl, _silo0Salt(_siloId), _deployer);
    }

    /// @notice Predicts the address of the SiloConfig _SILO1.
    /// @param _siloImpl The Silo implementation address.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    /// @param _deployer The deployer address.
    function predictSilo1Addr(
        address _siloImpl,
        uint256 _siloId,
        address _deployer
    )
        internal
        pure
        returns (address addr)
    {
        addr = Clones.predictDeterministicAddress(_siloImpl, _silo1Salt(_siloId), _deployer);
    }

    /// @notice Predicts the address of the SiloConfig _PROTECTED_COLLATERAL_SHARE_TOKEN0.
    /// @param _shareProtectedCollateralTokenImpl The ShareProtectedCollateralToken implementation address.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    /// @param _deployer The deployer address.
    function predictShareProtectedCollateralToken0Addr(
        address _shareProtectedCollateralTokenImpl,
        uint256 _siloId,
        address _deployer
    )
        internal
        pure
        returns (address addr)
    {
        addr = Clones.predictDeterministicAddress(
            _shareProtectedCollateralTokenImpl, _shareProtectedCollateralToken0Salt(_siloId), _deployer
        );
    }

    /// @notice Predicts the address of the SiloConfig _DEBT_SHARE_TOKEN0.
    /// @param _shareDebtTokenImpl The ShareDebtToken implementation address.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    /// @param _deployer The deployer address.
    function predictShareDebtToken0Addr(
        address _shareDebtTokenImpl,
        uint256 _siloId,
        address _deployer
    )
        internal
        pure
        returns (address addr)
    {
        addr = Clones.predictDeterministicAddress(
            _shareDebtTokenImpl, _shareDebtToken0Salt(_siloId), _deployer
        );
    }

    /// @notice Predicts the address of the SiloConfig _PROTECTED_COLLATERAL_SHARE_TOKEN1.
    /// @param _shareProtectedCollateralTokenImpl The ShareProtectedCollateralToken implementation address.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    /// @param _deployer The deployer address.
    function predictShareProtectedCollateralToken1Addr(
        address _shareProtectedCollateralTokenImpl,
        uint256 _siloId,
        address _deployer
    )
        internal
        pure
        returns (address addr)
    {
        addr = Clones.predictDeterministicAddress(
            _shareProtectedCollateralTokenImpl, _shareProtectedCollateralToken1Salt(_siloId), _deployer
        );
    }

    /// @notice Predicts the address of the SiloConfig _DEBT_SHARE_TOKEN1.
    /// @param _shareDebtTokenImpl The ShareDebtToken implementation address.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    /// @param _deployer The deployer address.
    function predictShareDebtToken1Addr(
        address _shareDebtTokenImpl,
        uint256 _siloId,
        address _deployer
    )
        internal
        pure
        returns (address addr)
    {
        addr = Clones.predictDeterministicAddress(
            _shareDebtTokenImpl, _shareDebtToken1Salt(_siloId), _deployer
        );
    }

    /// @notice Generates the salt for the `Silo0` `create2` operations.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    function _silo0Salt(uint256 _siloId) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(_siloId, _SILO_0));
    }

    /// @notice Generates the salt for the `Silo1` `create2` operations.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    function _silo1Salt(uint256 _siloId) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(_siloId, _SILO_1));
    }

    /// @notice Generates the salt for the `ShareProtectedCollateralToken0` `create2` operations.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    function _shareProtectedCollateralToken0Salt(uint256 _siloId) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(_siloId, _SHARE_PROTECTED_COLLATERAL_TOKEN_0));
    }

    /// @notice Generates the salt for the `ShareDebtToken0` `create2` operations.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    function _shareDebtToken0Salt(uint256 _siloId) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(_siloId, _SHARE_DEBT_TOKEN_0));
    }

    /// @notice Generates the salt for the `ShareProtectedCollateralToken1` `create2` operations.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    function _shareProtectedCollateralToken1Salt(uint256 _siloId) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(_siloId, _SHARE_PROTECTED_COLLATERAL_TOKEN_1));
    }

    /// @notice Generates the salt for the `ShareDebtToken1` `create2` operations.
    /// @param _siloId The Silo ID (assigned by the `SiloFactory`).
    function _shareDebtToken1Salt(uint256 _siloId) private pure returns (bytes32 salt) {
        salt = keccak256(abi.encodePacked(_siloId, _SHARE_DEBT_TOKEN_1));
    }
}
