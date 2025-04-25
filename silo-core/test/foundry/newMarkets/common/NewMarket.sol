// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Forking} from "silo-oracles/test/foundry/_common/Forking.sol";
import {IERC20Metadata} from "openzeppelin5/token/ERC20/extensions/IERC20Metadata.sol";
import {SiloConfig} from "silo-core/contracts/SiloConfig.sol";
import {ISilo, IERC4626} from "silo-core/contracts/interfaces/ISilo.sol";
import {ISiloConfig} from "silo-core/contracts/interfaces/ISiloConfig.sol";
import {TokenHelper} from "silo-core/contracts/lib/TokenHelper.sol";

contract NewMarketTest is Forking {
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
        uint256 _blockToFork,
        address _siloConfig,
        uint256 _externalPrice0,
        uint256 _externalPrice1
    ) Forking(BlockChain.SONIC) {
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
        _borrowTest({
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
        _borrowTest({
            _collateralSilo: SILO1,
            _collateralToken: TOKEN1,
            _debtSilo: SILO0,
            _debtToken: TOKEN0,
            _collateralPrice: EXTERNAL_PRICE1,
            _debtPrice: EXTERNAL_PRICE0,
            _ltv: MAX_LTV1
        });
    }

    function _borrowTest(
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

        if (_ltv != 0) {
            _debtSilo.borrow(maxBorrow, address(this), address(this));
            assertTrue(_debtToken.balanceOf(address(this)) >= maxBorrow);
        }
    }

    function _someoneDeposited(IERC20Metadata _token, ISilo _silo, uint256 _amount) internal {
        address stranger = address(1);

        deal(address(_token), stranger, _amount);
        vm.prank(stranger);
        _token.approve(address(_silo), _amount);

        vm.prank(stranger);
        _silo.deposit(_amount, stranger);
    }
}
