// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPoolManager {
    function swap(
        bytes32 poolId,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata hookData
    ) external returns (int256 amount0, int256 amount1);
    
    function isValidPool(bytes32 poolId) external view returns (bool);
}

interface IBiometricAuth {
    function isBiometricActive(address user) external view returns (bool);
}

contract BilleteraSwapRouter is ReentrancyGuard, Ownable {
    
    // State variables
    IPoolManager public immutable poolManager;
    IBiometricAuth public immutable biometricAuth;
    
    uint256 public feeRate = 10; // 0.1% (10 basis points)
    address public feeRecipient;
    
    // Security limits
    uint256 public constant MAX_FEE_RATE = 500; // 5% maximum fee
    uint256 public constant MIN_SWAP_AMOUNT = 1000; // Minimum 1000 wei
    uint256 public constant MAX_SWAP_AMOUNT = 1000 * 1e18; // Maximum 1000 tokens
    uint256 public constant MAX_SLIPPAGE_BPS = 5000; // 50% maximum slippage
    
    // Emergency controls
    bool public emergencyPaused = false;
    mapping(address => bool) public blacklistedTokens;
    mapping(bytes32 => bool) public blacklistedPools;
    
    struct SwapConfig {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 minAmountOut;
        bytes32 poolId;
        address recipient;
    }
    
    // Events
    event SwapExecuted(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    
    event EmergencyPaused(bool paused);
    event TokenBlacklisted(address indexed token, bool blacklisted);
    event PoolBlacklisted(bytes32 indexed poolId, bool blacklisted);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event FeeRecipientUpdated(address oldRecipient, address newRecipient);
    
    // Custom errors with more informative messages
    error InvalidPoolManager();
    error InvalidBiometricAuth();
    error InvalidFeeRecipient();
    error BiometricAuthenticationRequired();
    error ContractPaused();
    error InvalidAmount(uint256 provided, uint256 min, uint256 max);
    error InvalidTokens(string reason);
    error InvalidRecipient();
    error InvalidPoolId(bytes32 poolId);
    error BlacklistedToken(address token);
    error BlacklistedPool(bytes32 poolId);
    error InsufficientOutput(uint256 received, uint256 minimum);
    error ExcessiveSlippage(uint256 slippage, uint256 maxAllowed);
    error SwapFailed(string reason);
    error TokenTransferFailed(address token, string operation);
    error InsufficientAllowance(uint256 provided, uint256 required);
    error FeeRateTooHigh(uint256 provided, uint256 maximum);
    
    constructor(
        address _poolManager,
        address _biometricAuth,
        address _feeRecipient
    ) Ownable(msg.sender) {
        // Validate constructor parameters
        if (_poolManager == address(0)) revert InvalidPoolManager();
        if (_biometricAuth == address(0)) revert InvalidBiometricAuth();
        if (_feeRecipient == address(0)) revert InvalidFeeRecipient();
        
        poolManager = IPoolManager(_poolManager);
        biometricAuth = IBiometricAuth(_biometricAuth);
        feeRecipient = _feeRecipient;
    }
    
    // Modifiers
    modifier onlyBiometricAuthenticated() {
        // Robust error handling for external call
        try biometricAuth.isBiometricActive(msg.sender) returns (bool isActive) {
            if (!isActive) revert BiometricAuthenticationRequired();
        } catch {
            revert BiometricAuthenticationRequired();
        }
        _;
    }
    
    modifier notPaused() {
        if (emergencyPaused) revert ContractPaused();
        _;
    }
    
    modifier validSwapConfig(SwapConfig calldata config) {
        // Enhanced input validation with informative errors
        if (config.amountIn < MIN_SWAP_AMOUNT || config.amountIn > MAX_SWAP_AMOUNT) {
            revert InvalidAmount(config.amountIn, MIN_SWAP_AMOUNT, MAX_SWAP_AMOUNT);
        }
        if (config.tokenIn == address(0) || config.tokenOut == address(0)) {
            revert InvalidTokens("Token addresses cannot be zero");
        }
        if (config.tokenIn == config.tokenOut) {
            revert InvalidTokens("Cannot swap same token");
        }
        if (config.recipient == address(0)) {
            revert InvalidRecipient();
        }
        if (config.poolId == bytes32(0)) {
            revert InvalidPoolId(config.poolId);
        }
        if (blacklistedTokens[config.tokenIn]) {
            revert BlacklistedToken(config.tokenIn);
        }
        if (blacklistedTokens[config.tokenOut]) {
            revert BlacklistedToken(config.tokenOut);
        }
        if (blacklistedPools[config.poolId]) {
            revert BlacklistedPool(config.poolId);
        }
        
        // Enhanced slippage validation
        if (config.minAmountOut == 0) {
            revert InvalidTokens("Minimum output cannot be zero");
        }
        
        // Calculate expected slippage protection
        uint256 maxSlippage = (config.amountIn * MAX_SLIPPAGE_BPS) / 10000;
        if (config.amountIn > maxSlippage && config.minAmountOut < (config.amountIn - maxSlippage)) {
            revert ExcessiveSlippage(config.amountIn - config.minAmountOut, maxSlippage);
        }
        _;
    }
    
    function executeSwap(SwapConfig calldata config) 
        external 
        nonReentrant 
        notPaused
        onlyBiometricAuthenticated 
        validSwapConfig(config)
        returns (uint256 amountOut) 
    {
        // Validate pool exists with better error handling
        try poolManager.isValidPool(config.poolId) returns (bool isValid) {
            if (!isValid) revert InvalidPoolId(config.poolId);
        } catch {
            revert InvalidPoolId(config.poolId);
        }
        
        // Check user's token allowance with informative error
        uint256 allowance = IERC20(config.tokenIn).allowance(msg.sender, address(this));
        if (allowance < config.amountIn) {
            revert InsufficientAllowance(allowance, config.amountIn);
        }
        
        // Check user's token balance with informative error
        uint256 userBalance = IERC20(config.tokenIn).balanceOf(msg.sender);
        if (userBalance < config.amountIn) {
            revert InvalidAmount(userBalance, config.amountIn, type(uint256).max);
        }
        
        // Safe token transfer with enhanced error handling
        try IERC20(config.tokenIn).transferFrom(msg.sender, address(this), config.amountIn) 
            returns (bool success) {
            if (!success) revert TokenTransferFailed(config.tokenIn, "transferFrom user");
        } catch {
            revert TokenTransferFailed(config.tokenIn, "transferFrom user");
        }
        
        // Calculate fee and swap amount
        uint256 fee = (config.amountIn * feeRate) / 10000;
        uint256 swapAmount = config.amountIn - fee;
        
        // Approve tokens for pool manager with enhanced error handling
        try IERC20(config.tokenIn).approve(address(poolManager), swapAmount) 
            returns (bool success) {
            if (!success) revert TokenTransferFailed(config.tokenIn, "approve pool manager");
        } catch {
            revert TokenTransferFailed(config.tokenIn, "approve pool manager");
        }
        
        // Execute swap with comprehensive error handling
        try poolManager.swap(
            config.poolId,
            config.tokenIn < config.tokenOut,
            int256(swapAmount),
            0,
            ""
        ) returns (int256 amount0, int256 amount1) {
            // Calculate actual output amount
            amountOut = uint256(amount1 > 0 ? amount1 : -amount0);
            
            // Validate minimum output with informative error
            if (amountOut < config.minAmountOut) {
                revert InsufficientOutput(amountOut, config.minAmountOut);
            }
            
        } catch Error(string memory /* reason */) {
            // Handle known errors
            revert SwapFailed("Pool manager error");
        } catch {
            // Handle unknown errors
            revert SwapFailed("Unknown swap error");
        }
        
        // Safe transfer of output tokens with enhanced error handling
        try IERC20(config.tokenOut).transfer(config.recipient, amountOut) 
            returns (bool success) {
            if (!success) revert TokenTransferFailed(config.tokenOut, "transfer to recipient");
        } catch {
            revert TokenTransferFailed(config.tokenOut, "transfer to recipient");
        }
        
        // Safe transfer of fees with enhanced error handling
        if (fee > 0) {
            try IERC20(config.tokenIn).transfer(feeRecipient, fee) 
                returns (bool success) {
                if (!success) revert TokenTransferFailed(config.tokenIn, "transfer fee");
            } catch {
                revert TokenTransferFailed(config.tokenIn, "transfer fee");
            }
        }
        
        emit SwapExecuted(
            msg.sender,
            config.tokenIn,
            config.tokenOut,
            config.amountIn,
            amountOut,
            fee
        );
    }
    
    // Enhanced admin functions with validation
    function updateFeeRate(uint256 _newFeeRate) external onlyOwner {
        if (_newFeeRate > MAX_FEE_RATE) {
            revert FeeRateTooHigh(_newFeeRate, MAX_FEE_RATE);
        }
        
        uint256 oldRate = feeRate;
        feeRate = _newFeeRate;
        
        emit FeeRateUpdated(oldRate, _newFeeRate);
    }
    
    function updateFeeRecipient(address _newRecipient) external onlyOwner {
        if (_newRecipient == address(0)) revert InvalidFeeRecipient();
        
        address oldRecipient = feeRecipient;
        feeRecipient = _newRecipient;
        
        emit FeeRecipientUpdated(oldRecipient, _newRecipient);
    }
    
    // Emergency controls
    function setEmergencyPause(bool _paused) external onlyOwner {
        emergencyPaused = _paused;
        emit EmergencyPaused(_paused);
    }
    
    function setTokenBlacklist(address token, bool blacklisted) external onlyOwner {
        if (token == address(0)) revert InvalidTokens("Token address cannot be zero");
        blacklistedTokens[token] = blacklisted;
        emit TokenBlacklisted(token, blacklisted);
    }
    
    function setPoolBlacklist(bytes32 poolId, bool blacklisted) external onlyOwner {
        if (poolId == bytes32(0)) revert InvalidPoolId(poolId);
        blacklistedPools[poolId] = blacklisted;
        emit PoolBlacklisted(poolId, blacklisted);
    }
    
    // Enhanced emergency withdrawal with blacklist handling
    function emergencyWithdraw(address token, bool overrideBlacklist) external onlyOwner {
        if (token == address(0)) revert InvalidTokens("Token address cannot be zero");
        
        // Check if token is blacklisted and override is not set
        if (blacklistedTokens[token] && !overrideBlacklist) {
            revert BlacklistedToken(token);
        }
        
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            try IERC20(token).transfer(owner(), balance) returns (bool success) {
                if (!success) revert TokenTransferFailed(token, "emergency withdrawal");
            } catch {
                revert TokenTransferFailed(token, "emergency withdrawal");
            }
        }
    }
    
    // View functions for transparency
    function getSwapLimits() external pure returns (
        uint256 minAmount,
        uint256 maxAmount,
        uint256 maxSlippageBps,
        uint256 maxFeeRate
    ) {
        return (MIN_SWAP_AMOUNT, MAX_SWAP_AMOUNT, MAX_SLIPPAGE_BPS, MAX_FEE_RATE);
    }
    
    function isTokenBlacklisted(address token) external view returns (bool) {
        return blacklistedTokens[token];
    }
    
    function isPoolBlacklisted(bytes32 poolId) external view returns (bool) {
        return blacklistedPools[poolId];
    }
    
    function calculateSwapOutput(uint256 amountIn) external view returns (
        uint256 swapAmount,
        uint256 fee
    ) {
        fee = (amountIn * feeRate) / 10000;
        swapAmount = amountIn - fee;
        return (swapAmount, fee);
    }
}
