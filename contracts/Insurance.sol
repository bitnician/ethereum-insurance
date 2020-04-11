pragma solidity ^0.5.0;

import "./Whitelist.sol";
import "./CoronaToken.sol";


contract Insurance is Whitelist {
    struct Registrant {
        string dataHash;
        bool registered;
    }

    struct Claimer {
        uint256 deadLine;
        uint256 vote;
        mapping(address => bool) voters;
    }

    mapping(address => Registrant) public registrants;
    mapping(address => Claimer) public claimers;

    // For example: 1 crn token for registrationFee
    uint256 public registrationFee;
    // Maximum value that we pay claimer
    uint256 public maxPayment;

    CoronaToken _tokenInstance;

    constructor(
        uint256 _registrationFee,
        uint256 _maxPayment,
        address _tokenAddress
    ) public {
        registrationFee = _registrationFee;
        maxPayment = _maxPayment;
        _tokenInstance = CoronaToken(_tokenAddress);
    }

    /**
     * Get the balance Of the specific user
     **/

    function getBalance(address _address) public view returns (uint256) {
        return _tokenInstance.balanceOf(_address);
    }

    /**
     * Users should spend a specific amount of token(registrationFee) to register.
     * Users also should provide some information such as name and identity. their information will store in blockchain as a hash.
     **/

    function register(string memory _dataHash) public payable {
        require(
            getBalance(msg.sender) >= registrationFee,
            "Don not have enough token!"
        );

        require(
            keccak256(abi.encodePacked(_dataHash)) !=
                keccak256(abi.encodePacked("")),
            "Datahash not allowed to be empty"
        );

        Registrant storage registrant = registrants[msg.sender];
        registrant.dataHash = _dataHash;
        registrant.registered = true;

        _tokenInstance.decreaseBalance(msg.sender, registrationFee);
    }

    /**
     * Users can claim for Insurance
     **/
    function claim() public {
        require(
            registrants[msg.sender].registered,
            "You don not have registered yet!"
        );

        Claimer storage claimer = claimers[msg.sender];
        claimer.deadLine = now + 86400;
        claimer.vote = doctorAddresses.length * 100;
    }

    /**
     * Doctors can rate each claim
     **/

    function rate(uint256 _vote, address _claimAddress) public onlyDoctors {
        Claimer storage claimer = claimers[_claimAddress];

        require(now <= claimer.deadLine, "Doctors can vote less than 24H");
        require(!claimer.voters[msg.sender], "Every Doctor can vote once!");

        claimer.vote = claimer.vote - _vote;
        claimer.voters[msg.sender] = true;
    }

    /**
     * The payment amount will be calculated and transfer to a user wallet.
     **/

    function withdraw() public {}
}
