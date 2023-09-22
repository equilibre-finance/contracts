const BulkSender_ABI = [
    {
        "inputs": [],
        "name": "FailedToSendValue",
        "type": "error"
    },
    {
        "inputs": [],
        "name": "InvalidAmount",
        "type": "error"
    },
    {
        "inputs": [],
        "name": "InvalidRecipient",
        "type": "error"
    },
    {
        "inputs": [],
        "name": "InvalidRecipients",
        "type": "error"
    },
    {
        "inputs": [],
        "name": "InvalidToken",
        "type": "error"
    },
    {
        "inputs": [],
        "name": "NotEnoughApproval",
        "type": "error"
    },
    {
        "inputs": [],
        "name": "NotEnoughBalance",
        "type": "error"
    },
    {
        "inputs": [
            {
                "internalType": "address[]",
                "name": "recipients",
                "type": "address[]"
            },
            {
                "internalType": "uint256[]",
                "name": "amount",
                "type": "uint256[]"
            }
        ],
        "name": "sendKavaToMany",
        "outputs": [],
        "stateMutability": "payable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "contract IERC20",
                "name": "token",
                "type": "address"
            },
            {
                "internalType": "address[]",
                "name": "recipients",
                "type": "address[]"
            },
            {
                "internalType": "uint256",
                "name": "amount",
                "type": "uint256"
            }
        ],
        "name": "sendSameAmountToMany",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address[]",
                "name": "recipients",
                "type": "address[]"
            },
            {
                "internalType": "uint256",
                "name": "amount",
                "type": "uint256"
            }
        ],
        "name": "sendSameAmountToManyInFee",
        "outputs": [],
        "stateMutability": "payable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "contract IERC20",
                "name": "token",
                "type": "address"
            },
            {
                "internalType": "address[]",
                "name": "recipients",
                "type": "address[]"
            },
            {
                "internalType": "uint256[]",
                "name": "amount",
                "type": "uint256[]"
            }
        ],
        "name": "sendTokensToMany",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]