// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./SiloAmmPair.sol";
import "./interfaces/ISiloAmmPairFactory.sol";

contract SiloAmmPairFactory is ISiloAmmPairFactory {
    /// @inheritdoc ISiloAmmPairFactory
    function createPair(
        address _silo,
        address _token0,
        address _token1,
        ISiloOracle _oracle0,
        ISiloOracle _oracle1,
        address _bridgeQuoteToken,
        IAmmPriceModel.AmmPriceConfig memory _config
    )
        external
        virtual
        returns (ISiloAmmPair pair)
    {
        pair = new SiloAmmPair(msg.sender, _silo, _token0, _token1, _oracle0, _oracle1, _bridgeQuoteToken, _config);
    }

    /// @inheritdoc ISiloAmmPairFactory
    function siloAmmPairFactoryPing() external pure returns(bytes4) {
        return ISiloAmmPairFactory.siloAmmPairFactoryPing.selector;
    }
}
