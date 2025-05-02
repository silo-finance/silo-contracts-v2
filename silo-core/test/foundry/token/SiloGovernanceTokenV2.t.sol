// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Forking} from "silo-oracles/test/foundry/_common/Forking.sol";
import {SiloGovernanceTokenV2} from "silo-core/contracts/token/SiloGovernanceTokenV2.sol";
import {ERC20Burnable} from "openzeppelin5/token/ERC20/extensions/ERC20Burnable.sol";
import {IERC20} from "gitmodules/openzeppelin-contracts-5/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin5/access/Ownable2Step.sol";
import {ERC20Capped} from "openzeppelin5/token/ERC20/extensions/ERC20Capped.sol";

contract SiloGovernanceTokenV2Test is Forking {
    ERC20Burnable public constant SILO_V1 = ERC20Burnable(0x6f80310CA7F2C654691D1383149Fa1A57d8AB1f8);
    address public constant OWNER = 0xE8e8041cB5E3158A0829A19E014CA1cf91098554;
    address public constant SILO_V1_WHALE = 0xE641Dca2E131FA8BFe1D7931b9b040e3fE0c5BDc;
    uint256 public constant FORKING_BLOCK = 22395354;
    uint256 public constant CAP = 10**9 * 10**18;
    SiloGovernanceTokenV2 token;

    constructor() Forking(BlockChain.ETHEREUM) {
        initFork(FORKING_BLOCK);

        token = new SiloGovernanceTokenV2(OWNER, SILO_V1);
    }

    function test_constructor() public view {
        assertEq(token.owner(), OWNER);
        assertEq(address(token.SILO_V1()), address(SILO_V1));
        assertEq(token.cap(), CAP);
    }

    function test_mint_happyPath() public {
        uint256 mintAmount = 10**18;
        uint256 whaleBalanceBefore = SILO_V1.balanceOf(SILO_V1_WHALE);
        assertEq(token.balanceOf(SILO_V1_WHALE), 0);

        vm.prank(SILO_V1_WHALE);
        SILO_V1.approve(address(token), mintAmount);

        vm.prank(SILO_V1_WHALE);
        token.mint(SILO_V1_WHALE, mintAmount);

        assertEq(whaleBalanceBefore - SILO_V1.balanceOf(SILO_V1_WHALE), mintAmount);
        assertEq(token.balanceOf(SILO_V1_WHALE), mintAmount);
    }

    function test_mint_failsNoApprove() public {

        vm.prank(SILO_V1_WHALE);
        vm.expectRevert("ERC20: burn amount exceeds allowance");
        token.mint(SILO_V1_WHALE, 1);
    }

    function test_mint_failsApproveButNoTokens() public {
        uint256 mintAmount = 10**18;
        assertEq(SILO_V1.balanceOf(address(this)), 0);

        SILO_V1.approve(address(token), mintAmount);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        token.mint(address(this), 1);
    }

    function test_mint_failsAboveCap() public {
        vm.prank(Ownable(address(SILO_V1)).owner());
        SiloGovernanceTokenV2(address(SILO_V1)).mint(address(this), CAP * 2);

        SILO_V1.approve(address(token), CAP + 1);
        token.mint(address(this), CAP);

        vm.expectRevert(abi.encodeWithSelector(ERC20Capped.ERC20ExceededCap.selector, CAP + 1, CAP));
        token.mint(address(this), 1);
    }

    function test_mint_failsRepeatedMint() public {
        uint256 fullBalanceToMint = SILO_V1.balanceOf(SILO_V1_WHALE);

        vm.startPrank(SILO_V1_WHALE);
        SILO_V1.approve(address(token), type(uint256).max);
        token.mint(SILO_V1_WHALE, fullBalanceToMint);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        token.mint(SILO_V1_WHALE, fullBalanceToMint);
        vm.stopPrank();
    }

    function test_mint_decreasesSiloV1Supply() public {

    }

    function test_mint_increasesSupply() public {

    }

    function test_mint_whenPaused() public {

    }

    function test_pause_onlyOwner() public {

    }

    function test_unpause_onlyOwner() public {

    }

    function test_transfer() public {

    }

    function test_balanceOf() public {

    }

    function test_burn_onlySelf() public {

    }

    // cap
    // supply
}
