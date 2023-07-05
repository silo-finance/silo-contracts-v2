### SiloLiquidityGauge.vy
- As in the current implementation, we have an external ERC-20 Balancer handler. We added a function that can recalculate gauge math each time the balance updated ([3ab9b90](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/3ab9b90750287ce4c36d0329408a6bd9d39882d9))

- The current implementation of the gauge assumes that different smart contract performs balance accounting. Such information as a user balance and a tokens totals supply gauge read from the so-called `ERC-20 Balances handler` ([4682361](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/468236129c7222b62b6faf27726c4dc64ad8d73e))

- Deposit into the Silo and withdrawal from the Silo equal Balancer's deposit and withdrawal into/from the gauge. These functions were not needed and were removed ([da51889](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/da518898ff7c7704c79eeb5c69a0ad022ad830b8))

- As Silo's liquidity gauge is an extension of the silo shares tokens, deposits into the Silo (the step when we mint shares tokens) are equal to the deposit of the LP tokens into the Balancer's gauge implementation. Because of it, we don't need Vault and LP token in the gauge, and it were removed ([949b2c6](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/949b2c6d55396b2a5fccd7850f2644b679e4b124))

- As Silo's version of the gauge is an extension of the silo shares tokens, we had to remove from the gauge ERC-20 and ERC-2612 related functionality as it duplicates what we have in the shares token ([ab6c1fb](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/ab6c1fb59de147e0e13a5ea98ce9f8b21cb1dbf2))

- Copy of Balancer's implementation of the LiquidityGauge.vy ([bac7082](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/bac708248757c313a2f0c47c6dee0bd91ddaf531))

### LiquidityGaugeFactory.sol

- solhint-disable ordering for BaseGaugeFactory ([420307b](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/420307bfeae951a74f04d8d8e82507ea35d412bb))

- Introduced ISiloLiquidityGauge interface as SiloLiquidityGauge initialization function changed ([f25f91d](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/f25f91d693fd5894841688ba6e9095759ecc53ce))

- Bumped solidity to 0.8.19 and updated imports ([b1fceab](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/b1fceaba4398d4041e7ec958273deb6b9901cb4e))

- Copy of Balancer's implementation of the LiquidityGaugeFactory.sol ([c2bc3d5](https://github.com/silo-finance/silo-contracts-v2/pull/34/commits/c2bc3d539244abee8e2cd9b13e70b931eb251735))