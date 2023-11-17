# @version 0.3.7
"""
@title Boost Delegation V2
@author CurveFi
@modified Silo Finance
"""


event Approval:
    _owner: indexed(address)
    _spender: indexed(address)
    _value: uint256

event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _value: uint256

event Boost:
    _from: indexed(address)
    _to: indexed(address)
    _bias: uint256
    _slope: uint256
    _start: uint256

event Migrate:
    _token_id: indexed(uint256)

interface ERC20:
    def balanceOf(addr: address) -> uint256: view
    def totalSupply() -> uint256: view

interface VotingEscrow:
    def balanceOf(_user: address) -> uint256: view
    def totalSupply() -> uint256: view
    def locked__end(_user: address) -> uint256: view

interface ERC1271:
    def isValidSignature(_hash: bytes32, _signature: Bytes[65]) -> bytes32: view

struct Point:
    bias: uint256
    slope: uint256
    ts: uint256

struct BoostPoint:
    linear_blance: uint256
    bias: uint256
    slope: uint256
    ts: uint256


NAME: constant(String[32]) = "Silo Vote-Escrowed Boost"
SYMBOL: constant(String[8]) = "veBoost"
VERSION: constant(String[8]) = "v1.0.0"
TOKENLESS_PRODUCTION: constant(uint256) = 40

EIP712_TYPEHASH: constant(bytes32) = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
PERMIT_TYPEHASH: constant(bytes32) = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")

# keccak256("isValidSignature(bytes32,bytes)")[:4] << 224
ERC1271_MAGIC_VAL: constant(bytes32) = 0x1626ba7e00000000000000000000000000000000000000000000000000000000


WEEK: constant(uint256) = 86400 * 7


DOMAIN_SEPARATOR: immutable(bytes32)
VE: immutable(address)


allowance: public(HashMap[address, HashMap[address, uint256]])
nonces: public(HashMap[address, uint256])

delegated: public(HashMap[address, Point])
delegated_slope_changes: public(HashMap[address, HashMap[uint256, uint256]])

received: public(HashMap[address, Point])
received_slope_changes: public(HashMap[address, HashMap[uint256, uint256]])

migrated: public(HashMap[uint256, bool])

boost_points: public(HashMap[address, BoostPoint])

@external
def __init__(_ve: address):
    DOMAIN_SEPARATOR = keccak256(_abi_encode(EIP712_TYPEHASH, keccak256(NAME), keccak256(VERSION), chain.id, self))
    VE = _ve

    log Transfer(empty(address), msg.sender, 0)


@view
@internal
def _checkpoint_read(_user: address, _delegated: bool) -> Point:
    point: Point = empty(Point)

    if _delegated:
        point = self.delegated[_user]
    else:
        point = self.received[_user]

    if point.ts == 0:
        point.ts = block.timestamp

    if point.ts == block.timestamp:
        return point

    ts: uint256 = (point.ts / WEEK) * WEEK
    for _ in range(255):
        ts += WEEK

        dslope: uint256 = 0
        if block.timestamp < ts:
            ts = block.timestamp
        else:
            if _delegated:
                dslope = self.delegated_slope_changes[_user][ts]
            else:
                dslope = self.received_slope_changes[_user][ts]

        point.bias -= point.slope * (ts - point.ts)
        point.slope -= dslope
        point.ts = ts

        if ts == block.timestamp:
            break

    return point


@internal
def _checkpoint_write(_user: address, _delegated: bool) -> Point:
    point: Point = empty(Point)

    if _delegated:
        point = self.delegated[_user]
    else:
        point = self.received[_user]

    if point.ts == 0:
        point.ts = block.timestamp

    if point.ts == block.timestamp:
        return point

    dbias: uint256 = 0
    ts: uint256 = (point.ts / WEEK) * WEEK
    for _ in range(255):
        ts += WEEK

        dslope: uint256 = 0
        if block.timestamp < ts:
            ts = block.timestamp
        else:
            if _delegated:
                dslope = self.delegated_slope_changes[_user][ts]
            else:
                dslope = self.received_slope_changes[_user][ts]

        amount: uint256 = point.slope * (ts - point.ts)

        dbias += amount
        point.bias -= amount
        point.slope -= dslope
        point.ts = ts

        if ts == block.timestamp:
            break

    if _delegated == False and dbias != 0:  # received boost
        log Transfer(_user, empty(address), dbias)

    return point


