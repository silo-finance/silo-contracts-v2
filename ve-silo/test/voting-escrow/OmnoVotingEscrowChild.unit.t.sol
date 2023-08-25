// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IntegrationTest} from "silo-foundry-utils/networks/IntegrationTest.sol";

import {IVotingEscrow} from "lz_gauges/interfaces/IVotingEscrow.sol";
import {IL2LayerZeroDelegation} from "lz_gauges/interfaces/IL2LayerZeroDelegation.sol";

import {IOmniVotingEscrowSettings} from "ve-silo/contracts/voting-escrow/interfaces/IOmniVotingEscrowSettings.sol";
import {VeSiloContracts} from "ve-silo/deploy/_CommonDeploy.sol";
import {VeSiloAddressesKeys} from "ve-silo/deploy/_VeSiloAddresses.sol";
import {OmniVotingEscrowChildDeploy} from "ve-silo/deploy/OmniVotingEscrowChildDeploy.s.sol";
import {IOmniVotingEscrowChild} from "ve-silo/contracts/voting-escrow/interfaces/IOmniVotingEscrowChild.sol";

// FOUNDRY_PROFILE=ve-silo forge test --mc OmnoVotingEscrowChildTest --ffi -vvv
contract OmnoVotingEscrowChildTest is IntegrationTest {
    // gitmodules/lz_gauges/contracts/OmniVotingEscrow.sol:L15
    // Packet types for child chains:
    uint16 internal constant _PT_USER = 0; // user balance and total supply update
    uint16 internal constant _PT_TS = 1; // total supply update
    
    // https://layerzero.gitbook.io/docs/technical-reference/mainnet/supported-chain-ids
    uint16 internal constant _ETHEREUM_CHAIN_ID = 101;

    address internal _lzEndpoint = makeAddr("Lz endpoint");
    address internal _delegationHook = makeAddr("Delegation hook");
    address internal _omniVotingEscrow = makeAddr("OmniVotingEscrow");
    address internal _remoteUser = makeAddr("remoteUser");

    IOmniVotingEscrowChild internal _votingEscrowChild;
    IOmniVotingEscrowSettings internal _omniVotingEscrowSettings;

    function setUp() public {
        setAddress(VeSiloAddressesKeys.LZ_ENDPOINT, _lzEndpoint);
        setAddress(VeSiloContracts.L2_LAYER_ZERO_BRIDGE_FORWARDER, _delegationHook);

        OmniVotingEscrowChildDeploy deploy = new OmniVotingEscrowChildDeploy();
        deploy.disableDeploymentsSync();

        _votingEscrowChild = deploy.run();
        _omniVotingEscrowSettings = IOmniVotingEscrowSettings(address(_votingEscrowChild));
    }

    function testReceiveUserBalance() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.prank(deployer);
        _omniVotingEscrowSettings.setTrustedRemoteAddress(_ETHEREUM_CHAIN_ID, abi.encodePacked(_omniVotingEscrow));

        vm.mockCall(
            _delegationHook,
            abi.encodeWithSelector(IL2LayerZeroDelegation.onVeBalBridged.selector, _remoteUser),
            abi.encode(true)
        );

        IVotingEscrow.Point memory uPoint;
        IVotingEscrow.Point memory tsPoint;

        (uPoint, tsPoint) = _pointsForBalanceTransfer();

        uint64 nonce = 1;
        uint256 lockedEnd = 100;
        bytes memory lzPayload = abi.encode(_PT_USER, _remoteUser, lockedEnd, uPoint, tsPoint);

        vm.prank(_lzEndpoint);
        _votingEscrowChild.lzReceive(
            _ETHEREUM_CHAIN_ID,
            abi.encodePacked(_omniVotingEscrow, _omniVotingEscrowSettings),
            nonce,
            lzPayload
        );

        IVotingEscrow.Point memory uPointReceived = _votingEscrowChild.userPoints(_remoteUser);

        assertEq(uPointReceived.bias, uPoint.bias);
        assertEq(uPointReceived.slope, uPoint.slope);
        assertEq(uPointReceived.ts, uPoint.ts);
        assertEq(uPointReceived.blk, uPoint.blk);

        uint256 uPointValue = _votingEscrowChild.getPointValue(uPoint);
        uint256 balance = _votingEscrowChild.balanceOf(_remoteUser);

        assertEq(uPointValue, balance);

        uint256 tsPointValue = _votingEscrowChild.getPointValue(tsPoint);
        uint256 totalSupply = _votingEscrowChild.totalSupply();

        assertEq(tsPointValue, totalSupply);
    }

    function testReceiveTotalSupply() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.prank(deployer);
        _omniVotingEscrowSettings.setTrustedRemoteAddress(_ETHEREUM_CHAIN_ID, abi.encodePacked(_omniVotingEscrow));

        vm.mockCall(
            _delegationHook,
            abi.encodeWithSelector(IL2LayerZeroDelegation.onVeBalSupplyUpdate.selector),
            abi.encode(true)
        );

        IVotingEscrow.Point memory tsPoint = IVotingEscrow.Point({
            bias: 300e18,
            slope: 301,
            ts: block.timestamp,
            blk: 303
        });

        uint64 nonce = 1;
        bytes memory lzPayload = abi.encode(_PT_TS, tsPoint);

        vm.prank(_lzEndpoint);
        _votingEscrowChild.lzReceive(
            _ETHEREUM_CHAIN_ID,
            abi.encodePacked(_omniVotingEscrow, _omniVotingEscrowSettings),
            nonce,
            lzPayload
        );

        uint256 tsPointValue = _votingEscrowChild.getPointValue(tsPoint);
        uint256 totalSupply = _votingEscrowChild.totalSupply();

        assertEq(tsPointValue, totalSupply);
    }

    function _pointsForBalanceTransfer() internal view returns (
        IVotingEscrow.Point memory uPoint,
        IVotingEscrow.Point memory tsPoint
    ) {
        uPoint = IVotingEscrow.Point({
            bias: 100e18,
            slope: 101,
            ts: block.timestamp,
            blk: 103
        });

        tsPoint = IVotingEscrow.Point({
            bias: 200e18,
            slope: 201,
            ts: block.timestamp,
            blk: 203
        });
    }
}
