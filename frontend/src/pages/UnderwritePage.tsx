import { useState } from 'react'
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi'
import { parseUnits, formatUnits } from 'viem'
import { ADDRESSES, COLLATERAL_MANAGER_ABI, ERC20_ABI } from '../config/contracts'
import { useTopUnderwriters } from '../hooks/useSubgraph'
import { useBufferedGasPrice } from '../hooks/useGasPrice'
import { parseError } from '../utils/errors'

export function UnderwritePage() {
  const { address, isConnected } = useAccount()

  const gasPrice = useBufferedGasPrice()

  const [amount, setAmount] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [successMsg, setSuccessMsg] = useState<string | null>(null)

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

  const { data: allowance } = useReadContract({
    address: ADDRESSES.usdc,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address ? [address, ADDRESSES.collateralManager] : undefined,
    query: { enabled: !!address, refetchInterval: 4000 },
  })

  const { data: usdcBalance } = useReadContract({
    address: ADDRESSES.usdc,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address, refetchInterval: 4000 },
  })

  const { data: topUnderwriters, isLoading: uwLoading, isError: uwError } = useTopUnderwriters()

  const {
    writeContract: approve,
    data: approveTxHash,
    isPending: approveLoading,
  } = useWriteContract()

  const { isLoading: approveConfirming } = useWaitForTransactionReceipt({
    hash: approveTxHash,
  })

  const {
    writeContract: deposit,
    data: depositTxHash,
    isPending: depositLoading,
  } = useWriteContract()

  const { isLoading: depositConfirming } = useWaitForTransactionReceipt({
    hash: depositTxHash,
  })

  const parsedAmount = amount ? parseUnits(amount, 6) : 0n
  const needsApproval =
    allowance !== undefined && parsedAmount > 0n && (allowance as bigint) < parsedAmount

  const hfBigInt = healthFactor !== undefined ? (healthFactor as bigint) : undefined
  const isMaxHF = hfBigInt !== undefined && hfBigInt > 10_000_000n
  const hfValue = hfBigInt !== undefined && !isMaxHF ? Number(hfBigInt) : undefined
  const hfDisplay = hfBigInt === undefined ? '—' : isMaxHF ? '∞ Safe' : (hfValue! / 10000).toFixed(2)
  const hfClass = hfBigInt === undefined
    ? ''
    : isMaxHF || (hfValue !== undefined && hfValue >= 15000)
      ? 'health-green'
      : hfValue !== undefined && hfValue >= 8500
        ? 'health-yellow'
        : 'health-red'

  const formatUsdc = (val: bigint | undefined) => {
    if (val === undefined) return '—'
    return parseFloat(formatUnits(val, 6)).toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    })
  }

  const handleApprove = () => {
    setError(null)
    setSuccessMsg(null)
    approve(
      {
        address: ADDRESSES.usdc,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [ADDRESSES.collateralManager, parsedAmount],
        ...(gasPrice ? { gasPrice } : {}),
      },
      {
        onSuccess: () => setSuccessMsg('USDC approval confirmed.'),
        onError: (err) => setError(parseError(err)),
      }
    )
  }

  const handleDeposit = () => {
    setError(null)
    setSuccessMsg(null)
    deposit(
      {
        address: ADDRESSES.collateralManager,
        abi: COLLATERAL_MANAGER_ABI,
        functionName: 'depositCollateral',
        args: [parsedAmount],
        ...(gasPrice ? { gasPrice } : {}),
      },
      {
        onSuccess: () => {
          setSuccessMsg('Collateral deposited successfully!')
          setAmount('')
        },
        onError: (err) => setError(parseError(err)),
      }
    )
  }

  if (!isConnected) {
    return (
      <div className="page">
        <h1>Underwrite</h1>
        <div className="connect-prompt">
          <p>Connect your wallet to provide collateral and earn premiums.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="page underwrite-page">
      <h1>Underwrite</h1>

      <section className="card-grid three-cols">
        <div className="stat-card">
          <h3>Your Collateral</h3>
          <p className="stat-value">${formatUsdc(collateral as bigint | undefined)}</p>
        </div>
        <div className="stat-card">
          <h3>Your Exposure</h3>
          <p className="stat-value">${formatUsdc(exposure as bigint | undefined)}</p>
        </div>
        <div className="stat-card">
          <h3>Health Factor</h3>
          <p className={`stat-value ${hfClass}`}>{hfDisplay}</p>
          {hfValue !== undefined && !isMaxHF && hfValue < 8500 && (
            <p className="stat-sub health-red">At risk of liquidation</p>
          )}
        </div>
      </section>

      <section className="card form-card">
        <h2>Deposit Collateral</h2>

        <div className="form-group">
          <label htmlFor="depositAmount">Amount (USDC)</label>
          <input
            id="depositAmount"
            type="number"
            min="0"
            step="0.01"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="1000.00"
          />
          {usdcBalance !== undefined && (
            <span className="input-hint">
              Balance: {formatUsdc(usdcBalance as bigint)} USDC
            </span>
          )}
        </div>

        <div className="form-actions">
          {needsApproval ? (
            <button
              className="btn btn-primary"
              disabled={approveLoading || approveConfirming || parsedAmount === 0n}
              onClick={handleApprove}
            >
              {approveLoading || approveConfirming ? 'Approving...' : 'Approve USDC'}
            </button>
          ) : (
            <button
              className="btn btn-primary"
              disabled={depositLoading || depositConfirming || parsedAmount === 0n}
              onClick={handleDeposit}
            >
              {depositLoading || depositConfirming ? 'Depositing...' : 'Deposit Collateral'}
            </button>
          )}
        </div>

        {error && <div className="alert alert-error">{error}</div>}
        {successMsg && <div className="alert alert-success">{successMsg}</div>}
      </section>

      <section className="card">
        <h2>Top Underwriters</h2>
        {uwLoading && <p className="loading-text">Loading...</p>}
        {uwError && <p className="error-text">Subgraph not deployed — top underwriters will appear here once configured.</p>}
        {topUnderwriters?.underwriterPositions && topUnderwriters.underwriterPositions.length > 0 && (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Underwriter</th>
                  <th>Collateral</th>
                  <th>Shares</th>
                </tr>
              </thead>
              <tbody>
                {topUnderwriters.underwriterPositions.map((uw) => (
                    <tr key={uw.id}>
                      <td className="mono">{uw.underwriter.slice(0, 6)}...{uw.underwriter.slice(-4)}</td>
                      <td>${formatUsdc(BigInt(uw.collateral))}</td>
                      <td>{parseFloat(formatUnits(BigInt(uw.sharesOwned), 6)).toLocaleString()}</td>
                    </tr>
                  ))}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </div>
  )
}
