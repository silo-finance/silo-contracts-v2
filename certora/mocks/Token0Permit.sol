// SPDX-License-Identifier: MIT
pragma solidity >=0.8.21;




import {SimpleERC20} from "./SimpleERC20.sol";


contract Token0Permit is SimpleERC20  {


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
