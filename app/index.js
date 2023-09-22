const DEBUG = false;
let CONTRACT, ACCOUNT, web3, provider, ethers;
const CONTRACT_ADDRESS = '0xA5226986E9593F475c568892509CfD71d2746dA4';
const EXPLORER_URL = 'https://explorer.kava.io';

async function init(_ethers) {
    ethers = _ethers;
    if (window.ethereum) {
        await window.ethereum.send('eth_requestAccounts');
        web3 = new Web3(window.ethereum);
        provider = new ethers.BrowserProvider(window.ethereum);
        window.web3 = web3;
        const account = await window.web3.eth.getAccounts();
        ACCOUNT = account[0];
        CONTRACT = new window.web3.eth.Contract(BulkSender_ABI, CONTRACT_ADDRESS);
        $('#sendSameAmountToMany_SubmitHelp').html(`Connected, contract: ${CONTRACT_ADDRESS}`);
        if (DEBUG) debug();
        return true;
    }
    $('#sendSameAmountToMany_SubmitHelp').html("no metamask support");
    return false;
}


function splitAndClean(str, validateAsAddress = true) {
    let arr = str
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('"', '')
        .replaceAll("'", '')
        .split(RegExp(/[^a-zA-Z\d\\.]+/));
    let array = []
    for (let i in arr) {
        if (!arr[i]) continue;
        const address = _.trim(arr[i]);
        if (validateAsAddress && !web3.utils.isAddress(address)) continue;
        if (!validateAsAddress && isNaN(address)) continue;
        array.push(address);
    }
    return array;
}

//
function sendSameAmountToManyInFee(valueInDecimal, addressesText) {
    let addressesArray = splitAndClean(addressesText);
    let valueInWei = web3.utils.toWei(valueInDecimal);
    const total = parseFloat(valueInDecimal) * addressesArray.length;
    const totalInWei = web3.utils.toWei(total.toString());
    try {
        const args = {from: ACCOUNT, value: totalInWei};
        CONTRACT.methods.sendSameAmountToManyInFee(addressesArray, valueInWei).estimateGas(args,
            async function (error, gasAmount) {
                if (error) {
                    alert.html(error.toString());
                } else {
                    const tx = await CONTRACT.methods.sendSameAmountToManyInFee(addressesArray, valueInWei).send(args);
                    $("#sendSameAmountToMany_SubmitHelp").html(tx);
                }
            });
    } catch (e) {
        alert(e.toString());
    }
}

function sendKavaToMany(valuesInDecimal, addressesText, isWei) {
    let addressesArray = splitAndClean(addressesText);
    let valuesArray = splitAndClean(valuesInDecimal);
    let totalInDecimal = 0;
    let valuesInWei = [];
    for (let i in valuesArray) {
        const value = parseFloat(valuesArray[i]);
        totalInDecimal += value;
        if (!isWei) {
            valuesInWei.push(web3.utils.toWei(value.toString()));
        } else {
            valuesInWei.push(value.toString());
        }
    }
    //
    if (addressesArray.length !== valuesArray.length) {
        alert(`Error: addresses=${addressesArray.length}, values=${valuesArray.length}`);
        return;
    }
    const totalInWei = web3.utils.toWei(totalInDecimal.toString());
    try {
        const args = {from: ACCOUNT, value: totalInWei};
        console.log('addressesArray', addressesArray);
        console.log('valuesInWei', valuesInWei);
        console.log('args', args);
        CONTRACT.methods.sendKavaToMany(addressesArray, valuesInWei).estimateGas(args,
            async function (error, gasAmount) {
                if (error) {
                    alert(error.toString());
                } else {
                    const tx = await CONTRACT.methods.sendKavaToMany(addressesArray, valuesInWei).send(args);
                    $("#sendSameAmountToMany_SubmitHelp").html(tx);
                }
            });
    } catch (e) {
        alert(e.toString());
    }
}

