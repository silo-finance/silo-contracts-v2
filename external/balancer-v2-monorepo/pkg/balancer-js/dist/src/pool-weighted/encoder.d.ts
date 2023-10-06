import { BigNumberish } from '@ethersproject/bignumber';
export declare enum WeightedPoolJoinKind {
    INIT = 0,
    EXACT_TOKENS_IN_FOR_BPT_OUT = 1,
    TOKEN_IN_FOR_EXACT_BPT_OUT = 2,
    ALL_TOKENS_IN_FOR_EXACT_BPT_OUT = 3,
    ADD_TOKEN = 4
}
export declare enum WeightedPoolExitKind {
    EXACT_BPT_IN_FOR_ONE_TOKEN_OUT = 0,
    EXACT_BPT_IN_FOR_TOKENS_OUT = 1,
    BPT_IN_FOR_EXACT_TOKENS_OUT = 2,
    REMOVE_TOKEN = 3
}
export declare class WeightedPoolEncoder {
    /**
     * Cannot be constructed.
     */
    private constructor();
    /**
     * Encodes the userData parameter for providing the initial liquidity to a WeightedPool
     * @param initialBalances - the amounts of tokens to send to the pool to form the initial balances
     */
    static joinInit: (amountsIn: BigNumberish[]) => string;
    /**
     * Encodes the userData parameter for joining a WeightedPool with exact token inputs
     * @param amountsIn - the amounts each of token to deposit in the pool as liquidity
     * @param minimumBPT - the minimum acceptable BPT to receive in return for deposited tokens
     */
    static joinExactTokensInForBPTOut: (amountsIn: BigNumberish[], minimumBPT: BigNumberish) => string;
    /**
     * Encodes the userData parameter for joining a WeightedPool with a single token to receive an exact amount of BPT
     * @param bptAmountOut - the amount of BPT to be minted
     * @param enterTokenIndex - the index of the token to be provided as liquidity
     */
    static joinTokenInForExactBPTOut: (bptAmountOut: BigNumberish, enterTokenIndex: number) => string;
    /**
     * Encodes the userData parameter for joining a WeightedPool proportionally to receive an exact amount of BPT
     * @param bptAmountOut - the amount of BPT to be minted
     */
    static joinAllTokensInForExactBPTOut: (bptAmountOut: BigNumberish) => string;
    /**
     * Encodes the userData parameter for exiting a WeightedPool by removing a single token in return for an exact amount of BPT
     * @param bptAmountIn - the amount of BPT to be burned
     * @param enterTokenIndex - the index of the token to removed from the pool
     */
    static exitExactBPTInForOneTokenOut: (bptAmountIn: BigNumberish, exitTokenIndex: number) => string;
    /**
     * Encodes the userData parameter for exiting a WeightedPool by removing tokens in return for an exact amount of BPT
     * @param bptAmountIn - the amount of BPT to be burned
     */
    static exitExactBPTInForTokensOut: (bptAmountIn: BigNumberish) => string;
    /**
     * Encodes the userData parameter for exiting a WeightedPool by removing exact amounts of tokens
     * @param amountsOut - the amounts of each token to be withdrawn from the pool
     * @param maxBPTAmountIn - the minimum acceptable BPT to burn in return for withdrawn tokens
     */
    static exitBPTInForExactTokensOut: (amountsOut: BigNumberish[], maxBPTAmountIn: BigNumberish) => string;
}
export declare class ManagedPoolEncoder {
    /**
     * Cannot be constructed.
     */
    private constructor();
    /**
     * Encodes the userData parameter for exiting a ManagedPool to remove a token.
     * This can only be done by the pool owner.
     */
    static exitForRemoveToken: (tokenIndex: BigNumberish) => string;
}
