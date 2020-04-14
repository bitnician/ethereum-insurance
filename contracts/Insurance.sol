pragma solidity ^0.5.0;

import "Token.sol";


// ----------------------------------------------------------------------------
// Whitelist
// ----------------------------------------------------------------------------

contract Whitelist {
    struct Profile {
        string name;
        bool created;
    }

    mapping(address => Profile) public doctors;
    address[] public doctorAddresses;
    address public admin;

    constructor() public {
        admin = msg.sender;
    }

    modifier onlyDoctors() {
        require(doctors[msg.sender].created == true, "Only Doctors!");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only Admin!");
        _;
    }

    function addDoctor(string memory name, address _address) public onlyAdmin {
        require(
            keccak256(abi.encodePacked(name)) !=
                keccak256(abi.encodePacked("")),
            "name must not be empty!"
        );

        require(_address != address(0), "add zero address");

        Profile storage _profile = doctors[_address];

        require(
            _profile.created == false,
            "Profile with the same address already exists!"
        );

        _profile.name = name;
        _profile.created = true;

        doctorAddresses.push(_address);
    }

    function getDoctors() public view returns (address[] memory) {
        return doctorAddresses;
    }
}


// ----------------------------------------------------------------------------
// Insurance
// ----------------------------------------------------------------------------

contract Insurance is Whitelist {
    struct Registrant {
        address addr;
        string dataHash;
        bool registered;
    }

    struct Claimer {
        address addr;
        uint256 deadLine;
        uint256 vote;
        bool claimed;
        mapping(address => bool) voters;
    }

    //People who register for insurance
    mapping(address => Registrant) public registrants;
    //Registrants who request for claim
    mapping(address => Claimer) public claimers;

    event registered(address registrant, string dataHash, bool registered);
    event claimed(
        address claimer,
        uint256 deadLine,
        uint256 vote,
        bool claimed
    );

    // Price of each CRN token in USDT
    uint256 public crnPerTether;
    // User needs 1 token for register
    uint256 public registrationFee = 1;
    // Maximum value that we pay the claimer
    uint256 public maxPayment;

    //wallet
    address payable wallet;

    //Supported tokes
    address public _tether = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    ERC20Interface _tetherInstance;
    CoronaToken _crnInstance;

    constructor(uint256 _crnPerTether, uint256 _maxPayment, address _crnToken)
        public
    {
        crnPerTether = _crnPerTether;
        maxPayment = _maxPayment;
        _tetherInstance = ERC20Interface(_tether);
        _crnInstance = CoronaToken(_crnToken);
    }

    /**
     * Buy CRN token
     **/
    function buyToken() external returns (bool) {
        uint256 allowance = _tetherInstance.allowance(
            msg.sender,
            address(this)
        );
        require(allowance >= crnPerTether, "Now Allowed");

        bool transfered = _tetherInstance.transferFrom(
            msg.sender,
            address(this),
            crnPerTether
        );

        return transfered;
    }

    /**
     * Get the balance Of the specific user
     **/

    function getBalance(address _address) public view returns (uint256) {
        return _crnInstance.balanceOf(_address);
    }

    /**
     * Users should spend a specific amount of token(registrationFee) to register.
     * Users also should provide some information such as name and identity. their information will store in blockchain as a hash.
     **/

    function register(string memory _dataHash) public payable {
        require(getBalance(msg.sender) >= 1, "Don not have enough token!");

        require(
            keccak256(abi.encodePacked(_dataHash)) !=
                keccak256(abi.encodePacked("")),
            "Datahash not allowed to be empty"
        );

        require(
            !registrants[msg.sender].registered,
            "You have already registered!"
        );

        Registrant storage registrant = registrants[msg.sender];
        registrant.addr = msg.sender;
        registrant.dataHash = _dataHash;
        registrant.registered = true;

        // _tokenInstance.decreaseBalance(msg.sender, registrationFee);

        emit registered(
            registrant.addr,
            registrant.dataHash,
            registrant.registered
        );
    }

    /**
     * Users can claim for Insurance
     **/
    function claim() public {
        require(
            registrants[msg.sender].registered,
            "You do not have registered yet!"
        );
        require(!claimers[msg.sender].claimed, "You can claim once!");

        Claimer storage claimer = claimers[msg.sender];
        claimer.addr = msg.sender;
        claimer.deadLine = now + 86400;
        claimer.claimed = true;
        claimer.vote = doctorAddresses.length * 100;

        emit claimed(
            claimer.addr,
            claimer.deadLine,
            claimer.vote,
            claimer.claimed
        );
    }

    /**
     * Doctors can rate each claim
     **/

    function vote(uint256 _vote, address _claimAddress) public onlyDoctors {
        Claimer storage claimer = claimers[_claimAddress];

        require(now <= claimer.deadLine, "Doctors can vote less than 24H");
        require(!claimer.voters[msg.sender], "Every Doctor can vote once!");

        claimer.vote = claimer.vote - _vote;
        claimer.voters[msg.sender] = true;
    }

    /**
     * The payment amount will be calculated and transfer to a user wallet.
     **/

    function withdraw() external {
        Claimer storage claimer = claimers[msg.sender];

        require(claimer.claimed, "You have not claimed yet!");
        require(
            now > claimer.deadLine,
            "24H must be passed after claim request!"
        );
        require(claimer.vote > 0, "You will not receive any money!");
    }
}
