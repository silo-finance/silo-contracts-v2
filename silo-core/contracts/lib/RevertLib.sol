// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6 <=0.9.0;

library RevertLib {
    function revertBytes(bytes memory _errMsg, string memory _customErr) internal pure {
        if (_errMsg.length > 0) {
            assembly { // solhint-disable-line no-inline-assembly
                revert(add(32, _errMsg), mload(_errMsg))
            }
        }

        revert(_customErr);
    }

    function revertIfError(bytes4 _errorSelector) internal pure {
        if (_errorSelector == 0) return;

        bytes memory customError = abi.encodeWithSelector(_errorSelector);

        assembly {
            revert(add(32, customError), mload(customError))
        }
    }
}
