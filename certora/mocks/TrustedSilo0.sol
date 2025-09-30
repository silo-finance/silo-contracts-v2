// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin5/token/ERC20/utils/SafeERC20.sol";
import {SimpleCollateralToken0} from "./SimpleCollateralToken0.sol"; 



contract TrustedSilo0  is SimpleCollateralToken0 {

    using SafeERC20 for IERC20;

    IERC20 ASSET;
    IShareToken SHARE_TOKEN;
    IShareToken DEBT_TOKEN;
    uint256 totalAssets; 
    uint256 totalDebtAssets; 


    bytes32 internal constant _FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");
    uint256 internal constant FEE = 10; 

    function asset() external returns (address) {
        return address(ASSET); 
    }
    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data) 
        external virtual
        returns (bool)
    {
        IERC20(_token).safeTransfer(address(_receiver), _amount);
        
        require(_receiver.onFlashLoan(msg.sender, _token, _amount, FEE, _data) == _FLASHLOAN_CALLBACK);

        IERC20(_token).safeTransferFrom(address(_receiver), address(this), _amount + FEE);

        return true;
    }


    function repayShares(uint256 _shares, address _borrower) 
        external 
        returns (uint256 assets) {
            assets = convertToAmount_DebtToken(_shares);
            DEBT_TOKEN.burn(_borrower, msg.sender, _shares);
            totalDebtAssets -= assets;
            ASSET.safeTransferFrom(msg.sender, address(this), assets);
    }

    function redeem(uint256 _shares, address _receiver, address _owner, ISilo.CollateralType _collateralType)
        external
        returns (uint256 assets) {
            assets = convertToAmount_ShareToken(_shares);
            SHARE_TOKEN.burn(_owner, msg.sender, _shares);
            totalAssets -= assets;
            ASSET.safeTransfer(_receiver, assets);
    }

    function deposit(uint256 _assets, address _receiver, ISilo.CollateralType _collateralType)
        external
        returns (uint256 shares)
        {
            shares = convertToShares_ShareToken(_assets);
            SHARE_TOKEN.mint(_receiver, msg.sender, shares);
            totalAssets += _assets;
            ASSET.safeTransferFrom(msg.sender, address(this), _assets);
        }

    function borrow(uint256 _assets, address _receiver, address _borrower)
        external
        returns (uint256 shares) {
            shares = convertToShares_DebtToken(_assets);
            DEBT_TOKEN.mint(_borrower, msg.sender, shares);
            totalDebtAssets += _assets;
            ASSET.safeTransfer(_receiver, _assets);
        }
        

    function maxRepay(address _borrower) external view returns (uint256) {
        return convertToAmount_DebtToken(DEBT_TOKEN.balanceOf(_borrower));
    }

    function convertToAmount_DebtToken(uint256 shares) internal view virtual returns (uint256) {
        // return shares * totalDebtAssets / DEBT_TOKEN.totalSupply();
        return shares;
    }

    function convertToShares_DebtToken(uint256 assets) internal view virtual returns (uint256) {
        //if (DEBT_TOKEN.totalSupply() == 0)
            return assets;
        //return (assets * DEBT_TOKEN.totalSupply() / totalDebtAssets ) + 1;

    }

    function convertToShares_ShareToken(uint256 assets) internal view virtual returns (uint256) {
        //if (SHARE_TOKEN.totalSupply() == 0)
            return assets;
        //return assets * SHARE_TOKEN.totalSupply() / totalAssets;
    }

    function convertToAmount_ShareToken(uint256 shares) internal view virtual returns (uint256) {
        //return (shares * totalAssets / SHARE_TOKEN.totalSupply() ) + 1;
        return shares;
    }


    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    mapping(address account => uint256) private _nonces;

    function _useNonce(address owner) internal virtual returns (uint256) {
       return _nonces[owner]++;
    }

    
    
   function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {

      

         require (block.timestamp <= deadline) ;

         bytes32 hash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, _useNonce(owner), deadline));

         address signer = ecrecover(hash, v, r, s);
         require (signer == owner); 

        _approve(owner, spender, value); 
    }
}