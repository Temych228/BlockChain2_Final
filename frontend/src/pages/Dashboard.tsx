import { useAccount } from 'wagmi'
import { useReadContract } from 'wagmi'
import { formatUnits } from 'viem'
import { ADDRESSES, VAULT_ABI, COLLATERAL_MANAGER_ABI } from '../config/contracts'
import { useProtocolStats } from '../hooks/useSubgraph'

export function Dashboard() {
  const { address, isConnected } = useAccount()

  const { data: stats, isLoading: statsLoading, isError: statsError } = useProtocolStats()

  const { data: vaultShares } = useReadContract({
    address: ADDRESSES.vault,
    abi: VAULT_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address, refetchInterval: 4000 },
  })

  const { data: sharesValue } = useReadContract({
    address: ADDRESSES.vault,
    abi: VAULT_ABI,
    functionName: 'convertToAssets',
    args: vaultShares ? [vaultShares as bigint] : undefined,
    query: { enabled: !!vaultShares && (vaultShares as bigint) > 0n, refetchInterval: 4000 },
  })

  const { data: collateral } = useReadContract({
    address: ADDRESSES.collateralManager,
    abi: COLLATERAL_MANAGER_ABI,
    functionName: 'collateralBalances',
    args: address ? [address] : undefined,
    query: { enabled: !!address, refetchInterval: 4000 },
  })

  const { data: exposure } = useReadContract({
    address: ADDRESSES.collateralManager,
    abi: COLLATERAL_MANAGER_ABI,
    functionName: 'coverageExposure',
    args: address ? [address] : undefined,
    query: { enabled: !!address, refetchInterval: 4000 },
  })

  const { data: healthFactor } = useReadContract({
    address: ADDRESSES.collateralManager,
    abi: COLLATERAL_MANAGER_ABI,
    functionName: 'healthFactor',
    args: address ? [address] : undefined,
    query: { enabled: !!address, refetchInterval: 4000 },
  })

  const formatUsdc = (val: string | bigint | undefined) => {
    if (val === undefined) return '—'
    const n = typeof val === 'string' ? BigInt(val) : val
    return parseFloat(formatUnits(n, 6)).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  }

  const hfBigInt = healthFactor !== undefined ? (healthFactor as bigint) : undefined
  const isMaxHF = hfBigInt !== undefined && hfBigInt > 10_000_000n
  const hfValue = hfBigInt !== undefined && !isMaxHF ? Number(hfBigInt) : undefined
  const hfClass = hfBigInt === undefined
    ? ''
    : isMaxHF || (hfValue !== undefined && hfValue >= 15000)
      ? 'health-green'
      : hfValue !== undefined && hfValue >= 8500
        ? 'health-yellow'
        : 'health-red'

  return (
    <div className="page dashboard-page">
      <h1>Dashboard</h1>

      <section className="card-grid">
        <div className="stat-card">
          <h3>Total Policies</h3>
          <p className="stat-value">
            {statsLoading ? '...' : statsError ? 'N/A' : stats?.protocolStat?.totalPolicies ?? '0'}
          </p>
          {statsError && <p className="stat-sub">Subgraph not deployed</p>}
        </div>
        <div className="stat-card">
          <h3>Total Collateral</h3>
          <p className="stat-value">
            {statsLoading ? '...' : statsError ? 'N/A' : `$${formatUsdc(stats?.protocolStat?.totalCollateral)}`}
          </p>
          {statsError && <p className="stat-sub">Subgraph not deployed</p>}
        </div>
        <div className="stat-card">
          <h3>Claims Paid</h3>
          <p className="stat-value">
            {statsLoading ? '...' : statsError ? 'N/A' : `$${formatUsdc(stats?.protocolStat?.totalClaimsPaid)}`}
          </p>
          {statsError && <p className="stat-sub">Subgraph not deployed</p>}
        </div>
        <div className="stat-card">
          <h3>Total Premiums</h3>
          <p className="stat-value">
            {statsLoading ? '...' : statsError ? 'N/A' : `$${formatUsdc(stats?.protocolStat?.totalPremiums)}`}
          </p>
          {statsError && <p className="stat-sub">Subgraph not deployed</p>}
        </div>
      </section>

      {isConnected && (
        <>
          <h2>Your Position</h2>
          <section className="card-grid">
            <div className="stat-card">
              <h3>Vault Shares</h3>
              <p className="stat-value">
                {vaultShares !== undefined
                  ? parseFloat(formatUnits(vaultShares as bigint, 6)).toLocaleString()
                  : '—'}
              </p>
              <p className="stat-sub">
                ≈ ${formatUsdc(sharesValue as bigint | undefined)} USDC
              </p>
            </div>
            <div className="stat-card">
              <h3>Collateral</h3>
              <p className="stat-value">${formatUsdc(collateral as bigint | undefined)}</p>
            </div>
            <div className="stat-card">
              <h3>Exposure</h3>
              <p className="stat-value">${formatUsdc(exposure as bigint | undefined)}</p>
            </div>
            <div className="stat-card">
              <h3>Health Factor</h3>
              <p className={`stat-value ${hfClass}`}>
                {hfBigInt === undefined ? '—' : isMaxHF ? '∞ Safe' : (hfValue! / 10000).toFixed(2)}
              </p>
            </div>
          </section>
        </>
      )}

      {!isConnected && (
        <div className="connect-prompt">
          <p>Connect your wallet to view your position.</p>
        </div>
      )}
    </div>
  )
}
