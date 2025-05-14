// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";

import {INotificationReceiver} from "silo-vaults/contracts/interfaces/INotificationReceiver.sol";

import {XRedeemPolicy} from "./XRedeemPolicy.sol";
import {Stream} from "./Stream.sol";

abstract contract XSiloManagement is Ownable2Step {
    Stream public stream;

    INotificationReceiver public notificationReceiver;

    event NotificationReceiverUpdate(INotificationReceiver indexed newNotificationReceiver);
    event StreamUpdate(Stream indexed newStream);

    error NoChange();

    constructor(address _initialOwner, address _stream) Ownable(_initialOwner) {
        stream = Stream(_stream); // it is optional and can be address(0)
    }

    function setNotificationReceiver(INotificationReceiver _notificationReceiver) external onlyOwner {
        require(notificationReceiver != _notificationReceiver, NoChange());

        notificationReceiver = _notificationReceiver;
        emit NotificationReceiverUpdate(_notificationReceiver);
    }

    function setStream(Stream _stream) external onlyOwner {
        require(stream != _stream, NoChange());

        stream = _stream;
        emit StreamUpdate(_stream);
    }
}
