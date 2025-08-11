// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Forking} from "silo-oracles/test/foundry/_common/Forking.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {SiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {ISilo, IERC4626} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";
import {SiloLens, ISiloLens} from "silo-core/contracts/SiloLens.sol";
import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {ChainsLib} from "silo-foundry-utils/lib/ChainsLib.sol";

contract NewMarketTest is Forking {
    string public constant SUCCESS_SYMBOL = unicode"✅";
    string public constant SKIPPED_SYMBOL = unicode"⏩";
    string public constant DELIMITER = "------------------------------";

    SiloConfig public immutable SILO_CONFIG; // solhint-disable-line var-name-mixedcase
    uint256 public immutable EXTERNAL_PRICE0; // solhint-disable-line var-name-mixedcase
    uint256 public immutable EXTERNAL_PRICE1; // solhint-disable-line var-name-mixedcase

    ISilo public immutable SILO0; // solhint-disable-line var-name-mixedcase
    ISilo public immutable SILO1; // solhint-disable-line var-name-mixedcase

    IERC20Metadata public immutable TOKEN0; // solhint-disable-line var-name-mixedcase
    IERC20Metadata public immutable TOKEN1; // solhint-disable-line var-name-mixedcase

    uint256 public immutable MAX_LTV0; // solhint-disable-line var-name-mixedcase
    uint256 public immutable MAX_LTV1; // solhint-disable-line var-name-mixedcase

    constructor(
        BlockChain _chain,
        uint256 _blockToFork,
        address _siloConfig,
        uint256 _externalPrice0,
        uint256 _externalPrice1
    ) Forking(_chain) {
        initFork(_blockToFork);

        SILO_CONFIG = SiloConfig(_siloConfig);
        EXTERNAL_PRICE0 = _externalPrice0;
        EXTERNAL_PRICE1 = _externalPrice1;

        (address silo0, address silo1) = SILO_CONFIG.getSilos();

        SILO0 = ISilo(silo0);
        SILO1 = ISilo(silo1);

        TOKEN0 = IERC20Metadata(SILO_CONFIG.getConfig(silo0).token);
        TOKEN1 = IERC20Metadata(SILO_CONFIG.getConfig(silo1).token);

        MAX_LTV0 = SILO_CONFIG.getConfig(silo0).maxLtv;
        MAX_LTV1 = SILO_CONFIG.getConfig(silo1).maxLtv;
    }

    function test_newMarketTest_borrowSilo0ToSilo1() public {
        _borrowScenario({
            _collateralSilo: SILO0,
            _collateralToken: TOKEN0,
            _debtSilo: SILO1,
            _debtToken: TOKEN1,
            _collateralPrice: EXTERNAL_PRICE0,
            _debtPrice: EXTERNAL_PRICE1,
            _ltv: MAX_LTV0
        });
    }

    function test_newMarketTest_borrowSilo1ToSilo0() public {
        _borrowScenario({
            _collateralSilo: SILO1,
            _collateralToken: TOKEN1,
            _debtSilo: SILO0,
            _debtToken: TOKEN0,
            _collateralPrice: EXTERNAL_PRICE1,
            _debtPrice: EXTERNAL_PRICE0,
            _ltv: MAX_LTV1
        });
    }

    function _borrowScenario(
        ISilo _collateralSilo,
        IERC20Metadata _collateralToken,
        ISilo _debtSilo,
        IERC20Metadata _debtToken,
        uint256 _collateralPrice,
        uint256 _debtPrice,
        uint256 _ltv
    ) internal {
        uint256 tokensToDeposit = 100_000_000; // without decimals
        uint256 collateralAmount = 
            tokensToDeposit * 10 ** uint256(TokenHelper.assertAndGetDecimals(address(_collateralToken)));

        deal(address(_collateralToken), address(this), collateralAmount);
        _collateralToken.approve(address(_collateralSilo), collateralAmount);

        // 1. Deposit
        _collateralSilo.deposit(collateralAmount, address(this));
        _someoneDeposited(_debtToken, _debtSilo, 1e40);

        uint256 maxBorrow = _debtSilo.maxBorrow(address(this));

        // silo0 is collateral as example, silo1 is debt.
        // collateral / borrowed = LTV ->
        // tokensToBorrow * borrowPrice / tokensToDeposit * collateralPrice = LTV
        // EXTERNAL_PRICE0 * tokensToDeposit * MAX_LTV0/10**18 = EXTERNAL_PRICE1 * tokensToBorrow
        // EXTERNAL_PRICE0 * tokensToDeposit * MAX_LTV0/10**18 = EXTERNAL_PRICE1 * maxBorrow / 10**borrowTokensDecimals
        // EXTERNAL_PRICE0 * tokensToDeposit * MAX_LTV0/10**18 * 10**borrowTokensDecimals = EXTERNAL_PRICE1 * maxBorrow

        uint256 calculatedCollateralValue = _collateralPrice * tokensToDeposit;
        uint256 calculatedBorrowedValue = calculatedCollateralValue * _ltv / 10 ** 18;
        uint256 calculatedTokensToBorrow = calculatedBorrowedValue / _debtPrice;

        uint256 calculatedMaxBorrow = 
            calculatedTokensToBorrow * 10 ** TokenHelper.assertAndGetDecimals(address(_debtToken));

        assertTrue(
            _ltv == 0 || calculatedMaxBorrow > 10 ** TokenHelper.assertAndGetDecimals(address(_debtToken)),
            "at least one token for precision or LTV is zero"
        );

        assertApproxEqRel(
            maxBorrow,
            calculatedMaxBorrow,
            0.01e18 // 1% deviation max
        );

        if (_ltv == 0) {
            _logBorrowScenarioSkipped({
                _collateralSilo: _collateralSilo,
                _debtSilo: _debtSilo
            });

            return;
        }

        // 2. Borrow
        _debtSilo.borrow(maxBorrow, address(this), address(this));
        uint256 borrowed = _debtToken.balanceOf(address(this));
        assertTrue(borrowed >= maxBorrow, "Borrowed more or equal to calculated maxBorrow based on prices");

        // 3. Repay
        _repayAndCheck({
            _debtSilo: _debtSilo,
            _debtToken: _debtToken
        });

        _logBorrowScenarioSuccess({
            _collateralSilo: _collateralSilo,
            _collateralToken: _collateralToken,
            _debtSilo: _debtSilo,
            _debtToken: _debtToken,
            _deposited: collateralAmount,
            _borrowed: borrowed
        });

        // 4. Withdraw
        _withdrawAndCheck({
            _collateralSilo: _collateralSilo,
            _collateralToken: _collateralToken,
            _initiallyDeposited: collateralAmount
        });
    }

    function _withdrawAndCheck(
        ISilo _collateralSilo,
        IERC20Metadata _collateralToken,
        uint256 _initiallyDeposited
    ) internal {
        assertEq(_collateralToken.balanceOf(address(this)), 0, "no collateralToken yet");
        _collateralSilo.redeem(_collateralSilo.balanceOf(address(this)), address(this), address(this));

        assertApproxEqRel(
            _collateralToken.balanceOf(address(this)),
            _initiallyDeposited - 1, // lost one wei due to rounding
            uint256(1e18 / 1e6) // should be equal to initial deposit with 10^-4% deviation max due to rounding
        );
    }

    // solve stack too deep
    function _repayAndCheck(
        ISilo _debtSilo,
        IERC20Metadata _debtToken
    ) internal {
        uint256 sharesToRepay = _debtSilo.maxRepayShares(address(this));
        uint256 maxRepay = _debtSilo.previewRepayShares(sharesToRepay);
        _debtToken.approve(address(_debtSilo), maxRepay);

        deal(
            address(_debtToken),
            address(this),
            maxRepay
        );

        assertEq(_debtToken.balanceOf(address(this)), maxRepay);
        _debtSilo.repayShares(sharesToRepay, address(this));
        assertEq((new SiloLens()).getLtv(_debtSilo, address(this)), 0, "Repay is successful, LTV==0");
    }

    function _someoneDeposited(IERC20Metadata _token, ISilo _silo, uint256 _amount) internal {
        address stranger = address(1);

        deal(address(_token), stranger, _amount);
        vm.prank(stranger);
        _token.approve(address(_silo), _amount);

        vm.prank(stranger);
        _silo.deposit(_amount, stranger);
    }

    function _logBorrowScenarioSkipped(
        ISilo _collateralSilo,
        ISilo _debtSilo
    ) internal view {
        console2.log(
            string.concat(
                SKIPPED_SYMBOL,
                " Borrow scenario is skipped because asset is not borrowable for ",
                _collateralSilo.symbol(),
                " -> ",
                _debtSilo.symbol()
            )
        );
    }

    function _logBorrowScenarioSuccess(
        ISilo _collateralSilo,
        IERC20Metadata _collateralToken,
        ISilo _debtSilo,
        IERC20Metadata _debtToken,
        uint256 _deposited,
        uint256 _borrowed
    ) internal view {
        console2.log(DELIMITER);

        console2.log(
            string.concat(
                SUCCESS_SYMBOL,
                " Borrow scenario success for direction ",
                _collateralSilo.symbol(),
                " -> ",
                _debtSilo.symbol()
            )
        );

        console2.log(
            "1. Deposited (in own decimals)",
            _deposited / (10 ** _collateralToken.decimals()),
            _collateralToken.symbol()
        );

        console2.log(
            "2. Borrowed up to maxBorrow (in own decimals)",
            _borrowed / (10 ** _debtToken.decimals()),
            _debtToken.symbol(),
            "with less than 1% deviation from expected amount to maxBorrow() based on LTV and external prices"
        );

        console2.log("3. Repaid everything");
        console2.log("4. Withdrawn all collateral");
    }
}
