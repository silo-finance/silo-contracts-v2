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
    error StopAllRelatedPrograms();
    error NotBeneficiary();

    constructor(address _initialOwner, address _stream) Ownable(_initialOwner) {
        // it is optional and can be address(0)
        // we have to skip check because of deployment scripts: they using precalculated addresses
        if (_stream != address(0)) _setStream({_stream: Stream(_stream), _skipBeneficiaryCheck: true});
    }

    /// @notice This function allows setting the notification receiver to address(0).
    /// We know that it is dangerous if there are active incentive programs. Also, it can be an issue if we update to
    /// the new notification receiver while we have active incentive programs. That's why we have sanity check
    /// using `_allProgramsStopped`
    function setNotificationReceiver(INotificationReceiver _notificationReceiver, bool _allProgramsStopped)
        external
        onlyOwner
    {
        require(notificationReceiver != _notificationReceiver, NoChange());
        require(_allProgramsStopped, StopAllRelatedPrograms());

        notificationReceiver = _notificationReceiver;
        emit NotificationReceiverUpdate(_notificationReceiver);
    }

    function setStream(Stream _stream) external onlyOwner {
        _setStream(_stream, false);
    }

    function _setStream(Stream _stream, bool _skipBeneficiaryCheck) internal {
        require(stream != _stream, NoChange());
        require(_skipBeneficiaryCheck || _stream.BENEFICIARY() == address(this), NotBeneficiary());

        stream = _stream;
        emit StreamUpdate(_stream);
    }
}
