pragma solidity ^0.5.0;


// ============================================================================
// ERC Token Standard #20 Interface
// ============================================================================
contract ERC20Interface {
    function totalSupply() public view returns (uint256);

    function balanceOf(address tokenOwner)
        public
        view
        returns (uint256 balance);

    function allowance(address tokenOwner, address spender)
        public
        view
        returns (uint256 remaining);

    function transfer(address to, uint256 tokens) public returns (bool success);

    function approve(address spender, uint256 tokens)
        public
        returns (bool success);

    function transferFrom(address from, address to, uint256 tokens)
        public
        returns (bool success);

    event Transfer(address indexed from, address indexed to, uint256 tokens);
    event Approval(
        address indexed tokenOwner,
        address indexed spender,
        uint256 tokens
    );
}


// ============================================================================
// Whitelist Constract
// ============================================================================

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


// ============================================================================
// Insurance Contract
// ============================================================================

contract Insurance is Whitelist {
    //---------------------------------------------------
    //Structs
    //---------------------------------------------------
    //Registrant Detail structure
    struct RegistrantDetail {
        string dataHash;
        bool registered;
    }
    //Registrant structure
    struct Registrant {
        address addr;
        mapping(string => RegistrantDetail) details;
    }
    //Claimer Detail structure
    struct ClaimerDetail {
        uint256 deadLine;
        uint256 vote;
        uint256 maxVote;
        bool claimed;
        bool paid;
        mapping(address => bool) voters;
    }
    //Claimer structure
    struct Claimer {
        address addr;
        mapping(string => ClaimerDetail) details;
    }
    //---------------------------------------------------
    //Mappings
    //---------------------------------------------------
    //People who register for insurance
    mapping(address => Registrant) public registrants;
    //Registrants who request for claim
    mapping(address => Claimer) public claimers;
    //
    //---------------------------------------------------
    //Events
    //---------------------------------------------------
    event registered(address registrant, string dataHash);
    event claimed(
        address claimer,
        uint256 deadLine,
        uint256 vote,
        bool claimed,
        bool paid
    );
    //---------------------------------------------------
    //State Variables
    //---------------------------------------------------
    // Price of each CRN token in USDT, user may access contract to trasnfer this value from his/her wallet
    uint256 public crnPerTether;
    // User needs 1 CRN token for registeration, user may access contract to trasnfer this value from his/her wallet
    uint256 public registrationFee;
    // Maximum value that we pay the claimer
    uint256 public maxPayment;
    // The time that doctors needs for vote, default: 86400 seconds(24H)
    uint256 public suspendTime;

    //Supported tokens
    address public stableCoin;
    //Corona Token
    address public crn;

    //Conver values with 18 decimals
    uint256 convertable = 1000000000000000000;

    //Token insurances
    ERC20Interface _stableCoinInstance;
    ERC20Interface _crnInstance;

    //---------------------------------------------------
    //Setter Functions
    //---------------------------------------------------
    constructor(uint256 _crnPerTether, uint256 _maxPayment) public {
        crnPerTether = _crnPerTether * convertable;
        maxPayment = _maxPayment * convertable;
        registrationFee = 1;
        suspendTime = 86400;
    }

    //Set the stable Coin address (like Tether OR TrueUSD)
    function setStableCoin(address _stableCoinAddress) external onlyAdmin {
        stableCoin = _stableCoinAddress;
        _stableCoinInstance = ERC20Interface(_stableCoinAddress);
    }

    //Set the contract token if needed
    function setCrnToken(address _crnToken) external onlyAdmin {
        crn = _crnToken;
        _crnInstance = ERC20Interface(_crnToken);
    }

    //Updating the registrationFee if needed!
    function setRegistrationFee(uint256 _value) external onlyAdmin {
        registrationFee = _value;
    }

    //Updating the maxPayment if needed!
    function setMaxPayment(uint256 _value) external onlyAdmin {
        maxPayment = _value * convertable;
    }

    //Updating the crnPerTether if needed!
    function setCrnPerTether(uint256 _value) external onlyAdmin {
        crnPerTether = _value * convertable;
    }

    //Updating the SuspendTime if needed!
    function setSuspendTime(uint256 _value) external onlyAdmin {
        suspendTime = _value;
    }

    //Update the contract owner
    function setOwner(address payable _admin) external onlyAdmin {
        admin = _admin;
    }

    //---------------------------------------------------
    //Getter Functions
    //---------------------------------------------------

    function getRegistrant(address _addr, string memory _dataHash)
        public
        view
        returns (address _address, string memory _hash, bool _registered)
    {
        return (
            registrants[_addr].addr,
            registrants[_addr].details[_dataHash].dataHash,
            registrants[_addr].details[_dataHash].registered
        );
    }

    function getClaimer(address _addr, string memory _dataHash)
        public
        view
        returns (
            address _address,
            uint256 _deadLine,
            uint256 _vote,
            bool _claimed,
            bool _paid
        )
    {
        return (
            claimers[_addr].addr,
            claimers[_addr].details[_dataHash].deadLine,
            claimers[_addr].details[_dataHash].vote,
            claimers[_addr].details[_dataHash].claimed,
            claimers[_addr].details[_dataHash].paid
        );
    }

    //---------------------------------------------------
    //Contract life cycle Functions
    //---------------------------------------------------

    modifier registerValidation(address sender, string memory dataHash) {
        require(
            keccak256(abi.encodePacked(dataHash)) !=
                keccak256(abi.encodePacked("")),
            "Datahash not allowed to be empty!"
        );
        require(
            !registrants[sender].details[dataHash].registered,
            "User already registered!"
        );
        _;
    }

    /**
     * @dev Allows user to buy CRN token directly from the contract.
     */

    function buyToken(uint256 amount) public returns (bool) {
        uint256 allowance = _stableCoinInstance.allowance(
            msg.sender,
            address(this)
        );
        require(allowance >= crnPerTether * amount, "Now Allowed");

        bool transfered = _stableCoinInstance.transferFrom(
            msg.sender,
            address(this),
            crnPerTether
        );
        require(transfered, "Tether has not been transfered!");

        return _crnInstance.transfer(msg.sender, amount);
    }

    /**
     * @param sender The msg.sender
     * @param dataHash The hash of user info
     * @dev Add registrant
     **/

    function addRegistrant(address sender, string memory dataHash) internal {
        Registrant storage registrant = registrants[sender];
        registrant.addr = sender;
        registrant.details[dataHash].registered = true;
        registrant.details[dataHash].dataHash = dataHash;
        emit registered(registrant.addr, registrant.details[dataHash].dataHash);
    }

    /**
     * @param dataHash The hash of user info
     * @dev Allows user to register
     **/

    function registerWithStableCoin(string memory dataHash)
        public
        registerValidation(msg.sender, dataHash)
    {
        uint256 stableCoinAllowance = _stableCoinInstance.allowance(
            msg.sender,
            address(this)
        );
        require(stableCoinAllowance >= crnPerTether, "Low allowance!");
        _stableCoinInstance.transferFrom(
            msg.sender,
            address(this),
            crnPerTether
        );
        addRegistrant(msg.sender, dataHash);
    }

    /**
     * @param dataHash The hash of user info
     * @dev Allows user to register
     **/
    function registerWithCrnToken(string memory dataHash)
        public
        registerValidation(msg.sender, dataHash)
    {
        uint256 crnAllowance = _crnInstance.allowance(
            msg.sender,
            address(this)
        );
        require(crnAllowance >= registrationFee, "Low allowance!");
        _crnInstance.transferFrom(msg.sender, address(this), registrationFee);
        addRegistrant(msg.sender, dataHash);
    }

    /**
     * @param _dataHash The hash of user info
     * @dev Allows Registrant to Claim
     **/
    function claim(string memory _dataHash) public {
        require(
            registrants[msg.sender].details[_dataHash].registered,
            "You do not have registered yet!"
        );
        require(
            !claimers[msg.sender].details[_dataHash].claimed,
            "User claimed once!"
        );

        Claimer storage claimer = claimers[msg.sender];
        claimer.addr = msg.sender;

        claimer.details[_dataHash].deadLine = now + suspendTime;
        claimer.details[_dataHash].claimed = true;
        claimer.details[_dataHash].paid = false;
        claimer.details[_dataHash].vote = doctorsCount * 100;
        claimer.details[_dataHash].maxVote = claimer.details[_dataHash].vote;

        emit claimed(
            claimer.addr,
            claimer.details[_dataHash].deadLine,
            claimer.details[_dataHash].vote,
            claimer.details[_dataHash].claimed,
            claimer.details[_dataHash].paid
        );
    }

    /**
     * @param _vote the value between 0 to 100
     * @param _dataHash The address of claimer
     * @dev Allows Doctors to vote the claimer
     **/

    function vote(
        uint256 _vote,
        address _claimerAddress,
        string memory _dataHash
    ) public onlyDoctors {
        Claimer storage claimer = claimers[_claimerAddress];

        require(claimer.details[_dataHash].claimed, "Claimer does not exist!");
        require(
            now <= claimer.details[_dataHash].deadLine,
            "Doctors can vote less than 24H"
        );
        require(
            !claimer.details[_dataHash].voters[msg.sender],
            "Every Doctor can vote once!"
        );
        uint256 decreased = 100 - _vote;
        claimer.details[_dataHash].vote =
            claimer.details[_dataHash].vote -
            decreased;
        claimer.details[_dataHash].voters[msg.sender] = true;
    }

    /**
     * @dev Paying Claimer his/her demand after calculating
     **/
    function payClaimerDemand(string calldata _dataHash) external {
        Claimer storage claimer = claimers[msg.sender];
        uint256 totalBalance = _stableCoinInstance.balanceOf(address(this));

        require(
            claimer.details[_dataHash].claimed,
            "You have not claimed yet!"
        );
        require(!claimer.details[_dataHash].paid, "Previously paid!");
        require(
            now > claimer.details[_dataHash].deadLine,
            "24H must be passed after claim request!"
        );
        require(
            claimer.details[_dataHash].vote > 0,
            "You will not receive any money!"
        );

        uint256 claimerDemand = (claimer.details[_dataHash].vote * maxPayment) /
            claimer.details[_dataHash].maxVote;

        require(
            totalBalance >= claimerDemand,
            "Contract total balance is not enough!"
        );
        _stableCoinInstance.transfer(msg.sender, claimerDemand);
        claimer.details[_dataHash].paid = true;
    }

    //---------------------------------------------------
    //Withdraw Function
    //---------------------------------------------------
    /**
     * @dev admin can withdraw the contract balance
     **/
    function withdraw() external onlyAdmin {
        uint256 totalBalance = _stableCoinInstance.balanceOf(address(this));
        require(totalBalance > 0, "Contract total balance is 0");
        _stableCoinInstance.transfer(admin, totalBalance);
    }
}
