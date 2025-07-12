// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MockPoolManager is Ownable {
    
    struct PoolConfig {
        bool isActive;
        uint256 rate; // Rate with 18 decimals (e.g., 2471000000000000000000 = 2471)
        uint256 slippageBps; // Slippage in basis points (e.g., 50 = 0.5%)
        address token0;
        address token1;
    }
    
    mapping(bytes32 => PoolConfig) public pools;
    mapping(string => bytes32) public poolNames;
    
    event PoolAdded(bytes32 indexed poolId, string name, uint256 rate, uint256 slippageBps);
    event SwapExecuted(bytes32 indexed poolId, uint256 amountIn, uint256 amountOut, uint256 slippage);
    
    constructor() Ownable(msg.sender) {
        // Initialize realistic pools with consistent logic
        _addPool("ETH/USDC", 2471 * 1e18, 30); // 1 ETH = 2471 USDC, 0.3% slippage
        _addPool("ETH/DAI", 2468 * 1e18, 40);  // 1 ETH = 2468 DAI, 0.4% slippage  
        _addPool("USDC/DAI", 1 * 1e18, 10);    // 1 USDC = 1 DAI, 0.1% slippage
        _addPool("DAI/USDC", 1 * 1e18, 10);    // 1 DAI = 1 USDC, 0.1% slippage
    }
    
    function swap(
        bytes32 poolId,
        bool zeroForOne,
        int256 amountSpecified,
        uint160, // sqrtPriceLimitX96 - unused in mock
        bytes calldata // hookData - unused in mock
    ) external returns (int256 amount0, int256 amount1) {
        require(amountSpecified > 0, "Invalid amount");
        
        PoolConfig storage pool = pools[poolId];
        require(pool.isActive, "Pool not active");
        
        uint256 amountIn = uint256(amountSpecified);
        uint256 amountOut;
        
        // Calculate output based on pool rate
        if (zeroForOne) {
            // token0 -> token1
            amountOut = (amountIn * pool.rate) / 1e18;
        } else {
            // token1 -> token0  
            amountOut = (amountIn * 1e18) / pool.rate;
        }
        
        // Apply consistent slippage
        uint256 slippageAmount = (amountOut * pool.slippageBps) / 10000;
        amountOut = amountOut - slippageAmount;
        
        // Ensure minimum output
        require(amountOut > 0, "Insufficient output");
        
        // Return amounts (negative means outgoing)
        amount0 = zeroForOne ? amountSpecified : -int256(amountOut);
        amount1 = zeroForOne ? -int256(amountOut) : amountSpecified;
        
        emit SwapExecuted(poolId, amountIn, amountOut, slippageAmount);
        return (amount0, amount1);
    }
    
    // SECURE: Only owner can add pools
    function addPool(
        string calldata name,
        uint256 rate,
        uint256 slippageBps,
        address token0,
        address token1
    ) external onlyOwner {
        require(rate > 0, "Invalid rate");
        require(slippageBps <= 1000, "Slippage too high"); // Max 10%
        require(token0 != token1, "Same token");
        require(token0 != address(0) && token1 != address(0), "Invalid tokens");
        
        _addPool(name, rate, slippageBps);
    }
    
    function _addPool(string memory name, uint256 rate, uint256 slippageBps) internal {
        bytes32 poolId = keccak256(abi.encodePacked(name));
        
        pools[poolId] = PoolConfig({
            isActive: true,
            rate: rate,
            slippageBps: slippageBps,
            token0: address(0), // For mock, we don't need actual token addresses
            token1: address(0)
        });
        
        poolNames[name] = poolId;
        
        emit PoolAdded(poolId, name, rate, slippageBps);
    }
    
    // Get pool ID by name (helper function)
    function getPoolId(string calldata name) external view returns (bytes32) {
        return poolNames[name];
    }
    
    // Check if pool exists and is active
    function isValidPool(bytes32 poolId) external view returns (bool) {
        return pools[poolId].isActive;
    }
    
    // Get pool details
    function getPoolConfig(bytes32 poolId) external view returns (
        bool isActive,
        uint256 rate,
        uint256 slippageBps
    ) {
        PoolConfig storage pool = pools[poolId];
        return (pool.isActive, pool.rate, pool.slippageBps);
    }
    
    // Emergency: Deactivate a pool
    function deactivatePool(bytes32 poolId) external onlyOwner {
        pools[poolId].isActive = false;
    }
    
    // Emergency: Reactivate a pool
    function reactivatePool(bytes32 poolId) external onlyOwner {
        require(pools[poolId].rate > 0, "Pool doesn't exist");
        pools[poolId].isActive = true;
    }
    
    // Update pool rate (for testing different scenarios)
    function updatePoolRate(bytes32 poolId, uint256 newRate) external onlyOwner {
        require(pools[poolId].isActive, "Pool not active");
        require(newRate > 0, "Invalid rate");
        pools[poolId].rate = newRate;
    }
    
    // Update slippage (for testing)
    function updatePoolSlippage(bytes32 poolId, uint256 newSlippageBps) external onlyOwner {
        require(pools[poolId].isActive, "Pool not active");
        require(newSlippageBps <= 1000, "Slippage too high"); // Max 10%
        pools[poolId].slippageBps = newSlippageBps;
    }
}
