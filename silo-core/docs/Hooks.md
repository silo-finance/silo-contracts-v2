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

## leverage fn hook actions
```Hook.borrowAction(leverage, sameAsset)``` (beforeAction and afterAction) \
- actions: \
```Hook.BORROW | Hook.LEVERAGE | Hook.SAME_ASSET``` or \
```Hook.BORROW | Hook.LEVERAGE | Hook.TWO_ASSETS``` or

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

```Hook.shareTokenTransfer(tokenType)``` (afterAction) \
Where `tokenType` is `Hook.COLLATERAL_TOKEN` or `Hook.PROTECTED_TOKEN`
- actions: \
```Hook.SHARE_TOKEN_TRANSFER | Hook.COLLATERAL_TOKEN``` or \
```Hook.SHARE_TOKEN_TRANSFER | Hook.PROTECTED_TOKEN```

data: abi.encodePacked(sender, recipient, amount, balanceOfSender, balanceOfRecepient, totalSupply)
```
Hook.AfterTokenTransfer memory input = Hook.afterTokenTransferDecode(_inputAndOutput);
```

## leverageSameAsset fn hook actions
```Hook.LEVERAGE_SAME_ASSET``` (beforeAction and afterAction) \
- action: ```Hook.BORROW | Hook.LEVERAGE | Hook.SAME_ASSET``` \
before leverage data: abi.encodePacked(depositAssets, borrowAssets, borrower, collateralType)
```
Hook.BeforeLeverageSameAssetInput memory input = Hook.beforeLeverageSameAssetDecode(_inputAndOutput);
```
after leverage data: abi.encodePacked(depositAssets, borrowAssets, borrower, collateralType, depositedShares, borrowedShares)
```
Hook.BeforeLeverageSameAssetInput memory input = Hook.beforeLeverageSameAssetDecode(_inputAndOutput);
```
```Hook.shareTokenTransfer(tokenType)``` (afterAction) \
Where `tokenType` is `Hook.DEBT_TOKEN`
- action: ```Hook.SHARE_TOKEN_TRANSFER | Hook.DEBT_TOKEN```

data: abi.encodePacked(sender, recipient, amount, balanceOfSender, balanceOfRecepient, totalSupply)
```
Hook.AfterTokenTransfer memory input = Hook.afterTokenTransferDecode(_inputAndOutput);
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

## transitionCollateral fn hook actions
```Hook.transitionCollateralAction(withdrawType)``` (beforeAction and afterAction) \
Where `withdrawType` is `Hook.COLLATERAL_TOKEN` or `Hook.PROTECTED_TOKEN`
- actions: \
```Hook.TRANSITION_COLLATERAL | Hook.COLLATERAL_TOKEN``` or \
```Hook.TRANSITION_COLLATERAL | Hook.PROTECTED_TOKEN```

data before transition collateral: abi.encodePacked(shares, owner, assets)
```
Hook.BeforeTransitionCollateralInput memory input = Hook.beforeTransitionCollateralDecode(_inputAndOutput);
```
data after transition collateral: abi.encodePacked(shares, owner, assets)
```
Hook.AfterTransitionCollateralInput memory input = Hook.afterTransitionCollateralDecode(_inputAndOutput);
```

```Hook.shareTokenTransfer(tokenType)``` (afterAction) \
Where `tokenType` is `Hook.COLLATERAL_TOKEN` and `Hook.PROTECTED_TOKEN`
- actions: \
```Hook.SHARE_TOKEN_TRANSFER | Hook.COLLATERAL_TOKEN``` and \
```Hook.SHARE_TOKEN_TRANSFER | Hook.PROTECTED_TOKEN```


## switchCollateralTo fn hook actions
```Hook.switchCollateralAction(toSameAsset)``` (beforeAction and afterAction) \
Where `toSameAsset` is `true` or `false` which converts to `Hook.SAME_ASSET` or `Hook.TWO_ASSETS`
- actions: \
 ```Hook.SWITCH_COLLATERAL | Hook.SAME_ASSET``` or \
 ```Hook.SWITCH_COLLATERAL | Hook.TWO_ASSETS```

data: abi.encodePacked(msg.sender)
```
Hook.SwitchCollateralInput memory input = Hook.switchCollateralDecode(_inputAndOutput);
```

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

## liquidationCall fn hook actions
- ```Hook.LIQUIDATION``` (beforeAction and afterAction)

before liquidation call data: abi.encodePacked(siloWithDebt, collateralAsset, debtAsset, borrower, debtToCover, receiveSToken)
```
Hook.BeforeLiquidationInput memory input = Hook.beforeLiquidationDecode(_inputAndOutput);
```
after liquidation call data: abi.encodePacked(siloWithDebt, collateralAsset, debtAsset, borrower, debtToCover,receiveSToken, withdrawCollateral, repayDebtAssets)
```
Hook.AfterLiquidationInput memory input = Hook.afterLiquidationDecode(_inputAndOutput);
```
```Hook.shareTokenTransfer(tokenType)``` (afterAction) \
Where `tokenType` is `Hook.DEBT_TOKEN`
- action: ```Hook.SHARE_TOKEN_TRANSFER | Hook.DEBT_TOKEN```

data: abi.encodePacked(sender, recipient, amount, balanceOfSender, balanceOfRecepient, totalSupply)
```
Hook.AfterTokenTransfer memory input = Hook.afterTokenTransferDecode(_inputAndOutput);
```
```Hook.shareTokenTransfer(tokenType)``` (afterAction) \
Where `tokenType` is `Hook.COLLATERAL_TOKEN` or `Hook.PROTECTED_TOKEN`
- actions: \
```Hook.SHARE_TOKEN_TRANSFER | Hook.COLLATERAL_TOKEN``` and \
```Hook.SHARE_TOKEN_TRANSFER | Hook.PROTECTED_TOKEN```
data: abi.encodePacked(sender, recipient, amount, balanceOfSender, balanceOfRecepient, totalSupply)
```
Hook.AfterTokenTransfer memory input = Hook.afterTokenTransferDecode(_inputAndOutput);
```
