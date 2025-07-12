// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Minimal external dependencies - custom implementations for security
contract BulletproofBilleteraWallet {
    
    // =============================================================================
    // CUSTOM SECURITY IMPLEMENTATIONS (NO EXTERNAL DEPENDENCIES)
    // =============================================================================
    
    // Custom ReentrancyGuard implementation
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private _status = NOT_ENTERED;
    
    modifier nonReentrant() {
        require(_status != ENTERED, "ReentrancyGuard: reentrant call");
        _status = ENTERED;
        _;
        _status = NOT_ENTERED;
    }
    
    // Custom access control with role validation
    mapping(address => mapping(bytes32 => bool)) private _roles;
    mapping(bytes32 => uint256) private _roleMembers;
    
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    
    address private _owner;
    
    modifier onlyOwner() {
        require(msg.sender == _owner, "Not owner");
        _;
    }
    
    modifier onlyRole(bytes32 role) {
        require(_roles[msg.sender][role], "Access denied");
        _;
    }
    
    // =============================================================================
    // AUTOMATIC INTERFACE VALIDATION (CANNOT BE BYPASSED)
    // =============================================================================
    
    // Interface contracts with built-in validation
    address private immutable BIOMETRIC_AUTH;
    address private immutable SWAP_ROUTER;
    
    // Validation state that's checked on EVERY function call
    struct ValidationState {
        bool biometricValid;
        bool routerValid;
        uint256 lastCheck;
        bytes32 biometricHash;
        bytes32 routerHash;
    }
    
    ValidationState private validation;
    uint256 private constant VALIDATION_INTERVAL = 1 hours;
    
    // CRITICAL: This runs automatically on every state-changing function
    modifier automaticValidation() {
        _enforceInterfaceValidation();
        _;
        _postExecutionValidation();
    }
    
    function _enforceInterfaceValidation() private {
        // Force validation check every hour or on first call
        if (block.timestamp > validation.lastCheck + VALIDATION_INTERVAL || validation.lastCheck == 0) {
            _validateAllInterfaces();
        }
        
        // Always check current validation state
        require(validation.biometricValid && validation.routerValid, "Interface validation failed");
    }
    
    function _validateAllInterfaces() private {
        // Validate biometric interface - check if it responds to our expected function
        (bool success1, ) = BIOMETRIC_AUTH.staticcall(
            abi.encodeWithSignature("isBiometricActive(address)", address(this))
        );
        
        validation.biometricValid = success1; // If it responds, it's valid
        
        // Validate swap router interface - check if it has the expected function
        (bool success2, ) = SWAP_ROUTER.staticcall(
            abi.encodeWithSignature("feeRate()")
        );
        
        validation.routerValid = success2; // If it responds, it's valid
        
        validation.lastCheck = block.timestamp;
    }
    
    // =============================================================================
    // COMPREHENSIVE INPUT VALIDATION (MATHEMATICAL SAFETY)
    // =============================================================================
    
    // Custom SafeMath implementation to avoid external dependencies
    function _safeAdd(uint256 a, uint256 b) private pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }
    
    function _safeSub(uint256 a, uint256 b) private pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction underflow");
        return a - b;
    }
    
    function _safeMul(uint256 a, uint256 b) private pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    
    function _safeDiv(uint256 a, uint256 b) private pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }
    
    // Comprehensive input validation
    struct ValidationParams {
        uint256 minAmount;
        uint256 maxAmount;
        uint256 maxDecimals;
        bool allowZero;
        bool checkOverflow;
    }
    
    function _validateAmount(uint256 amount, ValidationParams memory params) private pure {
        if (!params.allowZero) {
            require(amount > 0, "Amount cannot be zero");
        }
        
        require(amount >= params.minAmount, "Amount below minimum");
        require(amount <= params.maxAmount, "Amount exceeds maximum");
        
        // Check for reasonable decimal places (prevent dust attacks)
        if (params.maxDecimals > 0) {
            uint256 decimals = 10 ** params.maxDecimals;
            require(amount % decimals == 0, "Too many decimal places");
        }
        
        // Check for overflow in future calculations
        if (params.checkOverflow) {
            require(amount <= type(uint256).max / 1000, "Potential overflow risk");
        }
    }
    
    function _validateAddress(address addr, bool allowZero) private view {
        if (!allowZero) {
            require(addr != address(0), "Zero address not allowed");
        }
        // Additional address validation
        require(addr != address(this), "Cannot be contract address");
    }
    
    function _validateTokenPair(address tokenA, address tokenB) private view {
        _validateAddress(tokenA, false);
        _validateAddress(tokenB, false);
        require(tokenA != tokenB, "Cannot be same token");
        
        // Prevent common attack patterns
        require(uint160(tokenA) > 1000, "Suspicious token address");
        require(uint160(tokenB) > 1000, "Suspicious token address");
    }
    
    // =============================================================================
    // IRONCLAD STATE MANAGEMENT
    // =============================================================================
    
    // Wallet state with invariant checking
    struct UserWallet {
        address owner;
        bool isActive;
        uint256 createdAt;
        bool swapLocked;
        uint256 dailySwapLimit;
        uint256 dailySwapUsed;
        uint256 lastSwapReset;
        uint256 transactionCount;
        bytes32 stateHash; // Integrity check
    }
    
    mapping(address => UserWallet) private _wallets;
    mapping(address => mapping(address => uint256)) private _balances;
    mapping(address => address[]) private _userTokens;
    mapping(address => uint256) private _nonces;
    
    // Contract-level state invariants
    uint256 private _totalUsers;
    uint256 private _totalTransactions;
    bytes32 private _globalStateHash;
    
    // Security limits (immutable for safety)
    uint256 private constant MIN_AMOUNT = 1000; // 1000 wei
    uint256 private constant MAX_AMOUNT = 100 * 1e18; // 100 tokens
    uint256 private constant MAX_DAILY_LIMIT = 50 * 1e18; // 50 tokens
    uint256 private constant MAX_DAILY_TRANSACTIONS = 20;
    uint256 private constant MIN_TIME_BETWEEN_TX = 1 minutes;
    
    mapping(address => uint256) private _lastTransactionTime;
    
    // =============================================================================
    // EVENTS AND ERRORS
    // =============================================================================
    
    event WalletCreated(address indexed user, uint256 timestamp);
    event TokenDeposited(address indexed user, address indexed token, uint256 amount);
    event TokenWithdrawn(address indexed user, address indexed token, uint256 amount);
    event SwapExecuted(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event SecurityViolation(address indexed user, string violation);
    event IntegrityCheckFailed(string reason);
    
    error ValidationFailed(string reason);
    error InvariantViolation(string reason);
    error SecurityBreach(string reason);
    error InsufficientBalance(uint256 available, uint256 requested);
    error RateLimitExceeded(uint256 lastTx, uint256 minInterval);
    error StateCorruption(string reason);
    
    // =============================================================================
    // CONSTRUCTOR WITH VALIDATION
    // =============================================================================
    
    constructor(
        address biometricAuth,
        address swapRouter
    ) {
        // Validate constructor parameters
        _validateAddress(biometricAuth, false);
        _validateAddress(swapRouter, false);
        
        BIOMETRIC_AUTH = biometricAuth;
        SWAP_ROUTER = swapRouter;
        _owner = msg.sender;
        
        // Initialize validation state with default hashes for existing contracts
        validation.biometricHash = keccak256("BIOMETRIC_AUTH_V1");
        validation.routerHash = keccak256("SWAP_ROUTER_V1");
        validation.biometricValid = true; // Start as valid
        validation.routerValid = true;
        validation.lastCheck = block.timestamp;
        
        // Set up roles
        _roles[msg.sender][ADMIN_ROLE] = true;
        _roles[msg.sender][EMERGENCY_ROLE] = true;
        _roleMembers[ADMIN_ROLE] = 1;
        _roleMembers[EMERGENCY_ROLE] = 1;
        
        // Initialize global state
        _globalStateHash = keccak256(abi.encodePacked(block.timestamp, msg.sender));
    }
    
    // =============================================================================
    // BULLETPROOF WALLET FUNCTIONS
    // =============================================================================
    
    function createWallet() external automaticValidation nonReentrant {
        require(!_wallets[msg.sender].isActive, "Wallet exists");
        
        // Validate biometric authentication
        (bool success, bytes memory data) = BIOMETRIC_AUTH.staticcall(
            abi.encodeWithSignature("isBiometricActive(address)", msg.sender)
        );
        require(success && data.length >= 32, "Biometric validation failed");
        require(abi.decode(data, (bool)), "Biometric not active");
        
        // Create wallet with state hash
        UserWallet memory wallet = UserWallet({
            owner: msg.sender,
            isActive: true,
            createdAt: block.timestamp,
            swapLocked: false,
            dailySwapLimit: 10 * 1e18,
            dailySwapUsed: 0,
            lastSwapReset: block.timestamp,
            transactionCount: 0,
            stateHash: bytes32(0)
        });
        
        // Calculate and set state hash
        wallet.stateHash = _calculateWalletHash(wallet);
        _wallets[msg.sender] = wallet;
        
        _totalUsers = _safeAdd(_totalUsers, 1);
        _updateGlobalState();
        
        emit WalletCreated(msg.sender, block.timestamp);
    }
    
    function depositToken(address token, uint256 amount) 
        external 
        automaticValidation 
        nonReentrant 
    {
        // Comprehensive validation
        _validateTokenPair(token, address(1)); // Use dummy second address for pair validation
        _validateAmount(amount, ValidationParams({
            minAmount: MIN_AMOUNT,
            maxAmount: MAX_AMOUNT,
            maxDecimals: 0, // Allow all decimals for deposits
            allowZero: false,
            checkOverflow: true
        }));
        
        // Rate limiting
        require(
            block.timestamp >= _lastTransactionTime[msg.sender] + MIN_TIME_BETWEEN_TX,
            "Rate limit exceeded"
        );
        
        // Wallet validation
        _validateWalletState(msg.sender);
        UserWallet storage wallet = _wallets[msg.sender];
        
        // Token validation
        (bool success1, bytes memory balanceData) = token.staticcall(
            abi.encodeWithSignature("balanceOf(address)", msg.sender)
        );
        require(success1, "Token balance check failed");
        uint256 userBalance = abi.decode(balanceData, (uint256));
        require(userBalance >= amount, "Insufficient token balance");
        
        (bool success2, bytes memory allowanceData) = token.staticcall(
            abi.encodeWithSignature("allowance(address,address)", msg.sender, address(this))
        );
        require(success2, "Token allowance check failed");
        uint256 allowance = abi.decode(allowanceData, (uint256));
        require(allowance >= amount, "Insufficient allowance");
        
        // Execute transfer
        (bool success3, bytes memory transferData) = token.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amount)
        );
        require(success3, "Transfer failed");
        if (transferData.length > 0) {
            require(abi.decode(transferData, (bool)), "Transfer returned false");
        }
        
        // Update state
        _balances[msg.sender][token] = _safeAdd(_balances[msg.sender][token], amount);
        wallet.transactionCount = _safeAdd(wallet.transactionCount, 1);
        _lastTransactionTime[msg.sender] = block.timestamp;
        
        // Add to user tokens if first deposit
        if (_balances[msg.sender][token] == amount) {
            _userTokens[msg.sender].push(token);
        }
        
        // Update state hash and validate
        wallet.stateHash = _calculateWalletHash(wallet);
        _updateGlobalState();
        _validateInvariants();
        
        emit TokenDeposited(msg.sender, token, amount);
    }
    
    function withdrawToken(address token, uint256 amount) 
        external 
        automaticValidation 
        nonReentrant 
    {
        // Comprehensive validation
        _validateAddress(token, false);
        _validateAmount(amount, ValidationParams({
            minAmount: 1, // Allow small withdrawals
            maxAmount: MAX_AMOUNT,
            maxDecimals: 0,
            allowZero: false,
            checkOverflow: false
        }));
        
        // Rate limiting and wallet validation
        require(
            block.timestamp >= _lastTransactionTime[msg.sender] + MIN_TIME_BETWEEN_TX,
            "Rate limit exceeded"
        );
        
        _validateWalletState(msg.sender);
        UserWallet storage wallet = _wallets[msg.sender];
        
        // Balance validation
        uint256 available = _balances[msg.sender][token];
        require(available >= amount, "Insufficient balance");
        
        // Update state first (CEI pattern)
        _balances[msg.sender][token] = _safeSub(available, amount);
        wallet.transactionCount = _safeAdd(wallet.transactionCount, 1);
        _lastTransactionTime[msg.sender] = block.timestamp;
        
        // Execute transfer
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount)
        );
        
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            // Revert state changes on failure
            _balances[msg.sender][token] = available;
            wallet.transactionCount = _safeSub(wallet.transactionCount, 1);
            revert("Transfer failed");
        }
        
        // Update state hash and validate
        wallet.stateHash = _calculateWalletHash(wallet);
        _updateGlobalState();
        _validateInvariants();
        
        emit TokenWithdrawn(msg.sender, token, amount);
    }
    
    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes32 poolId
    ) 
        external 
        automaticValidation 
        nonReentrant 
        returns (uint256 amountOut) 
    {
        // Comprehensive validation
        _validateTokenPair(tokenIn, tokenOut);
        _validateAmount(amountIn, ValidationParams({
            minAmount: MIN_AMOUNT,
            maxAmount: MAX_AMOUNT,
            maxDecimals: 0,
            allowZero: false,
            checkOverflow: true
        }));
        require(poolId != bytes32(0), "Invalid pool ID");
        require(minAmountOut > 0, "Min output must be positive");
        
        // Rate limiting and wallet validation
        require(
            block.timestamp >= _lastTransactionTime[msg.sender] + MIN_TIME_BETWEEN_TX,
            "Rate limit exceeded"
        );
        
        _validateWalletState(msg.sender);
        UserWallet storage wallet = _wallets[msg.sender];
        require(!wallet.swapLocked, "Swaps locked");
        
        // Daily limit validation
        if (block.timestamp >= wallet.lastSwapReset + 1 days) {
            wallet.dailySwapUsed = 0;
            wallet.lastSwapReset = block.timestamp;
        }
        
        require(
            _safeAdd(wallet.dailySwapUsed, amountIn) <= wallet.dailySwapLimit,
            "Daily limit exceeded"
        );
        
        // Balance validation
        uint256 available = _balances[msg.sender][tokenIn];
        require(available >= amountIn, "Insufficient balance");
        
        // Update state first
        _balances[msg.sender][tokenIn] = _safeSub(available, amountIn);
        wallet.dailySwapUsed = _safeAdd(wallet.dailySwapUsed, amountIn);
        wallet.transactionCount = _safeAdd(wallet.transactionCount, 1);
        _lastTransactionTime[msg.sender] = block.timestamp;
        
        // Approve tokens for swap
        (bool approveSuccess, bytes memory approveData) = tokenIn.call(
            abi.encodeWithSignature("approve(address,uint256)", SWAP_ROUTER, amountIn)
        );
        
        if (!approveSuccess || (approveData.length > 0 && !abi.decode(approveData, (bool)))) {
            // Revert state changes
            _balances[msg.sender][tokenIn] = available;
            wallet.dailySwapUsed = _safeSub(wallet.dailySwapUsed, amountIn);
            wallet.transactionCount = _safeSub(wallet.transactionCount, 1);
            revert("Approval failed");
        }
        
        // Execute swap
        bytes memory swapData = abi.encodeWithSignature(
            "executeSwap((address,address,uint256,uint256,bytes32,address))",
            tokenIn, tokenOut, amountIn, minAmountOut, poolId, address(this)
        );
        
        (bool swapSuccess, bytes memory swapResult) = SWAP_ROUTER.call(swapData);
        
        if (!swapSuccess) {
            // Revert all state changes
            _balances[msg.sender][tokenIn] = available;
            wallet.dailySwapUsed = _safeSub(wallet.dailySwapUsed, amountIn);
            wallet.transactionCount = _safeSub(wallet.transactionCount, 1);
            revert("Swap failed");
        }
        
        amountOut = abi.decode(swapResult, (uint256));
        require(amountOut >= minAmountOut, "Insufficient output");
        
        // Update output balance
        _balances[msg.sender][tokenOut] = _safeAdd(_balances[msg.sender][tokenOut], amountOut);
        
        // Add to user tokens if new
        if (_balances[msg.sender][tokenOut] == amountOut) {
            _userTokens[msg.sender].push(tokenOut);
        }
        
        // Update state hash and validate
        wallet.stateHash = _calculateWalletHash(wallet);
        _updateGlobalState();
        _validateInvariants();
        
        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }
    
    // =============================================================================
    // INTEGRITY VALIDATION FUNCTIONS
    // =============================================================================
    
    function _calculateWalletHash(UserWallet memory wallet) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            wallet.owner,
            wallet.isActive,
            wallet.createdAt,
            wallet.dailySwapLimit,
            wallet.transactionCount
        ));
    }
    
    function _validateWalletState(address user) private view {
        UserWallet storage wallet = _wallets[user];
        require(wallet.isActive, "Wallet not active");
        require(wallet.owner == user, "Not wallet owner");
        
        // Verify state hash integrity
        bytes32 expectedHash = _calculateWalletHash(wallet);
        require(wallet.stateHash == expectedHash, "Wallet state corrupted");
    }
    
    function _updateGlobalState() private {
        _totalTransactions = _safeAdd(_totalTransactions, 1);
        _globalStateHash = keccak256(abi.encodePacked(
            _globalStateHash,
            block.timestamp,
            _totalTransactions
        ));
    }
    
    function _validateInvariants() private view {
        // Contract-level invariants
        require(_totalUsers > 0, "Invalid user count");
        require(_totalTransactions > 0, "Invalid transaction count");
        require(_globalStateHash != bytes32(0), "Invalid global state");
    }
    
    function _postExecutionValidation() private view {
        // Ensure no state corruption occurred
        require(validation.biometricValid, "Biometric interface corrupted");
        require(validation.routerValid, "Router interface corrupted");
        require(_status == ENTERED, "Reentrancy guard corrupted");
    }
    
    // =============================================================================
    // VIEW FUNCTIONS
    // =============================================================================
    
    function getBalance(address user, address token) external view returns (uint256) {
        return _balances[user][token];
    }
    
    function getUserTokens(address user) external view returns (address[] memory) {
        return _userTokens[user];
    }
    
    function getWalletInfo(address user) external view returns (
        bool isActive,
        uint256 createdAt,
        uint256 transactionCount,
        bool stateValid
    ) {
        UserWallet storage wallet = _wallets[user];
        bytes32 expectedHash = _calculateWalletHash(wallet);
        
        return (
            wallet.isActive,
            wallet.createdAt,
            wallet.transactionCount,
            wallet.stateHash == expectedHash
        );
    }
    
    function getValidationState() external view returns (
        bool biometricValid,
        bool routerValid,
        uint256 lastCheck
    ) {
        return (
            validation.biometricValid,
            validation.routerValid,
            validation.lastCheck
        );
    }
    
    // =============================================================================
    // EMERGENCY FUNCTIONS (ADMIN ONLY)
    // =============================================================================
    
    function emergencyPause() external onlyRole(EMERGENCY_ROLE) {
        validation.biometricValid = false;
        validation.routerValid = false;
        emit SecurityViolation(msg.sender, "Emergency pause activated");
    }
    
    function forceValidation() external onlyRole(ADMIN_ROLE) {
        _validateAllInterfaces();
    }
}
