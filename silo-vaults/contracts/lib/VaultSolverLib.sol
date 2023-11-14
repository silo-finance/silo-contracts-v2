// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MathUpgradeable} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

struct VaultSolverInput {
    uint256 borrow;
    uint256 deposit;
    uint256 ucrit;
    uint256 uopt;
}

error Overflow();

library VaultSolverLib {
    struct LocalParams {
        uint256 basket;
        uint256 ind;
        uint256 dS;
    }

    /// @dev this is 100% or ONE
    uint256 internal constant ONE = 1e18;
    uint256 internal constant ONE_X_ONE = ONE * ONE;
    uint256 internal constant TWO = 2e18;

    /// @dev _amountToDistribute this is Stot in researchers math
    /// @dev _numberOfBaskets number of baskets between uopt and ucrit
    function solver(
        VaultSolverInput[] memory _input,
        uint256 _amountToDistribute, // Stot ?
        uint256 _numberOfBaskets // P
    ) internal pure returns (uint256[] memory S) {
        if (_amountToDistribute > type(uint256).max / ONE) revert Overflow();

        // uint256 _input.length = _input.length;
        S = new uint[](_input.length);

        if (_input.length == 0 || _amountToDistribute == 0) return S;

        LocalParams[] memory local = new LocalParams[](_input.length);

        uint256[] memory cnt = new uint[](_numberOfBaskets + 2); // TODO why P + 2?

        // Step 1 - Calculate basket for each silo
        for (uint256 i = 0; i < _input.length;) {
            VaultSolverInput memory data = _input[i];
            uint256 tmp = data.borrow * ONE;
            unchecked { tmp /= data.deposit; }
            uint256 f = factor(tmp, data.uopt, data.ucrit);
            uint256 k;

            // Silo is critically overutilized, assign to basket 0
            if (f > TWO) {
                k = 0;
                unchecked { cnt[1]++; }
            // silo is underutilized but not critically, assigned a basket from 1 to P based on how underutilized it is
            } else if (f > ONE) {
                // floor((2-f)*P) + 1;
                // safe to unchecked because:
                // - ONE > f > TWO: we not underflow on subtraction
                // - _numberOfBaskets is small number, so mul is safe
                // - division and +1 is save as well
                unchecked {
                    k = _numberOfBaskets * (TWO - f) / ONE + 1;
                    cnt[k + 1]++;
                }
            // silo is optimally utilized, assigned to basket P + 1
            } else {
                unchecked { k = _numberOfBaskets + 1; }
            }

            local[i].basket = k;

            unchecked { i++; }
        }

        {
            uint256 maxK;
            unchecked { maxK = _numberOfBaskets + 1; }
            // Calculate cumulative counts
            for (uint256 k = 2; k <= maxK;) {
                unchecked {
                    // cnt has indexes of array, so it is safe to uncheck
                    cnt[k] += cnt[k - 1];
                    k++;
                }
            }
        }

        // Calculate index array
        for (uint256 i = 0; i < _input.length;) {
            uint256 basketCache = local[i].basket;
            uint256 cntCache = cnt[basketCache];

            local[cntCache].ind = i;

            unchecked {
                // cnt has indexes of array, so it is safe to uncheck, especially on +1
                cnt[basketCache] = cntCache + 1;
                i++;
            }
        }

        // Redistribute deposits
        uint256 Ssum = 0;

        // Looping through each basket
        for (uint256 k = 0; k <= _numberOfBaskets;) {
            uint256 jk = cnt[k];

            // Skip redistribution for empty basket
            if (jk == 0) {
                continue;
            }

            uint256 f; // target factor
            // safe to unchecked, because `k` will be at least `_numberOfBaskets`, so max value we will subtract is ONE
            unchecked { f = TWO - k * ONE / _numberOfBaskets; }
            uint256 dSsum = 0;

            for (uint256 j = 0; j < jk;) { // all silos in baskets up to k'th
                uint256 i = local[j].ind;
                VaultSolverInput memory data = _input[i];
                // Calculate dS[i] = deposit amount needed to reach factor f for silo i
                uint256 dsCache = unfactor(f, data.borrow, data.deposit + S[i], data.uopt, data.ucrit);
                local[i].dS = dsCache;
                // Sum dS[i] to get total deposits dSsum needed for this basket
                dSsum += dsCache;

                unchecked { j++; }
            }

            uint256 scale;
            // safe to unchecked because we have Overflow check for _amountToDistribute * ONE
            unchecked { scale = MathUpgradeable.min(ONE, (_amountToDistribute - Ssum) * ONE / dSsum); }

            for (uint256 j = 0; j < jk;) {
                uint256 i = local[j].ind;
                S[i] += local[i].dS * scale / ONE;

                unchecked { j++; }
            }

            Ssum += dSsum * scale / ONE;

            if (scale < ONE) {
                break;
            }

            unchecked { k++; }
        }

        // After main distribution loop (top up remaining)
        if (Ssum < _amountToDistribute) {
            uint256[] memory Bu = new uint256[](_input.length);
            uint256 Dsum;
            uint256 Busum;

            for (uint256 i = 0; i < _input.length;) {
                VaultSolverInput memory data = _input[i];

                uint256 buCached = data.borrow * ONE / data.uopt;
                Bu[i] = buCached;
                Busum += buCached;
                Dsum += data.deposit;

                unchecked { i++; }
            }

            uint256 dSnegsum = 0;

            for (uint256 i = 0; i < _input.length;) {
                VaultSolverInput memory data = _input[i];

                uint256 value = Bu[i] * (_amountToDistribute + Dsum) / Busum;
                uint256 Si = S[i];

                if (value < data.deposit + Si) {
                    dSnegsum += (data.deposit + Si) - value;
                    local[i].dS = 0; // in pseudocode we not clearing this!
                } else {
                    local[i].dS = value - data.deposit - Si;
                }

                unchecked { i++; }
            }

            for (uint256 i = 0; i < _input.length;) {
                uint256 dS = local[i].dS;

                if (dS > 0) {
                    S[i] += dS - (dSnegsum * dS) / (_amountToDistribute - Ssum + dSnegsum);
                }

                unchecked { i++; }
            }
        }
    }

    /// @param _u can it fit under uint128?
    /// @param _uopt can it fit under uint128?
    /// @param _ucrit can it fit under uint128?
    /// @return f can it fit under uint128?
    function factor(uint256 _u, uint256 _uopt, uint256 _ucrit) private pure returns (uint256 f) {
        if (_u < _uopt) {
            return _u * ONE / _uopt;
        } else if (_u < _ucrit) {
            return ONE + (_u - _uopt) * ONE / (_ucrit - _uopt);
        } else {
            return TWO + (_u - _uopt) * ONE / (ONE - _uopt);
        }
    }

    /// @param _b list of borrow amounts
    /// @param _d list of initial deposits
    function unfactor(uint256 _f, uint256 _b, uint256 _d, uint256 _uopt, uint256 _ucrit)
        private
        pure
        returns (uint256 amountNeeded)
    {
        if (_f < ONE) {
            return _b * ONE / (_f * _uopt / ONE) - _d;
        } else if (_f < TWO) {
            // can we have negative result on _ucrit - _uopt?
            return _b * ONE / (_uopt + (_f - ONE) * (_ucrit - _uopt) / ONE) - _d;
        } else {
            // is _ucrit always < ONE?
            return _b * ONE / (_ucrit + (_f - TWO) * (ONE - _ucrit) / ONE) - _d;
        }
    }
}
