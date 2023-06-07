// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Test} from "forge-std/Test.sol";

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IVotingEscrowLike} from "../../contracts/voting-escrow/interfaces/IVotingEscrowLike.sol";
import {ISmartWalletChecker} from "../../contracts/voting-escrow/interfaces/ISmartWalletChecker.sol";
import {VotingEscrowDeploy} from "../../deploy/VotingEscrowDeploy.s.sol";

// FOUNDRY_PROFILE=ve-silo forge test --ffi -vvv
contract VotingEscrowTest is IntegrationTest {
    IVotingEscrowLike internal _votingEscrow;
    VotingEscrowDeploy internal _deploymentScript;

    address internal _authorizer = makeAddr("authorizer account");
    address internal _smartValletChecker = makeAddr("Smart wallet checker");
    address internal _user = makeAddr("test user1");

    uint256 internal constant _FORKING_BLOCK_NUMBER = 17336000;

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(MAINNET_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        _votingEscrow = deployVotingEscrowForTests();
    }

    function deployVotingEscrowForTests() public returns (IVotingEscrowLike instance) {
        _deploymentScript = new VotingEscrowDeploy();
        _deploymentScript.disableDeploymentsSync();

        _mockPermissions();

        instance = IVotingEscrowLike(_deploymentScript.run());

        vm.prank(_authorizer);
        instance.commit_smart_wallet_checker(_smartValletChecker);

        vm.prank(_authorizer);
        instance.apply_smart_wallet_checker();
    }

    function getVeSiloTokens(address _userAddr, uint256 _amount, uint256 _unlockTime) public {
        IERC20 silo80Weth20Token = IERC20(getAddress(SILO80_WETH20_TOKEN));

        deal(address(silo80Weth20Token), _userAddr, _amount);

        vm.prank(_userAddr);
        silo80Weth20Token.approve(address(_votingEscrow), _amount);

        vm.prank(_userAddr);
        _votingEscrow.create_lock(_amount, _unlockTime);
    }

    function testEnsureDeployedWithCorrectData() public {
        address siloToken = getAddress(SILO80_WETH20_TOKEN);

        assertEq(_votingEscrow.token(), siloToken, "Invalid voting escrow token");
        assertEq(_votingEscrow.name(), _deploymentScript.votingEscrowName(), "Wrong name");
        assertEq(_votingEscrow.symbol(), _deploymentScript.votingEscrowSymbol(), "Wrong symbol");

        assertEq(
            _votingEscrow.decimals(),
            IERC20(siloToken).decimals(),
            "Decimals should be the same with as a token decimals"
        );
    }

    function testGetVeSiloTokens() public {
        uint256 tokensAmount = 11 ether;

        uint256 timestamp = 1;
        uint256 year = 365 * 24 * 3600;

        vm.warp(timestamp);

        getVeSiloTokens(_user, tokensAmount, year);

        uint256 votingPower = _votingEscrow.balanceOf(_user);

        assertEq(votingPower, 10969862664878009779);
    }

    function _mockPermissions() internal {
        setAddress(_deploymentScript.AUTHORIZER_ADDRESS_KEY(), _authorizer);

        vm.mockCall(
            _smartValletChecker,
            abi.encodeCall(ISmartWalletChecker.check, _user),
            abi.encode(true)
        );
    }
}
