pragma solidity 0.5.11;


contract Whitelist {
    struct Profile {
        string name;
        bool created;
    }

    mapping(address => Profile) doctors;
    address[] doctorAddress;
    address admin;

    constructor() public {
        admin = msg.sender;
    }

    modifier onlyWhtielisted() {
        require(doctors[msg.sender].created == true, "");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    function addDoctor(string memory name) public onlyAdmin {
        require(
            keccak256(abi.encodePacked(name)) !=
                keccak256(abi.encodePacked("")),
            "name must not be empty!"
        );

        Profile storage _profile = doctors[msg.sender];

        require(
            _profile.created == false,
            "Profile with the same address already exists!"
        );

        _profile.name = name;
        _profile.created = true;

        doctorAddress.push(msg.sender);
    }

    function getDoctor(uint256 userId) public view returns (string memory) {
        address _doctorAddress = doctorAddress[userId];
        Profile memory _profile = doctors[_doctorAddress];
        return _profile.name;
    }
}
