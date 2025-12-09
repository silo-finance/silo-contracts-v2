// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {Ownable} from "openzeppelin5/access/Ownable.sol";
import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {Math} from "openzeppelin5/utils/math/Math.sol";

import {SiloIncentivesControllerFactory} from "silo-core/contracts/incentives/SiloIncentivesControllerFactory.sol";
import {SiloIncentivesControllerFactoryDeploy} from "silo-core/deploy/SiloIncentivesControllerFactoryDeploy.s.sol";
import {ISiloIncentivesControllerFactory} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesControllerFactory.sol";
import {RevertLib} from "silo-core/contracts/lib/RevertLib.sol";

import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {IGaugeHookReceiver} from "silo-core/contracts/interfaces/IGaugeHookReceiver.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISiloIncentivesController} from "silo-core/contracts/incentives/interfaces/ISiloIncentivesController.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IBackwardsCompatibleGaugeLike} from "silo-core/contracts/incentives/interfaces/IBackwardsCompatibleGaugeLike.sol";


contract BackwardsCompatibleGaugeLikeTest is Test {
    // we can't move too far because oracle can revert
    uint256 public constant INTERVAL = 10 minutes;
    address public user = makeAddr("qaUser");

    uint256 public decimals0;
    uint256 public decimals1;

    mapping(string network => address[] siloConfigs) public deployedSiloConfigs;
    string[] public networks;

    ISiloIncentivesControllerFactory internal _factory;

    error CantRemoveActiveGauge();

    function setUp() public {
        _parseSiloDeployments();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_backwardsCompatibility_arbitrum_one -vv

    we go over all deployed silos and manage gauges + do silo moves to make sure nothing break 
    goal si to verify is new SiloIncentivesControllerFactory is backwards compatible with old ones
    */
    function test_backwardsCompatibility_arbitrum_one() public {
        _backwardsCompatibility_forNetwork(vm.envString("RPC_ARBITRUM"), "arbitrum_one");
    }
    
    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_backwardsCompatibility_avalanche -vv
    */
    function test_backwardsCompatibility_avalanche() public {
        _backwardsCompatibility_forNetwork(vm.envString("RPC_AVALANCHE"), "avalanche");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_backwardsCompatibility_ink -vv
    */
    function test_backwardsCompatibility_ink() public {
        _backwardsCompatibility_forNetwork(vm.envString("RPC_INK"), "ink");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_backwardsCompatibility_mainnet -vv
    */
    function test_backwardsCompatibility_mainnet() public {
        _backwardsCompatibility_forNetwork(vm.envString("RPC_MAINNET"), "mainnet");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_backwardsCompatibility_optimism -vv
    */
    function test_backwardsCompatibility_optimism() public {
        _backwardsCompatibility_forNetwork(vm.envString("RPC_OPTIMISM"), "optimism");
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_backwardsCompatibility_sonic -vv
    */
    function test_backwardsCompatibility_sonic() public {
        _backwardsCompatibility_forNetwork(vm.envString("RPC_SONIC"), "sonic");
    }

    function _backwardsCompatibility_forNetwork(string memory _rpc, string memory _networkKey) internal {
        vm.createSelectFork(_rpc);

        uint256 snapshot = vm.snapshot();

        for (uint256 i = 0; i < deployedSiloConfigs[_networkKey].length; i++) {
            console2.log("_______ %s [%s] START _______", _networkKey, i);
            _check_backwardsCompatibility(ISiloConfig(deployedSiloConfigs[_networkKey][i]));
            console2.log("_______ %s [%s] DONE _______", _networkKey, i);

            vm.revertTo(snapshot);
        }
    }

    function _check_backwardsCompatibility(ISiloConfig _siloConfig) internal {
        console2.log("block.number: ", block.number);

        _deployFactory();
        (address silo0, address silo1) = _siloConfig.getSilos();

        IGaugeHookReceiver hookReceiver = _getSiloHookReceiver(silo0);

        ISiloIncentivesController controller0 = ISiloIncentivesController(_factory.create(address(this), address(hookReceiver), silo0, bytes32(0)));
        ISiloIncentivesController controller1 = ISiloIncentivesController(_factory.create(address(this), address(hookReceiver), silo1, bytes32(0)));

        // QA 

        _dealTokens(_siloConfig);

        _doSiloMoves(_siloConfig);

        assertTrue(_tryToSetNewGauge(controller0, true), "Failed to set new gauge for silo0");

        _doSiloMoves(_siloConfig);

        assertTrue(_tryToSetNewGauge(controller1, true), "Failed to set new gauge for silo1");

        _doSiloMoves(_siloConfig);

        // now remove new gauges without setting up anything new

        assertTrue(_killGauge(silo0) && _removeGauge(silo0), "Failed to KILL gauge for silo0 at the end");

        _doSiloMoves(_siloConfig);

        assertTrue(_killGauge(silo1) && _removeGauge(silo1), "Failed to KILL gauge for silo1 at the end");

        _doSiloMoves(_siloConfig);

        _printBalances(_siloConfig, "END");
    }

    function _dealTokens(ISiloConfig _siloConfig) internal {
        (address silo0, address silo1) = _siloConfig.getSilos();
        IERC20 asset0 = IERC20(IERC4626(silo0).asset());
        IERC20 asset1 = IERC20(IERC4626(silo1).asset());

        decimals0 = IERC20Metadata(address(asset0)).decimals();
        decimals1 = IERC20Metadata(address(asset1)).decimals();

        uint256 amount0 = 100_000 * (10 ** decimals0);
        uint256 amount1 = 100_000 * (10 ** decimals1);

        // must be huge amount in case there is no enough liquidity
        deal(address(asset0), user, amount0);
        deal(address(asset1), user, amount1);

        vm.startPrank(user);
        asset0.approve(silo0, type(uint256).max);
        asset1.approve(silo1, type(uint256).max);
        vm.stopPrank();

        _printBalances(_siloConfig, "START");
    }

    function _printBalances(ISiloConfig _siloConfig, string memory _prefix) internal {
        (address silo0, address silo1) = _siloConfig.getSilos();
        IERC20 asset0 = IERC20(IERC4626(silo0).asset());
        IERC20 asset1 = IERC20(IERC4626(silo1).asset());

        emit log_named_decimal_uint(string.concat(_prefix, " asset0 balance"), asset0.balanceOf(user), decimals0);
        emit log_named_decimal_uint(string.concat(_prefix, " asset1 balance"), asset1.balanceOf(user), decimals1);
    }

    function _doSiloMoves(ISiloConfig _siloConfig) internal {
        vm.startPrank(user);

        (address silo0, address silo1) = _siloConfig.getSilos();
        IERC20 asset0 = IERC20(IERC4626(silo0).asset());
        IERC20 asset1 = IERC20(IERC4626(silo1).asset());

        console2.log("----------- Silo %s/%s moves ---------", IERC20Metadata(address(asset0)).symbol(), IERC20Metadata(address(asset1)).symbol());

        uint256 amount0 = asset0.balanceOf(user);
        uint256 amount1 = asset1.balanceOf(user);

        // leve some in wallet for fees
        console2.log("depositing");
        IERC4626(silo0).deposit(amount0 * 99 / 100, user);

        vm.warp(block.timestamp + INTERVAL);

        IERC4626(silo1).deposit(amount1 * 99 / 100, user);

        vm.warp(block.timestamp + INTERVAL);

        if (_checkIfOracleWorking(ISilo(silo0))) {
            tryBorrow(_siloConfig, silo0, silo1, decimals0);
            vm.warp(block.timestamp + INTERVAL);
        } else {
            console2.log("oracle is not working for silo#0");
        }

        if (_checkIfOracleWorking(ISilo(silo1))) {
            tryBorrow(_siloConfig, silo1, silo0, decimals1);
            vm.warp(block.timestamp + INTERVAL);
        } else {
            console2.log("oracle is not working for silo#1");
        }

        console2.log("redeeming");
        uint256 maxWithdrawable0 = IERC4626(silo0).maxWithdraw(user);
        uint256 maxWithdrawable1 = IERC4626(silo1).maxWithdraw(user);

        if (maxWithdrawable0 == 0) console2.log("maxWithdrawable0 is 0, silo#0 might be broken");
        else IERC4626(silo0).redeem(maxWithdrawable0, user, user);

        if (maxWithdrawable1 == 0) console2.log("maxWithdrawable1 is 0, silo#1 might be broken");
        else IERC4626(silo1).redeem(maxWithdrawable1, user, user);
        
        vm.stopPrank();
    }

    function _borrowPossible(ISiloConfig _siloConfig, address _collateralSilo) internal view returns (bool success) {
        ISiloConfig.ConfigData memory config = _siloConfig.getConfig(_collateralSilo);
        return config.maxLtv > 0;
    }

    function _checkIfOracleWorking(ISilo _debtSilo) internal view returns (bool working) {
        try _debtSilo.maxBorrow(user) {
            working = true;
        } catch {
            working = false;
        }
    }

    function tryBorrow(ISiloConfig _siloConfig, address _debtSilo, address _collateralSilo, uint256 _debtDecimals) internal returns (bool success) {
        if (!_borrowPossible({_siloConfig: _siloConfig, _collateralSilo: _collateralSilo})) return true;

        uint256 maxBorrow = ISilo(_debtSilo).maxBorrow(user);
        uint256 liquidity = ISilo(_debtSilo).getLiquidity();
        uint256 borowAmount = maxBorrow / 100;

        if (liquidity == 0 && borowAmount == 0) {
            emit log_named_decimal_uint("borowAmount", borowAmount, _debtDecimals);
            emit log_named_decimal_uint("liquidity", liquidity, _debtDecimals);
            return false;
        } else if (liquidity != 0 && maxBorrow == 0) {
            emit log_named_decimal_uint("maxBorrow 0, liquidity", liquidity, _debtDecimals);
            revert("maxBorrow is 0 but we do have liquidity");
        }
        
        emit log_named_decimal_uint("trying to borrow", borowAmount, _debtDecimals);
        emit log_named_decimal_uint("liquidity", liquidity, _debtDecimals);

        ISilo(_debtSilo).borrow(borowAmount, user, user);
        
        vm.warp(block.timestamp + INTERVAL);

        ISilo(_debtSilo).repayShares(ISilo(_debtSilo).maxRepayShares(user), user);
        console2.log("borrow/repay on silo1 done");
        return true;
    }

    function _tryToSetNewGauge(ISiloIncentivesController _controller, bool _kill) internal returns (bool success) {
        // usually share token is collateral, but let's be sure
        address silo = _controller.SHARE_TOKEN();
        console2.log("Silo sanity check: call for factory - ", address(ISilo(silo).factory()));

        if (_setGauge(_controller, silo)) return true;

        if (_removeGauge(silo) && _setGauge(_controller, silo)) return true;

        if (_kill) _killGauge(silo);

        return _removeGauge(silo) && _setGauge(_controller, silo);
    }

    function _killGauge(address _silo) internal returns (bool success) {
        IGaugeHookReceiver hookReceiver = _getSiloHookReceiver(_silo);
        address controller = address(hookReceiver.configuredGauges(IShareToken(_silo)));
        address owner = Ownable(address(controller)).owner();

        console2.log("trying to kill gauge: ", controller);

        vm.prank(owner);
        IBackwardsCompatibleGaugeLike(controller).killGauge();

        console2.log("is killed: ", IBackwardsCompatibleGaugeLike(controller).is_killed());
        success = true;
    }

    function _getSiloHookReceiver(address _silo) internal view returns (IGaugeHookReceiver) {
        return IGaugeHookReceiver(address(IShareToken(_silo).hookReceiver()));
    }

    function _setGauge(ISiloIncentivesController _controller, address _silo) internal returns (bool success) {
        IGaugeHookReceiver hookReceiver = _getSiloHookReceiver(_silo);
        address owner = Ownable(address(hookReceiver)).owner();

        vm.prank(owner);
        try hookReceiver.setGauge(_controller, IShareToken(_silo)) {
            console2.log("Gauge set successfully!");
            return true;
        } catch (bytes memory e) {
            bytes32 alreadyConfiguredHash = keccak256(abi.encodeWithSelector(IGaugeHookReceiver.GaugeAlreadyConfigured.selector));

            if (keccak256(e) == alreadyConfiguredHash) {
                console2.log("Gauge already configured on hook", address(hookReceiver));
                return false;
            } else {
                RevertLib.revertBytes(e, "_setGauge");
            }
        }
    }

    function _removeGauge(address _silo) internal returns (bool success) {
        IGaugeHookReceiver hookReceiver = _getSiloHookReceiver(_silo);
        address owner = Ownable(address(hookReceiver)).owner();

        vm.prank(owner);
        try hookReceiver.removeGauge(IShareToken(_silo)) {
            console2.log("Gauge removed successfully!");
            return true;
        } catch (bytes memory e) {
            bytes32 cantRemoveActiveGaugeHash = keccak256(abi.encodeWithSelector(CantRemoveActiveGauge.selector));

            if (keccak256(e) == cantRemoveActiveGaugeHash) {
                console2.log("Can't remove active gauge - OLD IMPLEMENTATION");
                return false;
            } else {
                RevertLib.revertBytes(e, "_removeGauge");
            }
        }
    }

    function _printClaimable(ISiloIncentivesController _incentivesController)
        internal
        view
        returns (uint256 claimable)
    {
        // TODO check if we can claim?
        // string[] memory programNames = new string[](1);
        // programNames[0] = "USDC-for-xSilo";

        // claimable = _incentivesController.getRewardsBalance(qaUser, programNames);
        // console2.log("claimable", claimable);
    }

    function _deployFactory() internal {
        SiloIncentivesControllerFactoryDeploy deploy = new SiloIncentivesControllerFactoryDeploy();
        deploy.disableDeploymentsSync();
        _factory = deploy.run();
    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_parseSiloDeployments
    */
    function _parseSiloDeployments() internal {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/silo-core/deploy/silo/_siloDeployments.json");
        string memory json = vm.readFile(path);

        networks = vm.parseJsonKeys(json, ".");

        for (uint256 i = 0; i < networks.length; i++) {
            string memory network = networks[i];
            string memory networkPath = string.concat(".", network);
            string[] memory siloKeys = vm.parseJsonKeys(json, networkPath);

            address[] memory addresses = new address[](siloKeys.length);

            for (uint256 j = 0; j < siloKeys.length; j++) {
                string memory siloPath = _buildJsonPath(networkPath, siloKeys[j]);
                addresses[j] = vm.parseJsonAddress(json, siloPath);
                require(addresses[j] != address(0), string.concat("address is 0 for key: ", siloKeys[j]));
            }

            deployedSiloConfigs[network] = addresses;
        }
    }

    function _buildJsonPath(string memory _basePath, string memory _key) internal pure returns (string memory) {
        // Use bracket notation: ['key.with.dots'] because of "." in keys
        return string.concat(_basePath, "['", _key, "']");
    }
}

