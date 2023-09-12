# claim

## Contract Address

- [claim](contracts/ClaimAllImplementation.sol) [`0x9f80f639Ff87BE7299Eec54a08dB20dB3b3a4171`](https://kavascan.com/address/0x9f80f639Ff87BE7299Eec54a08dB20dB3b3a4171/contracts#address-tabs)

## Overview

The `claim` contract is designed to:

- allow users to claim all fees from all bribe contracts using a single transaction. 
- claim all rewards from reabase from all tokenId's using a single transaction.

Also, the contract can be used to subsidize the gas fees for the users that are in the auto-claim list.

## Implementing claimFees in a React Application

Function ABI signature:

```
function claimFees(address[] memory _fees, address[][] memory _tokens, uint _tokenId)
```

- **approve the `claim` contract**: the user needs to approve the `claim` 
  contract to process the fees from the bribe contracts, it betters to call 
  `setApprovalForAll` from `VotingEscrow` contract, because the user can claim 
  all tokenIds in a single transaction via `claimAllByTokenId` function.
- **build list of bribes with rewards**:
  - get a list of all pools available in the `PairFactory` contract calling the `allPairsLength` function.
  - get a list of all gauges by pools calling the `gauges` function in `Voter` contract.
  - get a list of all bribes by gauges calling the `internal_bribe` and 
    `external_bribe` functions in each `Gauge` contract, if the gauge address is different from 0x0.
  - now, on each bribe, call `earned` to know if there is a any reward for 
    this user on this bribe.
  - if there is a reward, add the bribe address to the list of bribes and the 
    token address to the list of tokens.
  - now you can call claimFees function passing the list of bribes and 
    tokens by this tokenId.
    

## Implementing claimRewards in a React Application

Function ABI signature:

```
function claimRewards(address _address)
```

This function you to claim all rewards of each tokenId from rebase.

As this function auto adds all claimed rewards to each token id, it does not 
need approval, just call the function passing the user address as argument.

## Adding tokenId to the auto-claim backend process

The auto-claim backend process is a script that runs just after epoch pass to claim all
fees from all bribe contracts, to add a tokenId to the auto-claim list, you need to add
the tokenId to the `autoClaimAddresses` list, to add an user, just call the 
`addToAutoClaimAddresses` function passing the user id as argument, after, the user
does not need to call the `claimAllByTokenId` function, the backend will claim for him.

You can know if a user is in the auto-claim list calling the `autoClaimStatus` view
passing the user address as argument, it will return true if the user is in the list.

## API to know the auto-claim user status

Attention: not implemented yet.

To see the progress of the auto-claim process, you can call the following endpoints:
- https://votingescrow.equilibrefinance.com/api/v1/auto-claim/status/0xADDRESS: returns the status of the user in the auto-claim list
- https://votingescrow.equilibrefinance.com/api/v1/auto-claim/token/1: returns the progress of the auto-claim process for tokenId 1.

