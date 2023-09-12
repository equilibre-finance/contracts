# TVL

Contracts:
- PairFactory = 0xA138FAFc30f6Ec6980aAd22656F2F11C38B56a95
- Pair = 0x9bf1E3ee61cBe5C61E520c8BEFf45Ed4D8212a9A

Event names:
- PairFactory.PairCreated: fired when new pair is created.
- Pair.Swap: fired with amount tokens swapped.

Description: 

To get the current TVL: call PairFactory.allPairsLength and then loop on PairFactory.allPairs 
to get all pair addresses. On each pool address call Pair.getReserves to get balance of each token.

To get TVL by events: check event Pair.Transfer to: transfer to address is a deposit, 
transfer from address is a withdraw. Pair.Swap give information about token balance swap.

# Volume

Contracts:
- PairFactory = 0xA138FAFc30f6Ec6980aAd22656F2F11C38B56a95
- Pair = 0x9bf1E3ee61cBe5C61E520c8BEFf45Ed4D8212a9A

Event names:
- PairFactory.PairCreated: fired when new pair is created.
- Pair.Swap: give amount swapped between tokens.

Description:

To get the current TVL: call PairFactory.allPairsLength and then loop on PairFactory.allPairs
to get all pair addresses. On each pool address call Pair.getReserves to get balance of each token.

To get TVL by events: check event Pair.Transfer to: transfer to address is a deposit,
transfer from address is a withdraw. Pair.Swap give information about token balance swap.
