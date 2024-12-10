# @version 0.3.7
"""
@title Liquidity Gauge
@author Curve Finance
@license MIT
@notice Implementation contract for use with Curve Factory
"""
interface ERC20:
    def balanceOf(addr: address) -> uint256: view
    def totalSupply() -> uint256: view

interface ShareToken:
    def balanceOf(addr: address) -> uint256: view
    def totalSupply() -> uint256: view
    def silo() -> address: view
    def hookReceiver() -> address: view
    def balanceOfAndTotalSupply(addr: address) -> (uint256, uint256): view

interface Silo:
    def factory() -> address: view

interface SiloFactory:
    def getFeeReceivers(silo: address) -> (address, address): view

interface TokenAdmin:
    def future_epoch_time_write() -> uint256: nonpayable
    def rate() -> uint256: view

interface Controller:
    def voting_escrow() -> address: view
    def checkpoint_gauge(addr: address): nonpayable
    def gauge_relative_weight(addr: address, time: uint256) -> uint256: view

interface Minter:
    def getBalancerTokenAdmin() -> address: view
    def getGaugeController() -> address: view
    def minted(user: address, gauge: address) -> uint256: view
    def getFees() -> (uint256, uint256): view

interface VotingEscrow:
    def user_point_epoch(addr: address) -> uint256: view
    def user_point_history__ts(addr: address, epoch: uint256) -> uint256: view

interface VotingEscrowBoost:
    def adjusted_balance_of(_account: address) -> uint256: view

interface FeesManager:
    def getFees() -> (uint256, uint256): view

event Deposit:
    provider: indexed(address)
    value: uint256

event Withdraw:
    provider: indexed(address)
    value: uint256

event UpdateLiquidityLimit:
    user: indexed(address)
    original_balance: uint256
    original_supply: uint256
    working_balance: uint256
    working_supply: uint256

event RewardDistributorUpdated:
    reward_token: indexed(address)
    distributor: address

event RelativeWeightCapChanged:
    new_relative_weight_cap: uint256

struct Reward:
    token: address
    distributor: address
    period_finish: uint256
    rate: uint256
    last_update: uint256
    integral: uint256


CLAIM_FREQUENCY: constant(uint256) = 3600
MAX_REWARDS: constant(uint256) = 8
TOKENLESS_PRODUCTION: constant(uint256) = 40
WEEK: constant(uint256) = 604800

VERSION: constant(String[8]) = "v5.0.0"

BAL_TOKEN_ADMIN: immutable(address)
AUTHORIZER_ADAPTOR: immutable(address)
GAUGE_CONTROLLER: immutable(address)
MINTER: immutable(address)
VOTING_ESCROW: immutable(address)
VEBOOST_PROXY: immutable(address)

MAX_RELATIVE_WEIGHT_CAP: constant(uint256) = 10 ** 18
BPS_BASE: constant(uint256) = 10 ** 4

# Gauge

hook_receiver: public(address)
share_token: public(address)
silo: public(address)
factory: public(address)
silo_factory: public(address)

is_killed: public(bool)

# [future_epoch_time uint40][inflation_rate uint216]
inflation_params: uint256

# For tracking external rewards
reward_count: public(uint256)
reward_data: public(HashMap[address, Reward])

# claimant -> default reward receiver
rewards_receiver: public(HashMap[address, address])

# reward token -> claiming address -> integral
reward_integral_for: public(HashMap[address, HashMap[address, uint256]])

# user -> [uint128 claimable amount][uint128 claimed amount]
claim_data: HashMap[address, HashMap[address, uint256]]

working_balances: public(HashMap[address, uint256])
working_supply: public(uint256)

# 1e18 * ∫(rate(t) / totalSupply(t) dt) from (last_action) till checkpoint
integrate_inv_supply_of: public(HashMap[address, uint256])
integrate_checkpoint_of: public(HashMap[address, uint256])

