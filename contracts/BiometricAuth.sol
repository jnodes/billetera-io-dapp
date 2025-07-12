// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ==============================================
// FILE 1: BiometricAuth.sol
// ==============================================

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BiometricAuth is Ownable, ReentrancyGuard {
    struct BiometricData {
        bytes32 hashedBiometric;
        uint256 timestamp;
        bool isActive;
        address walletAddress;
    }
    
    mapping(address => BiometricData) public biometricRegistry;
    mapping(bytes32 => address) public biometricToAddress;
    
    event BiometricRegistered(address indexed user, bytes32 indexed hashedBiometric);
    event BiometricAuthenticated(address indexed user, uint256 timestamp);
    event BiometricRevoked(address indexed user);
    
    constructor() Ownable(msg.sender) {}
    
    function registerBiometric(bytes32 _hashedBiometric) external {
        require(_hashedBiometric != bytes32(0), "Invalid hash");
        require(biometricToAddress[_hashedBiometric] == address(0), "Already registered");
        
        BiometricData storage data = biometricRegistry[msg.sender];
        
        if (data.hashedBiometric != bytes32(0)) {
            delete biometricToAddress[data.hashedBiometric];
        }
        
        data.hashedBiometric = _hashedBiometric;
        data.timestamp = block.timestamp;
        data.isActive = true;
        data.walletAddress = msg.sender;
        
        biometricToAddress[_hashedBiometric] = msg.sender;
        
        emit BiometricRegistered(msg.sender, _hashedBiometric);
    }
    
    function authenticate(bytes32 _hashedBiometric) external returns (bool) {
        address user = biometricToAddress[_hashedBiometric];
        require(user != address(0), "Not found");
        require(biometricRegistry[user].isActive, "Inactive");
        
        biometricRegistry[user].timestamp = block.timestamp;
        emit BiometricAuthenticated(user, block.timestamp);
        return true;
    }
    
    function revokeBiometric() external {
        BiometricData storage data = biometricRegistry[msg.sender];
        require(data.isActive, "No active biometric");
        
        delete biometricToAddress[data.hashedBiometric];
        data.isActive = false;
        
        emit BiometricRevoked(msg.sender);
    }
    
    function isBiometricActive(address user) external view returns (bool) {
        return biometricRegistry[user].isActive;
    }
}