@view
@internal
def _balance_of(_user: address) -> uint256:
    # if _user_is_vault(_user)
    #     point: BoostPoint = self._read_boost_checkpoint(msg.sender)

    #     return point.linear_balance + point.bias


    amount: uint256 = VotingEscrow(VE).balanceOf(_user)

    point: Point = self._checkpoint_read(_user, True)
    amount -= (point.bias - point.slope * (block.timestamp - point.ts))

    point = self._checkpoint_read(_user, False)
    amount += (point.bias - point.slope * (block.timestamp - point.ts))
    return amount


@internal
def _boost(_from: address, _to: address, _amount: uint256, _endtime: uint256):
    assert _to not in [_from, empty(address)]
    assert _amount != 0
    assert _endtime > block.timestamp
    assert _endtime % WEEK == 0
    assert _endtime <= VotingEscrow(VE).locked__end(_from)

    # checkpoint delegated point
    point: Point = self._checkpoint_write(_from, True)
    assert _amount <= VotingEscrow(VE).balanceOf(_from) - (point.bias - point.slope * (block.timestamp - point.ts))

    # calculate slope and bias being added
    slope: uint256 = _amount / (_endtime - block.timestamp)
    bias: uint256 = slope * (_endtime - block.timestamp)

    # update delegated point
    point.bias += bias
    point.slope += slope

    # store updated values
    self.delegated[_from] = point
    self.delegated_slope_changes[_from][_endtime] += slope

    # update received amount
    point = self._checkpoint_write(_to, False)
    point.bias += bias
    point.slope += slope

    # store updated values
    self.received[_to] = point
    self.received_slope_changes[_to][_endtime] += slope

    log Transfer(_from, _to, _amount)
    log Boost(_from, _to, bias, slope, block.timestamp)

    # also checkpoint received and delegated
    self.received[_from] = self._checkpoint_write(_from, False)
    self.delegated[_to] = self._checkpoint_write(_to, True)


@internal
def _calculate_curvature_point(
        _user: address,
        _user_liquidity: uint256,
        _total_liquidity: uint256,
        _voting_balance: uint256
    ) -> (uint256, uint256): # Need to return a voting power
    # calculate curvature_point (where we are starting receiving less incentives, it based on a balance)
    #   lim: uint256 = l * TOKENLESS_PRODUCTION / 100
    #   if voting_total > 0:
    #       lim += L * voting_balance / voting_total * (100 - TOKENLESS_PRODUCTION) / 100
    #   lim = min(l, lim)

    voting_total: uint256 = ERC20(VOTING_ESCROW).totalSupply()
    lim: uint256 = _user_liquidity * TOKENLESS_PRODUCTION / 100

    if voting_total > :
        lim += _total_liquidity * _voting_balance / voting_total * (100 - TOKENLESS_PRODUCTION) / 100




@internal
def _boost_based_on_deposit(_user: address, _user_liquidity: uint256, _total_liquidity):
    assert _user not in [msg.sender, empty(address)]
    assert _amount != 0

    locked_end: uint256 = VotingEscrow(VE).locked__end(_user) / WEEK * WEEK

    assert locked_end > block.timestamp

    voting_balance: uint256 = ERC20(VE).balanceOf(_user)

    linear_balance: uint256 = 0
    curvature_point: uint256 = 0

    (
        linear_balance,
        curvature_point
    ) = self._calculate_curvature_point(_user, _user_liquidity, voting_balance)

    point: BoostPoint = self._read_boost_checkpoint(msg.sender)

    if linear_balance == 0:
        time_diff = locked_end - block.timestamp

        slope: uint256 = voting_balance / time_diff # ?

        point.slope += slope
        point.bias += slope * time_diff

        slope_decrease[msg.sender][locked_end] += slope
        boost_points[msg.sender] = point

        return

    point.linear_balance += linear_balance
    linear_balance_decrease[msg.sender][curvature_point] += linear_balance
    slope_increase[msg.sender][curvature_point] += slope

    boost_points[msg.sender] = point

    # All boosts boosts for max voting power

    # calculate linear_balance

    

    # linear_balance will go to bias, and slope should be added after the curvature_point

    # we have two slope_changes
    #       - slope_increase - it is updated on a boost (in the case if linear_balance != 0)
    #       - slope_decrease - it is updated when we reach curvature_point or on a boost if it is not enough 