# ∫(balance * rate(t) / totalSupply(t) dt) from 0 till checkpoint
# Units: rate * t = already number of coins per address to issue
integrate_fraction: public(HashMap[address, uint256])

# The goal is to be able to calculate ∫(rate * balance / totalSupply dt) from 0 till checkpoint
# All values are kept in units of being multiplied by 1e18
period: public(int128)

# array of reward tokens
reward_tokens: public(address[MAX_REWARDS])

period_timestamp: public(uint256[100000000000000000000000000000])
# 1e18 * ∫(rate(t) / totalSupply(t) dt) from 0 till checkpoint
integrate_inv_supply: public(uint256[100000000000000000000000000000])  # bump epoch when rate() changes

_relative_weight_cap: uint256

@external
def __init__(minter: address, veBoostProxy: address, authorizerAdaptor: address):
    """
    @param minter Address of minter contract
    @param veBoostProxy Address of boost delegation contract
    """
    gaugeController: address = Minter(minter).getGaugeController()
    balTokenAdmin: address = Minter(minter).getBalancerTokenAdmin()
    BAL_TOKEN_ADMIN = balTokenAdmin
    AUTHORIZER_ADAPTOR = authorizerAdaptor
    GAUGE_CONTROLLER = gaugeController
    MINTER = minter
    VOTING_ESCROW = Controller(gaugeController).voting_escrow()
    VEBOOST_PROXY = veBoostProxy

    # Set the hook_receiver variable to a non-zero value
    # in order to prevent the implementation contracts from being initialized
    self.hook_receiver = 0x000000000000000000000000000000000000dEaD

# Internal Functions


@internal
@view
def _getCappedRelativeWeight(period: uint256) -> uint256:
    """
    @dev Returns the gauge's relative weight, capped to its _relative_weight_cap attribute.
    """
    return min(Controller(GAUGE_CONTROLLER).gauge_relative_weight(self, period), self._relative_weight_cap)

@internal
def _checkpoint(addr: address):
    """
    @notice Checkpoint for a user
    @dev Updates the BAL emissions a user is entitled to receive
    @param addr User address
    """
    _period: int128 = self.period
    _period_time: uint256 = self.period_timestamp[_period]
    _integrate_inv_supply: uint256 = self.integrate_inv_supply[_period]

    inflation_params: uint256 = self.inflation_params
    rate: uint256 = inflation_params % 2 ** 216
    prev_future_epoch: uint256 = shift(inflation_params, -216)
    new_rate: uint256 = rate

    if prev_future_epoch >= _period_time:
        new_rate = TokenAdmin(BAL_TOKEN_ADMIN).rate()
        self.inflation_params = shift(TokenAdmin(BAL_TOKEN_ADMIN).future_epoch_time_write(), 216) + new_rate

    if self.is_killed:
        # Stop distributing inflation as soon as killed
        rate = 0
        new_rate = 0  # prevent distribution when crossing epochs

    # Update integral of 1/supply
    if block.timestamp > _period_time:
        _working_supply: uint256 = self.working_supply
        Controller(GAUGE_CONTROLLER).checkpoint_gauge(self)
        prev_week_time: uint256 = _period_time
        week_time: uint256 = min((_period_time + WEEK) / WEEK * WEEK, block.timestamp)

        for i in range(500):
            dt: uint256 = week_time - prev_week_time
            w: uint256 = self._getCappedRelativeWeight(prev_week_time / WEEK * WEEK)

            if _working_supply > 0:
                if prev_future_epoch >= prev_week_time and prev_future_epoch < week_time:
                    # If we went across one or multiple epochs, apply the rate
                    # of the first epoch until it ends, and then the rate of
                    # the last epoch.
                    # If more than one epoch is crossed - the gauge gets less,
                    # but that'd meen it wasn't called for more than 1 year
                    _integrate_inv_supply += rate * w * (prev_future_epoch - prev_week_time) / _working_supply
                    rate = new_rate
                    _integrate_inv_supply += rate * w * (week_time - prev_future_epoch) / _working_supply
                else:
                    _integrate_inv_supply += rate * w * dt / _working_supply
                # On precisions of the calculation
                # rate ~= 10e18
                # last_weight > 0.01 * 1e18 = 1e16 (if pool weight is 1%)
                # _working_supply ~= TVL * 1e18 ~= 1e26 ($100M for example)
                # The largest loss is at dt = 1
                # Loss is 1e-9 - acceptable

            if week_time == block.timestamp:
                break
            prev_week_time = week_time
            week_time = min(week_time + WEEK, block.timestamp)

    _period += 1
    self.period = _period
    self.period_timestamp[_period] = block.timestamp
    self.integrate_inv_supply[_period] = _integrate_inv_supply

    # Update user-specific integrals
    _working_balance: uint256 = self.working_balances[addr]
    self.integrate_fraction[addr] += _working_balance * (_integrate_inv_supply - self.integrate_inv_supply_of[addr]) / 10 ** 18
    self.integrate_inv_supply_of[addr] = _integrate_inv_supply
    self.integrate_checkpoint_of[addr] = block.timestamp


