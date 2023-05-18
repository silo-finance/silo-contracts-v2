import { defaultAbiCoder } from '@ethersproject/abi';
import { WeiPerEther, Zero, MaxUint256, AddressZero } from '@ethersproject/constants';
import { BigNumber } from '@ethersproject/bignumber';
import { hexZeroPad, hexValue, splitSignature } from '@ethersproject/bytes';
import { Signer } from '@ethersproject/abstract-signer';
import { getAddress } from '@ethersproject/address';

var StablePoolJoinKind;
(function (StablePoolJoinKind) {
    StablePoolJoinKind[StablePoolJoinKind["INIT"] = 0] = "INIT";
    StablePoolJoinKind[StablePoolJoinKind["EXACT_TOKENS_IN_FOR_BPT_OUT"] = 1] = "EXACT_TOKENS_IN_FOR_BPT_OUT";
    StablePoolJoinKind[StablePoolJoinKind["TOKEN_IN_FOR_EXACT_BPT_OUT"] = 2] = "TOKEN_IN_FOR_EXACT_BPT_OUT";
    StablePoolJoinKind[StablePoolJoinKind["ALL_TOKENS_IN_FOR_EXACT_BPT_OUT"] = 3] = "ALL_TOKENS_IN_FOR_EXACT_BPT_OUT";
})(StablePoolJoinKind || (StablePoolJoinKind = {}));
var StablePoolExitKind;
(function (StablePoolExitKind) {
    StablePoolExitKind[StablePoolExitKind["EXACT_BPT_IN_FOR_ONE_TOKEN_OUT"] = 0] = "EXACT_BPT_IN_FOR_ONE_TOKEN_OUT";
    StablePoolExitKind[StablePoolExitKind["BPT_IN_FOR_EXACT_TOKENS_OUT"] = 1] = "BPT_IN_FOR_EXACT_TOKENS_OUT";
    StablePoolExitKind[StablePoolExitKind["EXACT_BPT_IN_FOR_ALL_TOKENS_OUT"] = 2] = "EXACT_BPT_IN_FOR_ALL_TOKENS_OUT";
})(StablePoolExitKind || (StablePoolExitKind = {}));
class StablePoolEncoder {
    /**
     * Cannot be constructed.
     */
    constructor() {
        // eslint-disable-next-line @typescript-eslint/no-empty-function
    }
}
/**
 * Encodes the userData parameter for providing the initial liquidity to a StablePool
 * @param initialBalances - the amounts of tokens to send to the pool to form the initial balances
 */
StablePoolEncoder.joinInit = (amountsIn) => defaultAbiCoder.encode(['uint256', 'uint256[]'], [StablePoolJoinKind.INIT, amountsIn]);
/**
 * Encodes the userData parameter for joining a StablePool with exact token inputs
 * @param amountsIn - the amounts each of token to deposit in the pool as liquidity
 * @param minimumBPT - the minimum acceptable BPT to receive in return for deposited tokens
 */
StablePoolEncoder.joinExactTokensInForBPTOut = (amountsIn, minimumBPT) => defaultAbiCoder.encode(['uint256', 'uint256[]', 'uint256'], [StablePoolJoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, amountsIn, minimumBPT]);
/**
 * Encodes the userData parameter for joining a StablePool with to receive an exact amount of BPT
 * @param bptAmountOut - the amount of BPT to be minted
 * @param enterTokenIndex - the index of the token to be provided as liquidity
 */
StablePoolEncoder.joinTokenInForExactBPTOut = (bptAmountOut, enterTokenIndex) => defaultAbiCoder.encode(['uint256', 'uint256', 'uint256'], [StablePoolJoinKind.TOKEN_IN_FOR_EXACT_BPT_OUT, bptAmountOut, enterTokenIndex]);
/**
 * Encodes the userData parameter for joining a StablePool proportionally
 * @param bptAmountOut - the amount of BPT to be minted
 */
StablePoolEncoder.joinAllTokensInForExactBptOut = (bptAmountOut) => defaultAbiCoder.encode(['uint256', 'uint256'], [StablePoolJoinKind.ALL_TOKENS_IN_FOR_EXACT_BPT_OUT, bptAmountOut]);
/**
 * Encodes the userData parameter for exiting a StablePool by removing a single token in return for an exact amount of BPT
 * @param bptAmountIn - the amount of BPT to be burned
 * @param exitTokenIndex - the index of the token to removed from the pool
 */
StablePoolEncoder.exitExactBPTInForOneTokenOut = (bptAmountIn, exitTokenIndex) => defaultAbiCoder.encode(['uint256', 'uint256', 'uint256'], [StablePoolExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, bptAmountIn, exitTokenIndex]);
/**
 * Encodes the userData parameter for exiting a StablePool by removing exact amounts of tokens
 * @param amountsOut - the amounts of each token to be withdrawn from the pool
 * @param maxBPTAmountIn - the minimum acceptable BPT to burn in return for withdrawn tokens
 */
StablePoolEncoder.exitBPTInForExactTokensOut = (amountsOut, maxBPTAmountIn) => defaultAbiCoder.encode(['uint256', 'uint256[]', 'uint256'], [StablePoolExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT, amountsOut, maxBPTAmountIn]);
/**
 * Encodes the userData parameter for exiting a StablePool proportionally
 * @param bptAmountIn - the amount of BPT to burn in exchange for withdrawn tokens
 */
