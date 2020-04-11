pragma solidity ^0.5.0;

import "./ERC20Token.sol";


contract CoronaToken is ERC20Token {
    constructor() public ERC20Token("Corona Token", "CRN", 0) {
        setTokenPerEther(10);
        setWallet(msg.sender);
    }
}
