import "../interfaces/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

interface IUniswapV2Router02 {
    function weth() external returns(address);
    function factory() external returns(address);
    struct route {
        address from;
        address to;
        bool stable;
    }
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        bool stable,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        bool stable,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    )
    external;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    )
    external;

    function addLiquidityETH(
        address token,
        bool stable,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

interface IFactory {
    function allPairsLength() external view returns (uint);
    function isPair(address pair) external view returns (bool);
    function pairCodeHash() external pure returns (bytes32);
    function getPair(address tokenA, address token, bool stable) external view returns (address);
    function createPair(address tokenA, address tokenB, bool stable) external returns (address pair);
}



contract TaxToken2 is IERC20, Ownable {
    string private constant _name = "test contract";
    string private constant _symbol = "test contract";
    uint8 private constant _decimals = 9;

    uint256 private constant _totalSupply = 100000000000000 * 10 ** 9;
    uint256 private constant _maxFee = 4; // Fees can not be set highter than this
    uint256 private _taxFeeOnBuy = 4;
    uint256 private _taxFeeOnSell = 4;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;

    address payable private constant _developmentAddress =
    payable(0xD500617FBc8D20699c2a11043F459dE28Cb31E0d);
    address payable private constant _marketingAddress =
    payable(0xD500617FBc8D20699c2a11043F459dE28Cb31E0d);

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool private inSwap = false;

    uint256 public _maxTxAmount = 2000000000000 * 10 ** 9;
    uint256 public _maxWalletSize = 2000000000000 * 10 ** 9;
    uint256 public _swapTokensAtAmount = 1000000000000 * 10 ** 9; // 0.1%

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() {
        _balances[_msgSender()] = _totalSupply;
        // 0xA7544C409d772944017BB95B99484B6E0d7B6388

        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[_developmentAddress] = true;
        _isExcludedFromFee[_marketingAddress] = true;

        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function initializeRouter( address _router ) external onlyOwner {

        require( address(uniswapV2Router) == address(0), "already initialized");

        uniswapV2Router = IUniswapV2Router02(
            _router
        );

        address factoryAddress = uniswapV2Router.factory();
        address wethAddress = uniswapV2Router.weth();
        IFactory factory = IFactory(factoryAddress);

        uniswapV2Pair = factory.getPair(address(this), wethAddress, false);

        if( uniswapV2Pair == address(0) ){
            uniswapV2Pair = factory.createPair(
                address(this), wethAddress, false
            );
        }

    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
    unchecked {
        _approve(sender, _msgSender(), currentAllowance - amount);
    }
        _transfer(sender, recipient, amount);
        return true;
    }

    // private

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (from != owner() && to != owner()) {
            if (
                to != _marketingAddress &&
                from != _marketingAddress &&
                to != _developmentAddress &&
                from != _developmentAddress
            ) {
                require(amount <= _maxTxAmount, "TOKEN: Max Transaction Limit");
            }

            if (
                to != uniswapV2Pair &&
                to != _marketingAddress &&
                from != _marketingAddress &&
                to != _developmentAddress &&
                from != _developmentAddress
            ) {
                require(
                    balanceOf(to) + amount < _maxWalletSize,
                    "TOKEN: Balance exceeds wallet size!"
                );
            }
            uint256 contractTokenBalance = balanceOf(address(this));

            if (contractTokenBalance >= _maxTxAmount) {
                contractTokenBalance = _maxTxAmount;
            }

            bool canSwap = contractTokenBalance >= _swapTokensAtAmount;

            if (
                canSwap &&
                !inSwap &&
                from != uniswapV2Pair &&
                !_isExcludedFromFee[from] &&
                !_isExcludedFromFee[to]
            ) {
                swapTokensForEth(contractTokenBalance);

                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance > 0) {
                    _marketingAddress.transfer(address(this).balance);
                }
            }
        }

        //Transfer Tokens
        uint256 _taxFee = 0;
        if (
            (_isExcludedFromFee[from] || _isExcludedFromFee[to]) ||
            (from != uniswapV2Pair && to != uniswapV2Pair)
        ) {
            _taxFee = 0;
        } else {
            //Set Fee for Buys
            if (from == uniswapV2Pair && to != address(uniswapV2Router)) {
                _taxFee = _taxFeeOnBuy;
            }

            //Set Fee for Sells
            if (to == uniswapV2Pair && from != address(uniswapV2Router)) {
                _taxFee = _taxFeeOnSell;
            }
        }

        _tokenTransfer(from, to, amount, _taxFee);
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {

        IUniswapV2Router02.route[] memory path = new IUniswapV2Router02.route[](1);
        path[0] = IUniswapV2Router02.route(address(this), address(uniswapV2Router.weth()), false);

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        uint256 tax
    ) private {
        uint256 tTeam = (amount * tax) / 100;
        uint256 tTransferAmount = amount - tTeam;
        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + tTransferAmount;
        if (tTeam > 0) {
            _balances[address(this)] = _balances[address(this)] + tTeam;
            emit Transfer(sender, address(this), tTeam);
        }
        emit Transfer(sender, recipient, tTransferAmount);
    }

    // onlyOwner external

    function setFee(
        uint256 taxFeeOnBuy,
        uint256 taxFeeOnSell
    ) external onlyOwner {
        require(taxFeeOnBuy <= _maxFee, "Fee is too high");
        require(taxFeeOnSell <= _maxFee, "Fee is too high");

        _taxFeeOnBuy = taxFeeOnBuy;
        _taxFeeOnSell = taxFeeOnSell;
    }

    //Set minimum tokens required to swap.
    function setMinSwapTokensThreshold(
        uint256 swapTokensAtAmount
    ) external onlyOwner {
        _swapTokensAtAmount = swapTokensAtAmount;
    }

    function excludeMultipleAccountsFromFees(
        address[] calldata accounts,
        bool excluded
    ) external onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFee[accounts[i]] = excluded;
        }
    }

    receive() external payable {}
}