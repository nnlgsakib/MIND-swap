// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

contract ReentrancyGuard {
    bool private locked;
    
    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }
}

contract MPTToken {
    string public name = "MIND PAIR TOKEN";
    string public symbol = "MPT";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) private balances;
    mapping(address => bool) private isMinter;

    constructor() {
        isMinter[msg.sender] = true; // Contract owner is a minter
    }

    modifier onlyMinter() {
        require(isMinter[msg.sender], "Not authorized to mint or burn");
        _;
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function mint(address account, uint256 amount) external onlyMinter {
        require(account != address(0), "Cannot mint to zero address");
        totalSupply += amount;
        balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function burn(address account, uint256 amount) external onlyMinter {
        require(account != address(0), "Cannot burn from zero address");
        require(balances[account] >= amount, "Burn amount exceeds balance");
        totalSupply -= amount;
        balances[account] -= amount;
        emit Transfer(account, address(0), amount);
    }

    function setMinter(address account, bool status) external onlyMinter {
        isMinter[account] = status;
    }

    event Transfer(address indexed from, address indexed to, uint256 value);
}

contract FixedRateSwap is ReentrancyGuard {
    IERC20 public usdt;
    IERC20 public erc20;
    MPTToken public mpt;

    uint256 public ethToUsdtRate = 5;  // 1 ETH = 5 USDT
    uint256 public ethToErc20Rate = 3; // 1 ETH = 3 ERC20
    uint256 public usdtToErc20Rate = 3; // 1 USDT = 3 ERC20

    address public owner;

    struct LiquidityProvider {
        uint256 ethAmount;
        uint256 usdtAmount;
        uint256 erc20Amount;
    }

    mapping(address => LiquidityProvider) public liquidityProviders;

    constructor(address _usdtAddress, address _erc20Address) {
        usdt = IERC20(_usdtAddress);
        erc20 = IERC20(_erc20Address);
        mpt = new MPTToken();
        mpt.setMinter(address(this), true);
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyLiquidityProvider() {
        require(mpt.balanceOf(msg.sender) > 0, "Not a liquidity provider");
        _;
    }

    // Swap ETH to USDT
    function swapEthToUsdt() external payable nonReentrant {
        uint256 usdtAmount = msg.value * ethToUsdtRate;
        require(usdt.balanceOf(address(this)) >= usdtAmount, "Not enough USDT in contract");
        usdt.transfer(msg.sender, usdtAmount);
    }

    // Swap USDT to ETH
    function swapUsdtToEth(uint256 usdtAmount) external nonReentrant {
        uint256 ethAmount = usdtAmount / ethToUsdtRate;
        require(address(this).balance >= ethAmount, "Not enough ETH in contract");
        usdt.transferFrom(msg.sender, address(this), usdtAmount);
        payable(msg.sender).transfer(ethAmount);
    }

    // Swap ETH to ERC20
    function swapEthToErc20() external payable nonReentrant {
        uint256 erc20Amount = msg.value * ethToErc20Rate;
        require(erc20.balanceOf(address(this)) >= erc20Amount, "Not enough ERC20 in contract");
        erc20.transfer(msg.sender, erc20Amount);
    }

    // Swap ERC20 to ETH
    function swapErc20ToEth(uint256 erc20Amount) external nonReentrant {
        uint256 ethAmount = erc20Amount / ethToErc20Rate;
        require(address(this).balance >= ethAmount, "Not enough ETH in contract");
        erc20.transferFrom(msg.sender, address(this), erc20Amount);
        payable(msg.sender).transfer(ethAmount);
    }

    // Swap USDT to ERC20
    function swapUsdtToErc20(uint256 usdtAmount) external nonReentrant {
        uint256 erc20Amount = usdtAmount * usdtToErc20Rate;
        require(erc20.balanceOf(address(this)) >= erc20Amount, "Not enough ERC20 in contract");
        usdt.transferFrom(msg.sender, address(this), usdtAmount);
        erc20.transfer(msg.sender, erc20Amount);
    }

    // Swap ERC20 to USDT
    function swapErc20ToUsdt(uint256 erc20Amount) external nonReentrant {
        uint256 usdtAmount = erc20Amount / usdtToErc20Rate;
        require(usdt.balanceOf(address(this)) >= usdtAmount, "Not enough USDT in contract");
        erc20.transferFrom(msg.sender, address(this), erc20Amount);
        usdt.transfer(msg.sender, usdtAmount);
    }

    // Calculator functions
    function calculateEthToUsdt(uint256 ethAmount) external view returns (uint256) {
        return ethAmount * ethToUsdtRate;
    }

    function calculateUsdtToEth(uint256 usdtAmount) external view returns (uint256) {
        return usdtAmount / ethToUsdtRate;
    }

    function calculateEthToErc20(uint256 ethAmount) external view returns (uint256) {
        return ethAmount * ethToErc20Rate;
    }

    function calculateErc20ToEth(uint256 erc20Amount) external view returns (uint256) {
        return erc20Amount / ethToErc20Rate;
    }

    function calculateUsdtToErc20(uint256 usdtAmount) external view returns (uint256) {
        return usdtAmount * usdtToErc20Rate;
    }

    function calculateErc20ToUsdt(uint256 erc20Amount) external view returns (uint256) {
        return erc20Amount / usdtToErc20Rate;
    }

    // Add liquidity functions
    function addLiquidityEth() external payable nonReentrant {
        liquidityProviders[msg.sender].ethAmount += msg.value;
        mpt.mint(msg.sender, msg.value);
    }

    function addLiquidityUsdt(uint256 usdtAmount) external nonReentrant {
        usdt.transferFrom(msg.sender, address(this), usdtAmount);
        liquidityProviders[msg.sender].usdtAmount += usdtAmount;
        mpt.mint(msg.sender, usdtAmount);
    }

    function addLiquidityErc20(uint256 erc20Amount) external nonReentrant {
        erc20.transferFrom(msg.sender, address(this), erc20Amount);
        liquidityProviders[msg.sender].erc20Amount += erc20Amount;
        mpt.mint(msg.sender, erc20Amount);
    }

    // Remove liquidity functions
    function removeLiquidityEth(uint256 amount) external onlyLiquidityProvider nonReentrant {
        require(liquidityProviders[msg.sender].ethAmount >= amount, "Not enough ETH liquidity provided");
        liquidityProviders[msg.sender].ethAmount -= amount;
        mpt.burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }

    function removeLiquidityUsdt(uint256 amount) external onlyLiquidityProvider nonReentrant {
        require(liquidityProviders[msg.sender].usdtAmount >= amount, "Not enough USDT liquidity provided");
        liquidityProviders[msg.sender].usdtAmount -= amount;
        mpt.burn(msg.sender, amount);
        usdt.transfer(msg.sender, amount);
    }

    function removeLiquidityErc20(uint256 amount) external onlyLiquidityProvider nonReentrant {
        require(liquidityProviders[msg.sender].erc20Amount >= amount, "Not enough ERC20 liquidity provided");
        liquidityProviders[msg.sender].erc20Amount -= amount;
        mpt.burn(msg.sender, amount);
        erc20.transfer(msg.sender, amount);
    }

    // Allow contract to receive ETH
    receive() external payable {}


    // Function to withdraw ETH from the contract
    function withdrawEth(uint256 amount) external onlyOwner nonReentrant {
        require(address(this).balance >= amount, "Not enough ETH in contract");
        payable(msg.sender).transfer(amount);
    }

    // Function to withdraw USDT from the contract
    function withdrawUsdt(uint256 amount) external onlyOwner nonReentrant {
        require(usdt.balanceOf(address(this)) >= amount, "Not enough USDT in contract");
        usdt.transfer(msg.sender, amount);
    }

    // Function to withdraw ERC20 from the contract
    function withdrawErc20(uint256 amount) external onlyOwner nonReentrant {
        require(erc20.balanceOf(address(this)) >= amount, "Not enough ERC20 in contract");
        erc20.transfer(msg.sender, amount);
    }
}

