// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ERC4626Upgradeable, IERC4626, ERC20Upgradeable, IERC20} from "openzeppelin5-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import {Strings} from "openzeppelin5/utils/Strings.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";

import {Whitelist} from "./modules/Whitelist.sol";

import {ISilo} from "../interfaces/ISilo.sol";
import {IInterestRateModel} from "../interfaces/IInterestRateModel.sol";

interface IRM {
    function pendingAccrueInterest(uint256 _blockTimestamp) external view returns (uint256 interest);
    function accrueInterest() external;
}

/*
FIRMVault (ERC-4626):

Before deposit check if depositors whitelist is configured if so verify if the depositor is whitelisted.

Claim rewards before any action.

Handle the case when we have no shares and we have to claim rewards 
(If we have an interest to distribute and total shares is 0 add interest to the deposit amount).
*/

contract FirmVault is ERC4626Upgradeable, Whitelist {
    using SafeERC20 for IERC20;

    ISilo firmSilo;
    IRM interestRateModel;

    event Initialized(address indexed _initialOwner, ISilo indexed _firmSilo);

    error ZeroShares();
    error ZeroAssets();
    error SelfTransferNotAllowed();
    error ZeroTransfer();
    error OwnerZero();
    error AddressZero();
    error AlreadyInitialized();


    modifier accrueInterest() {
        /*
        without depositors there is no need to accrue interest, 
        it is also expected, that for this period interest will be cumulating
        */
        if (totalSupply() != 0) {
            interestRateModel.accrueInterest();
        }

        _;
    }

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

        string memory siloId = Strings.toString(firmSilo.config().SILO_ID());

        __ERC20_init(string.concat("FIRM Vault for Silo-", siloId), string.concat("FV4S-", siloId));
    }

    /// @inheritdoc IERC4626
    function deposit(uint256 _assets, address _receiver) 
        public 
        virtual 
        override 
        accrueInterest 
        onlyWhitelisted(_receiver) 
        returns (uint256 shares) 
    {
        shares = super.deposit(_assets, _receiver);
    }

    /// @inheritdoc IERC4626
    function mint(uint256 _shares, address _receiver) public 
        virtual 
        override 
        accrueInterest 
        onlyWhitelisted(_receiver) 
        returns (uint256 assets) 
    {
        assets = super.mint(_shares, _receiver);
    }

    /// @inheritdoc IERC4626
    function withdraw(uint256 _assets, address _receiver, address _owner)
        public
        virtual
        override
        accrueInterest
        returns (uint256 shares)
    {
        shares = super.withdraw(_assets, _receiver, _owner);
    }

    /// @inheritdoc IERC4626
    function redeem(uint256 _shares, address _receiver, address _owner)
        public
        virtual
        override
        accrueInterest
        returns (uint256 assets)
    {
        assets = super.redeem(_shares, _receiver, _owner);
    }

    /// @inheritdoc ERC20Upgradeable
    function transfer(address _to, uint256 _value) 
        public 
        virtual 
        override(ERC20Upgradeable, IERC20) 
        accrueInterest // TODO do we have to accrue on transfer?
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
        accrueInterest 
        onlyWhitelisted(_to)
        returns (bool)
    {
        return super.transferFrom(_from, _to, _value);
    }

    /// @inheritdoc IERC4626
    function totalAssets() public view virtual override returns (uint256 total) {
        if (totalSupply() == 0) {
            // when vault is empty and everyone withdrew but there are still assets left, 
            // then reset totalAssets to 0 so the assets that remains goes to first depositor
            return 0;
        }

        uint256 pendingInterest = interestRateModel.pendingAccrueInterest(block.timestamp);

        total = firmSilo.maxWithdraw(address(this)) + pendingInterest;
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
