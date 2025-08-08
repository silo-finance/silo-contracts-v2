// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC4626Upgradeable, IERC4626, ERC20Upgradeable, IERC20} from "openzeppelin5-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {Whitelist} from "./modules/Whitelist.sol";

import {ISilo} from "../interfaces/ISilo.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";
import {IFirmVault} from "../interfaces/IFirmVault.sol";

interface IRM { // TODO replace with correct interface 
    function pendingAccrueInterest(uint256 _blockTimestamp) external view returns (uint256 interest);
}

contract FirmVault is ERC4626Upgradeable, Whitelist, IFirmVault {
    using SafeERC20 for IERC20;

    ISilo public firmSilo;
    IRM public interestRateModel;

    constructor() {
        // lock ownership for implementation
        firmSilo = ISilo(address(0xdead));
    }

    function initialize(address _initialOwner, ISilo _firmSilo) external initializer {
        require(address(firmSilo) == address(0), AlreadyInitialized());
        require(address(_firmSilo) != address(0), AddressZero());
        require(_initialOwner != address(0), OwnerZero()); // TODO allow for immutable?

        firmSilo = _firmSilo;
        interestRateModel = IRM(_firmSilo.config().getConfig(address(_firmSilo)).interestRateModel);

        emit Initialized(_initialOwner, _firmSilo);

        __Whitelist_init(_initialOwner);

        __ERC4626_init(IERC20(firmSilo.asset()));

        __ERC20_init("FIRM Vault for FirmSilo", "FIRMVault");
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver) 
        public 
        virtual 
        override 
        onlyWhitelisted(_receiver) 
        returns (uint256 shares) 
    {
        _claimFreeShares(_receiver);

        shares = super.deposit(_assets, _receiver);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) public 
        virtual 
        override 
        onlyWhitelisted(_receiver) 
        returns (uint256 assets) 
    {
        _claimFreeShares(_receiver);

        assets = super.mint(_shares, _receiver);
    }

    /// @inheritdoc ERC20Upgradeable
    function transfer(address _to, uint256 _value) 
        public 
        virtual 
        override(ERC20Upgradeable, IERC20) 
        onlyWhitelisted(_to)
        returns (bool) 
    {
        return super.transfer(_to, _value);
    }

    /// @inheritdoc ERC20Upgradeable
    function transferFrom(address _from, address _to, uint256 _value)
        public
        virtual
        override(ERC20Upgradeable, IERC20)
        onlyWhitelisted(_to)
        returns (bool)
    {
        return super.transferFrom(_from, _to, _value);
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view virtual override returns (uint256 total) {
        // TODO - change this to add deposit to first depostor 

        if (totalSupply() == 0) {
            // when vault is empty and everyone withdrew but there are still assets left, 
            // then reset totalAssets to 0 so the assets that remains goes to first depositor
            return 0;
        }

        // TODO should we try-catch for pendingAccrueInterest?

        uint256 pendingInterest = interestRateModel.pendingAccrueInterest(block.timestamp);

        total = firmSilo.maxWithdraw(address(this)) + pendingInterest;
    }

    function _claimFreeShares(address _receiver) internal virtual {
        if (totalSupply() != 0) return;

        uint256 freeFirmAssets = firmSilo.maxWithdraw(address(this));
        if (freeFirmAssets == 0) return;

        uint256 freeShares = _convertToShares(freeFirmAssets, Math.Rounding.Floor); // TODO check if this is correct
        if (freeShares == 0) return;

        _mint(_receiver, freeShares);
        emit FreeShares(_receiver, freeShares);
    }

    /**
     * @dev Deposit/mint common workflow.
     */
    function _deposit(address _caller, address _receiver, uint256 _assets, uint256 _shares) internal virtual override {
        require(_shares != 0, ZeroShares());
        require(_assets != 0, ZeroAssets());

        super._deposit(_caller, _receiver, _assets, _shares);

        IERC20(asset()).forceApprove(address(firmSilo), _assets);
        firmSilo.deposit(_assets, address(this));
    }

    /**
     * @dev Withdraw/redeem common workflow.
     */
    function _withdraw(
        address _caller,
        address _receiver,
        address _owner,
        uint256 _assetsToTransfer,
        uint256 _sharesToBurn
    ) internal virtual override {
        require(_sharesToBurn != 0, ZeroShares());
        require(_assetsToTransfer != 0, ZeroAssets());

        firmSilo.withdraw(_assetsToTransfer, address(this), address(this));
        super._withdraw(_caller, _receiver, _owner, _assetsToTransfer, _sharesToBurn);
    }

    function _update(address _from, address _to, uint256 _value) internal virtual override {
        require(_from != _to, SelfTransferNotAllowed());
        require(_value != 0, ZeroTransfer());

        super._update(_from, _to, _value);
    }
}