StablePoolEncoder.exitExactBptInForTokensOut = (bptAmountIn) => defaultAbiCoder.encode(['uint256', 'uint256'], [StablePoolExitKind.EXACT_BPT_IN_FOR_ALL_TOKENS_OUT, bptAmountIn]);

var WeightedPoolJoinKind;
(function (WeightedPoolJoinKind) {
    WeightedPoolJoinKind[WeightedPoolJoinKind["INIT"] = 0] = "INIT";
    WeightedPoolJoinKind[WeightedPoolJoinKind["EXACT_TOKENS_IN_FOR_BPT_OUT"] = 1] = "EXACT_TOKENS_IN_FOR_BPT_OUT";
    WeightedPoolJoinKind[WeightedPoolJoinKind["TOKEN_IN_FOR_EXACT_BPT_OUT"] = 2] = "TOKEN_IN_FOR_EXACT_BPT_OUT";
    WeightedPoolJoinKind[WeightedPoolJoinKind["ALL_TOKENS_IN_FOR_EXACT_BPT_OUT"] = 3] = "ALL_TOKENS_IN_FOR_EXACT_BPT_OUT";
    WeightedPoolJoinKind[WeightedPoolJoinKind["ADD_TOKEN"] = 4] = "ADD_TOKEN";
})(WeightedPoolJoinKind || (WeightedPoolJoinKind = {}));
var WeightedPoolExitKind;
(function (WeightedPoolExitKind) {
    WeightedPoolExitKind[WeightedPoolExitKind["EXACT_BPT_IN_FOR_ONE_TOKEN_OUT"] = 0] = "EXACT_BPT_IN_FOR_ONE_TOKEN_OUT";
    WeightedPoolExitKind[WeightedPoolExitKind["EXACT_BPT_IN_FOR_TOKENS_OUT"] = 1] = "EXACT_BPT_IN_FOR_TOKENS_OUT";
    WeightedPoolExitKind[WeightedPoolExitKind["BPT_IN_FOR_EXACT_TOKENS_OUT"] = 2] = "BPT_IN_FOR_EXACT_TOKENS_OUT";
    WeightedPoolExitKind[WeightedPoolExitKind["REMOVE_TOKEN"] = 3] = "REMOVE_TOKEN";
})(WeightedPoolExitKind || (WeightedPoolExitKind = {}));
class WeightedPoolEncoder {
    /**
     * Cannot be constructed.
     */
    constructor() {
        // eslint-disable-next-line @typescript-eslint/no-empty-function
    }
}
/**
 * Encodes the userData parameter for providing the initial liquidity to a WeightedPool
 * @param initialBalances - the amounts of tokens to send to the pool to form the initial balances
 */
WeightedPoolEncoder.joinInit = (amountsIn) => defaultAbiCoder.encode(['uint256', 'uint256[]'], [WeightedPoolJoinKind.INIT, amountsIn]);
/**
 * Encodes the userData parameter for joining a WeightedPool with exact token inputs
 * @param amountsIn - the amounts each of token to deposit in the pool as liquidity
 * @param minimumBPT - the minimum acceptable BPT to receive in return for deposited tokens
 */
WeightedPoolEncoder.joinExactTokensInForBPTOut = (amountsIn, minimumBPT) => defaultAbiCoder.encode(['uint256', 'uint256[]', 'uint256'], [WeightedPoolJoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, amountsIn, minimumBPT]);
/**
 * Encodes the userData parameter for joining a WeightedPool with a single token to receive an exact amount of BPT
 * @param bptAmountOut - the amount of BPT to be minted
 * @param enterTokenIndex - the index of the token to be provided as liquidity
 */
WeightedPoolEncoder.joinTokenInForExactBPTOut = (bptAmountOut, enterTokenIndex) => defaultAbiCoder.encode(['uint256', 'uint256', 'uint256'], [WeightedPoolJoinKind.TOKEN_IN_FOR_EXACT_BPT_OUT, bptAmountOut, enterTokenIndex]);
/**
 * Encodes the userData parameter for joining a WeightedPool proportionally to receive an exact amount of BPT
 * @param bptAmountOut - the amount of BPT to be minted
 */
WeightedPoolEncoder.joinAllTokensInForExactBPTOut = (bptAmountOut) => defaultAbiCoder.encode(['uint256', 'uint256'], [WeightedPoolJoinKind.ALL_TOKENS_IN_FOR_EXACT_BPT_OUT, bptAmountOut]);
/**
 * Encodes the userData parameter for exiting a WeightedPool by removing a single token in return for an exact amount of BPT
 * @param bptAmountIn - the amount of BPT to be burned
 * @param enterTokenIndex - the index of the token to removed from the pool
 */
WeightedPoolEncoder.exitExactBPTInForOneTokenOut = (bptAmountIn, exitTokenIndex) => defaultAbiCoder.encode(['uint256', 'uint256', 'uint256'], [WeightedPoolExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, bptAmountIn, exitTokenIndex]);
/**
 * Encodes the userData parameter for exiting a WeightedPool by removing tokens in return for an exact amount of BPT
 * @param bptAmountIn - the amount of BPT to be burned
 */
