// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloLiquidation} from "silo-core/contracts/interfaces/ISiloLiquidation.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IInterestRateModel} from "silo-core/contracts/interfaces/IInterestRateModel.sol";
import {IERC3156FlashBorrower} from "silo-core/contracts/interfaces/IERC3156FlashBorrower.sol";
import {Silo, ILeverageBorrower} from "silo-core/contracts/Silo.sol";
import {LeverageReentrancyGuard} from "silo-core/contracts/utils/LeverageReentrancyGuard.sol";

import {SiloFixture} from "../_common/fixtures/SiloFixture.sol";
import {SiloLittleHelper} from "../_common/SiloLittleHelper.sol";
import {MintableToken} from "../_common/MintableToken.sol";

contract Hack1 {
    bytes32 public constant FLASHLOAN_CALLBACK = keccak256("ERC3156FlashBorrower.onFlashLoan");

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
            Silo(msg.sender).withdraw(assets, receiver, _initiator);
        } else if (option == 1) {
            Silo(msg.sender).redeem(shares, receiver, _initiator);
        } else if (option == 2) {
            Silo(msg.sender).withdraw(assets, receiver, _initiator, ISilo.AssetType.Collateral);
        } else if (option == 3) {
            Silo(msg.sender).redeem(shares, receiver, _initiator, ISilo.AssetType.Collateral);
        } else if (option == 4) {
            Silo(msg.sender).transitionCollateral(shares, _initiator, ISilo.AssetType.Collateral);
        } else if (option == 5) {
            Silo(msg.sender).borrow(assets, receiver, _initiator);
        } else if (option == 6) {
            Silo(msg.sender).borrowShares(shares, receiver, _initiator);
        } else if (option == 7) {
            Silo(msg.sender).repay(assets, _initiator);
        } else if (option == 8) {
            Silo(msg.sender).repayShares(shares, _initiator);
        } else {
            Silo(msg.sender).leverage(assets, ILeverageBorrower(receiver), _initiator, bytes(""));
        }

        return FLASHLOAN_CALLBACK;
    }
}

/*
    forge test -vv --mc FlashloanTest
*/
contract FlashloanTest is SiloLittleHelper, Test {
    address constant BORROWER = address(0x123);

    ISiloConfig siloConfig;

    function setUp() public {
        token0 = new MintableToken();
        token1 = new MintableToken();

        SiloFixture siloFixture = new SiloFixture();
        (siloConfig, silo0, silo1,,) = siloFixture.deploy_local(SiloFixture.Override(address(token0), address(token1)));

        __init(vm, token0, token1, silo0, silo1);

        _depositForBorrow(8e18, address(1));

        _deposit(10e18, BORROWER);

        assertEq(token0.balanceOf(address(this)), 0);
        assertEq(token0.balanceOf(address(silo0)), 10e18);
        assertEq(token1.balanceOf(address(silo1)), 8e18);
    }

    /*
    forge test -vv --mt test_maxFlashLoan
    */
    function test_maxFlashLoan() public {
        assertEq(silo0.maxFlashLoan(address(token1)), 0);
        assertEq(silo1.maxFlashLoan(address(token0)), 0);
        assertEq(silo0.maxFlashLoan(address(token0)), 10e18);
        assertEq(silo1.maxFlashLoan(address(token1)), 8e18);
    }

    /*
    forge test -vv --mt test_flashFee
    */
    function test_flashFee() public {
        vm.expectRevert(ISilo.Unsupported.selector);
        silo0.flashFee(address(token1), 1e18);

        vm.expectRevert(ISilo.Unsupported.selector);
        silo1.flashFee(address(token0), 1e18);

        assertEq(silo0.flashFee(address(token0), 0), 0);
        assertEq(silo1.flashFee(address(token1), 0), 0);
        assertEq(silo0.flashFee(address(token0), 1e18), 0.01e18);
        assertEq(silo1.flashFee(address(token1), 1e18), 0.01e18);
    }

    /*
    forge test -vv --mt test_flashLoan
    */
    function test_flashLoan(bytes calldata _data) public {
        IERC3156FlashBorrower receiver = IERC3156FlashBorrower(makeAddr("IERC3156FlashBorrower"));
        uint256 amount = 1e18;
        uint256 fee = silo0.flashFee(address(token0), amount);

        token0.mint(address(receiver), fee);

        vm.prank(address(receiver));
        token0.approve(address(silo0), amount + fee);

        (uint256 daoAndDeployerFeesBefore,) = silo0.siloData();

        vm.mockCall(
            address(receiver),
            abi.encodeWithSelector(
                IERC3156FlashBorrower.onFlashLoan.selector, address(this), address(token0), amount, fee, _data
            ),
            abi.encode(Silo(address(silo0)).FLASHLOAN_CALLBACK())
        );

        vm.expectCall(address(token0), abi.encodeWithSelector(IERC20.transfer.selector, address(receiver), amount));
        vm.expectCall(
            address(token0),
            abi.encodeWithSelector(IERC20.transferFrom.selector, address(receiver), address(silo0), amount + fee)
        );
        vm.expectCall(
            address(receiver),
            abi.encodeWithSelector(
                IERC3156FlashBorrower.onFlashLoan.selector, address(this), address(token0), amount, fee, _data
            )
        );
        silo0.flashLoan(receiver, address(token0), amount, _data);

        (uint256 daoAndDeployerFeesAfter,) = silo0.siloData();
        assertEq(daoAndDeployerFeesAfter, daoAndDeployerFeesBefore + fee);
    }

    /*
    forge test -vv --mt test_flashLoan_leverageNonReentrant
    */
    function test_flashLoan_leverageNonReentrant(bytes32 _data) public {
        IERC3156FlashBorrower receiver = IERC3156FlashBorrower(address(new Hack1()));
        uint256 amount = 1e18;
        uint256 fee = silo0.flashFee(address(token0), amount);

        token0.mint(address(receiver), fee);

        vm.prank(address(receiver));
        token0.approve(address(silo0), amount + fee);

        (uint256 daoAndDeployerFeesBefore,) = silo0.siloData();

        vm.expectRevert(LeverageReentrancyGuard.LeverageReentrancyCall.selector);
        silo0.flashLoan(receiver, address(token0), amount, abi.encodePacked(_data));

        (uint256 daoAndDeployerFeesAfter,) = silo0.siloData();
        assertEq(daoAndDeployerFeesAfter, daoAndDeployerFeesBefore);
    }
}
