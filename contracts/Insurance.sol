pragma solidity 0.5.11;

import "Whitelist.sol";
import "Transfer.sol";


contract Insurance is Whitelist, Transfer {
    struct Registrant {
        string dataHash;
        bool registered;
    }

    struct Claimer {
        uint256 deadLine;
        uint256 rate;
    }

    mapping(address => Registrant) public registrants;
    mapping(address => Claimer) public claimers;

    uint256 public registrationFee;
    uint256 public maxPayment;

    constructor(uint256 _registrationFee, uint256 _maxPayment, address _token)
        public
        Transfer(_token)
    {
        registrationFee = _registrationFee;
        maxPayment = _maxPayment;
    }

    /**
     * Users should spend a specific amount of token(registrationFee) to register.
     * Users also should provide some information such as name and identity. their information will store in blockchain as a hash.
     **/

    function register(string memory _dataHash) public payable {
        require(balanceOf(msg.sender) >= registrationFee);
        require(
            keccak256(abi.encodePacked(_dataHash)) !=
                keccak256(abi.encodePacked(""))
        );

        Registrant storage registrant = registrants[msg.sender];
        registrant.dataHash = _dataHash;
        registrant.registered = true;

        decreaseBalance(msg.value);
    }

    /**
     * Users can claim for Insurance
     **/
    function claim() public {
        require(registrants[msg.sender].registered);

        Claimer storage claimer = claimers[msg.sender];
        claimer.deadLine = now + 86400;
        claimer.rate = 500;
    }

    /**
     * Doctors can rate each claim
     **/

    function rate(uint256 _rate, address _claimAddress) public onlyWhtielisted {
        Claimer storage claimer = claimers[_claimAddress];

        require(now <= claimer.deadLine);

        claimer.rate = claimer.rate - _rate;
    }

    /**
     * The payment amount will be calculated and transfer to a specific wallet.
     **/

    function withdraw() public {
        // Claimer memory claimer = claimers[msg.sender];
        // require(claimer.rate > 0);
        // uint256 payment = (claimer.rate / 500) * 10000;
        // msg.sender.transfer(payment);
    }
}
