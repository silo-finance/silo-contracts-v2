// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

library RevertLib {
    function revertBytes(bytes memory _errMsg, string memory _customErr) internal pure {
        if (_errMsg.length > 0) {
            assembly { // solhint-disable-line no-inline-assembly
                revert(add(32, _errMsg), mload(_errMsg))
            }
        }

        revert(_customErr);
    }

    function revertBytes(bytes memory _errMsg, bytes4 _customErrSelector) internal pure {
        if (_errMsg.length > 0) {
            assembly { // solhint-disable-line no-inline-assembly
                revert(add(32, _errMsg), mload(_errMsg))
            }
        }

        revertWithCustomError(_customErrSelector);
    }

    function revertIfError(bytes4 _errorSelector) internal pure {
        if (_errorSelector == 0) return;

        revertWithCustomError(_errorSelector);
    }

    function revertWithCustomError(bytes4 _errorSelector) internal pure {
        bytes memory customError = abi.encodeWithSelector(_errorSelector);

        assembly {
            revert(add(32, customError), mload(customError))
        }
    }
}
