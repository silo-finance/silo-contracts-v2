// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.6 <=0.9.0;

library RevertBytes {
    /// @dev it allow to "forward" revert error from low-lever calls
    /// @param _errMsg data that external contract returns on error
    /// @param _customErr in case `_errMsg` is empty, this custom message wil be used as revert message
    function revertBytes(bytes memory _errMsg, string memory _customErr) internal pure {
        if (_errMsg.length > 0) {
            assembly { // solhint-disable-line no-inline-assembly
                revert(add(32, _errMsg), mload(_errMsg))
            }
        }

        revert(_customErr);
    }
}