async function sendSameAmountToMany_Status() {
    const token = $('#sendSameAmountToMany_Token').val();
    const amount = parseFloat($('#sendSameAmountToMany_Amount').val());
    const addresses = $('#sendSameAmountToMany_List').val();
    const addressesArray = splitAndClean(addresses);

    // Vara: 0xE1da44C0dA55B075aE8E2e4b6986AdC76Ac77d73 (18)
    // cpVara: 0xFa4384b298084A0ef13F378853DEDbB33A857B31 (9)
    // Tiger: 0x471F79616569343e8e84a66F342B7B433b958154 (18)
    // USDC: 0xfA9343C3897324496A05fC75abeD6bAC29f8A40f (6)
    if (!token) {
        return red('#sendSameAmountToMany_TokenHelp', 'token is required');
        // check if token address is valid ethereum address:
    } else if (!web3.utils.isAddress(token)) {
        return red('#sendSameAmountToMany_TokenHelp', 'token address is invalid');
    }
    // create instance of the token contract:
    const tokenContract = new window.web3.eth.Contract(ERC20_ABI, token);
    // get token decimals and symbol:
    const decimals = parseInt((await tokenContract.methods.decimals().call()).toString());
    const symbol = await tokenContract.methods.symbol().call();
    const balance = (await tokenContract.methods.balanceOf(ACCOUNT).call()).toString();
    const balanceInDecimal = parseFloat(ethers.formatUnits(balance, decimals)).toFixed(2);
    const tokenInfo = `Symbol: ${symbol}, decimals: ${decimals}, balance: ${balanceInDecimal} ${symbol}`;
    green('#sendSameAmountToMany_TokenHelp', tokenInfo);

    // check if list of addresses is valid:

    if (!addressesArray || addressesArray.length === 0) {
        return red('#sendSameAmountToMany_ListHelp', 'addresses is required');
    }
    // loop on addresses and check if they are valid ethereum addresses:
    let addressesFound = [];
    for (let i in addressesArray) {
        const address = addressesArray[i];
        if (!web3.utils.isAddress(address)) {
            return red('#sendSameAmountToMany_ListHelp', `address ${address} at position ${i} is invalid`);
        }
        if (addressesFound.includes(address)) {
            return red('#sendSameAmountToMany_ListHelp', `address ${address} at position ${i} is duplicated`);
        }
        addressesFound.push(address);
    }
    green('#sendSameAmountToMany_ListHelp', `addresses ok: ${addressesArray.length} addresses`);

    // check if amount is a valid decimal:
    if (!amount) {
        return red('#sendSameAmountToMany_AmountHelp', 'amount is required');
    } else if (isNaN(amount)) {
        return red('#sendSameAmountToMany_AmountHelp', 'amount is not a number');
    } else if (parseFloat(amount) <= 0) {
        return red('#sendSameAmountToMany_AmountHelp', 'amount must be greater than zero');
    } else if (parseFloat(amount) > parseFloat(balanceInDecimal)) {
        return red('#sendSameAmountToMany_AmountHelp', 'amount is greater than balance');
    } else {
        green('#sendSameAmountToMany_AmountHelp', 'amount ok.');
    }

    // calculate amount for all addresses:
    const total = amount * addressesArray.length;
    // check if user has sufficient balance:
    if (total > parseFloat(balanceInDecimal)) {
        const totalInfo = parseFloat(total).toFixed(2);
        const balanceInfo = parseFloat(balanceInDecimal).toFixed(2);
        const missing = parseFloat(total - parseFloat(balanceInDecimal)).toFixed(2);
        const info = `You need ${totalInfo} ${symbol} but you only have ${balanceInfo} ${symbol}, add more ${missing} ${symbol} to your account`;
        const amountPerUser = parseFloat(balanceInDecimal / addressesArray.length).toFixed(2);
        const extraInfo = `Or you need to reduce the amount to lower than ${amountPerUser} ${symbol} per user.`;
        return red('#sendSameAmountToMany_AmountHelp', `${info}. <br/>${extraInfo}`);
    } else {
        green('#sendSameAmountToMany_AmountHelp', `You have sufficient balance for ${total} ${symbol}`);
    }

    // check approval:
    const allowance = (await tokenContract.methods.allowance(ACCOUNT, CONTRACT_ADDRESS).call()).toString();
    const allowanceInDecimal = parseFloat(ethers.formatUnits(allowance, decimals)).toFixed(2);
    $('#sendSameAmountToMany_ApproveBtn').css('display', 'none');
    if (parseFloat(allowanceInDecimal) < parseFloat(total)) {
        $('#sendSameAmountToMany_ApproveBtn').css('display', 'block');
        const str = `You need to approve ${total} ${symbol} for this contract`;
        const html = `<div class="alert alert-danger small" role="alert">${str}</div>`;
        return html;
    }

    return true;
}

