# Silo hooks
Silo provides a comprehensive hooks system allowing flexibility to extend it.

## deposit fn hook actions
```Hook.depositAction(collateralType)``` (beforeAction and afterAction) \
Where `collateralType` is `ISilo.CollateralType`
- actions: \
```Hook.DEPOSIT | Hook.COLLATERAL_TOKEN``` or \
```Hook.DEPOSIT | Hook.PROTECTED_TOKEN```

before deposit data: abi.encodePacked(assets, shares, receiver)
```
Hook.BeforeDepositInput memory input = Hook.beforeDepositDecode(_inputAndOutput);
```
after deposit data: abi.encodePacked(assets, shares, receiver, receivedAssets, mintedShares)
```
Hook.AfterDepositInput memory input = Hook.afterDepositDecode(_inputAndOutput);
```

```Hook.shareTokenTransfer(tokenType)``` (afterAction) \
Where `tokenType` is `Hook.COLLATERAL_TOKEN` or `Hook.PROTECTED_TOKEN`
- actions: \
```Hook.SHARE_TOKEN_TRANSFER | Hook.COLLATERAL_TOKEN``` or \
```Hook.SHARE_TOKEN_TRANSFER | Hook.PROTECTED_TOKEN```

data: abi.encodePacked(sender, recipient, amount, balanceOfSender, balanceOfRecepient, totalSupply)
```
Hook.AfterTokenTransfer memory input = Hook.afterTokenTransferDecode(_inputAndOutput);
```

## withdraw fn hook actions
```Hook.withdrawAction(collateralType)``` (beforeAction and afterAction) \
Where `collateralType` is `ISilo.CollateralType`
- actions: \
```Hook.WITHDRAW | Hook.COLLATERAL_TOKEN``` or \
```Hook.WITHDRAW | Hook.PROTECTED_TOKEN```

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
- actions: \
```Hook.SHARE_TOKEN_TRANSFER | Hook.COLLATERAL_TOKEN``` or \
```Hook.SHARE_TOKEN_TRANSFER | Hook.PROTECTED_TOKEN```

data: abi.encodePacked(sender, recipient, amount, balanceOfSender, balanceOfRecepient, totalSupply)
```
Hook.AfterTokenTransfer memory input = Hook.afterTokenTransferDecode(_inputAndOutput);
```

## borrow fn hook actions
```Hook.borrowAction(leverage, sameAsset)``` (beforeAction and afterAction) \
- actions: \
```Hook.BORROW | Hook.LEVERAGE | Hook.SAME_ASSET``` or \
```Hook.BORROW | Hook.LEVERAGE | Hook.TWO_ASSETS``` or \
```Hook.BORROW | Hook.NONE | Hook.SAME_ASSET``` or \
```Hook.BORROW | Hook.NONE | Hook.TWO_ASSETS```

before borrow data: abi.encodePacked(assets, shares, receiver, borrower)
```
Hook.BeforeBorrowInput memory input = Hook.beforeBorrowDecode(_inputAndOutput);
```
after borrow data: abi.encodePacked(assets, shares, receiver, borrower, borrowedAssets, borrowedShares)
```
Hook.AfterBorrowInput memory input = Hook.afterBorrowDecode(_inputAndOutput);
```

```Hook.shareTokenTransfer(tokenType)``` (afterAction) \
Where `tokenType` is `Hook.DEBT_TOKEN`
- action: ```Hook.SHARE_TOKEN_TRANSFER | Hook.DEBT_TOKEN```

data: abi.encodePacked(sender, recipient, amount, balanceOfSender, balanceOfRecepient, totalSupply)
```
Hook.AfterTokenTransfer memory input = Hook.afterTokenTransferDecode(_inputAndOutput);
```

## repay fn hook actions
- ```Hook.REPAY``` (beforeAction and afterAction) \
before repay data: abi.encodePacked(assets, shares, borrower, repayer)
```
Hook.BeforeRepayInput memory input = Hook.beforeRepayDecode(_inputAndOutput);
```
after repay data: abi.encodePacked(assets, shares, borrower, repayer, repayedAssets, repayedShares)
```
Hook.AfterRepayInput memory input = Hook.afterRepayDecode(_inputAndOutput);
```

```Hook.shareTokenTransfer(tokenType)``` (afterAction) \
Where `tokenType` is `Hook.DEBT_TOKEN`
- action: ```Hook.SHARE_TOKEN_TRANSFER | Hook.DEBT_TOKEN```

data: abi.encodePacked(sender, recipient, amount, balanceOfSender, balanceOfRecepient, totalSupply)
```
Hook.AfterTokenTransfer memory input = Hook.afterTokenTransferDecode(_inputAndOutput);
```

## leverageSameAsset
- ```Hook.BORROW | Hook.LEVERAGE | Hook.SAME_ASSE``` (beforeAction) \
abi.encodePacked(_depositAssets, _borrowAssets, _borrower, _collateralType)
- ```Hook.DEBT_TOKEN | Hook.SHARE_TOKEN_TRANSFER``` (afterAction) \
data: abi.encodePacked(_sender, _recipient, _amount, balanceOf(_sender), balanceOf(_recipient), totalSupply())
- ```Hook.COLLATERAL_TOKEN | Hook.SHARE_TOKEN_TRANSFER``` (afterAction) or
- ```Hook.PROTECTED_TOKEN | Hook.SHARE_TOKEN_TRANSFER``` (afterAction) \
data: abi.encodePacked(_sender, _recipient, _amount, balanceOf(_sender), balanceOf(_recipient), totalSupply())
- ```Hook.BORROW | Hook.LEVERAGE | Hook.SAME_ASSE``` (afterAction) \
data: abi.encodePacked(_depositAssets, _borrowAssets, _borrower, _collateralType, depositedShares, borrowedShares)

## transitionCollateral
- ```Hook.TRANSITION_COLLATERAL``` (beforeAction) \
data: abi.encodePacked(_shares, _owner, _withdrawType, assets)
- ```Hook.COLLATERAL_TOKEN | Hook.SHARE_TOKEN_TRANSFER``` (afterAction) and
- ```Hook.PROTECTED_TOKEN | Hook.SHARE_TOKEN_TRANSFER``` (afterAction) \
data: abi.encodePacked(_sender, _recipient, _amount, balanceOf(_sender), balanceOf(_recipient), totalSupply())
- ```Hook.TRANSITION_COLLATERAL``` (afterAction) \
data: abi.encodePacked(_shares, _owner, _withdrawType, assets)

## switchCollateralTo
- ```Hook.SWITCH_COLLATERAL``` (beforeAction) \
data: abi.encodePacked(_toSameAsset)
- ```Hook.SWITCH_COLLATERAL``` (afterAction) \
data: abi.encodePacked(_toSameAsset)

## flashLoan fn hook actions
- ```Hook.FLASH_LOAN``` (beforeAction and afterAction)

before flash loan data: abi.encodePacked(receiver, token, amount)
```
Hook.BeforeFlashLoanInput memory input = Hook.beforeFlashLoanDecode(_inputAndOutput);
```
after flash loan data: abi.encodePacked(receiver, token, amount, fee)
```
Hook.AfterFlashLoanInput memory input = Hook.afterFlashLoanDecode(_inputAndOutput);
```