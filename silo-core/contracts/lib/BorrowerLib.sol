// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

library BorrowerLib {
    function addMetadata(address _borrower, bool _singleToken, bool _forBorrow) internal pure returns (bytes32 info) {
        info = bytes32(abi.encode(_borrower, _singleToken, _forBorrow));
    }

    function extractMetadata(bytes32 _info) internal pure returns (address borrower, bool singleToken, bool forBorrow) {
        (borrower, singleToken, forBorrow) = (abi.decode(abi.encode(_info), (address, bool, bool)));
    }
}
