// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.24;

import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";
import {Ownable} from "openzeppelin5/access/Ownable.sol";

import {VeSiloContracts, VeSiloDeployments} from "ve-silo/common/VeSiloContracts.sol";
import {IVeSilo} from "ve-silo/contracts/voting-escrow/interfaces/IVeSilo.sol";
import {IVotingEscrowChildChain} from "ve-silo/contracts/voting-escrow/interfaces/IVotingEscrowChildChain.sol";
import {L2Test, ERC20} from "ve-silo/test/L2.integration.t.sol";
import {L2WithMocksDeploy} from "./deployments/L2WithMocksDeploy.s.sol";
import {VeSiloMocksContracts} from "./deployments/VeSiloMocksContracts.sol";
import {CCIPRouterReceiverLike} from "./ccip/CCIPRouterReceiverLike.sol";
import {AddrKey} from "common/addresses/AddrKey.sol";

interface IVeChaildChainGetter {
    function userPoints(address _user) external view returns (IVeSilo.Point memory);
}

// FOUNDRY_PROFILE=ve-silo-test forge test --mc L2WithMocksIntegrationTest --ffi -vvv
contract L2WithMocksIntegrationTest is L2Test {
    uint256 constant public OPTIMISM_FORKING_BLOCK = 114680480;

    function setUp() public override {
        vm.createSelectFork(
            getChainRpcUrl(OPTIMISM_ALIAS),
            OPTIMISM_FORKING_BLOCK
        );

        setAddress(AddrKey.L2_MULTISIG, _l2Multisig);

        // deploy with mocks
        L2WithMocksDeploy deploy = new L2WithMocksDeploy();
        deploy.disableDeploymentsSync();
        deploy.run();

        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployer = vm.addr(deployerPrivateKey);

        // disable deployment in `ve-silo/test/L2.integration.t.sol`
        _executeDeploy = false;

        _siloToken = ERC20(VeSiloDeployments.get(VeSiloMocksContracts.SILO_TOKEN_LIKE, ChainsLib.chainAlias()));

        vm.prank(_deployer); // only for testing
        Ownable(address(_siloToken)).transferOwnership(address(this));

        super.setUp();
    }

    function testVotingPowerReceiver() public {
        string memory chainAlias = ChainsLib.chainAlias();

        address someUserL2 = makeAddr("SomeUserL2");
        address ccipRouter = VeSiloDeployments.get(VeSiloMocksContracts.CCIP_ROUTER_RECEIVER_LIKE, chainAlias);

        IVotingEscrowChildChain veSiloChildChain = IVotingEscrowChildChain(
            VeSiloDeployments.get(VeSiloContracts.VOTING_ESCROW_CHILD_CHAIN, chainAlias)
        );

        vm.prank(_l2Multisig);
        veSiloChildChain.setSourceChainSender(someUserL2);

        uint256 balanceBefore = veSiloChildChain.balanceOf(someUserL2);
        IVeSilo.Point memory pointBefore = IVeChaildChainGetter(address(veSiloChildChain)).userPoints(someUserL2);

        assertEq(balanceBefore, 0, "User should have no balance before");
        assertEq(pointBefore.bias, 0, "User should have no point before");
        assertEq(pointBefore.slope, 0, "User should have no point before");

        CCIPRouterReceiverLike(ccipRouter).ccipReceiveVotingPower({
            _user: someUserL2,
            _veChildChain: address(veSiloChildChain),
            _amount: 1_000e18,
            _endTime: block.timestamp + 360 days,
            _totalSupply: 10_000e18,
            _totalSupplyEndTime: block.timestamp + 360 days
        });

        uint256 balanceAfter = veSiloChildChain.balanceOf(someUserL2);
        IVeSilo.Point memory pointAfter = IVeChaildChainGetter(address(veSiloChildChain)).userPoints(someUserL2);

        assertNotEq(balanceAfter, 0, "User should have balance after");
        assertNotEq(pointAfter.bias, 0, "User should have point after");
        assertNotEq(pointAfter.slope, 0, "User should have point after");
    }
}
