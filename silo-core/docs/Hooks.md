# Silo hooks
Silo provides a comprehensive hooks system allowing flexibility to extend it.

### deposit fn hook actions
```Hook.depositAction(collateralType)``` (beforeAction and afterAction) \
Where `collateralType` is `ISilo.CollateralType`
- action ```Hook.DEPOSIT | Hook.COLLATERAL_TOKEN``` or ```Hook.DEPOSIT | Hook.PROTECTED_TOKEN``` \
before deposit data: abi.encodePacked(assets, shares, receiver)
```
    (
        uint256 depositedAssets,
        uint256 depositedShares,
        address receiver
    ) = Hook.beforeDepositDecode(_inputAndOutput);
```
after deposit data: abi.encodePacked(assets, shares, receiver, receivedAssets, mintedShares)
```
    (
        uint256 depositedAssets,
        uint256 depositedShares,
        address receiver,
        uint256 receivedAssets,
        uint256 mintedShares
    ) = Hook.afterDepositDecode(_inputAndOutput);
```

```Hook.shareTokenTransfer(tokenType)``` (afterAction) \
Where `tokenType` is `Hook.COLLATERAL_TOKEN` or `Hook.PROTECTED_TOKEN`
- action: ```Hook.SHARE_TOKEN_TRANSFER | Hook.COLLATERAL_TOKEN``` or ```Hook.SHARE_TOKEN_TRANSFER | Hook.PROTECTED_TOKEN``` \
data: abi.encodePacked(sender, recipient, amount, balanceOfSender, balanceOfRecepient, totalSupply)
```
    (
        address sender,
        address recipient,
        uint256 amount,
        uint256 senderBalance,
        uint256 recipientBalance,
        uint256 totalSupply
    ) = Hook.afterTokenTransferDecode(inputAndOutput);
```

### withdraw fn hook actions
```Hook.withdrawAction(collateralType)``` (beforeAction and afterAction) \
Where `collateralType` is `ISilo.CollateralType`
- action ```Hook.WITHDRAW | Hook.COLLATERAL_TOKEN``` or ```Hook.WITHDRAW | Hook.PROTECTED_TOKEN``` \
before withdraw data: abi.encodePacked(assets, shares, receiver, owner, spender)
```
    Hook.BeforeWithdrawInput memory input = Hook.beforeWithdrawDecode(_inputAndOutput);
```
after withdraw data: abi.encodePacked(assets, shares, receiver, owner, spender, withdrawnAssets, withdrawnShares)
```
    Hook.AfterWithdrawInput memory input = Hook.afterWithdrawDecode(_inputAndOutput);
```
```Hook.shareTokenTransfer(tokenType)``` (afterAction) \
Where `tokenType` is `Hook.COLLATERAL_TOKEN` or `Hook.PROTECTED_TOKEN`
- action: ```Hook.SHARE_TOKEN_TRANSFER | Hook.COLLATERAL_TOKEN``` or ```Hook.SHARE_TOKEN_TRANSFER | Hook.PROTECTED_TOKEN``` \
data: abi.encodePacked(sender, recipient, amount, balanceOfSender, balanceOfRecepient, totalSupply)
```
    (
        address sender,
        address recipient,
        uint256 amount,
        uint256 senderBalance,
        uint256 recipientBalance,
        uint256 totalSupply
    ) = Hook.afterTokenTransferDecode(inputAndOutput);
```