WeightedPoolEncoder.exitExactBPTInForTokensOut = (bptAmountIn) => defaultAbiCoder.encode(['uint256', 'uint256'], [WeightedPoolExitKind.EXACT_BPT_IN_FOR_TOKENS_OUT, bptAmountIn]);
/**
 * Encodes the userData parameter for exiting a WeightedPool by removing exact amounts of tokens
 * @param amountsOut - the amounts of each token to be withdrawn from the pool
 * @param maxBPTAmountIn - the minimum acceptable BPT to burn in return for withdrawn tokens
 */
WeightedPoolEncoder.exitBPTInForExactTokensOut = (amountsOut, maxBPTAmountIn) => defaultAbiCoder.encode(['uint256', 'uint256[]', 'uint256'], [WeightedPoolExitKind.BPT_IN_FOR_EXACT_TOKENS_OUT, amountsOut, maxBPTAmountIn]);
class ManagedPoolEncoder {
    /**
     * Cannot be constructed.
     */
    constructor() {
        // eslint-disable-next-line @typescript-eslint/no-empty-function
    }
}
/**
 * Encodes the userData parameter for exiting a ManagedPool to remove a token.
 * This can only be done by the pool owner.
 */
ManagedPoolEncoder.exitForRemoveToken = (tokenIndex) => defaultAbiCoder.encode(['uint256', 'uint256'], [WeightedPoolExitKind.REMOVE_TOKEN, tokenIndex]);

// Should match MAX_WEIGHTED_TOKENS from v2-helpers/constants
// Including would introduce a dependency
const MaxWeightedTokens = 100;
/**
 * Normalize an array of token weights to ensure they sum to `1e18`
 * @param weights - an array of token weights to be normalized
 * @returns an equivalent set of normalized weights
 */
function toNormalizedWeights(weights) {
    // When the number is exactly equal to the max, normalizing with common inputs
    // leads to a value < 0.01, which reverts. In this case fill in the weights exactly.
    if (weights.length == MaxWeightedTokens) {
        return Array(MaxWeightedTokens).fill(WeiPerEther.div(MaxWeightedTokens));
    }
    const sum = weights.reduce((total, weight) => total.add(weight), Zero);
    if (sum.eq(WeiPerEther))
        return weights;
    const normalizedWeights = [];
    let normalizedSum = Zero;
    for (let index = 0; index < weights.length; index++) {
        if (index < weights.length - 1) {
            normalizedWeights[index] = weights[index].mul(WeiPerEther).div(sum);
            normalizedSum = normalizedSum.add(normalizedWeights[index]);
        }
        else {
            normalizedWeights[index] = WeiPerEther.sub(normalizedSum);
        }
    }
    return normalizedWeights;
}
/**
 * Check whether a set of weights are normalized
 * @param weights - an array of potentially unnormalized weights
 * @returns a boolean of whether the weights are normalized
 */
const isNormalizedWeights = (weights) => {
    const totalWeight = weights.reduce((total, weight) => total.add(weight), Zero);
    return totalWeight.eq(WeiPerEther);
};

var isProduction = process.env.NODE_ENV === 'production';
var prefix = 'Invariant failed';
function invariant(condition, message) {
    if (condition) {
        return;
    }
    if (isProduction) {
        throw new Error(prefix);
    }
    var provided = typeof message === 'function' ? message() : message;
    var value = provided ? "".concat(prefix, ": ").concat(provided) : prefix;
    throw new Error(value);
}

/**
 * Splits a poolId into its components, i.e. pool address, pool specialization and its nonce
 * @param poolId - a bytes32 string of the pool's ID
 * @returns an object with the decomposed poolId
 */
const splitPoolId = (poolId) => {
    return {
        address: getPoolAddress(poolId),
        specialization: getPoolSpecialization(poolId),
        nonce: getPoolNonce(poolId),
    };
};
/**
 * Extracts a pool's address from its poolId
 * @param poolId - a bytes32 string of the pool's ID
 * @returns the pool's address
 */
const getPoolAddress = (poolId) => {
    invariant(poolId.length === 66, 'Invalid poolId length');
    return poolId.slice(0, 42);
};
/**
 * Extracts a pool's specialization from its poolId
 * @param poolId - a bytes32 string of the pool's ID
 * @returns the pool's specialization
 */
const getPoolSpecialization = (poolId) => {
    invariant(poolId.length === 66, 'Invalid poolId length');
    // Only have 3 pool specializations so we can just pull the relevant character
    const specializationCode = parseInt(poolId[45]);
    invariant(specializationCode < 3, 'Invalid pool specialization');
    return specializationCode;
};
/**
 * Extracts a pool's nonce from its poolId
 * @param poolId - a bytes32 string of the pool's ID
 * @returns the pool's nonce
 */
const getPoolNonce = (poolId) => {
    invariant(poolId.length === 66, 'Invalid poolId length');
    return BigNumber.from(`0x${poolId.slice(46)}`);
};

