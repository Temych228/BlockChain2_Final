import { useAccount, useConnect, useDisconnect, useSwitchChain, useBalance } from 'wagmi'
import { useReadContract } from 'wagmi'
import { arbitrumSepolia } from 'wagmi/chains'
import { formatUnits } from 'viem'
import { ADDRESSES, GOVERNANCE_TOKEN_ABI } from '../config/contracts'
import { parseError } from '../utils/errors'
import { useState } from 'react'

export function WalletConnect() {
  const { address, isConnected, chain } = useAccount()
  const { connectors, connect } = useConnect()
  const { disconnect } = useDisconnect()
  const { switchChain } = useSwitchChain()
  const [connectError, setConnectError] = useState<string | null>(null)
  const [showConnectors, setShowConnectors] = useState(false)

  const { data: usdcBalance } = useBalance({
    address,
    token: ADDRESSES.usdc,
    query: { refetchInterval: 4000 },
  })

  const { data: idaoBalance } = useReadContract({
    address: ADDRESSES.governanceToken,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address, refetchInterval: 4000 },
  })

  const { data: votingPower } = useReadContract({
    address: ADDRESSES.governanceToken,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: 'getVotes',
    args: address ? [address] : undefined,
    query: { enabled: !!address, refetchInterval: 4000 },
  })

  const isWrongChain = isConnected && chain?.id !== arbitrumSepolia.id

  const truncateAddress = (addr: string) =>
    `${addr.slice(0, 6)}...${addr.slice(-4)}`

  const handleConnect = (connectorId: number) => {
    setConnectError(null)
    const connector = connectors[connectorId]
    if (connector) {
      connect(
        { connector },
        {
          onError: (err) => setConnectError(parseError(err)),
        }
      )
    }
    setShowConnectors(false)
  }

  if (!isConnected) {
    return (
      <div className="wallet-connect">
        <div className="wallet-connect-dropdown">
          <button
            className="btn btn-primary"
            onClick={() => setShowConnectors(!showConnectors)}
          >
            Connect Wallet
          </button>
          {showConnectors && (
            <div className="connector-list">
              {connectors.map((connector, i) => (
                <button
                  key={connector.uid}
                  className="btn btn-ghost connector-option"
                  onClick={() => handleConnect(i)}
                >
                  {connector.name}
                </button>
              ))}
            </div>
          )}
        </div>
        {connectError && <p className="error-text">{connectError}</p>}
      </div>
    )
  }

  if (isWrongChain) {
    return (
      <div className="wallet-connect">
        <div className="wallet-info wrong-chain">
          <span className="chain-badge chain-wrong">Wrong Network</span>
          <button
            className="btn btn-warning"
            onClick={() => switchChain({ chainId: arbitrumSepolia.id })}
          >
            Switch to Arbitrum Sepolia
          </button>
          <button className="btn btn-ghost" onClick={() => disconnect()}>
            Disconnect
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="wallet-connect">
      <div className="wallet-info">
        <span className="chain-badge chain-ok">Arbitrum Sepolia</span>
        <div className="wallet-balances">
          {usdcBalance && (
            <span className="balance-tag" title="USDC Balance">
              {parseFloat(formatUnits(usdcBalance.value, usdcBalance.decimals)).toFixed(2)} USDC
            </span>
          )}
          {idaoBalance !== undefined && (
            <span className="balance-tag" title="IDAO Balance">
              {parseFloat(formatUnits(idaoBalance as bigint, 18)).toFixed(2)} IDAO
            </span>
          )}
          {votingPower !== undefined && (
            <span className="balance-tag voting-power" title="Voting Power">
              ⚡ {parseFloat(formatUnits(votingPower as bigint, 18)).toFixed(2)}
            </span>
          )}
        </div>
        <span className="wallet-address">{truncateAddress(address!)}</span>
        <button className="btn btn-ghost btn-sm" onClick={() => disconnect()}>
          Disconnect
        </button>
      </div>
    </div>
  )
}
