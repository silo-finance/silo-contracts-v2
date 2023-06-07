// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Deployer} from "silo-foundry-utils/deployer/Deployer.sol";
import {AddressesCollection} from "silo-foundry-utils/networks/addresses/AddressesCollection.sol";

// forge script ve-silo/deploy/VotingEscrowDeploy.s.sol --ffi --broadcast --rpc-url http://127.0.0.1:8545
contract VotingEscrowDeploymentScript is Deployer, AddressesCollection {
    string public constant AUTHORIZER_ADDRESS_KEY = "authorizer";

    string internal constant _DEPLOYMENTS_SUB_DIR = "ve-silo";
    string internal constant _BASE_DIR = "external/balancer-v2-monorepo/pkg/liquidity-mining/contracts";
    string internal constant _FILE = "VotingEscrow.vy";

    function setUp() public {
        // TODO: Should be a DAO address after governance is implemented
        setAddress(AUTHORIZER_ADDRESS_KEY, 0x6f80310CA7F2C654691D1383149Fa1A57d8AB1f8);
    }

    function run() public returns (address votingEscrow) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        votingEscrow = _deploy(
            _BASE_DIR,
            _DEPLOYMENTS_SUB_DIR,
            _FILE,
            abi.encode(
                getAddress(SILO80_WETH20_TOKEN),
                votingEscrowName(),
                votingEscrowSymbol(),
                getAddress(AUTHORIZER_ADDRESS_KEY)
            )
        );

        vm.stopBroadcast();

        _syncDeployments();
    }

    function votingEscrowName() public pure returns (string memory name) {
        name = new string(64);
        name = "Voting Escrow (Silo)";
    }

    function votingEscrowSymbol() public pure returns (string memory symbol) {
        symbol = new string(32);
        symbol = "veSILO";
    }
}
