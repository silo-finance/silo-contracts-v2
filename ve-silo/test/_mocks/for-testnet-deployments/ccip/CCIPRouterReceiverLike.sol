// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {Client} from "chainlink-ccip/v0.8/ccip/interfaces/IAny2EVMMessageReceiver.sol";

import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {IVeSiloDelegatorViaCCIP} from "ve-silo/contracts/voting-escrow/interfaces/IVeSiloDelegatorViaCCIP.sol";

interface ICCIPReceiver {
    function ccipReceive(Client.Any2EVMMessage calldata message) external;
}

contract CCIPRouterReceiverLike {
    bytes32 public constant TEST_MESSAGE_ID = keccak256(abi.encodePacked(bytes("test message id")));
    uint64 public constant TEST_CHAIN_SELECTOR = 1;

    function ccipReceiveVotingPower(
        address _user,
        address _veChildChain,
        uint256 _amount,
        uint256 _endTime,
        uint256 _totalSupply,
        uint256 _totalSupplyEndTime
    ) external {
        int128 userSlope = int128(int256(_amount / (_endTime - block.timestamp)));
        int128 userBias = userSlope * int128(int256((_endTime - block.timestamp)));

        IVeSilo.Point memory uPoint = IVeSilo.Point({
            bias: userBias,
            slope: userSlope,
            ts: block.timestamp,
            blk: block.number
        });

        int128 totalSupplySlope = int128(int256(_totalSupply / (_totalSupplyEndTime - block.timestamp)));
        int128 totalSupplyBias = totalSupplySlope * int128(int256((_totalSupplyEndTime - block.timestamp)));

        IVeSilo.Point memory tsPoint = IVeSilo.Point({
            bias: totalSupplySlope,
            slope: totalSupplyBias,
            ts: block.timestamp,
            blk: block.number
        });

        bytes memory data = abi.encode(
            IVeSiloDelegatorViaCCIP.MessageType.BalanceAndTotalSupply,
            _user,
            _endTime,
            uPoint,
            tsPoint
        );

        Client.Any2EVMMessage memory ccipMessage = getCCIPMessage(data, _user);

        ICCIPReceiver(_veChildChain).ccipReceive(ccipMessage);
    }

    function getCCIPMessage(bytes memory _data, address _sender)
        public
        pure
        returns (Client.Any2EVMMessage memory ccipMessage)
    {
        ccipMessage = Client.Any2EVMMessage({
            messageId: TEST_MESSAGE_ID,
            sourceChainSelector: TEST_CHAIN_SELECTOR,
            sender: abi.encode(_sender),
            data: _data,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });
    }
}
