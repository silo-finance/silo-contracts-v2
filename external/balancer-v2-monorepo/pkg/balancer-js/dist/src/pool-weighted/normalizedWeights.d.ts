import { BigNumber, BigNumberish } from '@ethersproject/bignumber';
/**
 * Normalize an array of token weights to ensure they sum to `1e18`
 * @param weights - an array of token weights to be normalized
 * @returns an equivalent set of normalized weights
 */
export declare function toNormalizedWeights(weights: BigNumber[]): BigNumber[];
/**
 * Check whether a set of weights are normalized
 * @param weights - an array of potentially unnormalized weights
 * @returns a boolean of whether the weights are normalized
 */
export declare const isNormalizedWeights: (weights: BigNumberish[]) => boolean;