// RECOVERY_MODE must match BasePoolUserData.RECOVERY_MODE_EXIT_KIND, the value that
// (Legacy)BasePool uses to detect the special exit enabled in recovery mode.
var BasePoolExitKind;
(function (BasePoolExitKind) {
    BasePoolExitKind[BasePoolExitKind["RECOVERY_MODE"] = 255] = "RECOVERY_MODE";
})(BasePoolExitKind || (BasePoolExitKind = {}));
class BasePoolEncoder {
    /**
     * Cannot be constructed.
     */
    constructor() {
        // eslint-disable-next-line @typescript-eslint/no-empty-function
    }
}
/**
 * Encodes the userData parameter for exiting any Pool in recovery mode, by removing tokens in return for
 * an exact amount of BPT
 * @param bptAmountIn - the amount of BPT to be burned
 */
BasePoolEncoder.recoveryModeExit = (bptAmountIn) => defaultAbiCoder.encode(['uint256', 'uint256'], [BasePoolExitKind.RECOVERY_MODE, bptAmountIn]);

const balancerErrorCodes = {
    '000': 'ADD_OVERFLOW',
    '001': 'SUB_OVERFLOW',
    '002': 'SUB_UNDERFLOW',
    '003': 'MUL_OVERFLOW',
    '004': 'ZERO_DIVISION',
    '005': 'DIV_INTERNAL',
    '006': 'X_OUT_OF_BOUNDS',
    '007': 'Y_OUT_OF_BOUNDS',
    '008': 'PRODUCT_OUT_OF_BOUNDS',
    '009': 'INVALID_EXPONENT',
    '100': 'OUT_OF_BOUNDS',
    '101': 'UNSORTED_ARRAY',
    '102': 'UNSORTED_TOKENS',
    '103': 'INPUT_LENGTH_MISMATCH',
    '104': 'ZERO_TOKEN',
    '105': 'INSUFFICIENT_DATA',
    '200': 'MIN_TOKENS',
    '201': 'MAX_TOKENS',
    '202': 'MAX_SWAP_FEE_PERCENTAGE',
    '203': 'MIN_SWAP_FEE_PERCENTAGE',
    '204': 'MINIMUM_BPT',
    '205': 'CALLER_NOT_VAULT',
    '206': 'UNINITIALIZED',
    '207': 'BPT_IN_MAX_AMOUNT',
    '208': 'BPT_OUT_MIN_AMOUNT',
    '209': 'EXPIRED_PERMIT',
    '210': 'NOT_TWO_TOKENS',
    '211': 'DISABLED',
    '300': 'MIN_AMP',
    '301': 'MAX_AMP',
    '302': 'MIN_WEIGHT',
    '303': 'MAX_STABLE_TOKENS',
    '304': 'MAX_IN_RATIO',
    '305': 'MAX_OUT_RATIO',
    '306': 'MIN_BPT_IN_FOR_TOKEN_OUT',
    '307': 'MAX_OUT_BPT_FOR_TOKEN_IN',
    '308': 'NORMALIZED_WEIGHT_INVARIANT',
    '309': 'INVALID_TOKEN',
    '310': 'UNHANDLED_JOIN_KIND',
    '311': 'ZERO_INVARIANT',
    '312': 'ORACLE_INVALID_SECONDS_QUERY',
    '313': 'ORACLE_NOT_INITIALIZED',
    '314': 'ORACLE_QUERY_TOO_OLD',
    '315': 'ORACLE_INVALID_INDEX',
    '316': 'ORACLE_BAD_SECS',
    '317': 'AMP_END_TIME_TOO_CLOSE',
    '318': 'AMP_ONGOING_UPDATE',
    '319': 'AMP_RATE_TOO_HIGH',
    '320': 'AMP_NO_ONGOING_UPDATE',
    '321': 'STABLE_INVARIANT_DIDNT_CONVERGE',
    '322': 'STABLE_GET_BALANCE_DIDNT_CONVERGE',
    '323': 'RELAYER_NOT_CONTRACT',
    '324': 'BASE_POOL_RELAYER_NOT_CALLED',
    '325': 'REBALANCING_RELAYER_REENTERED',
    '326': 'GRADUAL_UPDATE_TIME_TRAVEL',
    '327': 'SWAPS_DISABLED',
    '328': 'CALLER_IS_NOT_LBP_OWNER',
    '329': 'PRICE_RATE_OVERFLOW',
    '330': 'INVALID_JOIN_EXIT_KIND_WHILE_SWAPS_DISABLED',
    '331': 'WEIGHT_CHANGE_TOO_FAST',
    '332': 'LOWER_GREATER_THAN_UPPER_TARGET',
    '333': 'UPPER_TARGET_TOO_HIGH',
    '334': 'UNHANDLED_BY_LINEAR_POOL',
    '335': 'OUT_OF_TARGET_RANGE',
    '336': 'UNHANDLED_EXIT_KIND',
    '337': 'UNAUTHORIZED_EXIT',
    '338': 'MAX_MANAGEMENT_SWAP_FEE_PERCENTAGE',
    '339': 'UNHANDLED_BY_MANAGED_POOL',
    '340': 'UNHANDLED_BY_PHANTOM_POOL',
    '341': 'TOKEN_DOES_NOT_HAVE_RATE_PROVIDER',
    '342': 'INVALID_INITIALIZATION',
    '343': 'OUT_OF_NEW_TARGET_RANGE',
    '344': 'FEATURE_DISABLED',
    '345': 'UNINITIALIZED_POOL_CONTROLLER',
    '346': 'SET_SWAP_FEE_DURING_FEE_CHANGE',
    '347': 'SET_SWAP_FEE_PENDING_FEE_CHANGE',
    '348': 'CHANGE_TOKENS_DURING_WEIGHT_CHANGE',
    '349': 'CHANGE_TOKENS_PENDING_WEIGHT_CHANGE',
    '350': 'MAX_WEIGHT',
    '351': 'UNAUTHORIZED_JOIN',
    '352': 'MAX_MANAGEMENT_AUM_FEE_PERCENTAGE',
    '353': 'FRACTIONAL_TARGET',
    '354': 'ADD_OR_REMOVE_BPT',
    '355': 'INVALID_CIRCUIT_BREAKER_BOUNDS',
    '356': 'CIRCUIT_BREAKER_TRIPPED',
    '357': 'MALICIOUS_QUERY_REVERT',
    '358': 'JOINS_EXITS_DISABLED',
    '400': 'REENTRANCY',
    '401': 'SENDER_NOT_ALLOWED',
    '402': 'PAUSED',
    '403': 'PAUSE_WINDOW_EXPIRED',
    '404': 'MAX_PAUSE_WINDOW_DURATION',
    '405': 'MAX_BUFFER_PERIOD_DURATION',
    '406': 'INSUFFICIENT_BALANCE',
    '407': 'INSUFFICIENT_ALLOWANCE',
    '408': 'ERC20_TRANSFER_FROM_ZERO_ADDRESS',
    '409': 'ERC20_TRANSFER_TO_ZERO_ADDRESS',
    '410': 'ERC20_MINT_TO_ZERO_ADDRESS',
    '411': 'ERC20_BURN_FROM_ZERO_ADDRESS',
    '412': 'ERC20_APPROVE_FROM_ZERO_ADDRESS',
    '413': 'ERC20_APPROVE_TO_ZERO_ADDRESS',
    '414': 'ERC20_TRANSFER_EXCEEDS_ALLOWANCE',
    '415': 'ERC20_DECREASED_ALLOWANCE_BELOW_ZERO',
    '416': 'ERC20_TRANSFER_EXCEEDS_BALANCE',
    '417': 'ERC20_BURN_EXCEEDS_ALLOWANCE',
    '418': 'SAFE_ERC20_CALL_FAILED',
    '419': 'ADDRESS_INSUFFICIENT_BALANCE',
    '420': 'ADDRESS_CANNOT_SEND_VALUE',
    '421': 'SAFE_CAST_VALUE_CANT_FIT_INT256',
    '422': 'GRANT_SENDER_NOT_ADMIN',
    '423': 'REVOKE_SENDER_NOT_ADMIN',
    '424': 'RENOUNCE_SENDER_NOT_ALLOWED',
    '425': 'BUFFER_PERIOD_EXPIRED',
    '426': 'CALLER_IS_NOT_OWNER',
    '427': 'NEW_OWNER_IS_ZERO',
    '428': 'CODE_DEPLOYMENT_FAILED',
    '429': 'CALL_TO_NON_CONTRACT',
    '430': 'LOW_LEVEL_CALL_FAILED',
    '431': 'NOT_PAUSED',
    '432': 'ADDRESS_ALREADY_ALLOWLISTED',
    '433': 'ADDRESS_NOT_ALLOWLISTED',
    '434': 'ERC20_BURN_EXCEEDS_BALANCE',
    '435': 'INVALID_OPERATION',
    '436': 'CODEC_OVERFLOW',
    '437': 'IN_RECOVERY_MODE',
    '438': 'NOT_IN_RECOVERY_MODE',
    '439': 'INDUCED_FAILURE',
    '440': 'EXPIRED_SIGNATURE',
    '441': 'MALFORMED_SIGNATURE',
    '442': 'SAFE_CAST_VALUE_CANT_FIT_UINT64',
    '443': 'UNHANDLED_FEE_TYPE',
    '444': 'BURN_FROM_ZERO',
    '500': 'INVALID_POOL_ID',
    '501': 'CALLER_NOT_POOL',
    '502': 'SENDER_NOT_ASSET_MANAGER',
    '503': 'USER_DOESNT_ALLOW_RELAYER',
    '504': 'INVALID_SIGNATURE',
    '505': 'EXIT_BELOW_MIN',
    '506': 'JOIN_ABOVE_MAX',
    '507': 'SWAP_LIMIT',
    '508': 'SWAP_DEADLINE',
    '509': 'CANNOT_SWAP_SAME_TOKEN',
    '510': 'UNKNOWN_AMOUNT_IN_FIRST_SWAP',
    '511': 'MALCONSTRUCTED_MULTIHOP_SWAP',
    '512': 'INTERNAL_BALANCE_OVERFLOW',
    '513': 'INSUFFICIENT_INTERNAL_BALANCE',
    '514': 'INVALID_ETH_INTERNAL_BALANCE',
    '515': 'INVALID_POST_LOAN_BALANCE',
    '516': 'INSUFFICIENT_ETH',
    '517': 'UNALLOCATED_ETH',
    '518': 'ETH_TRANSFER',
    '519': 'CANNOT_USE_ETH_SENTINEL',
    '520': 'TOKENS_MISMATCH',
    '521': 'TOKEN_NOT_REGISTERED',
    '522': 'TOKEN_ALREADY_REGISTERED',
    '523': 'TOKENS_ALREADY_SET',
    '524': 'TOKENS_LENGTH_MUST_BE_2',
    '525': 'NONZERO_TOKEN_BALANCE',
    '526': 'BALANCE_TOTAL_OVERFLOW',
    '527': 'POOL_NO_TOKENS',
    '528': 'INSUFFICIENT_FLASH_LOAN_BALANCE',
    '600': 'SWAP_FEE_PERCENTAGE_TOO_HIGH',
    '601': 'FLASH_LOAN_FEE_PERCENTAGE_TOO_HIGH',
    '602': 'INSUFFICIENT_FLASH_LOAN_FEE_AMOUNT',
    '603': 'AUM_FEE_PERCENTAGE_TOO_HIGH',
    '700': 'SPLITTER_FEE_PERCENTAGE_TOO_HIGH',
    '998': 'UNIMPLEMENTED',
    '999': 'SHOULD_NOT_HAPPEN',
};
class BalancerErrors {
    /**
     * Cannot be constructed.
     */
    constructor() {
        // eslint-disable-next-line @typescript-eslint/no-empty-function
    }
}
BalancerErrors.isErrorCode = (error) => {
    if (!error.includes('BAL#'))
        return false;
    const errorCode = error.replace('BAL#', '');
    return Object.keys(balancerErrorCodes).includes(errorCode);
};
/**
 * Decodes a Balancer error code into the corresponding reason
 * @param error - a Balancer error code of the form `BAL#000`
 * @returns The decoded error reason
 */