@internal
def _checkpoint_rewards(_user: address, _total_supply: uint256, _claim: bool, _receiver: address):
    """
    @notice Claim pending rewards and checkpoint rewards for a user
    """
    user_balance: uint256 = 0
    receiver: address = _receiver
    if _user != empty(address):
        user_balance = ShareToken(self.share_token).balanceOf(_user)
        if _claim and _receiver == empty(address):
            # if receiver is not explicitly declared, check if a default receiver is set
            receiver = self.rewards_receiver[_user]
            if receiver == empty(address):
                # if no default receiver is set, direct claims to the user
                receiver = _user

    reward_count: uint256 = self.reward_count
    for i in range(MAX_REWARDS):
        if i == reward_count:
            break
        token: address = self.reward_tokens[i]

        integral: uint256 = self.reward_data[token].integral
        last_update: uint256 = min(block.timestamp, self.reward_data[token].period_finish)
        duration: uint256 = last_update - self.reward_data[token].last_update
        if duration != 0:
            self.reward_data[token].last_update = last_update
            if _total_supply != 0:
                integral += duration * self.reward_data[token].rate * 10**18 / _total_supply
                self.reward_data[token].integral = integral

        if _user != empty(address):
            integral_for: uint256 = self.reward_integral_for[token][_user]
            new_claimable: uint256 = 0

            if integral_for < integral:
                self.reward_integral_for[token][_user] = integral
                new_claimable = user_balance * (integral - integral_for) / 10**18

            claim_data: uint256 = self.claim_data[_user][token]
            total_claimable: uint256 = shift(claim_data, -128) + new_claimable
            if total_claimable > 0:
                total_claimed: uint256 = claim_data % 2**128
                if _claim:
                    response: Bytes[32] = raw_call(
                        token,
                        _abi_encode(
                            receiver,
                            total_claimable,
                            method_id=method_id("transfer(address,uint256)")
                        ),
                        max_outsize=32,
                    )
                    if len(response) != 0:
                        assert convert(response, bool)
                    self.claim_data[_user][token] = total_claimed + total_claimable
                elif new_claimable > 0:
                    self.claim_data[_user][token] = total_claimed + shift(total_claimable, 128)


@internal
def _update_liquidity_limit(addr: address, l: uint256, L: uint256):
    """
    @notice Calculate limits which depend on the amount of BPT token per-user.
            Effectively it calculates working balances to apply amplification
            of BAL production by BPT
    @param addr User address
    @param l User's amount of liquidity (LP tokens)
    @param L Total amount of liquidity (LP tokens)
    """
    # To be called after totalSupply is updated
    voting_balance: uint256 = VotingEscrowBoost(VEBOOST_PROXY).adjusted_balance_of(addr)
    voting_total: uint256 = ERC20(VOTING_ESCROW).totalSupply()

    lim: uint256 = l * TOKENLESS_PRODUCTION / 100
    if voting_total > 0:
        lim += L * voting_balance / voting_total * (100 - TOKENLESS_PRODUCTION) / 100

    lim = min(l, lim)
    old_bal: uint256 = self.working_balances[addr]
    self.working_balances[addr] = lim
    _working_supply: uint256 = self.working_supply + lim - old_bal
    self.working_supply = _working_supply

    log UpdateLiquidityLimit(addr, l, L, lim, _working_supply)


