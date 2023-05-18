import { BigNumberish } from '@ethersproject/bignumber';
export declare enum PoolSpecialization {
    GeneralPool = 0,
    MinimalSwapInfoPool = 1,
    TwoTokenPool = 2
}
export declare type FundManagement = {
    sender: string;
    fromInternalBalance: boolean;
    recipient: string;
    toInternalBalance: boolean;
};
export declare enum SwapKind {
    GivenIn = 0,
    GivenOut = 1
}
export declare type SingleSwap = {
    poolId: string;
    kind: SwapKind;
    assetIn: string;
    assetOut: string;
    amount: BigNumberish;
    userData: string;
};
export declare type Swap = {
    kind: SwapKind;
    singleSwap: SingleSwap;
    limit: BigNumberish;
    deadline: BigNumberish;
};
export declare type BatchSwapStep = {
    poolId: string;
    assetInIndex: number;
    assetOutIndex: number;
    amount: BigNumberish;
    userData: string;
};
export declare type BatchSwap = {
    kind: SwapKind;
    swaps: BatchSwapStep[];
    assets: string[];
    funds: FundManagement;
    limits: BigNumberish[];
    deadline: BigNumberish;
};
export declare type SwapRequest = {
    kind: SwapKind;
    tokenIn: string;
    tokenOut: string;
    amount: BigNumberish;
    poolId: string;
    lastChangeBlock: BigNumberish;
    from: string;
    to: string;
    userData: string;
};
export declare type JoinPoolRequest = {
    assets: string[];
    maxAmountsIn: BigNumberish[];
    userData: string;
    fromInternalBalance: boolean;
};
export declare type ExitPoolRequest = {
    assets: string[];
    minAmountsOut: BigNumberish[];
    userData: string;
    toInternalBalance: boolean;
};
export declare enum UserBalanceOpKind {
    DepositInternal = 0,
    WithdrawInternal = 1,
    TransferInternal = 2,
    TransferExternal = 3
}
export declare type UserBalanceOp = {
    kind: UserBalanceOpKind;
    asset: string;
    amount: BigNumberish;
    sender: string;
    recipient: string;
};
export declare enum PoolBalanceOpKind {
    Withdraw = 0,
    Deposit = 1,
    Update = 2
}
export declare type PoolBalanceOp = {
    kind: PoolBalanceOpKind;
    poolId: string;
    token: string;
    amount: BigNumberish;
};
export declare enum GaugeType {
    LiquidityMiningCommittee = 0,
    veBAL = 1,
    Ethereum = 2,
    Polygon = 3,
    Arbitrum = 4,
    Optimism = 5,
    Gnosis = 6,
    ZkSync = 7
}