BalancerErrors.parseErrorCode = (error) => {
    if (!error.includes('BAL#'))
        throw new Error('Error code not found');
    const errorCode = error.replace('BAL#', '');
    const actualError = balancerErrorCodes[errorCode];
    if (!actualError)
        throw new Error('Error code not found');
    return actualError;
};
/**
 * Decodes a Balancer error code into the corresponding reason
 * @param error - a Balancer error code of the form `BAL#000`
 * @returns The decoded error reason if passed a valid error code, otherwise returns passed input
 */
BalancerErrors.tryParseErrorCode = (error) => {
    try {
        return BalancerErrors.parseErrorCode(error);
    }
    catch {
        return error;
    }
};
/**
 * Tests whether a string is a known Balancer error message
 * @param error - a string to be checked verified as a Balancer error message
 */
BalancerErrors.isBalancerError = (error) => Object.values(balancerErrorCodes).includes(error);
/**
 * Encodes an error string into the corresponding error code
 * @param error - a Balancer error message string
 * @returns a Balancer error code of the form `BAL#000`
 */
BalancerErrors.encodeError = (error) => {
    const encodedError = Object.entries(balancerErrorCodes).find(([, message]) => message === error);
    if (!encodedError)
        throw Error('Error message not found');
    return `BAL#${encodedError[0]}`;
};

