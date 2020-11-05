pragma solidity ^0.4.17;


contract Migrations {
    address public owner;
    uint256 public last_completed_migration;

    function Migrations() public {
        owner = msg.sender;
    }

    modifier restricted() {
        if (msg.sender == owner) _;
    }

    function setCompleted(uint256 completed) public restricted {
        last_completed_migration = completed;
    }
}
