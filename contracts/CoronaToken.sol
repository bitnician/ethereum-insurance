pragma solidity 0.5.11;
import "ERC20Token.sol";


contract CoronaToken is ERC20Token {
    constructor() public ERC20Token("Corona Token", "CRN", 0) {
        setTotalSupply(1000);
        setTokenPerEther(1000000);
        setWallet(msg.sender);
    }
}
