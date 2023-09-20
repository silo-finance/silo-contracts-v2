// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {MathUpgradeable as Math} from "openzeppelin-contracts-upgradeable/utils/math/MathUpgradeable.sol";

library SolverLib {
    uint256 constant P = 10;

    /// @dev Calculates a normalized utilization factor for a silo.
    /// @param u Current utilization of the silo (e.g., 75 represents 75%).
    /// @param uopt Optimal utilization percentage for the silo.
    /// @param ucrit Critical utilization percentage for the silo.
    /// @return Normalized utilization factor for the silo based on its current, optimal, and critical utilizations.
    function _factor(uint256 u, uint256 uopt, uint256 ucrit) internal pure returns (uint256) {
        if (u < uopt) {
            return u / uopt;
        } else if (u < ucrit) {
            return 1 + (u - uopt) / (ucrit - uopt);
        } else {
            return 2 + (u - ucrit) / (1 - ucrit);
        }
    }

    /// @dev Calculates the silo size based on the normalized utilization factor.
    /// @param f Target utilization factor
    /// @param B Current borrow amount of the silo.
    /// @param D Current deposit amount of the silo
    /// @param uopt Optimal utilization percentage for the silo.
    /// @param ucrit Critical utilization percentage for the silo.
    /// @return Amount of additional deposit needed beyond depositAmount to reach utilization factor f
    function _unfactor(uint256 f, uint256 B, uint256 D, uint256 uopt, uint256 ucrit) internal pure returns (uint256) {
        if (f < 1) {
            return B / (f * uopt) - D;
        } else if (f < 2) {
            return B / (uopt + (f - 1) * (ucrit - uopt)) - D;
        } else {
            return B / (ucrit + (f - 2) * (1 - ucrit)) - D;
        }
    }

    /// @dev Redistributes deposits across silos to optimize utilization
    /// @param B Array of current borrow amounts for each silo
    /// @param D Array of current deposit amounts for each silo
    /// @param uopt Array of optimal utilization percentages for each silo
    /// @param ucrit Array of critical utilization percentages for each silo
    /// @param Stot Total amount to distribute across silos
    /// @return Array of optimized deposit amounts for each silo
    function solver(uint256[] memory B, uint256[] memory D, uint256[] memory uopt, uint256[] memory ucrit, uint256 Stot)
        internal
        pure
        returns (uint256[] memory)
    {
        uint256 N = B.length;
        uint256[] memory basket = new uint[](N);
        uint256[] memory cnt = new uint[](P+2);
        uint256[] memory ind = new uint[](N);
        uint256[] memory S = new uint[](N);
        uint256[] memory dS = new uint[](N);

        // Calculate basket for each silo
        for (uint256 i = 0; i < N; i++) {
            uint256 f = _factor(B[i] / D[i], uopt[i], ucrit[i]);
            if (f > 2) {
                basket[i] = 0;
                cnt[1]++;
            } else if (f > 1) {
                basket[i] = (2 - f) * P;
                cnt[basket[i] + 1]++;
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
        for (uint256 k = 0; k <= P; k++) {
            uint256 jk = cnt[k];
            uint256 f = 2 - k / P; // target factor

            uint256 dSsum = 0;
            for (uint256 j = 0; j < jk; j++) {
                uint256 i = ind[j];
                dS[i] = _unfactor(f, B[i], D[i] + S[i], uopt[i], ucrit[i]);
                dSsum += dS[i];
            }

            uint256 scale = Math.min(1, (Stot - Ssum) / dSsum);
            for (uint256 j = 0; j < jk; j++) {
                uint256 i = ind[j];
                S[i] += dS[i] * scale;
            }

            Ssum += dSsum * scale;
            if (scale < 1) {
                break;
            }
        }

        return S;
    }
}
