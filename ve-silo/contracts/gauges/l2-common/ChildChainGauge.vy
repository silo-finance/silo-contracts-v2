# @version 0.3.7
"""
@title Child Liquidity Gauge
@license MIT
@author Curve Finance
"""
from vyper.interfaces import ERC20


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

interface Minter:
    def minted(_user: address, _gauge: address) -> uint256: view
    def getBalancerToken() -> address: view
    def getFees() -> (uint256, uint256): view

interface VotingEscrowDelegationProxy:
    def totalSupply() -> uint256: view
    def adjustedBalanceOf(_account: address) -> uint256: view

interface FeesManager:
    def getFees() -> (uint256, uint256): view


event Deposit:
    _user: indexed(address)
    _value: uint256

event Withdraw:
    _user: indexed(address)
    _value: uint256

event UpdateLiquidityLimit:
    _user: indexed(address)
    _original_balance: uint256
    _original_supply: uint256
    _working_balance: uint256
    _working_supply: uint256


struct Reward:
    distributor: address
    period_finish: uint256
    rate: uint256
    last_update: uint256
    integral: uint256


MAX_REWARDS: constant(uint256) = 8
TOKENLESS_PRODUCTION: constant(uint256) = 40
WEEK: constant(uint256) = 86400 * 7
BPS_BASE: constant(uint256) = 10 ** 4


BAL: immutable(address)
BAL_PSEUDO_MINTER: immutable(address)
VE_DELEGATION_PROXY: immutable(address)
AUTHORIZER_ADAPTOR: immutable(address)

hook_receiver: public(address)
share_token: public(address)
silo: public(address)
version: public(String[128])
factory: public(address)
silo_factory: public(address)

working_balances: public(HashMap[address, uint256])
working_supply: public(uint256)

period: public(uint256)
period_timestamp: public(HashMap[uint256, uint256])

integrate_checkpoint_of: public(HashMap[address, uint256])
integrate_fraction: public(HashMap[address, uint256])
integrate_inv_supply: public(HashMap[uint256, uint256])
integrate_inv_supply_of: public(HashMap[address, uint256])

# For tracking external rewards
reward_count: public(uint256)
reward_tokens: public(address[MAX_REWARDS])
reward_data: public(HashMap[address, Reward])
# claimant -> default reward receiver
rewards_receiver: public(HashMap[address, address])
# reward token -> claiming address -> integral
reward_integral_for: public(HashMap[address, HashMap[address, uint256]])
# user -> token -> [uint128 claimable amount][uint128 claimed amount]
claim_data: HashMap[address, HashMap[address, uint256]]

is_killed: public(bool)
inflation_rate: public(HashMap[uint256, uint256])


@external
def __init__(
    _voting_escrow_delegation_proxy: address,
    _bal_pseudo_minter: address,
    _authorizer_adaptor: address,
    _version: String[128]
):
    self.version = _version

    VE_DELEGATION_PROXY = _voting_escrow_delegation_proxy
    BAL_PSEUDO_MINTER = _bal_pseudo_minter
    BAL = Minter(_bal_pseudo_minter).getBalancerToken()
    AUTHORIZER_ADAPTOR = _authorizer_adaptor

    # Set the hook_receiver variable to a non-zero value
    # in order to prevent the implementation contracts from being initialized
    self.hook_receiver = 0x000000000000000000000000000000000000dEaD


@internal
def _checkpoint(_user: address):
    """
    @notice Checkpoint a user calculating their BAL entitlement
    @param _user User address
    """
    period: uint256 = self.period
    period_time: uint256 = self.period_timestamp[period]
    integrate_inv_supply: uint256 = self.integrate_inv_supply[period]

    # If killed, we skip accumulating inflation in `integrate_inv_supply`
    if block.timestamp > period_time and not self.is_killed:

        working_supply: uint256 = self.working_supply
        prev_week_time: uint256 = period_time
        week_time: uint256 = min((period_time + WEEK) / WEEK * WEEK, block.timestamp)

        for i in range(256):
            dt: uint256 = week_time - prev_week_time

            if working_supply != 0:
                # we don't have to worry about crossing inflation epochs
                # and if we miss any weeks, those weeks inflation rates will be 0 for sure
                # but that means no one interacted with the gauge for that long
                integrate_inv_supply += self.inflation_rate[prev_week_time / WEEK] * 10 ** 18 * dt / working_supply

            if week_time == block.timestamp:
                break
            prev_week_time = week_time
            week_time = min(week_time + WEEK, block.timestamp)

    # check BAL balance and increase weekly inflation rate by delta for the rest of the week
    bal_balance: uint256 = ERC20(BAL).balanceOf(self)
    if bal_balance != 0:
        current_week: uint256 = block.timestamp / WEEK
        self.inflation_rate[current_week] += bal_balance / ((current_week + 1) * WEEK - block.timestamp)
        ERC20(BAL).transfer(BAL_PSEUDO_MINTER, bal_balance)

    period += 1
    self.period = period
    self.period_timestamp[period] = block.timestamp
    self.integrate_inv_supply[period] = integrate_inv_supply

    working_balance: uint256 = self.working_balances[_user]
    self.integrate_fraction[_user] += working_balance * (integrate_inv_supply - self.integrate_inv_supply_of[_user]) / 10 ** 18
    self.integrate_inv_supply_of[_user] = integrate_inv_supply
    self.integrate_checkpoint_of[_user] = block.timestamp