@view
@internal
def _read_boost_checkpoint(_user: address) -> BoostPoint:
    point: BoostPoint = boost_points[msg.sender]

    if point.ts == 0:
        point.ts = block.timestamp

    if point.ts == block.timestamp:
        return point

    ts: uint256 = (point.ts / WEEK) * WEEK

    for _ in range(255):
        ts += WEEK
        d_slope: uint256 = 0

        if block.timestamp < ts:
            ts = block.timestamp
        else
            d_slope = slope_decrease[msg.sender][ts]

        # recalculating last/current week
        point.bias -= point.slope * (ts - point.ts)
        point.slope -= d_slope
        point.ts = ts

        if block.timestamp != ts:
            # entering curvature points
            linear_balance: uint256 = linear_balance_decrease[msg.sender][ts]
            i_slope: uint256 = slope_increase[msg.sender][ts]

            # reducing linear balance and increasing bias and slope
            point.linear_balance -= linear_balance
            point.bias += linear_balance
            point.slope += i_slope

        if ts == block.timestamp:
            break

    return point

@external
def boost(_to: address, _amount: uint256, _endtime: uint256, _from: address = msg.sender):
    # reduce approval if necessary
    if _from != msg.sender:
        allowance: uint256 = self.allowance[_from][msg.sender]
        if allowance != max_value(uint256):
            self.allowance[_from][msg.sender] = allowance - _amount
            log Approval(_from, msg.sender, allowance - _amount)

    self._boost(_from, _to, _amount, _endtime)


@external
def checkpoint_user(_user: address):
    self.delegated[_user] = self._checkpoint_write(_user, True)
    self.received[_user] = self._checkpoint_write(_user, False)


@external
def approve(_spender: address, _value: uint256) -> bool:
    self.allowance[msg.sender][_spender] = _value

    log Approval(msg.sender, _spender, _value)
    return True


@external
def permit(_owner: address, _spender: address, _value: uint256, _deadline: uint256, _v: uint8, _r: bytes32, _s: bytes32) -> bool:
    assert block.timestamp <= _deadline, 'EXPIRED_SIGNATURE'

    nonce: uint256 = self.nonces[_owner]
    digest: bytes32 = keccak256(
        concat(
            b"\x19\x01",
            DOMAIN_SEPARATOR,
            keccak256(_abi_encode(PERMIT_TYPEHASH, _owner, _spender, _value, nonce, _deadline))
        )
    )

    if _owner.is_contract:
        sig: Bytes[65] = concat(_abi_encode(_r, _s), slice(convert(_v, bytes32), 31, 1))
        # reentrancy not a concern since this is a staticcall
        assert ERC1271(_owner).isValidSignature(digest, sig) == ERC1271_MAGIC_VAL, 'INVALID_SIGNATURE'
    else:
        assert ecrecover(digest, convert(_v, uint256), convert(_r, uint256), convert(_s, uint256)) == _owner and _owner != empty(address), 'INVALID_SIGNATURE'

    self.allowance[_owner][_spender] = _value
    self.nonces[_owner] = nonce + 1

    log Approval(_owner, _spender, _value)
    return True


@external
def increaseAllowance(_spender: address, _added_value: uint256) -> bool:
    allowance: uint256 = self.allowance[msg.sender][_spender] + _added_value
    self.allowance[msg.sender][_spender] = allowance

    log Approval(msg.sender, _spender, allowance)
    return True


@external
def decreaseAllowance(_spender: address, _subtracted_value: uint256) -> bool:
    allowance: uint256 = self.allowance[msg.sender][_spender] - _subtracted_value
    self.allowance[msg.sender][_spender] = allowance

    log Approval(msg.sender, _spender, allowance)
    return True


@view
@external
def balanceOf(_user: address) -> uint256:
    return self._balance_of(_user)


@view
@external
def adjusted_balance_of(_user: address) -> uint256:
    return self._balance_of(_user)


@view
@external
def totalSupply() -> uint256:
    return VotingEscrow(VE).totalSupply()


@view
@external
def delegated_balance(_user: address) -> uint256:
    point: Point = self._checkpoint_read(_user, True)
    return point.bias - point.slope * (block.timestamp - point.ts)


@view
@external
def received_balance(_user: address) -> uint256:
    point: Point = self._checkpoint_read(_user, False)
    return point.bias - point.slope * (block.timestamp - point.ts)


@view
@external
def delegable_balance(_user: address) -> uint256:
    point: Point = self._checkpoint_read(_user, True)
    return VotingEscrow(VE).balanceOf(_user) - (point.bias - point.slope * (block.timestamp - point.ts))


@pure
@external
def name() -> String[32]:
    return NAME


@pure
@external
def symbol() -> String[8]:
    return SYMBOL


@pure
@external
def decimals() -> uint8:
    return 18


@pure
@external
def version() -> String[8]:
    return VERSION

@pure
@external
def DOMAIN_SEPARATOR() -> bytes32:
    return DOMAIN_SEPARATOR


@pure
@external
def VE() -> address:
    return VE
