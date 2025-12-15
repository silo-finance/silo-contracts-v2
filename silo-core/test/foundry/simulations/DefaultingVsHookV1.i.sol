// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Clones} from "openzeppelin5/proxy/Clones.sol";

import {SiloHookV2} from "silo-core/contracts/hooks/SiloHookV2.sol";
import {SiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {SiloLens} from "silo-core/contracts/SiloLens.sol";

import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {ISilo} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloOracle} from "silo-core/contracts/interfaces/ISiloOracle.sol";
import {IShareToken} from "silo-core/contracts/interfaces/IShareToken.sol";
import {IPartialLiquidationByDefaulting} from "silo-core/contracts/interfaces/IPartialLiquidationByDefaulting.sol";
import {IPartialLiquidation} from "silo-core/contracts/interfaces/IPartialLiquidation.sol";
import {ISiloHookV2} from "silo-core/contracts/interfaces/ISiloHookV2.sol";
import {IVersioned} from "silo-core/contracts/interfaces/IVersioned.sol";

contract HookV2Mock is SiloHookV2 {
    function validateDefaultingCollateral() public view override {
        (address silo0, address silo1) = siloConfig.getSilos();

        ISiloConfig.ConfigData memory config0 = siloConfig.getConfig(silo0);
        ISiloConfig.ConfigData memory config1 = siloConfig.getConfig(silo1);

        // require(config0.lt == 0 || config1.lt == 0, TwoWayMarketNotAllowed());
        
        require(config0.lt + LT_MARGIN_FOR_DEFAULTING < _DECIMALS_PRECISION, InvalidLTConfig0());
        require(config1.lt + LT_MARGIN_FOR_DEFAULTING < _DECIMALS_PRECISION, InvalidLTConfig1());
    }
}

