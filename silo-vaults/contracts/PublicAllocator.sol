// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";
import {UtilsLib} from "morpho-blue/libraries/UtilsLib.sol";

import {RevertLib} from "silo-core/contracts/lib/RevertLib.sol";

import {
    FlowCaps,
    FlowCapsConfig,
    Withdrawal,
    MAX_SETTABLE_FLOW_CAP,
    IPublicAllocatorStaticTyping,
    IPublicAllocatorBase
} from "./interfaces/IPublicAllocator.sol";
import {ISiloVault, MarketAllocation} from "./interfaces/ISiloVault.sol";

import {ErrorsLib} from "./libraries/ErrorsLib.sol";
import {EventsLib} from "./libraries/EventsLib.sol";

/// @title PublicAllocator
/// @author Forked with gratitude from Morpho Labs.
/// @custom:contact security@morpho.org
/// @notice Publicly callable allocator for SiloVault vaults.
contract PublicAllocator is IPublicAllocatorStaticTyping {
    using UtilsLib for uint256;
    
    /* STORAGE */

    /// @inheritdoc IPublicAllocatorBase
    mapping(ISiloVault => address) public admin;
    /// @inheritdoc IPublicAllocatorBase
    mapping(ISiloVault => uint256) public fee;
    /// @inheritdoc IPublicAllocatorBase
    mapping(ISiloVault => uint256) public accruedFee;
    /// @inheritdoc IPublicAllocatorStaticTyping
    mapping(ISiloVault => mapping(IERC4626 => FlowCaps)) public flowCaps;

    /* MODIFIER */

    /// @dev Reverts if the caller is not the admin nor the owner of this vault.
    modifier onlyAdminOrVaultOwner(ISiloVault vault) {
        if (msg.sender != admin[vault] && msg.sender != ISiloVault(vault).owner()) {
            revert ErrorsLib.NotAdminNorVaultOwner();
        }
        _;
    }

    /* ADMIN OR VAULT OWNER ONLY */

    /// @inheritdoc IPublicAllocatorBase
    function setAdmin(ISiloVault vault, address newAdmin) external virtual onlyAdminOrVaultOwner(vault) {
        if (admin[vault] == newAdmin) revert ErrorsLib.AlreadySet();
        admin[vault] = newAdmin;
        emit EventsLib.SetAdmin(msg.sender, vault, newAdmin);
    }

    /// @inheritdoc IPublicAllocatorBase
    function setFee(ISiloVault vault, uint256 newFee) external virtual onlyAdminOrVaultOwner(vault) {
        if (fee[vault] == newFee) revert ErrorsLib.AlreadySet();
        fee[vault] = newFee;
        emit EventsLib.SetFee(msg.sender, vault, newFee);
    }

    /// @inheritdoc IPublicAllocatorBase
    function setFlowCaps(ISiloVault vault, FlowCapsConfig[] calldata config)
        external
        virtual
        onlyAdminOrVaultOwner(vault)
    {
        for (uint256 i = 0; i < config.length; i++) {
            FlowCapsConfig memory cfg = config[i];
            IERC4626 market = cfg.market;
            
            if (!vault.config(market).enabled && (cfg.caps.maxIn > 0 || cfg.caps.maxOut > 0)) {
                revert ErrorsLib.MarketNotEnabled(market);
            }
            if (cfg.caps.maxIn > MAX_SETTABLE_FLOW_CAP || cfg.caps.maxOut > MAX_SETTABLE_FLOW_CAP) {
                revert ErrorsLib.MaxSettableFlowCapExceeded();
            }
            
            flowCaps[vault][market] = cfg.caps;
        }

        emit EventsLib.SetFlowCaps(msg.sender, vault, config);
    }

    /// @inheritdoc IPublicAllocatorBase
    function transferFee(ISiloVault vault, address payable feeRecipient) external virtual onlyAdminOrVaultOwner(vault) {
        uint256 claimed = accruedFee[vault];
        accruedFee[vault] = 0;
        (bool success, bytes memory data) = feeRecipient.call{value: claimed}("");
        if (!success) RevertLib.revertBytes(data, "fee transfer failed");

        emit EventsLib.TransferFee(msg.sender, vault, claimed, feeRecipient);
    }

    /* PUBLIC */

    /// @inheritdoc IPublicAllocatorBase
    function reallocateTo(ISiloVault vault, Withdrawal[] calldata withdrawals, IERC4626 supplyMarket)
        external
        payable
        virtual
    {
        if (msg.value != fee[vault]) revert ErrorsLib.IncorrectFee();
        if (msg.value > 0) accruedFee[vault] += msg.value;

        if (withdrawals.length == 0) revert ErrorsLib.EmptyWithdrawals();

        if (!vault.config(supplyMarket).enabled) revert ErrorsLib.MarketNotEnabled(supplyMarket);

        MarketAllocation[] memory allocations = new MarketAllocation[](withdrawals.length + 1);
        uint128 totalWithdrawn;

        IERC4626 market;
        IERC4626 prevMarket;
        
        for (uint256 i = 0; i < withdrawals.length; i++) {
            prevMarket = market;
            Withdrawal memory withdrawal = withdrawals[i];
            market = withdrawal.market;

            if (!vault.config(market).enabled) revert ErrorsLib.MarketNotEnabled(market);
            if (withdrawal.amount == 0) revert ErrorsLib.WithdrawZero(market);

            if (address(market) <= address(prevMarket)) revert ErrorsLib.InconsistentWithdrawals();
            if (address(market) == address(supplyMarket)) revert ErrorsLib.DepositMarketInWithdrawals();

            uint256 assets = _expectedSupplyAssets(market, address(vault));

            if (flowCaps[vault][market].maxOut < withdrawal.amount) revert ErrorsLib.MaxOutflowExceeded(market);
            if (assets < withdrawal.amount) revert ErrorsLib.NotEnoughSupply(market);

            flowCaps[vault][market].maxIn += withdrawal.amount;
            flowCaps[vault][market].maxOut -= withdrawal.amount;
            allocations[i].market = market;
            allocations[i].assets = assets - withdrawal.amount;

            totalWithdrawn += withdrawal.amount;

            emit EventsLib.PublicWithdrawal(msg.sender, vault, market, withdrawal.amount);
        }

        if (flowCaps[vault][supplyMarket].maxIn < totalWithdrawn) revert ErrorsLib.MaxInflowExceeded(supplyMarket);

        flowCaps[vault][supplyMarket].maxIn -= totalWithdrawn;
        flowCaps[vault][supplyMarket].maxOut += totalWithdrawn;
        allocations[withdrawals.length].market = supplyMarket;
        allocations[withdrawals.length].assets = type(uint256).max;

        vault.reallocate(allocations);

        emit EventsLib.PublicReallocateTo(msg.sender, vault, supplyMarket, totalWithdrawn);
    }

    /// @notice Returns the expected supply assets balance of `user` on a market after having accrued interest.
    function _expectedSupplyAssets(IERC4626 _market, address _user) internal view virtual returns (uint256 assets) {
        assets = _market.convertToAssets(_market.balanceOf(_user));
    }
}
