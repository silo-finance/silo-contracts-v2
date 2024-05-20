// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721Receiver} from "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "openzeppelin-contracts/token/ERC1155/IERC1155Receiver.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";

interface ISiloTimelockController is IAccessControl, IERC721Receiver, IERC1155Receiver {
    // solhint-disable-next-line func-name-mixedcase
    function PROPOSER_ROLE() external pure returns (bytes32);
    // solhint-disable-next-line func-name-mixedcase
    function EXECUTOR_ROLE() external pure returns (bytes32);
    // solhint-disable-next-line func-name-mixedcase
    function CANCELLER_ROLE() external pure returns (bytes32);
    // solhint-disable-next-line func-name-mixedcase
    function DEFAULT_ADMIN_ROLE() external pure returns (bytes32);
    // solhint-disable-next-line func-name-mixedcase
    function TIMELOCK_ADMIN_ROLE() external pure returns (bytes32);
}
