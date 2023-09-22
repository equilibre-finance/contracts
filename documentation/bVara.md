# bVara token

## Contract Address

- [bVara](contracts/bVaraImplementation.sol) [`0x9d8054aaf108A5B5fb9fE27F89F3Db11E82fc94F`](https://kavascan.com/address/0x9d8054aaf108A5B5fb9fE27F89F3Db11E82fc94F/contracts#address-tabs)
  > Attention: use the proxy address to interact with the contract.

- [Admin: `0x7cef2432A2690168Fb8eb7118A74d5f8EfF9Ef55`](https://kavascan.com/address/0x7cef2432A2690168Fb8eb7118A74d5f8EfF9Ef55)
  > This is the user that can mint and burn tokens also, this user can burn
  tokens from any address.

## Overview

- The `bVara` contract is an implementation of the OFTV2 token standard, this
  will allow the token to be bridged to any OZ supported chain in the future.
- It introduces a unique mechanism of penalizing early withdrawals, which is
  controlled by time decay.
- Users can redeem Vara from bVara at anytime, but the earlier the redemption,
  the higher the penalty.
- The contract allows for minting of tokens by contract admin only. So the only
  way to get bVara is by team minting to any address.
- Transfers are only allowed if either the sender or the receiver is
  whitelisted, so any interaction with bVara needs to be whitelisted first by
  the team first.

# Mint

- Only admin can mint tokens, to mint, just call `mint(address, amount)` to mint
  to a given address.
- The contract will mint the tokens to the destination address and update the
  last mint time for the address.
- The user address that received tokens needs to interact with a whitelisted
  contract to be able to use bVara.

# Bribe Interactions

To be able to bribe and claim the bribed bVara, the following steps are
required:

- To use bVara to bribe, you must whitelist the bribe contract, calling
  `setWhitelist(address, bool)` to whitelist the bribe.
- Once whilitested the bribe, admin can bribe and users can claim the
  bribed bVara reward.
- Also, it is important to whitelist the bVara token into the Voter contract
  (`0x4eB2B9768da9Ea26E3aBe605c9040bC12F236a59`).

# Whitelisting

- Whitelisting is required for any contract to be able to interact with bVara.
- If any of `from` or `to` is a whitelisted, the transfer or interaction is
  allowed.
- The contract allows for whitelisting of contracts, to whitelist a contract,
  just call `whitelist(address, bool)` to whitelist a contract or any address.

# Vesting

- The vesting is done by locking the bVara tokens for a given period of time.
- To create a new vest, call `vest(amount)` to lock the given
  amount of bVara tokens for a given period of time.
- The list of vesting of the user will be updated, call `getVestLength
  (address)` to know the list length of vested queue.
- The vesting will be queued for the user, call `getVestInfo(address, vestId)`
  to get the vesting info for a given address and vestId.

# Canceling a Vest

- At anytime, user can call `cancelVest(vestId)` to cancel the vesting for a
  given vestId.
- Once canceled, the vesting will be removed from the queue and the bVara tokens
  will be unlocked.

# Redemption

- To redeem Vara from bVara, just call `redeem(vestID)` to redeem the given
  amount of Vara.
- The `amount` should be any amount that use has as balance in bVara.
- The contract will burn the given amount of bVara from the sender and queue
  the redemption for the sender. A new `vestId` will be added to the user
  list of vesting queue.
- Use: `getVestLength` to know the amount of vest in the queue.
- Use: `getAllVestInfo` to get all vesting info for a given address.
- Use: `getVestInfo` to get vesting info for a given address and vestId.
- Use: `balanceOfVestId` to get the amount of Vara for a given address and
  vestId.

# Penalty Management

- The penalty is calculated based on the time decay, with 90% a maximum
  penalty applied for withdrawals less than an epoch (7 days) and 0% penalty
  for withdrawals after 90 days.
- The contract also provides a methods to compute the penalty redemption for a
  given amount of `bVara` tokens, you can use:
    - `penalty(currentTimestamp, vestStartAt, vestEndAt, amount)`: to know the 
      penalty
      redemption for a given amount of `bVara` tokens. Arguments are:
        - `currentTimestamp`: the current timestamp.
        - `vestStartAt`: when this vest started, used to compute the epoch.
        - `vestEndAt`: the vest end timestamp.
        - `amount`: the amount of `bVara` tokens to calculate the penalty for.
        - The returned value is the penalty redemption for the given amount
          of `bVara` tokens.

# Converting bVARA to veVARA

- To convert bVara to veVara, just call `convertToVe(amount)` to convert the
  given amount of bVara to veVara.
- The `amount` should be any amount that use has as balance in bVara.
- All conversions from bVara to veVARA are a full 4y lock.
- The contract will mint the given amount of veVara to the sender and burn the
  same amount of bVara from the sender.
- Also, a new tokenId or position will be created and sent to the sender, this
  will be used to vote in the governance.

# Adding bVara to an existing veVARA position

> Attention: user must approve the contract to manipulate the tokenId before
> in the veVara contract for the bVara contract to be able to manipulate the
> tokenId.

> Attention: the lock period of tokenId will be pushed to 4y from the current
> timestamp.

- To convert bVara to veVara, just call `addToVe(tokenId, amount)` to 
  add the given amount of bVara to veVara.
- The `tokenId` should be an existing tokenId that the user has.
- The `amount` should be any amount that use has as balance in bVara.
- The token lock period will be pushed to 4y from the current timestamp.
