// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";

import {IERC20} from "openzeppelin5/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo, IERC3156FlashLender} from "silo-core/contracts/interfaces/ISilo.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";
import {Silo} from "silo-core/contracts/Silo.sol";
import {SiloStdLib} from "silo-core/contracts/lib/SiloStdLib.sol";

import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {MintableToken} from "../_common/MintableToken.sol";
import {FlashLoanReceiverWithInvalidResponse} from "../_mocks/FlashLoanReceiverWithInvalidResponse.sol";
import {Gas} from "../gas/Gas.sol";

bytes32 constant FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

contract Hack1 {
    function bytesToUint256(bytes memory input) public pure returns (uint256 output) {
        assembly {
            output := mload(add(input, 32))
        }
    }

    function onFlashLoan(address _initiator, address, uint256, uint256, bytes calldata _data)
        external
        returns (bytes32)
    {
        uint256 option = bytesToUint256(_data);
        uint256 assets = 1e18;
        uint256 shares = 1e18;
        address receiver = address(this);

        option = option % 10;

        if (option == 0) {
            Silo(payable(msg.sender)).withdraw(assets, receiver, _initiator);
        } else if (option == 1) {
            Silo(payable(msg.sender)).redeem(shares, receiver, _initiator);
        } else if (option == 2) {
            Silo(payable(msg.sender)).withdraw(assets, receiver, _initiator, ISilo.CollateralType.Collateral);
        } else if (option == 3) {
            Silo(payable(msg.sender)).redeem(shares, receiver, _initiator, ISilo.CollateralType.Collateral);
        } else if (option == 4) {
            Silo(payable(msg.sender)).transitionCollateral(shares, _initiator, ISilo.CollateralType.Collateral);
        } else if (option == 5) {
            Silo(payable(msg.sender)).borrow(assets, receiver, _initiator);
        } else if (option == 6) {
            Silo(payable(msg.sender)).borrowShares(shares, receiver, _initiator);
        } else if (option == 7) {
            Silo(payable(msg.sender)).repay(assets, _initiator);
        } else if (option == 8) {
            Silo(payable(msg.sender)).repayShares(shares, _initiator);
        }

        return FLASHLOAN_CALLBACK;
    }
}

/*
    forge test -vv --ffi --mc FlashloanTest
*/
contract FlashloanTest is SiloLittleHelper, Test, Gas {
    ISiloConfig siloConfig;

    function setUp() public {
        siloConfig = _setUpLocalFixture();

        _depositForBorrow(8e18, address(1));

        _deposit(10e18, BORROWER);

        assertEq(token0.balanceOf(address(this)), 0);
        assertEq(token0.balanceOf(address(silo0)), 10e18);
        assertEq(token1.balanceOf(address(silo1)), 8e18);
    }

    /*
    forge test -vv --ffi --mt test_maxFlashLoan
    */
    function test_maxFlashLoan() public view {
        assertEq(silo0.maxFlashLoan(address(token1)), 0);
        assertEq(silo1.maxFlashLoan(address(token0)), 0);
        assertEq(silo0.maxFlashLoan(address(token0)), 10e18);
        assertEq(silo1.maxFlashLoan(address(token1)), 8e18);
    }

    /*
    forge test -vv --ffi --mt test_flashFee
    */
    function test_flashFee() public {
        vm.expectRevert(ISilo.Unsupported.selector);
        silo0.flashFee(address(token1), 1e18);

        vm.expectRevert(ISilo.Unsupported.selector);
        silo1.flashFee(address(token0), 1e18);

        vm.expectRevert(SiloStdLib.ZeroAmount.selector);
        silo0.flashFee(address(token0), 0);

        vm.expectRevert(SiloStdLib.ZeroAmount.selector);
        silo1.flashFee(address(token1), 0);

        assertEq(silo0.flashFee(address(token0), 1e18), 0.01e18);
        assertEq(silo1.flashFee(address(token1), 1e18), 0.01e18);
    }

    /*
    forge test -vv --ffi --mt test_gas_flashLoan
    */
    function test_gas_flashLoan(bytes calldata _data) public {
        IERC3156FlashBorrower receiver = IERC3156FlashBorrower(makeAddr("IERC3156FlashBorrower"));
        uint256 amount = 1e18;
        uint256 fee = silo0.flashFee(address(token0), amount);

        token0.mint(address(receiver), fee);

        vm.prank(address(receiver));
        token0.approve(address(silo0), amount + fee);

        (uint256 daoAndDeployerFeesBefore,) = silo0.siloData();

        bytes memory data = abi.encodeWithSelector(
            IERC3156FlashBorrower.onFlashLoan.selector, address(this), address(token0), amount, fee, _data
        );

        vm.mockCall(address(receiver), data, abi.encode(FLASHLOAN_CALLBACK));
        vm.expectCall(address(receiver), data);

        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, address(receiver), amount));
        vm.expectCall(
            address(token0),
            abi.encodeWithSelector(IERC20.transferFrom.selector, address(receiver), address(silo0), amount + fee)
        );

        _action(
            address(this),
            address(silo0),
            abi.encodeCall(IERC3156FlashLender.flashLoan, (receiver, address(token0), amount, _data)),
            "flashLoan gas",
            30482,
            500
        );

        (uint256 daoAndDeployerFeesAfter,) = silo0.siloData();
        assertEq(daoAndDeployerFeesAfter, daoAndDeployerFeesBefore + fee);
    }

    /*
    forge test -vv --ffi --mt test_flashLoanInvalidResponce
    */
    function test_flashLoanInvalidResponce() public {
        bytes memory data;
        uint256 amount = 1e18;
        FlashLoanReceiverWithInvalidResponse receiver = new FlashLoanReceiverWithInvalidResponse();

        vm.expectRevert(ISilo.FlashloanFailed.selector);
        silo0.flashLoan(IERC3156FlashBorrower(address(receiver)), address(token0), amount, data);
    }
}