@internal
def _update_user(
    _user: address,
    _user_new_balance: uint256,
    _total_supply: uint256
):
    assert _total_supply >= _user_new_balance

    self._checkpoint(_user)

    if self.reward_count != 0:
        self._checkpoint_rewards(_user, _total_supply, False, empty(address))

    self._update_liquidity_limit(_user, _user_new_balance, _total_supply)


@internal
@view
def _dao_and_deployer_fee(_amount: uint256) -> (uint256, uint256):
    """
    @notice Calculates DAO and a Silo Deployer fees
    @param _amount Amount from which fee should be deducted
    """
    fee_to_dao: uint256 = 0
    fee_to_deployer: uint256 = 0

    if _amount == 0:
        return (fee_to_dao, fee_to_deployer)

    dao_fee: uint256 = 0
    deployer_fee: uint256 = 0
    dao_fee_receiver: address = empty(address)
    deployer_fee_receiver: address = empty(address)

    (
        dao_fee_receiver,
        deployer_fee_receiver
    ) = SiloFactory(self.silo_factory).getFeeReceivers(self.silo)

    (dao_fee, deployer_fee) = Minter(MINTER).getFees()

    if dao_fee_receiver != empty(address):
        fee_to_dao = self._calculate_fee(_amount, dao_fee)

    if deployer_fee_receiver != empty(address):
        fee_to_deployer = self._calculate_fee(_amount, deployer_fee)

    return (fee_to_dao, fee_to_deployer)


@internal
def _get_dao_and_deployer_fee_from_rewards(_amount: uint256, _token: address) -> uint256:
    """
    @notice Calculates DAO and a Silo Deployer fees
    @param _amount Amount from which fee should be deducted
    """
    dao_fee: uint256 = 0
    deployer_fee: uint256 = 0
    fee_to_dao: uint256 = 0
    fee_to_deployer: uint256 = 0

    (dao_fee, deployer_fee) = FeesManager(self.factory).getFees()

    if _amount == 0:
        return _amount

    dao_fee_receiver: address = empty(address)
    deployer_fee_receiver: address = empty(address)

    (
        dao_fee_receiver,
        deployer_fee_receiver
    ) = SiloFactory(self.silo_factory).getFeeReceivers(self.silo)

    if dao_fee_receiver != empty(address) and dao_fee != 0:
        fee_to_dao = self._calculate_fee(_amount, dao_fee)
        if fee_to_dao != 0:
            self._transfer_token(dao_fee_receiver, _token, fee_to_dao)

    if deployer_fee_receiver != empty(address) and deployer_fee != 0:
        fee_to_deployer = self._calculate_fee(_amount, deployer_fee)
        if fee_to_deployer != 0:
            self._transfer_token(deployer_fee_receiver, _token, fee_to_deployer)

    return _amount - (fee_to_dao + fee_to_deployer)


@internal
def _transfer_token(_receiver: address, _reward_token: address, _amount: uint256):
    """
    @notice Transfer token to the `_receiver`
    """
    response: Bytes[32] = raw_call(
        _reward_token,
        _abi_encode(
            _receiver, _amount, method_id=method_id("transfer(address,uint256)")
        ),
        max_outsize=32,
    )
    if len(response) != 0:
        assert convert(response, bool)


@internal
@pure
def _calculate_fee(_amount: uint256, _bps: uint256) -> uint256:
    if _amount == 0 or _bps == 0:
        return 0

    return _amount * _bps / BPS_BASE


