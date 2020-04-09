pragma solidity 0.5.11;


contract ERC20Token {
    mapping(address => uint256) private _balances;

    string public name;
    string public symbol;
    uint8 public decimals;
    address payable public wallet;
    address owner;

    uint256 public totalSupply;
    uint256 public tokenPerEther;

    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(string memory _name, string memory _symbol, uint8 _decimals)
        public
    {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;
    }

    function setWallet(address payable _address) public {
        wallet = _address;
    }

    function setTotalSupply(uint256 _totalSupply) public {
        totalSupply = _totalSupply;
    }

    function setTokenPerEther(uint256 _tokenPerEther) public {
        tokenPerEther = _tokenPerEther;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function decreaseBalance(address _address, uint256 amount) public {
        _balances[_address] -= amount;
    }

    function increaseBalance(address _address, uint256 amount) public {
        _balances[_address] += amount;
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        require(recipient != address(0), "transfer to the zero address");

        decreaseBalance(msg.sender, amount);
        increaseBalance(recipient, amount);

        emit Transfer(msg.sender, recipient, amount);
    }

    function convertFromEther(uint256 value) public view returns (uint256) {
        return (value * tokenPerEther) / 1 ether;
    }

    function buyToken() public payable {
        require(msg.value != 0, "invalid amount of invest!");
        require(totalSupply > 0);

        wallet.transfer(msg.value);

        uint256 tokens = convertFromEther(msg.value);

        totalSupply -= tokens;

        increaseBalance(msg.sender, tokens);

        emit Transfer(address(0), msg.sender, tokens);
    }
}
