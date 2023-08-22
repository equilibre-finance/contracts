# veClaimAllFees

## Contract Address

`**0x30afc78CC63741eF1C9095963C259c9FD05ec8F1**`

## Overview

The veClaimAllFees contract is designed to allow users to claim all fees from all bribe 
contracts using a single transaction. This contract is used to subsidize the gas fees 
for the users that are in the auto-claim list.

## Implementing claimAllByTokenId in a React Application

Make sure the contract is approved to spend the tokenId's passed as argument, the contract
will check if the user has approved the contract to spend the tokenId's before claiming,
if the contract is not approved, the claim will revert with `NotApproved` event.

Call the claimAllByTokenId function with the tokenId's as argument, the contract will
run until all possible max gas is used, after, you need to check the 
`lastClaimedIndex` view passing the tokenId as argument, it will return the amount
bribes claimed, then you compare with the total amount of bribes in the contract calling
`bribesLength` to know how many bribes are left to claim, if the `lastClaimedIndex` is
equal to the `bribesLength` it means that all bribes were claimed.

## Adding tokenId to the auto-claim backend process

The auto-claim backend process is a script that runs just after epoch pass to claim all
fees from all bribe contracts, to add a tokenId to the auto-claim list, you need to add
the tokenId to the `autoClaimAddresses` list, to add an user, just call the 
`addToAutoClaimAddresses` function passing the user id as argument, after, the user
does not need to call the `claimAllByTokenId` function, the backend will claim for him.

You can know if an user is in the auto-claim list calling the `autoClaimStatus` view
passing the user address as argument, it will return true if the user is in the list.

## API to know the auto-claim user status

To see the progress of the auto-claim process, you can call the following endpoints:
- https://votingescrow.equilibrefinance.com/api/v1/auto-claim/status/0xADDRESS: returns the status of the user in the auto-claim list
- https://votingescrow.equilibrefinance.com/api/v1/auto-claim/token/1: returns the progress of the auto-claim process for tokenId 1.
