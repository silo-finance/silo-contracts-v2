import { Contract } from '@ethersproject/contracts';
import { BigNumber, BigNumberish } from '@ethersproject/bignumber';
import { Signer, TypedDataSigner } from '@ethersproject/abstract-signer';
export declare type Account = string | Signer | Contract;
export declare function accountToAddress(account: Account): Promise<string>;
export declare enum RelayerAction {
    JoinPool = "JoinPool",
    ExitPool = "ExitPool",
    Swap = "Swap",
    BatchSwap = "BatchSwap",
    SetRelayerApproval = "SetRelayerApproval"
}
export declare class RelayerAuthorization {
    /**
     * Cannot be constructed.
     */
    private constructor();
    static encodeCalldataAuthorization: (calldata: string, deadline: BigNumberish, signature: string) => string;
    static signJoinAuthorization: (validator: Contract, user: Signer & TypedDataSigner, allowedSender: Account, allowedCalldata: string, deadline?: BigNumberish | undefined, nonce?: BigNumberish | undefined) => Promise<string>;
    static signExitAuthorization: (validator: Contract, user: Signer & TypedDataSigner, allowedSender: Account, allowedCalldata: string, deadline?: BigNumberish | undefined, nonce?: BigNumberish | undefined) => Promise<string>;
    static signSwapAuthorization: (validator: Contract, user: Signer & TypedDataSigner, allowedSender: Account, allowedCalldata: string, deadline?: BigNumberish | undefined, nonce?: BigNumberish | undefined) => Promise<string>;
    static signBatchSwapAuthorization: (validator: Contract, user: Signer & TypedDataSigner, allowedSender: Account, allowedCalldata: string, deadline?: BigNumberish | undefined, nonce?: BigNumberish | undefined) => Promise<string>;
    static signSetRelayerApprovalAuthorization: (validator: Contract, user: Signer & TypedDataSigner, allowedSender: Account, allowedCalldata: string, deadline?: BigNumberish | undefined, nonce?: BigNumberish | undefined) => Promise<string>;
    static signAuthorizationFor: (type: RelayerAction, validator: Contract, user: Signer & TypedDataSigner, allowedSender: Account, allowedCalldata: string, deadline?: BigNumberish, nonce?: BigNumberish | undefined) => Promise<string>;
}
export declare class BalancerMinterAuthorization {
    /**
     * Cannot be constructed.
     */
    private constructor();
    static signSetMinterApproval: (minterContract: Contract, minter: Account, approval: boolean, user: Signer & TypedDataSigner, deadline?: BigNumberish, nonce?: BigNumberish | undefined) => Promise<{
        v: number;
        r: string;
        s: string;
        deadline: BigNumber;
    }>;
}