@internal
def _update_liquidity_limit(_user: address, _user_balance: uint256, _total_supply: uint256):
    """
    @notice Calculate working balances to apply amplification of BAL production.
    @param _user The user address
    @param _user_balance User's amount of liquidity (LP tokens)
    @param _total_supply Total amount of liquidity (LP tokens)
    """
    working_balance: uint256 = _user_balance * TOKENLESS_PRODUCTION / 100

    ve: address = VE_DELEGATION_PROXY
    if ve != empty(address):
        ve_ts: uint256 = VotingEscrowDelegationProxy(ve).totalSupply()
        if ve_ts != 0:
            ve_user_balance: uint256 = VotingEscrowDelegationProxy(ve).adjustedBalanceOf(_user)
            working_balance += _total_supply * ve_user_balance / ve_ts * (100 - TOKENLESS_PRODUCTION) / 100
            working_balance = min(_user_balance, working_balance)

    old_working_balance: uint256 = self.working_balances[_user]
    self.working_balances[_user] = working_balance

    working_supply: uint256 = self.working_supply + working_balance - old_working_balance
    self.working_supply = working_supply

    log UpdateLiquidityLimit(_user, _user_balance, _total_supply, working_balance, working_supply)


@view
@internal
def _all_indexes() -> DynArray[uint256, MAX_REWARDS]:
    indexes: DynArray[uint256, MAX_REWARDS] = []
    for i in range(MAX_REWARDS):
        if i >= self.reward_count:
            break
        indexes.append(i)

    return indexes


@internal
def _checkpoint_rewards(
    _user: address,
    _total_supply: uint256,
    _claim: bool,
    _receiver: address,
    _input_reward_indexes: DynArray[uint256, MAX_REWARDS]
):
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
    reward_indexes: DynArray[uint256, MAX_REWARDS] = []
    if len(_input_reward_indexes) == 0:
        reward_indexes = self._all_indexes()
    else:
        reward_indexes = _input_reward_indexes

    for i in reward_indexes:
        assert i < reward_count, "INVALID_REWARD_INDEX"

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
                        assert convert(response, bool), "TRANSFER_FAILURE"
                    self.claim_data[_user][token] = total_claimed + total_claimable
                elif new_claimable > 0:
                    self.claim_data[_user][token] = total_claimed + shift(total_claimable, 128)


@internal
def _update_user(
    _user: address,
    _user_new_balance: uint256,
    _total_supply: uint256
):
    assert _total_supply >= _user_new_balance

    self._checkpoint(_user)

    if self.reward_count != 0:
        self._checkpoint_rewards(_user, _total_supply, False, empty(address), [])

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

    (dao_fee, deployer_fee) = Minter(BAL_PSEUDO_MINTER).getFees()

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
def user_checkpoint(addr: address) -> bool:
    """
    @notice Record a checkpoint for `addr`
    @param addr User address
    @return bool success
    """
    self._checkpoint(addr)

    user_balance: uint256 = 0
    total_supply: uint256 = 0

    (user_balance, total_supply) = ShareToken(self.share_token).balanceOfAndTotalSupply(addr)

    self._update_liquidity_limit(addr, user_balance, total_supply)
    return True


@external
def claimable_tokens(addr: address) -> uint256:
    """
    @notice Get the number of claimable tokens per user
    @dev This function should be manually changed to "view" in the ABI
    @return uint256 number of claimable tokens per user
    """
    self._checkpoint(addr)
    return self.integrate_fraction[addr] - Minter(BAL_PSEUDO_MINTER).minted(addr, self)


@external
def claimable_tokens_with_fees(addr: address) -> (uint256, uint256, uint256):
    """
    @notice Get the number of claimable tokens per user
    @dev This function should be manually changed to "view" in the ABI
    @return uint256 number of claimable tokens per user
    """
    self._checkpoint(addr)

    claimable_tokens: uint256 = self.integrate_fraction[addr] - Minter(BAL_PSEUDO_MINTER).minted(addr, self)

    fee_dao: uint256 = 0
    fee_deployer: uint256 = 0
    
    if claimable_tokens != 0:
        (fee_dao, fee_deployer) = self._dao_and_deployer_fee(claimable_tokens)
        claimable_tokens -= (fee_dao + fee_deployer)

    return (claimable_tokens, fee_dao, fee_deployer)


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
def set_rewards_receiver(_receiver: address):
    """
    @notice Set the default reward receiver for the caller.
    @dev When set to empty(address), rewards are sent to the caller
    @param _receiver Receiver address for any rewards claimed via `claim_rewards`
    """
    self.rewards_receiver[msg.sender] = _receiver


