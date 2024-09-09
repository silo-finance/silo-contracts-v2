// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.24;

import {IOmniVotingEscrowAdaptor} from "balancer-labs/v2-interfaces/liquidity-mining/IOmniVotingEscrowAdaptor.sol";
import {IVotingEscrow} from "balancer-labs/v2-interfaces/liquidity-mining/IVotingEscrow.sol";
import {ISmartWalletChecker} from "balancer-labs/v2-interfaces/liquidity-mining/ISmartWalletChecker.sol";
import {Errors, _require} from "balancer-labs/v2-interfaces/solidity-utils/helpers/BalancerErrors.sol";

import {Address} from "openzeppelin5/utils/Address.sol";
import {ReentrancyGuard} from "openzeppelin5/utils/ReentrancyGuard.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {IVeSiloDelegatorViaCCIP} from "ve-silo/contracts/voting-escrow/interfaces/IVeSiloDelegatorViaCCIP.sol";
import {ICCIPMessageSender} from "ve-silo/contracts/utils/CCIPMessageSender.sol";
import {IVotingEscrowCCIPRemapper} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowCCIPRemapper.sol";

// solhint-disable ordering
// solhint-disable function-max-lines

/**
 * @notice This contract allows veBAL holders on Ethereum to assign their balance to designated addresses on each L2.
 * This is intended for smart contracts that are not deployed to the same address on all networks. EOA's are
 * expected to either use the same address, or manage delegation on L2 networks themselves.
 *
 * @dev For each network (chainId), we maintain a mapping between local (Ethereum) and remote (L2) addresses.
 * This contract remaps balance queries on remote network addresses to their corresponding local addresses.
 * Users able to call this contract can set their own mappings, or delegate this function to another account if they
 * cannot.
 */
