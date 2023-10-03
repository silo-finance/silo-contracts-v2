### ethereum/SiloLiquidityGauge.vy

- Fees receivers from the Silo factory and fees for the gauge from the MainnetBalancerMinter.sol ([35c6ac8](https://github.com/silo-finance/silo-contracts-v2/pull/155/commits/35c6ac87bf4a327758fa22486ef7cf2aec7810f0))

- Implemented `claimable_tokens_with_fees` fn, which returns claimable tokens for a user and also fees gained by a DAO and deployer ([a96d717](https://github.com/silo-finance/silo-contracts-v2/pull/97/commits/a96d7173319a766536acc4874aa9b1670c54f0fa))

- Replaced an ERC-20 Balancer handler with a Silo Hook Receiver. Added integration with the Silo share token ([ccf97d1](https://github.com/silo-finance/silo-contracts-v2/pull/94/commits/ccf97d1d8434ac54c169e954094a3d4537ed5b3d))

- As in the current implementation, we have an external ERC-20 Balancer handler. We added a function that can recalculate gauge math each time the balance updated ([3ab9b90](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/3ab9b90750287ce4c36d0329408a6bd9d39882d9))

- The current implementation of the gauge assumes that different smart contract performs balance accounting. Such information as a user balance and a tokens totals supply gauge read from the so-called `ERC-20 Balances handler` ([4682361](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/468236129c7222b62b6faf27726c4dc64ad8d73e))

- Deposit into the Silo and withdrawal from the Silo equal Balancer's deposit and withdrawal into/from the gauge. These functions were not needed and were removed ([da51889](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/da518898ff7c7704c79eeb5c69a0ad022ad830b8))

- As Silo's liquidity gauge is an extension of the silo shares tokens, deposits into the Silo (the step when we mint shares tokens) are equal to the deposit of the LP tokens into the Balancer's gauge implementation. Because of it, we don't need Vault and LP token in the gauge, and it were removed ([949b2c6](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/949b2c6d55396b2a5fccd7850f2644b679e4b124))

- As Silo's version of the gauge is an extension of the silo shares tokens, we had to remove from the gauge ERC-20 and ERC-2612 related functionality as it duplicates what we have in the shares token ([ab6c1fb](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/ab6c1fb59de147e0e13a5ea98ce9f8b21cb1dbf2))

- Copy of Balancer's implementation of the LiquidityGauge.vy ([bac7082](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/bac708248757c313a2f0c47c6dee0bd91ddaf531))

### controller/GaugeController.sol

- Introduced a `Gauge Adder` role, which can be set by an `AUTHORIZER_ADAPTOR` and is eligible to add gauge into the gauge controller ([4aacd41](https://github.com/silo-finance/silo-contracts-v2/pull/69/commits/4aacd41da29853662f3391e4826af4fd207adde4))

- Bumped vyper to 0.3.7 ([db7ad37](https://github.com/silo-finance/silo-contracts-v2/pull/69/commits/db7ad3739e4ac02dd7556b58d64a933b7744691b))

- Copy of Balancer's implementation of the GaugeController.vy ([a9562fe](https://github.com/silo-finance/silo-contracts-v2/pull/69/commits/a9562fee86534cc563b23bd7ea663292af85eec8))

### ethereum/LiquidityGaugeFactory.sol

- solhint-disable ordering for BaseGaugeFactory ([420307b](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/420307bfeae951a74f04d8d8e82507ea35d412bb))

- Introduced ISiloLiquidityGauge interface as SiloLiquidityGauge initialization function changed ([f25f91d](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/f25f91d693fd5894841688ba6e9095759ecc53ce))

- Bumped solidity to 0.8.19 and updated imports ([b1fceab](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/b1fceaba4398d4041e7ec958273deb6b9901cb4e))

- Copy of Balancer's implementation of the LiquidityGaugeFactory.sol ([c2bc3d5](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/c2bc3d539244abee8e2cd9b13e70b931eb251735))

### l2-common/ChildChainGauge.vy

- Fees receivers from the Silo factory and fees for the gauge from the L2BalancerPseudoMinter.sol ([3f6faaa](https://github.com/silo-finance/silo-contracts-v2/pull/155/commits/3f6faaafe909da7aa2a064660f02c8233e4be86a))

- Implemented `claimable_tokens_with_fees` fn, which returns claimable tokens for a user and also fees gained by a DAO and deployer ([5611fe5](https://github.com/silo-finance/silo-contracts-v2/pull/97/commits/5611fe5eb81553e6a47db71638a601346fad065e))

- Replaced an ERC-20 Balancer handler with a Silo Hook Receiver. Added integration with the Silo share token ([53ee1fe](https://github.com/silo-finance/silo-contracts-v2/pull/94/commits/53ee1febf52e92b80fe81e03cd1ee675ed88e955))

- As in the current implementation, we have an external ERC-20 Balancer handler. We added a function that can recalculate gauge math each time the balance updated ([54ad3d0](https://github.com/silo-finance/silo-contracts-v2/pull/56/commits/54ad3d017658e95b0b4e07356998ce558ff2f1ec))

- The current implementation of the gauge assumes that different smart contract performs balance accounting. Such information as a user balance and a tokens totals supply gauge read from the so-called `ERC-20 Balances handler` ([f64e530](https://github.com/silo-finance/silo-contracts-v2/pull/56/commits/f64e530d98b49ef6ad17444b4106c536b1776b80))

- Deposit into the Silo and withdrawal from the Silo equal Balancer's deposit and withdrawal into/from the gauge. These functions were not needed and were removed ([b00d227](https://github.com/silo-finance/silo-contracts-v2/pull/56/commits/b00d227e1335070fec7407e4cdba1703db8be1d7))

- As Silo's child chain gauge is an extension of the silo shares tokens, deposits into the Silo (the step when we mint shares tokens) are equal to the deposit of the LP tokens into the Balancer's gauge implementation. Because of it, we don't need Vault and LP token in the gauge, and it were removed ([c583651](https://github.com/silo-finance/silo-contracts-v2/pull/56/commits/c583651a873e64d4050db8875bc0824d8af772c9))

- As Silo's version of the gauge is an extension of the silo shares tokens, we had to remove from the gauge ERC-20 and ERC-2612 related functionality as it duplicates what we have in the shares token ([3ee1aaf](https://github.com/silo-finance/silo-contracts-v2/pull/56/commits/3ee1aafedf1becad3d9a08141ea192ad1c9ab8bb))

- Bumped vyper to 0.3.7 ([f411dd3](https://github.com/silo-finance/silo-contracts-v2/pull/56/commits/f411dd338f4386693108b019b42ef32dd008bd89))

- Copy of Balancer's implementation of the ChildChainGauge.vy ([1c535c4](https://github.com/silo-finance/silo-contracts-v2/pull/56/commits/1c535c462b0fa00b4a42531e741caa357894a7ad))

### l2-common/ChildChainGaugeFactory.sol

- Updated naming and comment in a favor of the ERC-20 balances handler instead of the pool ([1ea523d](https://github.com/silo-finance/silo-contracts-v2/pull/56/commits/1ea523d4fba941b1ad192091c36f9268bdde3f41))

- Bumped solidity to 0.8.19, updated imports, and solhint ([430e843](https://github.com/silo-finance/silo-contracts-v2/pull/56/commits/430e843bed16bf2dfde6cd39b5eaf1b25c4e02b7))

- Copy of Balancer's implementation of the ChildChainGaugeFactory.sol ([0543b3f](https://github.com/silo-finance/silo-contracts-v2/pull/56/commits/0543b3fd50fe02c3555c0d2efc82fa7771fba33e))

### stakeless-gauge/StakelessGauge.sol
- Changed StakelessGauge.sol location and updated an IStakelessGauge import ([8a43a53](https://github.com/silo-finance/silo-contracts-v2/pull/71/commits/8a43a53bc9c415d6d13b9ed89b25fdfac793b6fd))

- introduced `checkpointer` role that can checkpoint gauge ([f6603fa](https://github.com/silo-finance/silo-contracts-v2/pull/70/commits/f6603fa4a728fb9d934be846ab5968f359d91d96))

- Changed balancer token type ([931f28e](https://github.com/silo-finance/silo-contracts-v2/pull/63/commits/931f28eba3e58321e1a7c3c330634202bcdd1345))

- Changed ownership system for StakelessGauge. Replaced SingletonAuthentication with Ownable2Step ([65fbc67](https://github.com/silo-finance/silo-contracts-v2/pull/63/commits/65fbc670f9a91105742b8ae3738ee4215280c7e3))

- Bumped solidity to 0.8.19 and updated imports. Some imports were removed as they were not used ([6075b4a](https://github.com/silo-finance/silo-contracts-v2/pull/63/commits/6075b4a97a142967a68071a7b3e4f5f82df6f402))

- Copy of Balancer's implementation of the StakelessGauge.sol ([c731307](https://github.com/silo-finance/silo-contracts-v2/pull/63/commits/c7313073b1ca24f4d75fd9f6e5eab3110489249a))

### stakeless-gauge/CCIPGaugeCheckpointer.sol
- Calldata instead of memory for external functions ([cadcaf9](https://github.com/silo-finance/silo-contracts-v2/pull/171/commits/cadcaf99500d5d34714a406df5b43293d2e4abec))

- Implementation of the `CCIPGaugeCheckpointer` ([bfa6cfa](https://github.com/silo-finance/silo-contracts-v2/pull/111/commits/bfa6cfa11fd91e51c6904b9399247774dd2022df))

- Copy of the [StakelessGaugeCheckpointer.sol commit 7bddde6](https://github.com/silo-finance/silo-contracts-v2/pull/72/commits/7bddde63c1b895c5ec938a320468a53ca666379e) ([2f0e3ed](https://github.com/silo-finance/silo-contracts-v2/pull/111/commits/2f0e3edf24969ebbd3c8c65ca68b4eaa6c5005d6))

### StakelessGaugeCheckpointer.sol (see CCIPGaugeCheckpointer.sol)
- Added `receive` fn to be able to receive leftover ETH from the `StakelessGaugeCheckpointerAdaptor` if there will be any ([7bddde6](https://github.com/silo-finance/silo-contracts-v2/pull/72/commits/7bddde63c1b895c5ec938a320468a53ca666379e))

- Bumped solidity to 0.8.19, updated imports, and solhint ([f752edd](https://github.com/silo-finance/silo-contracts-v2/pull/72/commits/f752eddb5972cc99fc5d4dae3806c1287113bb83))

- Changed ownership system for StakelessGauge. Replaced SingletonAuthentication with Ownable2Step ([a42ae4c](https://github.com/silo-finance/silo-contracts-v2/pull/72/commits/a42ae4ca7bfd1a76ad76251ede5b265fba7bfa87))

- Replaced authorizerAdaptorEntrypoint with StakelessGaugeCheckpointerAdaptor ([6afed53](https://github.com/silo-finance/silo-contracts-v2/pull/72/commits/6afed5359eef99bb1367c21960412715542c14ef))

- Copy of Balancer's implementation of the StakelessGaugeCheckpointer.sol ([5c7ea22](https://github.com/silo-finance/silo-contracts-v2/pull/72/commits/5c7ea225313e8a3b10ba809f47153271fcdac6fc))

### gauge-adder/GaugeAdder.sol
- Updated `_ETHEREUM_GAUGE_CONTROLLER_TYPE` value to `0` ([c1dce5f](https://github.com/silo-finance/silo-contracts-v2/pull/85/commits/c1dce5f0e0825176632bfb0c8332d40caf5832dc))

- Removed gauge types as they were deprecated ([0ea9da8](https://github.com/silo-finance/silo-contracts-v2/pull/66/commits/0ea9da87c6827ed73211bb266aa183a7a71d82ec))

- Refactored `_addGauge` fn, fixed data types conversion ([0faa476](https://github.com/silo-finance/silo-contracts-v2/pull/66/commits/0faa476b4422be322d44ffa5701bb08829013493))

- Bumped solidity to 0.8.19 and updated imports. Some imports were removed as they were not used ([6177204](https://github.com/silo-finance/silo-contracts-v2/pull/66/commits/617720407034bf9ef324908eac900afd09f4dc6a))

- Removed verification of the gauge LP token while adding a gauge, as gauges will be created only for the Silo share tokens ([c23d305](https://github.com/silo-finance/silo-contracts-v2/pull/66/commits/c23d3057199a85a32297b8095c203a0519bc350b))

- Changed ownership system for GaugeAdder. Replaced SingletonAuthentication with Ownable2Step ([6b8206f](https://github.com/silo-finance/silo-contracts-v2/pull/66/commits/6b8206ff6a538cdacde7b3d90269d04b64c46b91))

- Copy of Balancer's implementation of the GaugeAdder.sol ([fa25615](https://github.com/silo-finance/silo-contracts-v2/pull/66/commits/fa256150b70ff6cf222f39d26b52a5fb90788e6f))