async function sendSameAmountToMany_Approve() {
    const token = $('#sendSameAmountToMany_Token').val();
    const tokenContract = new window.web3.eth.Contract(ERC20_ABI, token);
    const symbol = await tokenContract.methods.symbol().call();
    const amountPerUser = parseFloat($('#sendSameAmountToMany_Amount').val());
    const decimals = parseInt((await tokenContract.methods.decimals().call()).toString());
    const addressesArray = splitAndClean($('#sendSameAmountToMany_List').val());
    const totalInDecimal = amountPerUser * addressesArray.length;
    const total = ethers.parseUnits(totalInDecimal.toString(), decimals);
    blue('#sendSameAmountToMany_SubmitHelp', 'Approving...');
    const tx = await tokenContract.methods.approve(CONTRACT_ADDRESS, total).send({from: ACCOUNT});
    const txUrl = `<a href="${EXPLORER_URL}/tx/${tx.transactionHash}" target="_blank">View transaction</a>`;
    const approvedInfo = `Approved ${totalInDecimal} ${symbol} for ${addressesArray.length} addresses. ${txUrl}`;
    green('#sendSameAmountToMany_SubmitHelp', approvedInfo);
}

async function sendSameAmountToMany_Run() {
    yellow('#sendSameAmountToMany_SubmitHelp', 'Check your input data...');
    const status = await sendSameAmountToMany_Status();
    if (status !== true) {
        $('#sendSameAmountToMany_SubmitHelp').html(status);
    } else {
        yellow('#sendSameAmountToMany_SubmitHelp', 'Sending...');
        try {
            const token = $('#sendSameAmountToMany_Token').val();
            const tokenContract = new window.web3.eth.Contract(ERC20_ABI, token);
            const symbol = await tokenContract.methods.symbol().call();
            const amountPerUser = parseFloat($('#sendSameAmountToMany_Amount').val());
            const decimals = parseInt((await tokenContract.methods.decimals().call()).toString());
            const addressesArray = splitAndClean($('#sendSameAmountToMany_List').val());
            const totalInDecimal = amountPerUser * addressesArray.length;
            const total = ethers.parseUnits(amountPerUser.toString(), decimals);
            const tx = await CONTRACT.methods.sendSameAmountToMany(token, addressesArray, total).send({from: ACCOUNT});
            const txUrl = `<a href="${EXPLORER_URL}/tx/${tx.transactionHash}" target="_blank">View transaction</a>`;
            const sendInfo = `Sent ${totalInDecimal} ${symbol} to ${addressesArray.length} addresses. ${txUrl}`;
            green('#sendSameAmountToMany_SubmitHelp', sendInfo);
        } catch (e) {
            red('#sendSameAmountToMany_SubmitHelp', e.message);
        }
    }
}