### borrow
- ```Hook.BORROW | Hook.LEVERAGE | Hook.SAME_ASSET``` (beforeAction) or
- ```Hook.BORROW | Hook.LEVERAGE | Hook.TWO_ASSETS``` (beforeAction) or
- ```Hook.BORROW | Hook.NONE | Hook.SAME_ASSET``` (beforeAction) or
- ```Hook.BORROW | Hook.NONE | Hook.TWO_ASSETS``` (beforeAction) \
data: abi.encodePacked(_args.assets, _args.shares, _args.receiver, _args.borrower)
- ```Hook.COLLATERAL_TOKEN | Hook.SHARE_TOKEN_TRANSFER``` (afterAction) and
- ```Hook.DEBT_TOKEN | Hook.SHARE_TOKEN_TRANSFER``` (afterAction) \
data: abi.encodePacked(_sender, _recipient, _amount, balanceOf(_sender), balanceOf(_recipient), totalSupply())
- ```Hook.BORROW | Hook.LEVERAGE | Hook.SAME_ASSET``` (afterAction) or
- ```Hook.BORROW | Hook.LEVERAGE | Hook.TWO_ASSETS``` (afterAction) or
- ```Hook.BORROW | Hook.NONE | Hook.SAME_ASSET``` (afterAction) or
- ```Hook.BORROW | Hook.NONE | Hook.TWO_ASSETS``` (afterAction) \
data: abi.encodePacked(_args.assets, _args.shares, _args.receiver, _args.borrower, assets, shares)

### repay
- ```Hook.REPAY``` (beforeAction) \
data: abi.encodePacked(_assets, _shares, _borrower, _repayer)
- ```Hook.COLLATERAL_TOKEN | Hook.SHARE_TOKEN_TRANSFER``` (afterAction) and
- ```Hook.DEBT_TOKEN | Hook.SHARE_TOKEN_TRANSFER``` (afterAction) \
data: abi.encodePacked(_sender, _recipient, _amount, balanceOf(_sender), balanceOf(_recipient), totalSupply())
- ```Hook.REPAY``` (afterAction) \
data: abi.encodePacked(_assets, _shares, _borrower, _repayer, assets, shares)

### leverageSameAsset
- ```Hook.BORROW | Hook.LEVERAGE | Hook.SAME_ASSE``` (beforeAction) \
abi.encodePacked(_depositAssets, _borrowAssets, _borrower, _collateralType)
- ```Hook.DEBT_TOKEN | Hook.SHARE_TOKEN_TRANSFER``` (afterAction) \
data: abi.encodePacked(_sender, _recipient, _amount, balanceOf(_sender), balanceOf(_recipient), totalSupply())
- ```Hook.COLLATERAL_TOKEN | Hook.SHARE_TOKEN_TRANSFER``` (afterAction) or
- ```Hook.PROTECTED_TOKEN | Hook.SHARE_TOKEN_TRANSFER``` (afterAction) \
data: abi.encodePacked(_sender, _recipient, _amount, balanceOf(_sender), balanceOf(_recipient), totalSupply())
- ```Hook.BORROW | Hook.LEVERAGE | Hook.SAME_ASSE``` (afterAction) \
data: abi.encodePacked(_depositAssets, _borrowAssets, _borrower, _collateralType, depositedShares, borrowedShares)

### transitionCollateral
- ```Hook.TRANSITION_COLLATERAL``` (beforeAction) \
data: abi.encodePacked(_shares, _owner, _withdrawType, assets)
- ```Hook.COLLATERAL_TOKEN | Hook.SHARE_TOKEN_TRANSFER``` (afterAction) and
- ```Hook.PROTECTED_TOKEN | Hook.SHARE_TOKEN_TRANSFER``` (afterAction) \
data: abi.encodePacked(_sender, _recipient, _amount, balanceOf(_sender), balanceOf(_recipient), totalSupply())
- ```Hook.TRANSITION_COLLATERAL``` (afterAction) \
data: abi.encodePacked(_shares, _owner, _withdrawType, assets)

### switchCollateralTo
- ```Hook.SWITCH_COLLATERAL``` (beforeAction) \
data: abi.encodePacked(_toSameAsset)
- ```Hook.SWITCH_COLLATERAL``` (afterAction) \
data: abi.encodePacked(_toSameAsset)

### flashLoan
- ```Hook.FLASH_LOAN``` (beforeAction) \
data: abi.encodePacked(_receiver, _token, _amount)
- ```Hook.FLASH_LOAN``` (afterAction) \
data: abi.encodePacked(_receiver, _token, _amount, success)