async function accountToAddress(account) {
    if (typeof account == 'string')
        return account;
    if (Signer.isSigner(account))
        return account.getAddress();
    if (account.address)
        return account.address;
    throw new Error('Could not read account address');
}
var RelayerAction;
(function (RelayerAction) {
    RelayerAction["JoinPool"] = "JoinPool";
    RelayerAction["ExitPool"] = "ExitPool";
    RelayerAction["Swap"] = "Swap";
    RelayerAction["BatchSwap"] = "BatchSwap";
    RelayerAction["SetRelayerApproval"] = "SetRelayerApproval";
})(RelayerAction || (RelayerAction = {}));
class RelayerAuthorization {
    /**
     * Cannot be constructed.
     */
    constructor() {
        // eslint-disable-next-line @typescript-eslint/no-empty-function
    }
}
RelayerAuthorization.encodeCalldataAuthorization = (calldata, deadline, signature) => {
    const encodedDeadline = hexZeroPad(hexValue(deadline), 32).slice(2);
    const { v, r, s } = splitSignature(signature);
    const encodedV = hexZeroPad(hexValue(v), 32).slice(2);
    const encodedR = r.slice(2);
    const encodedS = s.slice(2);
    return `${calldata}${encodedDeadline}${encodedV}${encodedR}${encodedS}`;
};
RelayerAuthorization.signJoinAuthorization = (validator, user, allowedSender, allowedCalldata, deadline, nonce) => RelayerAuthorization.signAuthorizationFor(RelayerAction.JoinPool, validator, user, allowedSender, allowedCalldata, deadline, nonce);
RelayerAuthorization.signExitAuthorization = (validator, user, allowedSender, allowedCalldata, deadline, nonce) => RelayerAuthorization.signAuthorizationFor(RelayerAction.ExitPool, validator, user, allowedSender, allowedCalldata, deadline, nonce);
RelayerAuthorization.signSwapAuthorization = (validator, user, allowedSender, allowedCalldata, deadline, nonce) => RelayerAuthorization.signAuthorizationFor(RelayerAction.Swap, validator, user, allowedSender, allowedCalldata, deadline, nonce);
RelayerAuthorization.signBatchSwapAuthorization = (validator, user, allowedSender, allowedCalldata, deadline, nonce) => RelayerAuthorization.signAuthorizationFor(RelayerAction.BatchSwap, validator, user, allowedSender, allowedCalldata, deadline, nonce);
RelayerAuthorization.signSetRelayerApprovalAuthorization = (validator, user, allowedSender, allowedCalldata, deadline, nonce) => RelayerAuthorization.signAuthorizationFor(RelayerAction.SetRelayerApproval, validator, user, allowedSender, allowedCalldata, deadline, nonce);
RelayerAuthorization.signAuthorizationFor = async (type, validator, user, allowedSender, allowedCalldata, deadline = MaxUint256, nonce) => {
    const { chainId } = await validator.provider.getNetwork();
    if (!nonce) {
        const userAddress = await user.getAddress();
        nonce = (await validator.getNextNonce(userAddress));
    }
    const domain = {
        name: 'Balancer V2 Vault',
        version: '1',
        chainId,
        verifyingContract: validator.address,
    };
    const types = {
        [type]: [
            { name: 'calldata', type: 'bytes' },
            { name: 'sender', type: 'address' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
        ],
    };
    const value = {
        calldata: allowedCalldata,
        sender: await accountToAddress(allowedSender),
        nonce: nonce.toString(),
        deadline: deadline.toString(),
    };
    return user._signTypedData(domain, types, value);
};
class BalancerMinterAuthorization {
    /**
     * Cannot be constructed.
     */
    constructor() {
        // eslint-disable-next-line @typescript-eslint/no-empty-function
    }
}
BalancerMinterAuthorization.signSetMinterApproval = async (minterContract, minter, approval, user, deadline = MaxUint256, nonce) => {
    const { chainId } = await minterContract.provider.getNetwork();
    if (!nonce) {
        const userAddress = await user.getAddress();
        nonce = (await minterContract.getNextNonce(userAddress));
    }
    const domain = {
        name: 'Balancer Minter',
        version: '1',
        chainId,
        verifyingContract: minterContract.address,
    };
    const types = {
        SetMinterApproval: [
            { name: 'minter', type: 'address' },
            { name: 'approval', type: 'bool' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
        ],
    };
    const value = {
        minter: await accountToAddress(minter),
        approval,
        nonce: nonce.toString(),
        deadline: deadline.toString(),
    };
    const signature = await user._signTypedData(domain, types, value);
    return { ...splitSignature(signature), deadline: BigNumber.from(deadline) };
};

const signPermit = async (token, owner, spender, amount, deadline = MaxUint256, nonce) => {
    const { chainId } = await token.provider.getNetwork();
    const ownerAddress = await owner.getAddress();
    if (!nonce)
        nonce = (await token.nonces(ownerAddress));
    // Hack around some tokens not exposing a `version()` function.
    // If they do then use it, otherwise assume that their version is "1".
    let version = '1';
    try {
        if (token.version) {
            version = await token.version();
        }
    }
    catch {
        // eslint-disable-prev-line no-empty
    }
    const domain = {
        name: await token.name(),
        version,
        chainId,
        verifyingContract: token.address,
    };
    const types = {
        Permit: [
            { name: 'owner', type: 'address' },
            { name: 'spender', type: 'address' },
            { name: 'value', type: 'uint256' },
            { name: 'nonce', type: 'uint256' },
            { name: 'deadline', type: 'uint256' },
        ],
    };
    const value = {
        owner: ownerAddress,
        spender: await accountToAddress(spender),
        value: amount,
        nonce,
        deadline,
    };
    const signature = await owner._signTypedData(domain, types, value);
    return { ...splitSignature(signature), deadline: BigNumber.from(deadline), nonce: BigNumber.from(nonce) };
};

const cmpTokens = (tokenA, tokenB) => (tokenA.toLowerCase() > tokenB.toLowerCase() ? 1 : -1);
const transposeMatrix = (matrix) => matrix[0].map((_, columnIndex) => matrix.map((row) => row[columnIndex]));
class AssetHelpers {
    constructor(wethAddress) {
        this.ETH = AddressZero;
        /**
         * Tests whether `token` is ETH (represented by `0x0000...0000`).
         *
         * @param token - the address of the asset to be checked
         */
        this.isETH = (token) => AssetHelpers.isEqual(token, this.ETH);
        /**
         * Tests whether `token` is WETH.
         *
         * @param token - the address of the asset to be checked
         */
        this.isWETH = (token) => AssetHelpers.isEqual(token, this.WETH);
        /**
         * Converts an asset to the equivalent ERC20 address.
         *
         * For ERC20s this will return the passed address but passing ETH (`0x0000...0000`) will return the WETH address
         * @param token - the address of the asset to be translated to an equivalent ERC20
         * @returns the address of translated ERC20 asset
         */
        this.translateToERC20 = (token) => (this.isETH(token) ? this.WETH : token);
        this.WETH = getAddress(wethAddress);
    }
    /**
     * Sorts an array of token addresses into ascending order to match the format expected by the Vault.
     *
     * Passing additional arrays will result in each being sorted to maintain relative ordering to token addresses.
     *
     * The zero address (representing ETH) is sorted as if it were the WETH address.
     * This matches the behaviour expected by the Vault when receiving an array of addresses.
     *
     * @param tokens - an array of token addresses to be sorted in ascending order
     * @param others - a set of arrays to be sorted in the same order as the tokens, e.g. token weights or asset manager addresses
     * @returns an array of the form `[tokens, ...others]` where each subarray has been sorted to maintain its ordering relative to `tokens`
     *
     * @example
     * const [tokens] = sortTokens([tokenB, tokenC, tokenA])
     * const [tokens, weights] = sortTokens([tokenB, tokenC, tokenA], [weightB, weightC, weightA])
     * // where tokens = [tokenA, tokenB, tokenC], weights = [weightA, weightB, weightC]
     */
    sortTokens(tokens, ...others) {
        others.forEach((array) => invariant(tokens.length === array.length, 'array length mismatch'));
        // We want to sort ETH as if were WETH so we translate to ERC20s
        const erc20Tokens = tokens.map(this.translateToERC20);
        const transpose = transposeMatrix([erc20Tokens, ...others]);
        const sortedTranspose = transpose.sort(([tokenA], [tokenB]) => cmpTokens(tokenA, tokenB));
        const [sortedErc20s, ...sortedOthers] = transposeMatrix(sortedTranspose);
        // If one of the tokens was ETH, we need to translate back from WETH
        const sortedTokens = tokens.includes(this.ETH)
            ? sortedErc20s.map((token) => (this.isWETH(token) ? this.ETH : token))
            : sortedErc20s;
        return [sortedTokens, ...sortedOthers];
    }
}
AssetHelpers.isEqual = (addressA, addressB) => getAddress(addressA) === getAddress(addressB);

var PoolSpecialization;
(function (PoolSpecialization) {
    PoolSpecialization[PoolSpecialization["GeneralPool"] = 0] = "GeneralPool";
    PoolSpecialization[PoolSpecialization["MinimalSwapInfoPool"] = 1] = "MinimalSwapInfoPool";
    PoolSpecialization[PoolSpecialization["TwoTokenPool"] = 2] = "TwoTokenPool";
})(PoolSpecialization || (PoolSpecialization = {}));
// Swaps
var SwapKind;
(function (SwapKind) {
    SwapKind[SwapKind["GivenIn"] = 0] = "GivenIn";
    SwapKind[SwapKind["GivenOut"] = 1] = "GivenOut";
})(SwapKind || (SwapKind = {}));
// Balance Operations
var UserBalanceOpKind;
(function (UserBalanceOpKind) {
    UserBalanceOpKind[UserBalanceOpKind["DepositInternal"] = 0] = "DepositInternal";
    UserBalanceOpKind[UserBalanceOpKind["WithdrawInternal"] = 1] = "WithdrawInternal";
    UserBalanceOpKind[UserBalanceOpKind["TransferInternal"] = 2] = "TransferInternal";
    UserBalanceOpKind[UserBalanceOpKind["TransferExternal"] = 3] = "TransferExternal";
})(UserBalanceOpKind || (UserBalanceOpKind = {}));
var PoolBalanceOpKind;
(function (PoolBalanceOpKind) {
    PoolBalanceOpKind[PoolBalanceOpKind["Withdraw"] = 0] = "Withdraw";
    PoolBalanceOpKind[PoolBalanceOpKind["Deposit"] = 1] = "Deposit";
    PoolBalanceOpKind[PoolBalanceOpKind["Update"] = 2] = "Update";
})(PoolBalanceOpKind || (PoolBalanceOpKind = {}));
// Stakeless gauges
var GaugeType;
(function (GaugeType) {
    GaugeType[GaugeType["LiquidityMiningCommittee"] = 0] = "LiquidityMiningCommittee";
    GaugeType[GaugeType["veBAL"] = 1] = "veBAL";
    GaugeType[GaugeType["Ethereum"] = 2] = "Ethereum";
    GaugeType[GaugeType["Polygon"] = 3] = "Polygon";
    GaugeType[GaugeType["Arbitrum"] = 4] = "Arbitrum";
    GaugeType[GaugeType["Optimism"] = 5] = "Optimism";
    GaugeType[GaugeType["Gnosis"] = 6] = "Gnosis";
    GaugeType[GaugeType["ZkSync"] = 7] = "ZkSync";
})(GaugeType || (GaugeType = {}));

export { AssetHelpers, BalancerErrors, BalancerMinterAuthorization, BasePoolEncoder, BasePoolExitKind, GaugeType, ManagedPoolEncoder, PoolBalanceOpKind, PoolSpecialization, RelayerAction, RelayerAuthorization, StablePoolEncoder, StablePoolExitKind, StablePoolJoinKind, SwapKind, UserBalanceOpKind, WeightedPoolEncoder, WeightedPoolExitKind, WeightedPoolJoinKind, accountToAddress, getPoolAddress, getPoolNonce, getPoolSpecialization, isNormalizedWeights, signPermit, splitPoolId, toNormalizedWeights };
//# sourceMappingURL=index.esm.js.map
