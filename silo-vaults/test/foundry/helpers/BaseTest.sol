// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {Strings} from "openzeppelin5/utils/Strings.sol";

import {IERC4626} from "openzeppelin5/interfaces/IERC4626.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {SiloLittleHelper, SiloFixture, SiloConfigOverride} from "silo-core/test/foundry/_common/SiloLittleHelper.sol";
import {MintableToken} from "silo-core/test/foundry/_common/MintableToken.sol";
import {SiloConfigsNames} from "silo-core/deploy/silo/SiloDeployments.sol";

import {SiloFixture, SiloConfigOverride} from "silo-core/test/foundry/_common/fixtures/SiloFixture.sol";
import {SiloFixtureWithVeSilo} from "silo-core/test/foundry/_common/fixtures/SiloFixtureWithVeSilo.sol";

import {SiloVault} from "../../../contracts/SiloVault.sol";
import {IdleVault} from "../../../contracts/IdleVault.sol";

import {ISiloVault} from "../../../contracts/interfaces/ISiloVault.sol";
import {ConstantsLib} from "../../../contracts/libraries/ConstantsLib.sol";
import {VaultIncentivesModule} from "../../../contracts/incentives/VaultIncentivesModule.sol";

uint256 constant BLOCK_TIME = 1;
uint256 constant MIN_TEST_ASSETS = 1e8;
uint256 constant MAX_TEST_ASSETS = 1e28;
uint184 constant CAP = type(uint128).max;
uint256 constant NB_MARKETS = ConstantsLib.MAX_QUEUE_LENGTH + 1;
uint256 constant TIMELOCK = 1 weeks;

