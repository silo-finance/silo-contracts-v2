import { Wallet, Contract, constants } from 'ethers'
import { Web3Provider } from 'ethers/providers'
import { deployContract } from 'ethereum-waffle'

import { expandTo18Decimals } from './utilities'

import SiloAmmPairFactory from 'silo-amm-core/artifacts/SiloAmmPairFactory.sol/SiloAmmPairFactory.json'
import IUniswapV2Pair from 'uniswap-v2-core/build/IUniswapV2Pair.json'

import ERC20 from '../../build/ERC20.json'
import WETH9 from '../../build/WETH9.json'
import UniswapV1Exchange from '../../buildV1/UniswapV1Exchange.json'
import UniswapV1Factory from '../../buildV1/UniswapV1Factory.json'
import SiloAmmRouter from 'silo-amm-periphery/artifacts/SiloAmmRouter.sol/SiloAmmRouter.json'
import RouterEventEmitter from '../../build/RouterEventEmitter.json'
import {ContractJSON} from "ethereum-waffle/dist/esm/ContractJSON";

const overrides = {
  gasLimit: 9999999
}

interface V2Fixture {
  token0: Contract
  token1: Contract
  WETH: Contract
  WETHPartner: Contract
  factoryV1: Contract
  factoryV2: Contract
  router02: Contract
  routerEventEmitter: Contract
  WETHExchangeV1: Contract
  pair: Contract
  WETHPair: Contract
}

export async function v2Fixture(provider: Web3Provider, [wallet]: Wallet[]): Promise<V2Fixture> {
  // deploy tokens
  const tokenA = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)])
  const tokenB = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)])
  const WETH = await deployContract(wallet, WETH9)
  const WETHPartner = await deployContract(wallet, ERC20, [expandTo18Decimals(10000)])

  // deploy V1
  const factoryV1 = await deployContract(wallet, UniswapV1Factory, [])
  await factoryV1.initializeFactory((await deployContract(wallet, UniswapV1Exchange, [])).address)

  // deploy V2
  const factory = await deployContract(wallet, (SiloAmmPairFactory as unknown) as ContractJSON, [])

  // deploy routers
  const router02 = await deployContract(wallet, (SiloAmmRouter as unknown) as ContractJSON, [factory.address, WETH.address], overrides)
  const factoryV2 = router02;

  // event emitter for testing
  const routerEventEmitter = await deployContract(wallet, RouterEventEmitter, [])

  // initialize V1
  await factoryV1.createExchange(WETHPartner.address, overrides)
  const WETHExchangeV1Address = await factoryV1.getExchange(WETHPartner.address)
  const WETHExchangeV1 = new Contract(WETHExchangeV1Address, JSON.stringify(UniswapV1Exchange.abi), provider).connect(
    wallet
  )

  // initialize V2
  await factoryV2.createPair(
    tokenA.address,
    constants.AddressZero,
    tokenB.address,
    constants.AddressZero,
    {tSlow: 60 * 60, q: '100000000000000', kMax: '10000000000000000', kMin: 0, vFast: '4629629629629', deltaK: 3564},
    constants.AddressZero
  );

  const pairAddress = await factoryV2.getPair(tokenA.address, tokenB.address, constants.AddressZero)
  const pair = new Contract(pairAddress, JSON.stringify(IUniswapV2Pair.abi), provider).connect(wallet)

  const token0Address = await pair.token0()
  const token0 = tokenA.address === token0Address ? tokenA : tokenB
  const token1 = tokenA.address === token0Address ? tokenB : tokenA

  await factoryV2.createPair(
    WETH.address,
    constants.AddressZero,
    WETHPartner.address,
    constants.AddressZero,
    {tSlow: 60 * 60, q: '100000000000000', kMax: '10000000000000000', kMin: 0, vFast: '4629629629629', deltaK: 3564},
    constants.AddressZero
  )
  const WETHPairAddress = await factoryV2.getPair(WETH.address, WETHPartner.address, constants.AddressZero)
  const WETHPair = new Contract(WETHPairAddress, JSON.stringify(IUniswapV2Pair.abi), provider).connect(wallet)

  return {
    token0,
    token1,
    WETH,
    WETHPartner,
    factoryV1,
    factoryV2,
    router02,
    routerEventEmitter,
    WETHExchangeV1,
    pair,
    WETHPair
  }
}
