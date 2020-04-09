pragma solidity ^0.5.0;
import "CoronaToken.sol";


contract TokenInstance {
    CoronaToken private _instance;

    constructor(address _token) public {
        _instance = CoronaToken(_token);
    }

    function balanceOf(address _address) public view returns (uint256) {
        _instance.balanceOf(_address);
    }

    function decreaseBalance(address addr, uint256 amount) public {
        _instance.decreaseBalance(addr, amount);
    }
}