contract BaseTest is SiloLittleHelper, Test {
    address internal OWNER = makeAddr("Owner");
    address internal SUPPLIER = makeAddr("Supplier");
    address internal BORROWER = makeAddr("Borrower");
    address internal REPAYER = makeAddr("Repayer");
    address internal ONBEHALF = makeAddr("OnBehalf");
    address internal RECEIVER = makeAddr("Receiver");
    address internal ALLOCATOR = makeAddr("Allocator");
    address internal CURATOR = makeAddr("Curator");
    address internal GUARDIAN = makeAddr("Guardian");
    address internal FEE_RECIPIENT = makeAddr("FeeRecipient");
    address internal SKIM_RECIPIENT = makeAddr("SkimRecipient");

    MintableToken internal loanToken = new MintableToken(18);
    MintableToken internal collateralToken = new MintableToken(18);
    VaultIncentivesModule internal vaultIncentivesModule = new VaultIncentivesModule(OWNER);

    IERC4626[] internal allMarkets;
    mapping (IERC4626 collateral => IERC4626) internal collateralMarkets;

    IERC4626 internal idleMarket;

    ISiloVault internal vault;

    function setUp() public virtual {
        assertEq(allMarkets.length, 0, "allMarkets is fresh");

        collateralToken.setOnDemand(true);
        loanToken.setOnDemand(true);

        emit log_named_address("loanToken", address(loanToken));

        vault = ISiloVault(address(
            new SiloVault(OWNER, TIMELOCK, vaultIncentivesModule, address(loanToken), "SiloVault Vault", "MMV")
        ));

        idleMarket = new IdleVault(address(vault), address(loanToken), "idle vault", "idle");

        _createNewMarkets();
    }

    function createSiloVault(
        address owner,
        uint256 initialTimelock,
        address asset,
        string memory name,
        string memory symbol
    ) public returns (ISiloVault) {
        return ISiloVault(address(
            new SiloVault(owner, initialTimelock, vaultIncentivesModule, asset, name, symbol)
        ));
    }

    function _createNewMarkets() public virtual {
        // TODO each market will have separate full deployment, we can spend some time to create fixture
        // for deploying just new silo.
        SiloFixture siloFixture = new SiloFixtureWithVeSilo();
        SiloConfigOverride memory _override;

        _override.token0 = address(collateralToken);
        _override.token1 = address(loanToken);
        _override.configName = SiloConfigsNames.SILO_LOCAL_GAUGE_HOOK_RECEIVER;

        for (uint256 i; i < NB_MARKETS; i++) {
            (, ISilo silo0_, ISilo silo1_,,, address hook) = siloFixture.deploy_local(_override);
            vm.label(address(silo0_), string.concat("Market#", Strings.toString(i)));

            allMarkets.push(silo1_);
            collateralMarkets[silo1_] = silo0_;

            if (i == 0) {
                // setup default values for silo fixture
                silo0 = silo0_;
                silo1 = silo1_;
                partialLiquidation = IPartialLiquidation(hook);
            }
        }

        allMarkets.push(idleMarket); // Must be pushed last.
    }

    function _createNewMarket(address _collateralToken, address _loanToken) public virtual returns (IERC4626) {
        SiloFixture siloFixture = new SiloFixtureWithVeSilo();
        SiloConfigOverride memory _override;

        _override.token0 = _collateralToken;
        _override.token1 = _loanToken;
        _override.configName = SiloConfigsNames.SILO_LOCAL_NO_ORACLE_SILO;

        (,, ISilo silo1_,,,) = siloFixture.deploy_local(_override);
        return silo1_;
    }

    /// @dev Rolls & warps the given number of blocks forward the blockchain.
    function _forward(uint256 blocks) internal {
        vm.roll(block.number + blocks);
        vm.warp(block.timestamp + blocks * BLOCK_TIME); // Block speed should depend on test network.
    }

    /// @dev Bounds the fuzzing input to a realistic number of blocks.
    function _boundBlocks(uint256 blocks) internal pure returns (uint256) {
        // on silo we have much higher interest than on morpho, so we need to limit blocks more
        return bound(blocks, 2, 1e6);
    }

    /// @dev Bounds the fuzzing input to a non-zero address.
    /// @dev This function should be used in place of `vm.assume` in invariant test handler functions:
    /// https://github.com/foundry-rs/foundry/issues/4190.
    function _boundAddressNotZero(address input) internal view virtual returns (address) {
        return address(uint160(bound(uint256(uint160(input)), 1, type(uint160).max)));
    }

    function _accrueInterest(IERC4626 _market) internal {
        ISilo(address(_market)).accrueInterest();
    }

    /// @dev Returns a random market params from the list of markets enabled on Blue (except the idle market).
    function _randomMarket(uint256 seed) internal view returns (IERC4626) {
        return allMarkets[seed % (allMarkets.length - 1)];
    }

    function _randomCandidate(address[] memory candidates, uint256 seed) internal pure returns (address) {
        if (candidates.length == 0) return address(0);

        return candidates[seed % candidates.length];
    }

    function _removeAll(address[] memory inputs, address removed) internal pure returns (address[] memory result) {
        result = new address[](inputs.length);

        uint256 nbAddresses;
        for (uint256 i; i < inputs.length; ++i) {
            address input = inputs[i];

            if (input != removed) {
                result[nbAddresses] = input;
                ++nbAddresses;
            }
        }

        assembly {
            mstore(result, nbAddresses)
        }
    }

    function _randomNonZero(address[] memory users, uint256 seed) internal pure returns (address) {
        users = _removeAll(users, address(0));

        return _randomCandidate(users, seed);
    }

    /// @notice Returns the expected supply assets balance of `user` on a market after having accrued interest.
    function _expectedSupplyAssets(IERC4626 _market, address _user) internal view virtual returns (uint256 assets) {
        assets = _market.convertToAssets(_market.balanceOf(_user));
    }

    function _lastUpdate(IERC4626 _market) internal view returns (uint256 lastUpdate) {
        lastUpdate = ISilo(address(_market)).utilizationData().interestRateTimestamp;
    }
}