contract DefaultingVsHookV1 is Test {
    // DefaultingVsHookV1
    // "Silo_xUSD_USDC": "0x6B13d486027c1B645ad663Ba9f9A28744D04B8f8",
    uint256 constant public SONIC_1D = 54930150 - 54800800;
    uint256 constant public SONIC_1H = SONIC_1D / 24;
    uint256 constant public SONIC_1M = SONIC_1H / 60;


    address[] lpPrpviders;
    ISiloConfig siloConfig;
    ISilo silo0;
    ISilo silo1;
    ISiloOracle oracle0;
    IERC20Metadata token0;
    IERC20Metadata token1;
    IPartialLiquidation hookV1;
    IPartialLiquidationByDefaulting hookV2;

    uint256 siloID;
    uint256 decimals0;
    uint256 decimals1;

    string symbol0;
    string symbol1;

    function setUp() public {

        _ws_USDC();

        (address silo0_, address silo1_) = siloConfig.getSilos();
        siloID = siloConfig.SILO_ID();
        silo0 = ISilo(silo0_);
        silo1 = ISilo(silo1_);

        token0 = IERC20Metadata(silo0.asset());
        token1 = IERC20Metadata(silo1.asset());
        
        decimals0 = token0.decimals();
        decimals1 = token1.decimals();

        symbol0 = token0.symbol();
        symbol1 = token1.symbol();

        ISiloConfig.ConfigData memory cfg0 = siloConfig.getConfig(silo0_);
        hookV1 = IPartialLiquidation(cfg0.hookReceiver);
        hookV2 = IPartialLiquidationByDefaulting(cfg0.hookReceiver);
        console2.log("hookV1", address(hookV1));
        console2.log("silo0", silo0_);
        console2.log("silo1", silo1_);
        oracle0 = ISiloOracle(cfg0.solvencyOracle);
    }

    function _xUSD_USDC() public {
        vm.createSelectFork(vm.envString("RPC_AVALANCHE"), 71760734);
        siloConfig = ISiloConfig(0x6B13d486027c1B645ad663Ba9f9A28744D04B8f8);
    }

    function _ws_USDC() internal {
        siloConfig = ISiloConfig(0x062A36Bbe0306c2Fd7aecdf25843291fBAB96AD2);

        // https://sonicscan.org/tokentxns?a=0x6AAFD9Dd424541885fd79C06FDA96929CFD512f9&p=125
        // vm.createSelectFork(vm.envString("RPC_SONIC"), 50000800); // price 0.2698
        // this is liquidation ON THE BLOCK when price was changed! 
        
        vm.createSelectFork(vm.envString("RPC_SONIC"), 50057262); // price 0.2698
        // 50060037 - price 0.0866

    }

    /*
    FOUNDRY_PROFILE=core_test forge test --ffi --mt test_defaultingVsHookV1 -vv
    */
    function test_defaultingVsHookV1() public {
        _printState(silo1, symbol1, decimals1);
        _printOracleState();



        // liquidation 
        // https://sonicscan.org/tx/0x4660d51247a1fd9f0f3ba892904654ad2c9bd182915a53ffc1885fd81e7ef4a6
        // block 50057262 - price 0.2698
        // borrower = 0x6495DeCdDa0D5e7711B0Dc2FEbf83C6c763dD7f1
        // vm.createSelectFork(vm.envString("RPC_SONIC"), 50057262); // price 0.23

        // vm.rollFork(50057262);
        _printUserState(0x6495DeCdDa0D5e7711B0Dc2FEbf83C6c763dD7f1);
        _cloneHook();
        _printUserState(0x6495DeCdDa0D5e7711B0Dc2FEbf83C6c763dD7f1);
        _tryDefaulting(0x6495DeCdDa0D5e7711B0Dc2FEbf83C6c763dD7f1);

        _printState(silo1, symbol1, decimals1);
        _printOracleState();

        vm.rollFork(50057262 + 1);
        _printState(silo1, symbol1, decimals1);
        _printOracleState();
                _printUserState(0x6495DeCdDa0D5e7711B0Dc2FEbf83C6c763dD7f1);

    }

    function _printState(ISilo _silo, string memory _symbol, uint256 _decimals) public {
        console2.log("[%s] silo %s", siloID, _symbol);
        console2.log("block %s at %s", block.number, block.timestamp);

        uint256 totalCollateralStorage = _silo.getTotalAssetsStorage(ISilo.AssetType.Collateral);
        uint256 totalDebtStorage = _silo.getTotalAssetsStorage(ISilo.AssetType.Debt);
        uint256 totalAssets = _silo.totalAssets();
        uint256 totalDebt = _silo.getDebtAssets();
        uint256 liquidity = _silo.getLiquidity();

        emit log_named_decimal_uint("getLiquidity", liquidity, _decimals);

        emit log_named_decimal_uint("getTotalAssetsStorage(ISilo.AssetType.Collateral)", totalCollateralStorage, _decimals);
        emit log_named_decimal_uint("                                    totalAssets()", totalAssets, _decimals);

        emit log_named_decimal_uint("getTotalAssetsStorage(ISilo.AssetType.Debt)", totalDebtStorage, _decimals);
        emit log_named_decimal_uint("                          totalDebtAssets()", totalDebt, _decimals);

        emit log_named_decimal_uint("storage market LTV %", totalDebtStorage * 1e18 / totalCollateralStorage, 16);
        emit log_named_decimal_uint("        market LTV %", totalDebt * 1e18 / totalAssets, 16);

    }

    function _printOracleState() public {
        emit log_named_decimal_uint(string.concat(symbol0, "/", symbol1, " price "), oracle0.quote(10 ** decimals0, silo0.asset()), 18);
    }

    function _cloneHook() internal {
        HookV2Mock implementation = new HookV2Mock();
        address hook = Clones.clone(address(implementation));

        ISiloHookV2(hook).initialize(siloConfig, abi.encode(address(this)));
        vm.etch(address(hookV1), hook.code);

        console2.log("hookV2", IVersioned(hook).VERSION());

        // ISiloConfig.ConfigData memory cfg0 = siloConfig.getConfig(address(silo0));
        // ISiloConfig.ConfigData memory cfg1 = siloConfig.getConfig(address(silo1));

        // cfg0.hookReceiver = hook;
        // cfg1.hookReceiver = hook;

        // SiloConfig sc = new SiloConfig(siloID, cfg0, cfg1);
        // vm.etch(address(siloConfig), address(sc).code);

        // console2.log("hookV1 is now V2", IVersioned(address(hookV1)).VERSION());
    }

    function _tryDefaulting(address _borrower) internal {
        require(!silo0.isSolvent(_borrower), "borrower is solvent");

        try hookV2.liquidationCallByDefaulting(_borrower) {
            console2.log("defaulting successful");
        } catch (bytes memory data) {
            if (keccak256(data) == keccak256(abi.encodeWithSelector(IPartialLiquidation.UserIsSolvent.selector))) {
                console2.log("user not ready for defaulting");
            } else {
                console2.log("defaulting failed", string(data));
                revert();
            }
        }
    }

    function _printUserState(address _user) internal {
        (ISiloConfig.ConfigData memory collateralCfg, ISiloConfig.ConfigData memory debtCfg) =
            siloConfig.getConfigsForSolvency(_user);

            SiloLens lens = new SiloLens();

        console2.log("--------------------------------");

        string memory collateralSymbol = IERC20Metadata(collateralCfg.token).symbol();
        string memory debtSymbol = IERC20Metadata(debtCfg.token).symbol();

        console2.log("SILO ID: ", siloConfig.SILO_ID(), string.concat(": ", collateralSymbol, " - ", debtSymbol));
        console2.log("block number: ", block.number);
        console2.log("block timestamp: ", block.timestamp);
        console2.log("user: ", _user);

        console2.log("collateral silo: ", collateralCfg.silo);
        console2.log("collateral asset: ", collateralSymbol, collateralCfg.token);
        console2.log("      debt silo: ", debtCfg.silo);
        console2.log("      debt asset: ", debtSymbol, debtCfg.token);
        console2.log("collateral Liquidation Threshold: ", collateralCfg.lt);
        console2.log("      debt Liquidation Threshold: ", debtCfg.lt);
        emit log_named_decimal_uint(
            "                        user LTV: ", lens.getUserLTV(ISilo(debtCfg.silo), _user), 16
        );
        emit log_named_string("user solvent?: ", ISilo(debtCfg.silo).isSolvent(_user) ? "yes" : "no");

        IPartialLiquidation hook = IPartialLiquidation(collateralCfg.hookReceiver);
        (uint256 collateralToLiquidate, uint256 debtToRepay, bool sTokenRequired) = hook.maxLiquidation(_user);

        uint256 collateralDecimals = IERC20Metadata(collateralCfg.token).decimals();
        uint256 debtDecimals = IERC20Metadata(debtCfg.token).decimals();

        emit log_named_decimal_uint(
            "[maxLiquidation] collateral to liquidate: ", collateralToLiquidate, collateralDecimals
        );
        emit log_named_decimal_uint("[maxLiquidation]           debt to repay: ", debtToRepay, debtDecimals);
        console2.log("[maxLiquidation] sToken required: ", sTokenRequired ? "yes" : "no");

        // emit log_named_decimal_uint(
        //     "collateral value: ",
        //     ISiloOracle(collateralCfg.solvencyOracle).quote(collateralToLiquidate, collateralCfg.token),
        //     18
        // );
        // emit log_named_decimal_uint(
        //     "      debt value: ", ISiloOracle(debtCfg.solvencyOracle).quote(debtToRepay, debtCfg.token), 18
        // );
    }
}