contract VotingEscrowRemapper is IVotingEscrowCCIPRemapper, Ownable2Step, ReentrancyGuard {
    // solhint-disable-next-line var-name-mixedcase
    IERC20 public immutable LINK;

    IVotingEscrow private immutable _votingEscrow;
    IVeSiloDelegatorViaCCIP private _veSiloDelegator;
    mapping(uint64 => mapping(address => address)) private _localToRemoteAddressMap;
    mapping(uint64 => mapping(address => address)) private _remoteToLocalAddressMap;

    // Records a mapping from an address to another address which is authorized to manage its remote users.
    mapping(address => address) private _localRemappingManager;

    constructor(IVotingEscrow votingEscrow, IERC20 _link) Ownable(msg.sender) {
        _votingEscrow = votingEscrow;
        LINK = _link;
    }

    /// @inheritdoc IVotingEscrowCCIPRemapper
    function setVeSiloDelegator(IVeSiloDelegatorViaCCIP _delegator) external onlyOwner {
        _veSiloDelegator = _delegator;

        emit VeSiloDelegatorUpdated(_delegator);
    }

    /// @inheritdoc IVotingEscrowCCIPRemapper
    function getVotingEscrow() public view returns (IVotingEscrow) {
        return _votingEscrow;
    }

    function getVeSiloDelegator() public view returns (IVeSiloDelegatorViaCCIP) {
        return _veSiloDelegator;
    }

    /// @inheritdoc IVotingEscrowCCIPRemapper
    function getTotalSupplyPoint() external view returns (IVotingEscrow.Point memory) {
        IVotingEscrow votingEscrow = getVotingEscrow();
        uint256 totalSupplyEpoch = votingEscrow.epoch();
        return votingEscrow.point_history(totalSupplyEpoch);
    }

    /// @inheritdoc IVotingEscrowCCIPRemapper
    function getUserPoint(address user) external view returns (IVotingEscrow.Point memory) {
        IVotingEscrow votingEscrow = getVotingEscrow();
        uint256 userEpoch = votingEscrow.user_point_epoch(user);
        return votingEscrow.user_point_history(user, userEpoch);
    }

    /// @inheritdoc IVotingEscrowCCIPRemapper
    function getLockedEnd(address user) external view returns (uint256) {
        return getVotingEscrow().locked__end(user);
    }

    /// @inheritdoc IVotingEscrowCCIPRemapper
    function getLocalUser(address remoteUser, uint64 chainId) public view returns (address) {
        return _remoteToLocalAddressMap[chainId][remoteUser];
    }

    /// @inheritdoc IVotingEscrowCCIPRemapper
    function getRemoteUser(address localUser, uint64 chainId) public view returns (address) {
        return _localToRemoteAddressMap[chainId][localUser];
    }

    /// @inheritdoc IVotingEscrowCCIPRemapper
    function getRemappingManager(address localUser) public view returns (address) {
        return _localRemappingManager[localUser];
    }

    // Remapping Setters

    function setNetworkRemapping(
        address localUser,
        address remoteUser,
        uint64 chainId,
        ICCIPMessageSender.PayFeesIn payFeesIn
    ) external payable nonReentrant {
        _require(msg.sender == localUser || msg.sender == _localRemappingManager[localUser], Errors.SENDER_NOT_ALLOWED);
        require(_isAllowedContract(localUser), "Only contracts which can hold veBAL can set up a mapping");
        require(remoteUser != address(0), "Zero address cannot be used as remote user");

        // We keep a 1-to-1 local-remote mapping for each chain.
        // If A --> B (i.e. A in the local chain is remapped to B in the remote chain), to keep the state consistent
        // the user effectively 'owns' both A and B in both chains.
        //
        // This means that whenever a new remapping is created (assuming A --> B previously):
        // - The remote address must not already be in use by another local user (C --> B is forbidden).
        // - The remote address must not be a local address that has already been remapped (C --> A is forbidden).
        // - The local address must not be the target remote address for another local user (B --> C is forbidden).
        //
        // Note that this means that it is possible to frontrun this call to grief a user by taking up their
        // selected remote address before they do so. This is mitigated somewhat by restricting potential attackers to
        // the set of contracts that are allowlisted to hold veBAL (and their remapping managers). Should
        // one of them grief, then Balancer governance can remove them from these allowlists.

        // B cannot be remapped to (i.e. be a remote) if a prior A --> B mapping exists.
        // To prevent it, we verify that the reverse mapping of our remote does not exist.
        require(
            _remoteToLocalAddressMap[chainId][remoteUser] == address(0),
            "Cannot overwrite an existing mapping by another user"
        );

        // A cannot be remapped to (i.e. be a remote) if a prior A --> B mapping exists.
        // To prevent it, we verify that the mapping of our remote does not exist.
        require(
            _localToRemoteAddressMap[chainId][remoteUser] == address(0),
            "Cannot remap to an address that is in use locally"
        );

        // B cannot be mapped from (i.e. be a local) if a prior A --> B mapping exists.
        // To prevent it, we verify that the reverse mapping of our local does not exist.
        require(
            _remoteToLocalAddressMap[chainId][localUser] == address(0),
            "Cannot remap to an address that is in use remotely"
        );

        // This is a best-effort check: we should not allow griefing the existing balance of an account,
        // because with this remapping we would overwrite it in the target chain ID.
        require(_votingEscrow.balanceOf(remoteUser) == 0, "Target remote address has non-zero veBAL balance");

        // Clear out the old remote user to avoid orphaned entries.
        address oldRemoteUser = _localToRemoteAddressMap[chainId][localUser];
        if (oldRemoteUser != address(0)) {
            _remoteToLocalAddressMap[chainId][oldRemoteUser] = address(0);
            emit RemoteAddressMappingCleared(oldRemoteUser, chainId);
        }

        // Set up new remapping.
        _remoteToLocalAddressMap[chainId][remoteUser] = localUser;
        _localToRemoteAddressMap[chainId][localUser] = remoteUser;

        emit AddressMappingUpdated(localUser, remoteUser, chainId);

        // Note: it is important to perform the bridge calls _after_ the mappings are settled, since the
        // omni voting escrow will rely on the correct mappings to bridge the balances.
        uint256 fee = _veSiloDelegator.estimateSendUserBalance(localUser, chainId, payFeesIn);

        if (payFeesIn == ICCIPMessageSender.PayFeesIn.Native) {
            _transferAndPayFeesInNative(
                fee,
                oldRemoteUser,
                localUser,
                chainId,
                payFeesIn
            );
        } else {
            _transferAndPayFeesInLink(
                fee,
                oldRemoteUser,
                localUser,
                chainId,
                payFeesIn
            );
        }

        // Send back any leftover ETH to the caller.
        uint256 remainingBalance = address(this).balance;
        if (remainingBalance > 0) {
            Address.sendValue(payable(msg.sender), remainingBalance);
        }
    }

    function _transferAndPayFeesInNative(
        uint256 nativeFee,
        address oldRemoteUser,
        address localUser,
        uint64 chainId,
        ICCIPMessageSender.PayFeesIn payFeesIn
    ) internal {
        IVeSiloDelegatorViaCCIP delegator = _veSiloDelegator;

        if (oldRemoteUser != address(0)) {
            require(msg.value >= nativeFee * 2, "Insufficient ETH to bridge user balance");
            // If there was an old mapping, send balance from (local) oldRemoteUser --> (remote) oldRemoteUser
            // This should clean up the existing bridged balance from localUser --> oldRemoteUser.
            delegator.sendUserBalance{ value: nativeFee }(oldRemoteUser, chainId, payFeesIn);
        } else {
            require(msg.value >= nativeFee, "Insufficient ETH to bridge user balance");
        }

        // Bridge balance for new mapping localUser --> remoteUser.
        delegator.sendUserBalance{ value: nativeFee }(localUser, chainId, payFeesIn);
    }

    /// @inheritdoc IVotingEscrowCCIPRemapper
    function setNetworkRemappingManager(address localUser, address delegate)
        external
        override
        onlyOwner
        nonReentrant
    {
        require(_isAllowedContract(localUser), "Only contracts which can hold veBAL may have a delegate");

        _localRemappingManager[localUser] = delegate;
        emit AddressDelegateUpdated(localUser, delegate);
    }

    /// @inheritdoc IVotingEscrowCCIPRemapper
    function clearNetworkRemapping(
        address localUser,
        uint64 chainId,
        ICCIPMessageSender.PayFeesIn payFeesIn
    ) external payable nonReentrant {
        require(localUser != address(0), "localUser cannot be zero address");
        require(!_isAllowedContract(localUser) || localUser == msg.sender, "localUser is still in good standing");

        address remoteUser = _localToRemoteAddressMap[chainId][localUser];
        require(remoteUser != address(0), "Remapping to clear does not exist");

        _remoteToLocalAddressMap[chainId][remoteUser] = address(0);
        _localToRemoteAddressMap[chainId][localUser] = address(0);

        emit AddressMappingUpdated(localUser, address(0), chainId);
        emit RemoteAddressMappingCleared(remoteUser, chainId);

        // Note: it is important to perform the bridge calls _after_ the mappings are settled, since the
        // omni voting escrow will rely on the correct mappings to bridge the balances.
        // Clean up the balance for the old mapping, and bridge the new (default) one.
        uint256 fee = _veSiloDelegator.estimateSendUserBalance(localUser, chainId, payFeesIn);

        if (payFeesIn == ICCIPMessageSender.PayFeesIn.Native) {
            _transferAndPayFeesInNative(
                fee,
                remoteUser,
                localUser,
                chainId,
                payFeesIn
            );
        } else {
            _transferAndPayFeesInLink(
                fee,
                remoteUser,
                localUser,
                chainId,
                payFeesIn
            );
        }

        // Send back any leftover ETH to the caller.
        uint256 remainingBalance = address(this).balance;
        if (remainingBalance > 0) {
            Address.sendValue(payable(msg.sender), remainingBalance);
        }
    }

    // Internal Functions

    function _transferAndPayFeesInLink(
        uint256 fee,
        address oldRemoteUser,
        address localUser,
        uint64 chainId,
        ICCIPMessageSender.PayFeesIn payFeesIn
    ) internal {
        IVeSiloDelegatorViaCCIP delegator = _veSiloDelegator;

        if (oldRemoteUser != address(0)) {
            // It is insane to have a `fee` > type(uint128).max.
            // Even if so, and we will overflow, the chainlink router will revert.
            unchecked { fee = fee * 2; }

            _handleFee(address(delegator), fee);

            // If there was an old mapping, send balance from (local) oldRemoteUser --> (remote) oldRemoteUser
            // This should clean up the existing bridged balance from localUser --> oldRemoteUser.
            delegator.sendUserBalance(oldRemoteUser, chainId, payFeesIn);
        } else {
            _handleFee(address(delegator), fee);
        }

        // Bridge balance for new mapping localUser --> remoteUser.
        delegator.sendUserBalance(localUser, chainId, payFeesIn);
    }

    function _handleFee(address delegator, uint256 fee) internal {
        IERC20(LINK).transferFrom(msg.sender, address(this), fee);
        IERC20(LINK).approve(delegator, fee);
    }

    /**
     * @notice Returns whether `localUser` is a contract which is authorized to hold veBAL.
     * @param localUser - The address to check against the `SmartWalletChecker`.
     */
    function _isAllowedContract(address localUser) private view returns (bool) {
        ISmartWalletChecker smartWalletChecker = getVotingEscrow().smart_wallet_checker();
        return smartWalletChecker.check(localUser);
    }
}
