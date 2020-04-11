pragma solidity ^0.5.0;


contract Whitelist {
    struct Profile {
        string name;
        bool created;
    }

    mapping(address => Profile) public doctors;
    address[] public doctorAddresses;
    address admin;

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

    function getDoctor(uint256 userId) public view returns (string memory) {
        address _doctorAddress = doctorAddresses[userId];
        Profile memory _profile = doctors[_doctorAddress];
        return _profile.name;
    }

    function getDoctors() public view returns (address[] memory) {
        return doctorAddresses;
    }
}