# External User Facing Functions


@external
@nonreentrant('lock')
def afterTokenTransfer(
    _user1: address,
    _user1_new_balance: uint256,
    _user2: address,
    _user2_new_balance: uint256,
    _total_supply: uint256,
    _amount: uint256
) -> bool:
    assert msg.sender == self.hook_receiver # dev: only silo hook receiver

    if _user1 != empty(address):
        self._update_user(_user1, _user1_new_balance, _total_supply)

    if _user2 != empty(address):
        self._update_user(_user2, _user2_new_balance, _total_supply)

    return True

@external
@nonreentrant('lock')
def claim_rewards(_addr: address = msg.sender, _receiver: address = empty(address)):
    """
    @notice Claim available reward tokens for `_addr`
    @param _addr Address to claim for
    @param _receiver Address to transfer rewards to - if set to
                     empty(address), uses the default reward receiver
                     for the caller
    """
    if _receiver != empty(address):
        assert _addr == msg.sender  # dev: cannot redirect when claiming for another user

    total_supply: uint256 = ShareToken(self.share_token).totalSupply()

    self._checkpoint_rewards(_addr, total_supply, True, _receiver)

@external
def user_checkpoint(addr: address) -> bool:
    """
    @notice Record a checkpoint for `addr`
    @param addr User address
    @return bool success
    """
    assert msg.sender in [addr, MINTER]  # dev: unauthorized

    user_balance: uint256 = 0
    total_supply: uint256 = 0
    
    (user_balance, total_supply) = ShareToken(self.share_token).balanceOfAndTotalSupply(addr)

    self._checkpoint(addr)
    self._update_liquidity_limit(addr, user_balance, total_supply)
    return True


@external
def set_rewards_receiver(_receiver: address):
    """
    @notice Set the default reward receiver for the caller.
    @dev When set to empty(address), rewards are sent to the caller
    @param _receiver Receiver address for any rewards claimed via `claim_rewards`
    """
    self.rewards_receiver[msg.sender] = _receiver


@external
def kick(addr: address):
    """
    @notice Kick `addr` for abusing their boost
    @dev Only if either they had another voting event, or their voting escrow lock expired
    @param addr Address to kick
    """
    t_last: uint256 = self.integrate_checkpoint_of[addr]
    t_ve: uint256 = VotingEscrow(VOTING_ESCROW).user_point_history__ts(
        addr, VotingEscrow(VOTING_ESCROW).user_point_epoch(addr)
    )

    _balance: uint256 = 0
    _total_supply: uint256 = 0
    
    (_balance, _total_supply) = ShareToken(self.share_token).balanceOfAndTotalSupply(addr)

    assert ERC20(VOTING_ESCROW).balanceOf(addr) == 0 or t_ve > t_last # dev: kick not allowed
    assert self.working_balances[addr] > _balance * TOKENLESS_PRODUCTION / 100  # dev: kick not needed

    self._checkpoint(addr)
    self._update_liquidity_limit(addr, _balance, _total_supply)


# Administrative Functions


@external
@nonreentrant("lock")
def deposit_reward_token(_reward_token: address, _amount: uint256):
    """
    @notice Deposit a reward token for distribution
    @param _reward_token The reward token being deposited
    @param _amount The amount of `_reward_token` being deposited
    """
    assert msg.sender == self.reward_data[_reward_token].distributor

    total_supply: uint256 = ShareToken(self.share_token).totalSupply()

    self._checkpoint_rewards(empty(address), total_supply, False, empty(address))

    response: Bytes[32] = raw_call(
        _reward_token,
        _abi_encode(
            msg.sender, self, _amount, method_id=method_id("transferFrom(address,address,uint256)")
        ),
        max_outsize=32,
    )
    if len(response) != 0:
        assert convert(response, bool)

    _amountWithoutFee: uint256 = self._get_dao_and_deployer_fee_from_rewards(_amount, _reward_token)

    period_finish: uint256 = self.reward_data[_reward_token].period_finish
    if block.timestamp >= period_finish:
        self.reward_data[_reward_token].rate = _amountWithoutFee / WEEK
    else:
        remaining: uint256 = period_finish - block.timestamp
        leftover: uint256 = remaining * self.reward_data[_reward_token].rate
        self.reward_data[_reward_token].rate = (_amountWithoutFee + leftover) / WEEK

    self.reward_data[_reward_token].last_update = block.timestamp
    self.reward_data[_reward_token].period_finish = block.timestamp + WEEK


