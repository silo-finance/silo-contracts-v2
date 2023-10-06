import { BigNumberish } from '@ethersproject/bignumber';
export declare enum BasePoolExitKind {
    RECOVERY_MODE = 255
}
export declare class BasePoolEncoder {
    /**
     * Cannot be constructed.
     */
    private constructor();
    /**
     * Encodes the userData parameter for exiting any Pool in recovery mode, by removing tokens in return for
     * an exact amount of BPT
     * @param bptAmountIn - the amount of BPT to be burned
     */
    static recoveryModeExit: (bptAmountIn: BigNumberish) => string;
}