async function sendManyAmountToMany_Status() {
    const token = $('#sendManyAmountToMany_Token').val();
    const amounts = $('#sendManyAmountToMany_Amount').val();
    const amountsArray = splitAndClean(amounts, false);
    const addresses = $('#sendManyAmountToMany_List').val();
    const addressesArray = splitAndClean(addresses);
    if (!token) {
        return red('#sendManyAmountToMany_TokenHelp', 'token is required');
        // check if token address is valid ethereum address:
    } else if (!web3.utils.isAddress(token)) {
        return red('#sendManyAmountToMany_TokenHelp', 'token address is invalid');
    }
    // create instance of the token contract:
    const tokenContract = new window.web3.eth.Contract(ERC20_ABI, token);
    // get token decimals and symbol:
    const decimals = parseInt((await tokenContract.methods.decimals().call()).toString());
    const symbol = await tokenContract.methods.symbol().call();
    const balance = (await tokenContract.methods.balanceOf(ACCOUNT).call()).toString();
    const balanceInDecimal = parseFloat(ethers.formatUnits(balance, decimals)).toFixed(2);
    const tokenInfo = `Symbol: ${symbol}, decimals: ${decimals}, balance: ${balanceInDecimal} ${symbol}`;
    green('#sendManyAmountToMany_TokenHelp', tokenInfo);

    // check if amount is a valid decimal:
    if (!amountsArray || amountsArray.length === 0) {
        return red('#sendManyAmountToMany_AmountHelp', 'amounts are required');
    }

    // check if a list of addresses is valid:
    if (!addressesArray || addressesArray.length === 0) {
        return red('#sendManyAmountToMany_ListHelp', 'addresses is required');
    }

    // addresses and amounts must have the same length:
    if (addressesArray.length !== amountsArray.length) {
        const str = `addresses and amounts must have the same length: ${addressesArray.length} addresses, ${amountsArray.length} amounts`;
        red('#sendManyAmountToMany_ListHelp', str);
        return red('#sendManyAmountToMany_AmountHelp', str);
    }

    // loop on amounts and check if they are valid decimals:
    let totalAmount = 0, totalInWei = BigInt(0);
    for (let i in amountsArray) {
        const amount = parseFloat(parseFloat(amountsArray[i]).toFixed(18).toString());
        if (isNaN(amount)) {
            return red('#sendManyAmountToMany_AmountHelp', `amount ${amount} at position ${i} is not a number`);
        }
        if (amount <= 0) {
            return red('#sendManyAmountToMany_AmountHelp', `amount ${amount} at position ${i} is not positive`);
        }
        totalAmount += amount;
        try {
            const amount = parseFloat(amountsArray[i]).toFixed(18).toString();
            totalInWei += BigInt(ethers.parseUnits(amount, decimals).toString());
        } catch (e) {
            console.log(e);
            return red('#sendManyAmountToMany_AmountHelp', `amount ${amount} at position ${i} is not a valid decimal, decimals is ${decimals}.`);
        }
    }
    // loop on addresses and check if they are valid ethereum addresses:
    let addressesFound = [];
    for (let i in addressesArray) {
        const address = addressesArray[i];
        if (!web3.utils.isAddress(address)) {
            return red('#sendManyAmountToMany_ListHelp', `address ${address} at position ${i} is invalid`);
        }
        if (addressesFound.includes(address)) {
            return red('#sendManyAmountToMany_ListHelp', `address ${address} at position ${i} is duplicated`);
        }
        addressesFound.push(address);
    }
    green('#sendManyAmountToMany_ListHelp', `addresses ok: ${addressesArray.length} addresses`);

    // check if amount is a valid decimal:
    if (!totalAmount) {
        return red('#sendManyAmountToMany_AmountHelp', 'total amount is required');
    } else if (isNaN(totalAmount)) {
        return red('#sendManyAmountToMany_AmountHelp', 'total amount is not a number');
    } else if (parseFloat(totalAmount) <= 0) {
        return red('#sendManyAmountToMany_AmountHelp', 'amount must be greater than zero');
    } else if (parseFloat(totalAmount) > parseFloat(balanceInDecimal)) {
        return red('#sendManyAmountToMany_AmountHelp', 'total amount is greater than balance');
    } else {
        green('#sendManyAmountToMany_AmountHelp', 'total amount ok.');
    }

    // check if user has sufficient balance:
    if (totalAmount > parseFloat(balanceInDecimal)) {
        const totalInfo = parseFloat(totalAmount).toFixed(2);
        const balanceInfo = parseFloat(balanceInDecimal).toFixed(2);
        const missing = parseFloat(totalAmount - parseFloat(balanceInDecimal)).toFixed(2);
        const info = `You need ${totalInfo} ${symbol} but you only have ${balanceInfo} ${symbol}, add more ${missing} ${symbol} to your account`;
        const amountPerUser = parseFloat(balanceInDecimal / addressesArray.length).toFixed(2);
        const extraInfo = `Or you need to reduce the amount to lower than ${amountPerUser} ${symbol} per user.`;
        return red('#sendManyAmountToMany_AmountHelp', `${info}. <br/>${extraInfo}`);
    } else {
        green('#sendManyAmountToMany_AmountHelp', `You have sufficient balance for ${totalAmount} ${symbol}`);
    }

    // check approval:
    const allowanceInWei = BigInt((await tokenContract.methods.allowance(ACCOUNT, CONTRACT_ADDRESS).call()).toString());


    $('#sendManyAmountToMany_ApproveBtn').css('display', 'none');
    if (allowanceInWei < totalInWei) {
        $('#sendManyAmountToMany_ApproveBtn').css('display', 'block');
        const str = `You need to approve ${totalAmount} ${symbol} for this contract`;
        return `<div class="alert alert-danger small" role="alert">${str}</div>`;
    }

    return true;
}

async function sendManyAmountToMany_Approve() {
    const token = $('#sendManyAmountToMany_Token').val();
    const tokenContract = new window.web3.eth.Contract(ERC20_ABI, token);
    const symbol = await tokenContract.methods.symbol().call();
    const decimals = parseInt((await tokenContract.methods.decimals().call()).toString());
    const addressesArray = splitAndClean($('#sendManyAmountToMany_List').val());
    const amountsArray = splitAndClean($('#sendManyAmountToMany_Amount').val(), false);
    let totalInDecimal = 0, totalInWei = BigInt(0);
    for (let i in amountsArray) {
        const amount = parseFloat(amountsArray[i]).toFixed(18).toString();
        totalInDecimal += parseFloat(amount);
        totalInWei += BigInt(ethers.parseUnits(amount, decimals).toString());
    }

    blue('#sendManyAmountToMany_SubmitHelp', 'Approving...');
    const tx = await tokenContract.methods.approve(CONTRACT_ADDRESS, totalInWei).send({from: ACCOUNT});
    const txUrl = `<a href="${EXPLORER_URL}/tx/${tx.transactionHash}" target="_blank">View transaction</a>`;
    const approvedInfo = `Approved ${totalInDecimal} ${symbol} for ${addressesArray.length} addresses. ${txUrl}`;
    green('#sendManyAmountToMany_SubmitHelp', approvedInfo);
}