@external
@nonreentrant('lock')
def claim_rewards(
    _addr: address = msg.sender,
    _receiver: address = empty(address),
    _reward_indexes: DynArray[uint256, MAX_REWARDS] = []
):
    """
    @notice Claim available reward tokens for `_addr`
    @param _addr Address to claim for
    @param _receiver Address to transfer rewards to - if set to
                     empty(address), uses the default reward receiver
                     for the caller
    @param _reward_indexes Array with indexes of the rewards to be checkpointed (all of them by default)
    """
    if _receiver != empty(address):
        assert _addr == msg.sender, "CANNOT_REDIRECT_CLAIM"  # dev: cannot redirect when claiming for another user

    total_supply: uint256 = ShareToken(self.share_token).totalSupply()

    self._checkpoint_rewards(_addr, total_supply, True, _receiver, _reward_indexes)


@external
def add_reward(_reward_token: address, _distributor: address):
    """
    @notice Set the active reward contract.
    @dev The reward token cannot be BAL, since it is transferred automatically to the pseudo minter during checkpoints.
    """
    assert msg.sender == AUTHORIZER_ADAPTOR, "SENDER_NOT_ALLOWED"  # dev: only owner
    assert _reward_token != BAL, "CANNOT_ADD_BAL_REWARD"

    reward_count: uint256 = self.reward_count
    assert reward_count < MAX_REWARDS, "MAX_REWARDS_REACHED"
    assert self.reward_data[_reward_token].distributor == empty(address), "REWARD_ALREADY_EXISTS"

    self.reward_data[_reward_token].distributor = _distributor
    self.reward_tokens[reward_count] = _reward_token
    self.reward_count = reward_count + 1


@external
def set_reward_distributor(_reward_token: address, _distributor: address):
    current_distributor: address = self.reward_data[_reward_token].distributor

    assert msg.sender in [current_distributor, AUTHORIZER_ADAPTOR], "SENDER_NOT_ALLOWED"
    assert current_distributor != empty(address), "REWARD_NOT_ADDED"
    assert _distributor != empty(address), "INVALID_DISTRIBUTOR"

    self.reward_data[_reward_token].distributor = _distributor


@external
@nonreentrant("lock")
def deposit_reward_token(_reward_token: address, _amount: uint256):
    assert msg.sender == self.reward_data[_reward_token].distributor, "SENDER_NOT_ALLOWED"

    total_supply: uint256 = ShareToken(self.share_token).totalSupply()

    # It is safe to checkpoint all the existing rewards as long as `_claim` is set to false (i.e. no external calls).
    self._checkpoint_rewards(empty(address), total_supply, False, empty(address), [])

    response: Bytes[32] = raw_call(
        _reward_token,
        _abi_encode(
            msg.sender,
            self,
            _amount,
            method_id=method_id("transferFrom(address,address,uint256)")
        ),
        max_outsize=32,
    )
    if len(response) != 0:
        assert convert(response, bool), "TRANSFER_FROM_FAILURE"

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
def killGauge():
    """
    @notice Kills the gauge so it always yields a rate of 0 and so cannot mint BAL
    """
    assert msg.sender == AUTHORIZER_ADAPTOR, "SENDER_NOT_ALLOWED"  # dev: only owner

    self.is_killed = True


@external
def unkillGauge():
    """
    @notice Unkills the gauge so it can mint BAL again
    """
    assert msg.sender == AUTHORIZER_ADAPTOR, "SENDER_NOT_ALLOWED"  # dev: only owner

    self.is_killed = False


@view
@external
def getFeeReceivers() -> (address, address):
    return SiloFactory(self.silo_factory).getFeeReceivers(self.silo)


@view
@external
def integrate_checkpoint() -> uint256:
    return self.period_timestamp[self.period]


@view
@external
def bal_token() -> address:
    return BAL


@view
@external
def bal_pseudo_minter() -> address:
    return BAL_PSEUDO_MINTER


@view
@external
def voting_escrow_delegation_proxy() -> address:
    return VE_DELEGATION_PROXY


@view
@external
def authorizer_adaptor() -> address:
    """
    @notice Return the authorizer adaptor address.
    """
    return AUTHORIZER_ADAPTOR


@external
def initialize(silo_share_token: address, _version: String[128]):
    assert silo_share_token != empty(address) # dev: silo share token required
    assert self.hook_receiver == empty(address) # dev: already initialized

    self.version = _version
    self.factory = msg.sender
    self.hook_receiver = ShareToken(silo_share_token).hookReceiver()
    self.share_token = silo_share_token
    
    silo: address = ShareToken(self.share_token).silo()

    self.silo = silo
    self.silo_factory = Silo(silo).factory()

    self.period_timestamp[0] = block.timestamp
