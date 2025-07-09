import React, { useState, useEffect } from 'react';
import { Fingerprint, Shield, ArrowUpDown, Send, Plus, Settings, Eye, EyeOff, Wallet, TrendingUp, History, Zap, RefreshCw } from 'lucide-react';

const BilleteraIO = () => {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [currentView, setCurrentView] = useState('dashboard');
  const [balance, setBalance] = useState({ eth: 2.847, usdc: 1250.32, dai: 890.15 });
  const [isLoading, setIsLoading] = useState(false);
  const [swapAmount, setSwapAmount] = useState('');
  const [fromToken, setFromToken] = useState('ETH');
  const [toToken, setToToken] = useState('USDC');
  const [showBalance, setShowBalance] = useState(true);
  const [transactions, setTransactions] = useState([
    { id: 1, type: 'swap', from: 'ETH', to: 'USDC', amount: '0.5', value: '$1,235.50', time: '2 mins ago', status: 'completed' },
    { id: 2, type: 'bridge', from: 'Ethereum', to: 'Polygon', amount: '100 USDC', value: '$100.00', time: '1 hour ago', status: 'completed' },
    { id: 3, type: 'send', to: '0x742d...8f3a', amount: '0.1 ETH', value: '$247.10', time: '3 hours ago', status: 'completed' },
  ]);

  const protocols = [
    { name: 'Ethereum', symbol: 'ETH', color: 'bg-blue-500' },
    { name: 'Polygon', symbol: 'MATIC', color: 'bg-purple-500' },
    { name: 'Arbitrum', symbol: 'ARB', color: 'bg-blue-600' },
    { name: 'Optimism', symbol: 'OP', color: 'bg-red-500' },
    { name: 'Base', symbol: 'BASE', color: 'bg-blue-400' },
  ];

  const tokens = ['ETH', 'USDC', 'DAI', 'WBTC', 'LINK', 'UNI', 'AAVE'];

  const handleBiometricAuth = async () => {
    setIsLoading(true);
    try {
      if (navigator.credentials && navigator.credentials.create) {
        setTimeout(() => {
          setIsAuthenticated(true);
          setIsLoading(false);
        }, 2000);
      } else {
        setTimeout(() => {
          setIsAuthenticated(true);
          setIsLoading(false);
        }, 2000);
      }
    } catch (error) {
      console.error('Biometric authentication failed:', error);
      setIsLoading(false);
    }
  };

  const handleSwap = async () => {
    if (!swapAmount || parseFloat(swapAmount) <= 0) return;
    
    setIsLoading(true);
    
    setTimeout(() => {
      const newTransaction = {
        id: transactions.length + 1,
        type: 'swap',
        from: fromToken,
        to: toToken,
        amount: swapAmount,
        value: `$${(parseFloat(swapAmount) * 2471).toFixed(2)}`,
        time: 'Just now',
        status: 'completed'
      };
      
      setTransactions([newTransaction, ...transactions]);
      setSwapAmount('');
      setIsLoading(false);
    }, 3000);
  };

  if (!isAuthenticated) {
    return (
      <div className="min-h-screen bg-gradient-to-br from-blue-900 via-purple-900 to-indigo-900 flex items-center justify-center p-4">
        <div className="max-w-md w-full bg-white/10 backdrop-blur-lg rounded-3xl p-8 text-center border border-white/20">
          <div className="mb-8">
            <div className="w-20 h-20 bg-gradient-to-r from-blue-500 to-purple-600 rounded-full flex items-center justify-center mx-auto mb-4">
              <Wallet className="w-10 h-10 text-white" />
            </div>
            <h1 className="text-3xl font-bold text-white mb-2">Billetera IO</h1>
            <p className="text-blue-200">Biometric DeFi Wallet</p>
          </div>
          
          <div className="space-y-6">
            <div className="bg-white/10 rounded-2xl p-6 border border-white/20">
              <Shield className="w-12 h-12 text-blue-400 mx-auto mb-4" />
              <h3 className="text-xl font-semibold text-white mb-2">Secure Authentication</h3>
              <p className="text-blue-200 text-sm">Your wallet is protected by biometric authentication</p>
            </div>
            
            <button
              onClick={handleBiometricAuth}
              disabled={isLoading}
              className="w-full bg-gradient-to-r from-blue-500 to-purple-600 text-white py-4 px-6 rounded-2xl font-semibold text-lg hover:from-blue-600 hover:to-purple-700 transition-all duration-300 flex items-center justify-center space-x-2 disabled:opacity-50"
            >
              {isLoading ? (
                <RefreshCw className="w-5 h-5 animate-spin" />
              ) : (
                <Fingerprint className="w-6 h-6" />
              )}
              <span>{isLoading ? 'Authenticating...' : 'Authenticate with Biometrics'}</span>
            </button>
            
            <div className="text-xs text-blue-300">
              <p>✓ Uniswap V4 Integration</p>
              <p>✓ Cross-Protocol Swaps</p>
              <p>✓ Ultra-Low Fees</p>
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-blue-900 to-indigo-900">
      <div className="bg-black/20 backdrop-blur-lg border-b border-white/10 p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center space-x-3">
            <div className="w-8 h-8 bg-gradient-to-r from-blue-500 to-purple-600 rounded-full flex items-center justify-center">
              <Wallet className="w-4 h-4 text-white" />
            </div>
            <h1 className="text-xl font-bold text-white">Billetera IO</h1>
          </div>
          <div className="flex items-center space-x-2">
            <div className="flex items-center space-x-1 bg-green-500/20 text-green-400 px-3 py-1 rounded-full text-sm">
              <div className="w-2 h-2 bg-green-400 rounded-full"></div>
              <span>Connected</span>
            </div>
            <button
              onClick={() => setCurrentView('settings')}
              className="p-2 hover:bg-white/10 rounded-full transition-colors"
            >
              <Settings className="w-5 h-5 text-white" />
            </button>
          </div>
        </div>
      </div>

      <div className="bg-black/20 backdrop-blur-lg border-b border-white/10 p-4">
        <div className="flex space-x-1">
          {[
            { key: 'dashboard', label: 'Dashboard', icon: TrendingUp },
            { key: 'swap', label: 'Swap', icon: ArrowUpDown },
            { key: 'bridge', label: 'Bridge', icon: RefreshCw },
            { key: 'history', label: 'History', icon: History },
          ].map(({ key, label, icon: Icon }) => (
            <button
              key={key}
              onClick={() => setCurrentView(key)}
              className={`flex items-center space-x-2 px-4 py-2 rounded-xl transition-all ${
                currentView === key
                  ? 'bg-blue-500/20 text-blue-400 border border-blue-500/30'
                  : 'text-white/70 hover:text-white hover:bg-white/10'
              }`}
            >
              <Icon className="w-4 h-4" />
              <span className="font-medium">{label}</span>
            </button>
          ))}
        </div>
      </div>

      <div className="p-4">
        {currentView === 'dashboard' && (
          <div className="space-y-6">
            <div className="bg-gradient-to-r from-blue-500/20 to-purple-600/20 backdrop-blur-lg rounded-3xl p-6 border border-white/10">
              <div className="flex items-center justify-between mb-4">
                <h2 className="text-lg font-semibold text-white">Total Balance</h2>
                <button
                  onClick={() => setShowBalance(!showBalance)}
                  className="p-2 hover:bg-white/10 rounded-full transition-colors"
                >
                  {showBalance ? <Eye className="w-5 h-5 text-white" /> : <EyeOff className="w-5 h-5 text-white" />}
                </button>
              </div>
              <div className="text-3xl font-bold text-white mb-2">
                {showBalance ? '$4,387.97' : '••••••'}
              </div>
              <div className="text-green-400 text-sm">+2.45% today</div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {Object.entries(balance).map(([token, amount]) => (
                <div key={token} className="bg-black/20 backdrop-blur-lg rounded-2xl p-4 border border-white/10">
                  <div className="flex items-center space-x-3">
                    <div className="w-10 h-10 bg-gradient-to-r from-blue-500 to-purple-600 rounded-full flex items-center justify-center">
                      <span className="text-white font-bold text-sm">{token.toUpperCase()}</span>
                    </div>
                    <div>
                      <div className="text-white font-semibold">{showBalance ? amount.toFixed(3) : '•••••'}</div>
                      <div className="text-white/60 text-sm">{token.toUpperCase()}</div>
                    </div>
                  </div>
                </div>
              ))}
            </div>

            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {[
                { label: 'Swap', icon: ArrowUpDown, action: () => setCurrentView('swap') },
                { label: 'Bridge', icon: RefreshCw, action: () => setCurrentView('bridge') },
                { label: 'Send', icon: Send, action: () => {} },
                { label: 'Add Token', icon: Plus, action: () => {} },
              ].map(({ label, icon: Icon, action }) => (
                <button
                  key={label}
                  onClick={action}
                  className="bg-black/20 backdrop-blur-lg rounded-2xl p-4 border border-white/10 hover:bg-white/10 transition-all group"
                >
                  <Icon className="w-6 h-6 text-blue-400 mx-auto mb-2 group-hover:scale-110 transition-transform" />
                  <div className="text-white font-medium">{label}</div>
                </button>
              ))}
            </div>

            <div className="bg-black/20 backdrop-blur-lg rounded-2xl p-6 border border-white/10">
              <h3 className="text-lg font-semibold text-white mb-4">Recent Transactions</h3>
              <div className="space-y-3">
                {transactions.slice(0, 3).map((tx) => (
                  <div key={tx.id} className="flex items-center space-x-3 p-3 hover:bg-white/5 rounded-xl transition-colors">
                    <div className="w-10 h-10 bg-gradient-to-r from-green-500 to-blue-500 rounded-full flex items-center justify-center">
                      <ArrowUpDown className="w-5 h-5 text-white" />
                    </div>
                    <div className="flex-1">
                      <div className="text-white font-medium">{tx.type === 'swap' ? `${tx.from} → ${tx.to}` : tx.type}</div>
                      <div className="text-white/60 text-sm">{tx.time}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-white font-medium">{tx.amount}</div>
                      <div className="text-white/60 text-sm">{tx.value}</div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}

        {currentView === 'swap' && (
          <div className="max-w-md mx-auto">
            <div className="bg-black/20 backdrop-blur-lg rounded-3xl p-6 border border-white/10">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-semibold text-white">Swap Tokens</h2>
                <div className="flex items-center space-x-1 bg-green-500/20 text-green-400 px-3 py-1 rounded-full text-sm">
                  <Zap className="w-4 h-4" />
                  <span>Uniswap V4</span>
                </div>
              </div>

              <div className="space-y-4">
                <div className="bg-white/5 rounded-2xl p-4 border border-white/10">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-white/60 text-sm">From</span>
                    <span className="text-white/60 text-sm">Balance: {balance.eth}</span>
                  </div>
                  <div className="flex items-center space-x-3">
                    <select
                      value={fromToken}
                      onChange={(e) => setFromToken(e.target.value)}
                      className="bg-transparent text-white font-semibold text-lg border-none outline-none"
                    >
                      {tokens.map((token) => (
                        <option key={token} value={token} className="bg-slate-800">{token}</option>
                      ))}
                    </select>
                    <input
                      type="number"
                      value={swapAmount}
                      onChange={(e) => setSwapAmount(e.target.value)}
                      placeholder="0.0"
                      className="bg-transparent text-white text-lg font-semibold text-right flex-1 outline-none"
                    />
                  </div>
                </div>

                <div className="flex justify-center">
                  <button
                    onClick={() => {
                      setFromToken(toToken);
                      setToToken(fromToken);
                    }}
                    className="bg-blue-500/20 hover:bg-blue-500/30 p-3 rounded-full transition-colors"
                  >
                    <ArrowUpDown className="w-5 h-5 text-blue-400" />
                  </button>
                </div>

                <div className="bg-white/5 rounded-2xl p-4 border border-white/10">
                  <div className="flex items-center justify-between mb-2">
                    <span className="text-white/60 text-sm">To</span>
                    <span className="text-white/60 text-sm">Balance: {balance.usdc}</span>
                  </div>
                  <div className="flex items-center space-x-3">
                    <select
                      value={toToken}
                      onChange={(e) => setToToken(e.target.value)}
                      className="bg-transparent text-white font-semibold text-lg border-none outline-none"
                    >
                      {tokens.map((token) => (
                        <option key={token} value={token} className="bg-slate-800">{token}</option>
                      ))}
                    </select>
                    <div className="text-white/60 text-lg text-right flex-1">
                      {swapAmount ? (parseFloat(swapAmount) * 2471).toFixed(2) : '0.0'}
                    </div>
                  </div>
                </div>

                <div className="bg-white/5 rounded-2xl p-4 border border-white/10 space-y-2">
                  <div className="flex justify-between text-sm">
                    <span className="text-white/60">Rate</span>
                    <span className="text-white">1 ETH = 2,471 USDC</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-white/60">Network Fee</span>
                    <span className="text-green-400">~$0.45</span>
                  </div>
                  <div className="flex justify-between text-sm">
                    <span className="text-white/60">Price Impact</span>
                    <span className="text-green-400">&lt; 0.01%</span>
                  </div>
                </div>

                <button
                  onClick={handleSwap}
                  disabled={!swapAmount || isLoading}
                  className="w-full bg-gradient-to-r from-blue-500 to-purple-600 text-white py-4 px-6 rounded-2xl font-semibold text-lg hover:from-blue-600 hover:to-purple-700 transition-all duration-300 flex items-center justify-center space-x-2 disabled:opacity-50"
                >
                  {isLoading ? (
                    <RefreshCw className="w-5 h-5 animate-spin" />
                  ) : (
                    <ArrowUpDown className="w-5 h-5" />
                  )}
                  <span>{isLoading ? 'Swapping...' : 'Swap Tokens'}</span>
                </button>
              </div>
            </div>
          </div>
        )}

        {currentView === 'bridge' && (
          <div className="max-w-md mx-auto">
            <div className="bg-black/20 backdrop-blur-lg rounded-3xl p-6 border border-white/10">
              <h2 className="text-xl font-semibold text-white mb-6">Cross-Protocol Bridge</h2>
              
              <div className="space-y-4">
                <div className="bg-white/5 rounded-2xl p-4 border border-white/10">
                  <div className="text-white/60 text-sm mb-2">From Network</div>
                  <div className="grid grid-cols-2 gap-2">
                    {protocols.slice(0, 2).map((protocol) => (
                      <button
                        key={protocol.name}
                        className="flex items-center space-x-2 p-3 bg-white/5 rounded-xl hover:bg-white/10 transition-colors"
                      >
                        <div className={`w-4 h-4 ${protocol.color} rounded-full`}></div>
                        <span className="text-white font-medium">{protocol.name}</span>
                      </button>
                    ))}
                  </div>
                </div>

                <div className="bg-white/5 rounded-2xl p-4 border border-white/10">
                  <div className="text-white/60 text-sm mb-2">To Network</div>
                  <div className="grid grid-cols-2 gap-2">
                    {protocols.slice(2).map((protocol) => (
                      <button
                        key={protocol.name}
                        className="flex items-center space-x-2 p-3 bg-white/5 rounded-xl hover:bg-white/10 transition-colors"
                      >
                        <div className={`w-4 h-4 ${protocol.color} rounded-full`}></div>
                        <span className="text-white font-medium">{protocol.name}</span>
                      </button>
                    ))}
                  </div>
                </div>

                <div className="bg-white/5 rounded-2xl p-4 border border-white/10">
                  <div className="text-white/60 text-sm mb-2">Amount</div>
                  <div className="flex items-center space-x-3">
                    <input
                      type="number"
                      placeholder="0.0"
                      className="bg-transparent text-white text-lg font-semibold flex-1 outline-none"
                    />
                    <select className="bg-transparent text-white border-none outline-none">
                      <option value="USDC" className="bg-slate-800">USDC</option>
                      <option value="ETH" className="bg-slate-800">ETH</option>
                      <option value="DAI" className="bg-slate-800">DAI</option>
                    </select>
                  </div>
                </div>

                <button className="w-full bg-gradient-to-r from-blue-500 to-purple-600 text-white py-4 px-6 rounded-2xl font-semibold text-lg hover:from-blue-600 hover:to-purple-700 transition-all duration-300">
                  Bridge Tokens
                </button>
              </div>
            </div>
          </div>
        )}

        {currentView === 'history' && (
          <div className="max-w-2xl mx-auto">
            <div className="bg-black/20 backdrop-blur-lg rounded-3xl p-6 border border-white/10">
              <h2 className="text-xl font-semibold text-white mb-6">Transaction History</h2>
              
              <div className="space-y-3">
                {transactions.map((tx) => (
                  <div key={tx.id} className="flex items-center space-x-4 p-4 bg-white/5 rounded-xl border border-white/10">
                    <div className="w-12 h-12 bg-gradient-to-r from-blue-500 to-purple-600 rounded-full flex items-center justify-center">
                      <ArrowUpDown className="w-6 h-6 text-white" />
                    </div>
                    <div className="flex-1">
                      <div className="text-white font-medium">
                        {tx.type === 'swap' ? `${tx.from} → ${tx.to}` : 
                         tx.type === 'bridge' ? `Bridge: ${tx.from} → ${tx.to}` : 
                         `Send to ${tx.to}`}
                      </div>
                      <div className="text-white/60 text-sm">{tx.time}</div>
                    </div>
                    <div className="text-right">
                      <div className="text-white font-medium">{tx.amount}</div>
                      <div className="text-white/60 text-sm">{tx.value}</div>
                    </div>
                    <div className={`px-3 py-1 rounded-full text-xs font-medium ${
                      tx.status === 'completed' ? 'bg-green-500/20 text-green-400' : 
                      tx.status === 'pending' ? 'bg-yellow-500/20 text-yellow-400' : 
                      'bg-red-500/20 text-red-400'
                    }`}>
                      {tx.status}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default function Home() {
  return <BilleteraIO />;
}