function red(id, str) {
    return message(id, str, 'danger');
}

function green(id, str) {
    return message(id, str, 'success');
}

function blue(id, str) {
    return message(id, str, 'primary');
}

function yellow(id, str) {
    return message(id, str, 'warning');
}

function message(id, str, type) {
    if (!id) new Error('id is required');
    if (!type) type = 'primary';
    console.log(str);
    const html = `<div class="alert alert-${type} small" role="alert">${str}</div>`;
    $(id).html(html);
    return html;
}

function debug() {
    // show accordion tab collapseTwo:
    $('#collapseOne').addClass('hide');
    $('#collapseOne').removeClass('show');
    $('#collapseTwo').addClass('show');
    sendManyAmountToMany_Approve();
    const token = '0x471F79616569343e8e84a66F342B7B433b958154';
    const addresses = '[0x395ef2d7a5d499b62ac479064b7eaa51ae823a22,0x2aed58b953fd1bc8f7c0c50ae4af2c2eeb0bb9b2,0x3d6991085ab1ae3926cb96f25684c40a364b6856,0x498dd5a79ab7e19be1da81738239214f807e3462,0x46f4f8b8fb7a454ba996f0ce396b32400f5193af,0xb46141deefe1b01f2a33236ba35fa9ed2ae6993f,0x82e8936b187d83fd6eb2b7dab5b19556e9deff1c,0xcfccc57dddc110c806a7c005c197646210e529ac,0xab0f2100299f39ce1fb4253fc89241baba9826e3,0x52aac9e83a3793f327942ac6541c7161cec14360,0xb3a30ceb000e91d60ba23a732cd143a0b91f2c27,0xb6f910509a1f665b9178dec64095ddfc5ad2cede,0x2de0c1df3736d51ac96a806521b171e3dd08f246,0xd8b584268def53179a055762199dfcf25111a2cc]';
    const values = '[0.00006895766230381033,0.0004609812096759444,0.009219624193518888,40.335971091947556,4.893646961562623,4.5762757137555194,21.29175341560381,6.057177849839491,3.3520248661586303,0.022703324576540267,0.598468855461795,61.716049106113026,19.03575807235845,6.110421179557063]';
    $('#sendManyAmountToMany_Token').val(token);
    $('#sendManyAmountToMany_List').val(addresses);
    $('#sendManyAmountToMany_Amount').val(values);
}

async function sendManyAmountToMany_Run() {
    yellow('#sendManyAmountToMany_SubmitHelp', 'Checking your input data...');
    const status = await sendManyAmountToMany_Status();
    if (status !== true) {
        $('#sendManyAmountToMany_SubmitHelp').html(status);
    } else {
        yellow('#sendManyAmountToMany_SubmitHelp', 'Sending...');
        try {
            const token = $('#sendManyAmountToMany_Token').val();
            const tokenContract = new window.web3.eth.Contract(ERC20_ABI, token);
            const symbol = await tokenContract.methods.symbol().call();
            let amountsArray = splitAndClean($('#sendManyAmountToMany_Amount').val(), false);
            const totalInDecimal = amountsArray.reduce((a, b) => parseFloat(a) + parseFloat(b), 0);
            const decimals = parseInt((await tokenContract.methods.decimals().call()).toString());
            // convert decimals to wei:
            for (let i in amountsArray) {
                const amount = parseFloat(amountsArray[i]).toFixed(18).toString();
                amountsArray[i] = ethers.parseUnits(amount, decimals);
            }
            const addressesArray = splitAndClean($('#sendManyAmountToMany_List').val());
            try {
                const tx = await CONTRACT.methods.sendTokensToMany(token, addressesArray, amountsArray).send({from: ACCOUNT});
                const txUrl = `<a href="${EXPLORER_URL}/tx/${tx.transactionHash}" target="_blank">View transaction</a>`;
                const sendInfo = `Sent ${totalInDecimal} ${symbol} to ${addressesArray.length} addresses. ${txUrl}`;
                green('#sendManyAmountToMany_SubmitHelp', sendInfo);
            } catch (e) {
                red('#sendManyAmountToMany_SubmitHelp', e.message);
            }
        } catch (e) {
            red('#sendManyAmountToMany_SubmitHelp', e.message);
        }
    }
}