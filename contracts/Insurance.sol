pragma solidity ^0.4.17;


// ============================================================================
// ERC Token Standard #20 Interface
// ============================================================================
contract ERC20Interface {
    function totalSupply() public view returns (uint256);

    function balanceOf(address tokenOwner) public view returns (uint256 balance);

    function allowance(address tokenOwner, address spender) public view returns (uint256 remaining);

    function transfer(address to, uint256 tokens) public returns (bool success);

    function approve(address spender, uint256 tokens) public returns (bool success);

    function transferFrom(address from, address to, uint256 tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint256 tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint256 tokens);
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
    address public admin;

    function Whitelist() public {
        admin = msg.sender;
        doctorsCount = 0;
    }

    modifier onlyDoctors() {
        require(doctors[msg.sender].created == true);
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    function addDoctor(string memory name, address _address) public onlyAdmin {
        require(bytes(name).length > 0);
        require(_address != address(0));

        Profile storage _profile = doctors[_address];

        require(_profile.created == false);

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
    //The hash of user data
    mapping(string => bool) hashes;
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

    //Token insurances
    ERC20Interface _stableCoinInstance;
    ERC20Interface _crnInstance;

    //---------------------------------------------------
    //Setter Functions
    //---------------------------------------------------
    function Insurance(uint256 _crnPerTether, uint256 _maxPayment) public {
        crnPerTether = _crnPerTether;
        maxPayment = _maxPayment;
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

    //Update the contract owner
    function setOwner(address _admin) external onlyAdmin {
        admin = _admin;
    }

    //---------------------------------------------------
    //Getter Functions
    //---------------------------------------------------

    function getRegistrant(address _addr, string memory _dataHash) public view returns (address _address, string memory _hash, bool _registered) {
        return (registrants[_addr].addr, registrants[_addr].details[_dataHash].dataHash, registrants[_addr].details[_dataHash].registered);
    }

    function getClaimer(address _addr, string memory _dataHash) public view returns (address _address, uint256 _deadLine, uint256 _vote, bool _claimed, bool _paid) {
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

    modifier registerValidation(string memory dataHash) {
        require(bytes(dataHash).length > 0);
        require(!hashes[dataHash]);
        _;
    }

    /**
     * @dev Allows user to buy CRN token directly from the contract.
     */

    function buyToken(uint256 amount) public returns (bool) {
        uint256 allowance = _stableCoinInstance.allowance(msg.sender, address(this));
        require(allowance >= crnPerTether * amount);

        bool transfered = _stableCoinInstance.transferFrom(msg.sender, address(this), crnPerTether);
        require(transfered);

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
        hashes[dataHash] = true;
    }

    /**
     * @param dataHash The hash of user info
     * @dev Allows user to register
     **/

    function registerWithStableCoin(string memory dataHash) public registerValidation(dataHash) {
        _stableCoinInstance.transferFrom(msg.sender, address(this), crnPerTether);
        addRegistrant(msg.sender, dataHash);
    }

    /**
     * @param dataHash The hash of user info
     * @dev Allows user to register
     **/
    function registerWithCrnToken(string memory dataHash) public registerValidation(dataHash) {
        _crnInstance.transferFrom(msg.sender, address(this), registrationFee);
        addRegistrant(msg.sender, dataHash);
    }

    /**
     * @param _dataHash The hash of user info
     * @dev Allows Registrant to Claim
     **/
    function claim(string memory _dataHash) public {
        require(registrants[msg.sender].details[_dataHash].registered);
        require(!claimers[msg.sender].details[_dataHash].claimed);

        Claimer storage claimer = claimers[msg.sender];
        claimer.addr = msg.sender;

        claimer.details[_dataHash].deadLine = now + suspendTime;
        claimer.details[_dataHash].claimed = true;
        claimer.details[_dataHash].paid = false;
        claimer.details[_dataHash].vote = doctorsCount * 100;
        claimer.details[_dataHash].maxVote = claimer.details[_dataHash].vote;
    }

    /**
     * @param _vote the value between 0 to 100
     * @param _dataHash The address of claimer
     * @dev Allows Doctors to vote the claimer
     **/

    function vote(uint256 _vote, address _claimerAddress, string memory _dataHash) public onlyDoctors {
        Claimer storage claimer = claimers[_claimerAddress];

        require(claimer.details[_dataHash].claimed);
        require(now <= claimer.details[_dataHash].deadLine);
        require(!claimer.details[_dataHash].voters[msg.sender]);
        uint256 decreased = 100 - _vote;
        claimer.details[_dataHash].vote = claimer.details[_dataHash].vote - decreased;
        claimer.details[_dataHash].voters[msg.sender] = true;
    }

    /**
     * @dev Paying Claimer his/her demand after calculating
     **/
    function payClaimerDemand(string _dataHash) external {
        Claimer storage claimer = claimers[msg.sender];
        uint256 totalBalance = _stableCoinInstance.balanceOf(address(this));

        require(claimer.details[_dataHash].claimed);
        require(!claimer.details[_dataHash].paid);
        require(now > claimer.details[_dataHash].deadLine);
        require(claimer.details[_dataHash].vote > 0);

        uint256 claimerDemand = (claimer.details[_dataHash].vote * maxPayment) / claimer.details[_dataHash].maxVote;

        require(totalBalance >= claimerDemand);
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
        require(totalBalance > 0);
        _stableCoinInstance.transfer(admin, totalBalance);
    }
}
