pragma solidity ^0.5.0;

import "./Token.sol";


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
    uint256 public doctorsCount;
    address payable public admin;

    constructor() public {
        admin = msg.sender;
        doctorsCount = 0;
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
            "Name must not be empty!"
        );

        require(_address != address(0), "Zero address!");

        Profile storage _profile = doctors[_address];

        require(
            _profile.created == false,
            "Profile with the same address already exists!"
        );

        _profile.name = name;
        _profile.created = true;

        doctorAddresses.push(_address);

        doctorsCount++;
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
        bool paid;
        mapping(address => bool) voters;
    }

    //People who register for insurance
    mapping(address => Registrant) public registrants;
    //Registrants who request for claim
    mapping(address => Claimer) public claimers;

    //Events
    event registered(address registrant, string dataHash, bool registered);
    event claimed(
        address claimer,
        uint256 deadLine,
        uint256 vote,
        bool claimed,
        bool paid
    );

    // Price of each CRN token in USDT
    uint256 public crnPerTether;
    // User needs 1 CRN token for registeration, default: 1 CRN Token
    uint256 public registrationFee;
    // Maximum value that we pay the claimer
    uint256 public maxPayment;
    // The time that doctors needs for vote, default: 86400 seconds(24H)
    uint256 public suspendTime;

    //Supported tokens
    address public stableCoin;
    //Corona Token
    address public crn;

    ERC20Interface _stableCoinInstance;
    ERC20Interface _crnInstance;

    constructor(uint256 _crnPerTether, uint256 _maxPayment, address _crn)
        public
    {
        crnPerTether = _crnPerTether;
        maxPayment = _maxPayment;
        registrationFee = 1;
        suspendTime = 86400;
        crn = _crn;
        _crnInstance = ERC20Interface(_crn);
    }

    //Set the stable Coin address (like Tether OR TrueUSD)
    function setStableCoin(address _stableCoinAddress) external onlyAdmin {
        stableCoin = _stableCoinAddress;
        _stableCoinInstance = ERC20Interface(_stableCoinAddress);
    }

    //Updating the registrationFee if needed!
    function setRegistrationFee(uint256 _value) external onlyAdmin {
        registrationFee = _value;
    }

    //Updating the maxPayment if needed!
    function setMaxPayment(uint256 _value) external onlyAdmin {
        maxPayment = _value;
    }

    //Updating the crnPerTether if needed!
    function setCrnPerTether(uint256 _value) external onlyAdmin {
        crnPerTether = _value;
    }

    //Updating the SuspendTime if needed!
    function setSuspendTime(uint256 _value) external onlyAdmin {
        suspendTime = _value;
    }

    /**
     *  ***Buy CRN token***
     *
     * -Contract check the allowance to see if the user has given permission
     *  to smart contract for transfering Tether from user wallet.
     *
     * -The allowance should be equal or greater than crnPerTether.
     *
     * -The Tethers will be transfered to contract balance.
     *
     * -Contract send 1 CRN token to user wallet.
     *
     **/
    function buyToken() public returns (bool) {
        uint256 allowance = _stableCoinInstance.allowance(
            msg.sender,
            address(this)
        );
        require(allowance >= crnPerTether, "Now Allowed");

        bool transfered = _stableCoinInstance.transferFrom(
            msg.sender,
            address(this),
            crnPerTether
        );
        require(transfered, "Tether has not been transfered!");

        return _crnInstance.transfer(msg.sender, registrationFee);
    }

    /**
     * Get the balance Of the specific user
     **/

    function getBalance(address _address) public view returns (uint256) {
        return _crnInstance.balanceOf(_address);
    }

    /**
     * ***Register A User***
     *
     * -Contract check the allowance to see if the user has given permission
     *  to smart contract for transfering CRN from user wallet.
     *
     * -Users should spend a specific amount of token (registrationFee) for registering.
     *
     * -Users also should provide some information such as name and identity.
     *  their information will store in blockchain as a hash.
     **/

    function register(string memory _dataHash) public {
        require(
            getBalance(msg.sender) >= registrationFee,
            "Don not have enough token!"
        );

        require(
            keccak256(abi.encodePacked(_dataHash)) !=
                keccak256(abi.encodePacked("")),
            "Datahash not allowed to be empty"
        );

        require(
            !registrants[msg.sender].registered,
            "You have already registered!"
        );

        uint256 allowance = _crnInstance.allowance(msg.sender, address(this));
        require(allowance >= registrationFee, "Now Allowed");

        bool transfered = _crnInstance.transferFrom(
            msg.sender,
            address(this),
            registrationFee
        );

        require(transfered, "CRN has not been transfered!");

        Registrant storage registrant = registrants[msg.sender];
        registrant.addr = msg.sender;
        registrant.dataHash = _dataHash;
        registrant.registered = true;

        emit registered(
            registrant.addr,
            registrant.dataHash,
            registrant.registered
        );
    }

    /**
     * ***Registered User Can Claim***
     *
     * -First of all, user should be registered.
     *
     * -The registered user can request for claim only once.
     *
     *
     **/
    function claim() public {
        require(
            registrants[msg.sender].registered,
            "You do not have registered yet!"
        );
        require(!claimers[msg.sender].claimed, "You can claim once!");

        Claimer storage claimer = claimers[msg.sender];
        claimer.addr = msg.sender;
        claimer.deadLine = now + suspendTime;
        claimer.claimed = true;
        claimer.paid = false;
        claimer.vote = doctorsCount * 100;

        emit claimed(
            claimer.addr,
            claimer.deadLine,
            claimer.vote,
            claimer.claimed,
            claimer.paid
        );
    }

    /**
     * ***Doctors Can Vote Each Claim Request***
     *
     * -Doctors should vote less than 24H, unless they want to give the full vote(100).
     *
     * -Every Doctor can vote once!
     **/

    function vote(uint256 _vote, address _claimerAddress) public onlyDoctors {
        Claimer storage claimer = claimers[_claimerAddress];

        require(claimer.claimed, "Claimer does not exist!");
        require(now <= claimer.deadLine, "Doctors can vote less than 24H");
        require(!claimer.voters[msg.sender], "Every Doctor can vote once!");
        uint256 decreased = 100 - _vote;
        claimer.vote = claimer.vote - decreased;
        claimer.voters[msg.sender] = true;
    }

    /**
     * ***Transfer tether to the claimer wallet.***
     *
     * -Only user that request for claim can call the function.
     *
     * -Claimer can call the function after 24H from the claim request,
     *  so the doctors have time to vote the claim.
     *
     * -The total of votes should be greater than 0.
     *
     * -The payment value will be calculated and transfer
     *  from the smart contract to the user wallet.
     *
     **/

    function payClaimerDemand() external {
        Claimer storage claimer = claimers[msg.sender];
        uint256 totlaBalance = _stableCoinInstance.balanceOf(address(this));

        require(claimer.claimed, "You have not claimed yet!");
        require(!claimer.paid, "Previously paid!");
        require(
            now > claimer.deadLine,
            "24H must be passed after claim request!"
        );
        require(claimer.vote > 0, "You will not receive any money!");

        uint256 maxVote = doctorsCount * 100;
        uint256 claimerDemand = (claimer.vote / maxVote) * maxPayment;

        require(
            totlaBalance >= claimerDemand,
            "Contract total balance is not enough!"
        );
        _stableCoinInstance.transfer(msg.sender, claimerDemand);
        claimer.paid = true;
    }

    /**
     * ***Withdraw***
     *
     * Admin can withdraw the Tether balance of the smart contract
     **/
    function withdraw() external onlyAdmin {
        uint256 totlaBalance = _stableCoinInstance.balanceOf(address(this));
        require(totlaBalance > 0, "Contract total balance is 0");
        _stableCoinInstance.transfer(admin, totlaBalance);
    }
}