@external
def add_reward(_reward_token: address, _distributor: address):
    """
    @notice Add additional rewards to be distributed to stakers
    @param _reward_token The token to add as an additional reward
    @param _distributor Address permitted to fund this contract with the reward token
    """
    assert _distributor != empty(address)
    assert msg.sender == AUTHORIZER_ADAPTOR  # dev: only owner

    reward_count: uint256 = self.reward_count
    assert reward_count < MAX_REWARDS
    assert self.reward_data[_reward_token].distributor == empty(address)

    self.reward_data[_reward_token].distributor = _distributor
    self.reward_tokens[reward_count] = _reward_token
    self.reward_count = reward_count + 1
    log RewardDistributorUpdated(_reward_token, _distributor)


@external
def set_reward_distributor(_reward_token: address, _distributor: address):
    """
    @notice Reassign the reward distributor for a reward token
    @param _reward_token The reward token to reassign distribution rights to
    @param _distributor The address of the new distributor
    """
    current_distributor: address = self.reward_data[_reward_token].distributor

    assert msg.sender == current_distributor or msg.sender == AUTHORIZER_ADAPTOR
    assert current_distributor != empty(address)
    assert _distributor != empty(address)

    self.reward_data[_reward_token].distributor = _distributor
    log RewardDistributorUpdated(_reward_token, _distributor)

@external
def killGauge():
    """
    @notice Kills the gauge so it always yields a rate of 0 and so cannot mint BAL
    """
    assert msg.sender == AUTHORIZER_ADAPTOR  # dev: only owner

    self.is_killed = True

@external
def unkillGauge():
    """
    @notice Unkills the gauge so it can mint BAL again
    """
    assert msg.sender == AUTHORIZER_ADAPTOR  # dev: only owner

    self.is_killed = False


# View Methods


@view
@external
def claimed_reward(_addr: address, _token: address) -> uint256:
    """
    @notice Get the number of already-claimed reward tokens for a user
    @param _addr Account to get reward amount for
    @param _token Token to get reward amount for
    @return uint256 Total amount of `_token` already claimed by `_addr`
    """
    return self.claim_data[_addr][_token] % 2**128


@view
@external
def claimable_reward(_user: address, _reward_token: address) -> uint256:
    """
    @notice Get the number of claimable reward tokens for a user
    @param _user Account to get reward amount for
    @param _reward_token Token to get reward amount for
    @return uint256 Claimable reward token amount
    """
    integral: uint256 = self.reward_data[_reward_token].integral

    user_balance: uint256 = 0
    total_supply: uint256 = 0
    
    (user_balance, total_supply) = ShareToken(self.share_token).balanceOfAndTotalSupply(_user)

    if total_supply != 0:
        last_update: uint256 = min(block.timestamp, self.reward_data[_reward_token].period_finish)
        duration: uint256 = last_update - self.reward_data[_reward_token].last_update
        integral += (duration * self.reward_data[_reward_token].rate * 10**18 / total_supply)

    integral_for: uint256 = self.reward_integral_for[_reward_token][_user]
    new_claimable: uint256 = user_balance * (integral - integral_for) / 10**18

    return shift(self.claim_data[_user][_reward_token], -128) + new_claimable


@external
def claimable_tokens(addr: address) -> uint256:
    """
    @notice Get the number of claimable tokens per user
    @dev This function should be manually changed to "view" in the ABI
    @return uint256 number of claimable tokens per user
    """
    self._checkpoint(addr)
    return self.integrate_fraction[addr] - Minter(MINTER).minted(addr, self)


