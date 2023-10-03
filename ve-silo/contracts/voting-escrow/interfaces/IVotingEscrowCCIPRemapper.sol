// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General external License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General external License for more details.

// You should have received a copy of the GNU General external License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity >=0.7.0 <0.9.0;
pragma experimental ABIEncoderV2;

import {IVotingEscrow} from "balancer-labs/v2-interfaces/liquidity-mining/IVotingEscrow.sol";
import {IVeSiloDelegatorViaCCIP} from "ve-silo/contracts/voting-escrow/interfaces/IVeSiloDelegatorViaCCIP.sol";
import {ICCIPMessageSender} from "ve-silo/contracts/utils/CCIPMessageSender.sol";

// solhint-disable ordering
// solhint-disable max-line-length

/**
 * @notice This contract allows veSilo holders on Ethereum to assign their balance to designated addresses on each L2.
 * This is intended for smart contracts that are not deployed to the same address on all networks. EOA's are
 * expected to either use the same address, or manage delegation on L2 networks themselves.
 *
 * @dev For each network (chainId), we maintain a mapping between local (Ethereum) and remote (L2) addresses.
 * This contract remaps balance queries on remote network addresses to their corresponding local addresses.
 * Users able to call this contract can set their own mappings, or delegate this function to another account if they
 * cannot.
 */
interface IVotingEscrowCCIPRemapper {
    event AddressMappingUpdated(address indexed localUser, address indexed remoteUser, uint64 indexed chainId);
    event RemoteAddressMappingCleared(address indexed remoteUser, uint64 indexed chainId);
    event AddressDelegateUpdated(address indexed localUser, address indexed delegate);
    event VeSiloDelegatorUpdated(IVeSiloDelegatorViaCCIP delegator);

    /**
     * @notice Returns Voting Escrow contract address.
     */
    function getVotingEscrow() external view returns (IVotingEscrow);

    /**
     * @notice Returns VeSilo Delegator contract address, which interfaces with the gateway to bridge
     * veSilo balances to L2s.
     */
    function getVeSiloDelegator() external view returns (IVeSiloDelegatorViaCCIP);

    /**
     * @notice Returns the current total supply of veSilo as a Point.
     * @dev We return the total supply as a Point to allow extrapolating this into the future. Note that this
     * extrapolation will become invalid when crossing weeks, since we're not taking into account veSilo locks that
     * expire then.
     */
    function getTotalSupplyPoint() external view returns (IVotingEscrow.Point memory);

    /**
     * @notice Returns a user's current veSilo balance as a Point. Note that we don't apply any remappings in this query.
     * The returned value is taken directly from the voting escrow.
     * @dev We return the balance as a Point to allow extrapolating this into the future.
     */
    function getUserPoint(address user) external view returns (IVotingEscrow.Point memory);

    /**
     * @notice Get timestamp when `user`'s lock finishes.
     * @dev The returned value is taken directly from the voting escrow.
     */
    function getLockedEnd(address user) external view returns (uint256);

    /**
     * @notice Returns the local user corresponding to an address on a remote chain.
     * @dev Returns `address(0)` if the remapping does not exist for the given remote user.
     * @param remoteUser - Address of the user on the remote chain corresponding to the local address.
     * @param chainId - The chain ID of the remote network.
     */
    function getLocalUser(address remoteUser, uint64 chainId) external view returns (address);

    /**
     * @notice Returns the remote user corresponding to an address on the local chain.
     * @dev Returns `address(0)` if the remapping does not exist for the given local user.
     * @param localUser - Address of the user on the local chain corresponding to the remote address.
     * @param chainId - The chain ID of the remote network.
     */
    function getRemoteUser(address localUser, uint64 chainId) external view returns (address);

    /**
     * @notice Gets the account that can set a remapping for a given local user.
     * @param localUser - Address of the user on the local chain with a remapping manager.
     */
    function getRemappingManager(address localUser) external view returns (address);

    // Remapping Setters

    /**
     * @notice Sets up a mapping from `localUser`'s veSilo balance to `remoteUser` for chain `chainId`.
     * @dev In order to set up a remapping on this contract, `localUser` must be a smart contract which has been
     * allowlisted to hold veSilo. EOAs are expected to set up any delegation of their veSilo on L2s directly.
     * @param localUser - The address of a contract allowlisted on the `SmartWalletChecker`.
     * @param remoteUser - The address to receive `localUser`'s balance of veSilo on the remote chain.
     * @param chainId - The chain id of the remote chain on which `remoteUser` resides.
     * @param payFeesIn Pay fees in Native/LINK.
     */
    function setNetworkRemapping(
        address localUser,
        address remoteUser,
        uint64 chainId,
        ICCIPMessageSender.PayFeesIn payFeesIn
    ) external payable;

    /**
     * @notice Sets an address to manage the mapping for a given local user on their behalf.
     * @dev This is intended to handle contracts which cannot interact with this contract directly.
     * @param localUser - The address of a contract allowlisted on the `SmartWalletChecker`.
     * @param delegate - The address which is allowed to manage remote users to be linked to `localUser`.
     */
    function setNetworkRemappingManager(address localUser, address delegate) external;

    /**
     * @notice Clears a local user's mapping for a particular network.
     * @dev This is intended to discourage and also allow recovery from griefing attacks.
     * If griefing occurs then the griefer can be removed from Smart Wallet Checker and have their remappings erased.
     * The local user can always clear their own mapping, regardless the state of the Smart Wallet Checker.
     * @param localUser - The address of the local user to erase.
     * @param chainId - The chain id of the network to erase.
     * @param payFeesIn Pay fees in Native/LINK.
     */
    function clearNetworkRemapping(
        address localUser,
        uint64 chainId,
        ICCIPMessageSender.PayFeesIn payFeesIn
    ) external payable;

    /**
     * @notice Configure VeSilo delegator
     * @param _delegator VeSilo delegator smart contract address
     */
    function setVeSiloDelegator(IVeSiloDelegatorViaCCIP _delegator) external;
}
