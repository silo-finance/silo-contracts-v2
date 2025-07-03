// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPausable} from "./interfaces/IPausable.sol";
import {IGnosisSafeLike} from "./interfaces/IGnosisSafeLike.sol";

contract GlobalPause is Pausable {
    IGnosisSafeLike public multisig;

    IPausable public router;
    IPausable public leverage;

    error Unauthorized();

    modifier onlySigner() {
        address[] memory signers = multisig.getOwners();

        bool isSigner = false;
        
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == msg.sender) {
                isSigner = true;
                break;
            }
        }

        require(isSigner, Unauthorized());

        _;
    }

    constructor(address _multisig, address _router, address _leverage) {
        multisig = IGnosisSafeLike(_multisig);
        router = IPausable(_router);
        leverage = IPausable(_leverage);
    }

    function pauseAll() public onlySigner {
        router.pause();
        leverage.pause();
    }

    function unpauseAll() public onlySigner {
        router.unpause();
        leverage.unpause();
    }

    function pauseRouter() public onlySigner {
        router.pause();
    }

    function unpauseRouter() public onlySigner {
        router.unpause();
    }

    function pauseLeverage() public onlySigner {
        leverage.pause();
    }

    function unpauseLeverage() public onlySigner {
        leverage.unpause();
    }
}
