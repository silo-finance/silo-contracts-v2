// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from "openzeppelin5/access/Ownable2Step.sol";

import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";

import {INotificationReceiver} from "silo-vaults/contracts/interfaces/INotificationReceiver.sol";

import {XRedeemPolicy} from "./XRedeemPolicy.sol";
import {Stream} from "./Stream.sol";

contract XSiloManagement is Ownable2Step {
    Stream public stream;

    INotificationReceiver public notificationReceiver;

    event NotificationReceiverUpdate(INotificationReceiver indexed newNotificationReceiver);
    event StreamUpdate(Stream indexed newStream);

    constructor() Ownable(msg.sender) {
    }

    function setNotificationReceiver(INotificationReceiver _notificationReceiver) external onlyOwner {
        require(notificationReceiver != _notificationReceiver, "TODO errors");

        notificationReceiver = _notificationReceiver;
        emit NotificationReceiverUpdate(_notificationReceiver);
    }

    function setStream(Stream _stream) external onlyOwner {
        require(stream != _stream, "TODO errors");

        stream = _stream;
        emit StreamUpdate(_stream);
    }
}