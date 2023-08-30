// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.8.19;

import {IArbitrumFeeProvider} from "balancer-labs/v2-interfaces/liquidity-mining/IArbitrumFeeProvider.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

import {StakelessGauge, Ownable2Step, IMainnetBalancerMinter} from "../StakelessGauge.sol";
import {IGatewayRouter} from "./IGatewayRouter.sol";

contract ArbitrumRootGauge is StakelessGauge {
    using SafeERC20 for IERC20;

    address private immutable _gateway;
    IGatewayRouter private immutable _gatewayRouter;
    IArbitrumFeeProvider private immutable _factory;

    address private _recipient;

    constructor(IMainnetBalancerMinter minter, IGatewayRouter gatewayRouter) StakelessGauge(minter) {
        _gateway = gatewayRouter.getGateway(address(minter.getBalancerToken()));
        _gatewayRouter = gatewayRouter;
        _factory = IArbitrumFeeProvider(msg.sender);
    }

    // solhint-disable ordering

    function initialize(address recipient, uint256 relativeWeightCap, address checkpointer) external {
        // This will revert in all calls except the first one
        __StakelessGauge_init(relativeWeightCap);

        _setCheckpointer(checkpointer);

        // Transfer ownership to the Factory's owner (DAO)
        _transferOwnership(Ownable2Step(msg.sender).owner());

        _recipient = recipient;
    }

    function getRecipient() external view override returns (address) {
        return _recipient;
    }

    function _postMintAction(uint256 mintAmount) internal override {
        // Token needs to be approved on the gateway NOT the gateway router
        IERC20(address(_balToken)).safeApprove(_gateway, mintAmount);

        (uint256 gasLimit, uint256 gasPrice, uint256 maxSubmissionCost) = _factory.getArbitrumFees();
        uint256 totalBridgeCost = _getTotalBridgeCost(gasLimit, gasPrice, maxSubmissionCost);
        require(msg.value == totalBridgeCost, "Incorrect msg.value passed");

        // After bridging, the BAL should arrive on Arbitrum within 10 minutes. If it
        // does not, the L2 transaction may have failed due to an insufficient amount
        // within `max_submission_cost + (gas_limit * gas_price)`
        // In this case, the transaction can be manually broadcasted on Arbitrum by calling
        // `ArbRetryableTicket(0x000000000000000000000000000000000000006e).redeem(redemption-TxID)`
        // The calldata for this manual transaction is easily obtained by finding the reverted
        // transaction in the tx history for 0x000000000000000000000000000000000000006e on Arbiscan.
        // https://developer.offchainlabs.com/docs/l1_l2_messages#retryable-transaction-lifecycle
        _gatewayRouter.outboundTransfer{ value: totalBridgeCost }(
            _balToken,
            _recipient,
            mintAmount,
            gasLimit,
            gasPrice,
            abi.encode(maxSubmissionCost, "")
        );
    }

    function getTotalBridgeCost() external view returns (uint256) {
        (uint256 gasLimit, uint256 gasPrice, uint256 maxSubmissionCost) = _factory.getArbitrumFees();
        return _getTotalBridgeCost(gasLimit, gasPrice, maxSubmissionCost);
    }

    function _getTotalBridgeCost(
        uint256 gasLimit,
        uint256 gasPrice,
        uint256 maxSubmissionCost
    ) internal pure returns (uint256) {
        return gasLimit * gasPrice + maxSubmissionCost;
    }
}