@external
def claimable_tokens_with_fees(addr: address) -> (uint256, uint256, uint256):
    """
    @notice Get the number of claimable tokens per user
    @dev This function should be manually changed to "view" in the ABI
    @return uint256 number of claimable tokens per user
    """
    self._checkpoint(addr)

    claimable_tokens: uint256 = self.integrate_fraction[addr] - Minter(MINTER).minted(addr, self)

    fee_dao: uint256 = 0
    fee_deployer: uint256 = 0
    
    if claimable_tokens != 0:
        (fee_dao, fee_deployer) = self._dao_and_deployer_fee(claimable_tokens)
        claimable_tokens -= (fee_dao + fee_deployer)

    return (claimable_tokens, fee_dao, fee_deployer)


@view
@external
def integrate_checkpoint() -> uint256:
    """
    @notice Get the timestamp of the last checkpoint
    """
    return self.period_timestamp[self.period]


@view
@external
def future_epoch_time() -> uint256:
    """
    @notice Get the locally stored BAL future epoch start time
    """
    return shift(self.inflation_params, -216)


@view
@external
def inflation_rate() -> uint256:
    """
    @notice Get the locally stored BAL inflation rate
    """
    return self.inflation_params % 2 ** 216

@view
@external
def version() -> String[8]:
    """
    @notice Get the version of this gauge contract
    """
    return VERSION


# Initializer

@internal
def _setRelativeWeightCap(relative_weight_cap: uint256):
    assert relative_weight_cap <= MAX_RELATIVE_WEIGHT_CAP, "Relative weight cap exceeds allowed absolute maximum"
    self._relative_weight_cap = relative_weight_cap
    log RelativeWeightCapChanged(relative_weight_cap)

@external
def initialize(relative_weight_cap: uint256, silo_share_token: address):
    """
    @notice Contract constructor
    """
    assert silo_share_token != empty(address) # dev: silo share token required
    assert self.hook_receiver == empty(address) # dev: already initialized

    self.hook_receiver = ShareToken(silo_share_token).hookReceiver()
    self.share_token = silo_share_token
    self.factory = msg.sender

    silo: address = ShareToken(silo_share_token).silo()

    self.silo = silo
    self.silo_factory = Silo(silo).factory()

    self.period_timestamp[0] = block.timestamp
    self.inflation_params = shift(TokenAdmin(BAL_TOKEN_ADMIN).future_epoch_time_write(), 216) + TokenAdmin(BAL_TOKEN_ADMIN).rate()
    self._setRelativeWeightCap(relative_weight_cap)

@external
def setRelativeWeightCap(relative_weight_cap: uint256):
    """
    @notice Sets a new relative weight cap for the gauge.
            The value shall be normalized to 1e18, and not greater than MAX_RELATIVE_WEIGHT_CAP.
    @param relative_weight_cap New relative weight cap.
    """
    assert msg.sender == AUTHORIZER_ADAPTOR  # dev: only owner
    self._setRelativeWeightCap(relative_weight_cap)

@external
@view
def getRelativeWeightCap() -> uint256:
    """
    @notice Returns relative weight cap for the gauge.
    """
    return self._relative_weight_cap

@external
@view
def getCappedRelativeWeight(time: uint256) -> uint256:
    """
    @notice Returns the gauge's relative weight for a given time, capped to its _relative_weight_cap attribute.
    @param time Timestamp in the past or present.
    """
    return self._getCappedRelativeWeight(time)

@external
@view
def getFeeReceivers() -> (address, address):
    return SiloFactory(self.silo_factory).getFeeReceivers(self.silo)

@external
@pure
def getMaxRelativeWeightCap() -> uint256:
    """
    @notice Returns the maximum value that can be set to _relative_weight_cap attribute.
    """
    return MAX_RELATIVE_WEIGHT_CAP
