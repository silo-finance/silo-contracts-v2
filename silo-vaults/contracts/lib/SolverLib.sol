// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {Math} from "openzeppelin-contracts/utils/math/Math.sol";

library SolverLib {
    uint256 constant P = 5;

    function _factor(uint256 util, uint256 uopt, uint256 ucrit) internal pure returns (uint256 f) {
        if (util < uopt) {
            return util * 1e18 / uopt;
        } else if (util < ucrit) {
            return 1e18 + (util - uopt) * 1e18 / (ucrit - uopt);
        } else {
            uint256 numerator = util - ucrit;
            uint256 denominator = 1e18 - ucrit;
            return 2e18 + numerator * 1e18 / denominator;
        }
    }

    function _unfactor(uint256 factor, uint256 borrow, uint256 deposit, uint256 uopt, uint256 ucrit)
        internal
        pure
        returns (uint256 amountNeeded)
    {
        if (factor < 1e18) {
            return borrow * 1e36 / (factor * uopt) - deposit;
        } else if (factor < 2e18) {
            return borrow * 1e36 / (uopt + (factor - 1e18) * (ucrit - uopt) / 1e18) - deposit;
        } else {
            return borrow * 1e36 / (ucrit + (factor - 2e18) * (1e18 - ucrit) / 1e18) - deposit;
        }
    }

    function _solver(
        uint256[] memory borrow,
        uint256[] memory deposit,
        uint256[] memory uopt,
        uint256[] memory ucrit,
        uint256 amountToDistribute
    ) internal pure returns (uint256[] memory) {
        uint256 N = borrow.length;
        uint256[] memory basket = new uint[](N);
        uint256[] memory cnt = new uint[](P+2);
        uint256[] memory ind = new uint[](N);
        uint256[] memory S = new uint[](N);
        uint256[] memory dS = new uint[](N);

        // Step 1 - Calculate basket for each silo
        for (uint256 i = 0; i < N; i++) {
            uint256 f = _factor(borrow[i] * 1e18 / deposit[i], uopt[i], ucrit[i]);
            // Silo is critically overutilized, assign to basket 0
            if (f > 2 * 1e18) {
                basket[i] = 0;
                cnt[1]++;
                // silo is underutilized but not critically, assigned a basket from 1 to P based on how underutilized it is
            } else if (f > 1e18) {
                basket[i] = P - (f - 1e18) / (1e18 / P);
                cnt[basket[i] + 1]++;
                // silo is optimally utilized, assigned to basket P+1
            } else {
                basket[i] = P + 1;
            }
        }

        // Calculate cumulative counts
        for (uint256 k = 2; k <= P + 1; k++) {
            cnt[k] += cnt[k - 1];
        }

        // Calculate index array
        for (uint256 i = 0; i < N; i++) {
            ind[cnt[basket[i]]] = i;
            cnt[basket[i]]++;
        }

        // Redistribute deposits
        uint256 Ssum = 0;
        // Looping throught each basket
        for (uint256 k = 0; k <= P; k++) {
            uint256 jk = cnt[k];
            // Skip redistribution for empty basket
            if (jk == 0) {
                continue;
            }

            uint256 f = 2e18 - k * 1e18 / P; // target factor
            uint256 dSsum = 0;
            for (uint256 j = 0; j < jk; j++) {
                uint256 i = ind[j];
                // Calculate dS[i] = deposit amount needed to reach factor f for silo i
                dS[i] = _unfactor(f, borrow[i], deposit[i] + S[i], uopt[i], ucrit[i]);
                // Sum dS[i] to get total deposits dSsum needed for this basket
                dSsum += dS[i];
            }

            uint256 scale = Math.min(1e18, (amountToDistribute - Ssum) * 1e18 / dSsum);

            for (uint256 j = 0; j < jk; j++) {
                uint256 i = ind[j];
                S[i] += dS[i] * scale / 1e18;
            }

            Ssum += dSsum * scale / 1e18;
            if (scale < 1e18) {
                break;
            }
        }

        // After main distribution loop (top up remaining)
        if (Ssum < amountToDistribute) {
            uint256[] memory Bu = new uint256[](N);
            uint256 Dsum;
            uint256 Busum;
            uint256 dSnegsum = 0;

            for (uint256 i = 0; i < N; i++) {
                Bu[i] = borrow[i] * 1e18 / uopt[i];
                Busum += Bu[i];
                Dsum += deposit[i];
            }

            for (uint256 i = 0; i < N; i++) {
                uint256 value = Bu[i] * (amountToDistribute + Dsum) / Busum;

                if (value < deposit[i] + S[i]) {
                    dSnegsum += (deposit[i] + S[i]) - value;
                    dS[i] = 0;
                } else {
                    dS[i] = value - deposit[i] - S[i];
                }
            }

            for (uint256 i = 0; i < N; i++) {
                if (dS[i] > 0) {
                    S[i] += dS[i] - (dSnegsum * dS[i]) / (amountToDistribute - Ssum + dSnegsum);
                }
            }
        }

        return S;
    }
}
