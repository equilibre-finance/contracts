# bVara token

## Contract Address

- [bVara](contracts/bVara.sol) [`0x20f29Ba234d84664D2B382DB6803b6b334BFC43d`](https://kavascan.com/address/0x20f29Ba234d84664D2B382DB6803b6b334BFC43d/contracts#address-tabs)

## Overview

- The `bVara` contract is an implementation of the OFTV2 token standard, this will allow the token to be bridged to any OZ supported chain in the future.
- It introduces a unique mechanism of penalizing early withdrawals, which is controlled by time decay.
- Users can redeem Vara from bVara at anytime, but the earlier the redemption, the higher the penalty. 
- The contract allows for minting and burning of tokens by contract admin only. So the only way to get bVara is by team minting to any address.
- Transfers are only allowed if either the sender or the receiver is whitelisted, so any interaction with bVara needs to be whitelisted first by the team first.

# Mint

- Only admin can mint tokens, to mint, just call `mint(address, amount)` to mint to a given address.
- The contract will mint the tokens to the destination address and update the last mint time for the address.
- The user address that received tokens needs to interact with a whitelisted contract to be able to use bVara. 

# Whitelisting

- Whitelisting is required for any contract to be able to interact with bVara.
- If any of `from` or `to` is a whitelisted, the transfer or interaction is allowed.
- The contract allows for whitelisting of contracts, to whitelist a contract, just call `whitelist(address, bool)` to whitelist a contract or any address.

# Redemption

- To redeem Vara from bVara, just call `redeem(amount)` to redeem the given amount of Vara.
- The contract will calculate the penalty redemption and send the amount of Vara to the sender.
- The contract will also burn the amount of bVara from the sender.

# Penalty Management

- The penalty is calculated based on the time decay, with 90% a maximum penalty applied for withdrawals within a day and 0% penalty for withdrawals after 90 days.
- The contract also provides a methods to compute the penalty redemption for a given amount of `bVara` tokens, you can use:
  - `lastMint(address)` to know the last mint time for a given address, use this to subtract from the current time to get the number of seconds of a deposit. 
  - `penalty(seconds)`: to know the penalty percentage for a given amount of time in seconds.
  - `computePenaltyRedemption(address, amount)`: to know the penalty redemption for a given amount of `bVara` tokens. This will return the amount of VARA user will receive after penalty redemption.

# Burning

- To burn bVara tokens, just call `burn(fromAddress, amount)` to burn the given amount of bVara.
- Only admin can burn tokens, also, the admin can burn tokens from any address.

# Converting bVARA to veVARA

- To convert bVara to veVara, just call `convertToVe(amount)` to convert the given amount of bVara to veVara.
- The `amount` should be any amount that use has as balance in bVara.
- All conversions from bVara to veVARA are a full 4y lock.
- The contract will mint the given amount of veVara to the sender and burn the same amount of bVara from the sender.
- Also, a new tokenId or position will be created and sent to the sender, this will be used to vote in the governance.