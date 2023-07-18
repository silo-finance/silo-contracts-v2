// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IOmniVotingEscrowAdaptor} from "balancer-labs/v2-interfaces/liquidity-mining/IOmniVotingEscrowAdaptor.sol";
import {IVotingEscrowRemapper} from "balancer-labs/v2-interfaces/liquidity-mining/IVotingEscrowRemapper.sol";
import {IOmniVotingEscrow} from "balancer-labs/v2-interfaces/liquidity-mining/IOmniVotingEscrow.sol";

import {IOmniVotingEscrowSettings} from "ve-silo/contracts/voting-escrow/interfaces/IOmniVotingEscrowSettings.sol";
import {VotingEscrowRemapperDeploy} from "ve-silo/deploy/VotingEscrowRemapperDeploy.s.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {VotingEscrowTest} from "./VotingEscrow.integration.t.sol";
import {ISmartWalletChecker} from "ve-silo/contracts/voting-escrow/interfaces/ISmartWalletChecker.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc VotingEscrowRemapperTest --ffi -vvv
contract VotingEscrowRemapperTest is IntegrationTest {
    IOmniVotingEscrow public omniVotingEscrow;
    IOmniVotingEscrowSettings public omniVotingEscrowSettings;
    IOmniVotingEscrowAdaptor public adaptor;
    IVotingEscrowRemapper public remapper;
    VotingEscrowTest public veTest;
    IVeSilo public votingEscrow;

    uint256 internal constant _FORKING_BLOCK_NUMBER = 17713060;

    address internal _localUser = makeAddr("localUser");
    address internal _remoteUser = makeAddr("remoteUser");
    address internal _omniChild = makeAddr("OmniVotingEscrowChild");
    address internal _smartValletChecker = makeAddr("Smart wallet checker");

    event UserBalToChain(
        uint16 dstChainId,
        address localUser,
        address remoteUser,
        IVeSilo.Point userPoint,
        IVeSilo.Point totalSupplyPoint
    );

    function setUp() public {
        vm.createSelectFork(
            getChainRpcUrl(MAINNET_ALIAS),
            _FORKING_BLOCK_NUMBER
        );

        veTest = new VotingEscrowTest();
        veTest.deployVotingEscrowForTests();

        VotingEscrowRemapperDeploy deploy = new VotingEscrowRemapperDeploy();
        deploy.disableDeploymentsSync();

        vm.mockCall(
            _smartValletChecker,
            abi.encodeCall(ISmartWalletChecker.check, _localUser),
            abi.encode(true)
        );

        veTest.getVeSiloTokens(_localUser, 1 ether, block.timestamp + 365 * 24 * 3600);

        (omniVotingEscrow, adaptor, remapper) = deploy.run();

        omniVotingEscrowSettings = IOmniVotingEscrowSettings(address(omniVotingEscrow));

        votingEscrow = IVeSilo(getAddress(VeSiloContracts.VOTING_ESCROW));
    }

    function testTransferToArbitrum() public {
        // https://layerzero.gitbook.io/docs/technical-reference/mainnet/supported-chain-ids
        // Arbitrum chainId: 110
        uint16 arbitrumChainId = 110;

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.prank(deployer);
        omniVotingEscrowSettings.setTrustedRemoteAddress(arbitrumChainId, abi.encodePacked(_omniChild));

        uint userEpoch = votingEscrow.user_point_epoch(_localUser);
        IVeSilo.Point memory userPoint = votingEscrow.user_point_history(_localUser, userEpoch);

        // always send total supply along with a user update
        uint totalSupplyEpoch = votingEscrow.epoch();
        IVeSilo.Point memory totalSupplyPoint = votingEscrow.point_history(totalSupplyEpoch);

        vm.expectEmit(false, false, false, true);
        emit UserBalToChain(
            arbitrumChainId,
            _localUser,
            _remoteUser,
            userPoint,
            totalSupplyPoint
        );

        uint256 nativeFee;
        uint256 zroFee;

        vm.deal(_localUser, 1 ether);
        (nativeFee, zroFee) = adaptor.estimateSendUserBalance(arbitrumChainId);

        vm.prank(_localUser);
        remapper.setNetworkRemapping{value: nativeFee + zroFee}(_localUser, _remoteUser, arbitrumChainId);
    }
}
