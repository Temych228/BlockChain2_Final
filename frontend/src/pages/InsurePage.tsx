import { useState } from 'react'
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { useReadContract } from 'wagmi'
import { parseUnits, formatUnits } from 'viem'
import { ADDRESSES, INSURANCE_POOL_ABI, ERC20_ABI } from '../config/contracts'
import { usePoliciesByHolder } from '../hooks/useSubgraph'
import { useBufferedGasPrice } from '../hooks/useGasPrice'
import { parseError } from '../utils/errors'

const POLICY_STATUS_LABELS: Record<string, string> = {
  '0': 'Active',
  '1': 'Triggered',
  '2': 'Claimed',
  '3': 'Expired',
  Active: 'Active',
  Triggered: 'Triggered',
  Claimed: 'Claimed',
  Expired: 'Expired',
}

export function InsurePage() {
  const { address, isConnected } = useAccount()

  const [policyTypeId, setPolicyTypeId] = useState('0')
  const [coverageAmount, setCoverageAmount] = useState('')
  const [duration, setDuration] = useState('')
  const [error, setError] = useState<string | null>(null)
  const [successMsg, setSuccessMsg] = useState<string | null>(null)

  const gasPrice = useBufferedGasPrice()

  const { data: policies, isLoading: policiesLoading, isError: policiesError } =
    usePoliciesByHolder(address)

  const { data: allowance } = useReadContract({
    address: ADDRESSES.usdc,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address ? [address, ADDRESSES.insurancePool] : undefined,
    query: { enabled: !!address, refetchInterval: 4000 },
  })

  const { data: usdcBalance } = useReadContract({
    address: ADDRESSES.usdc,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address, refetchInterval: 4000 },
  })

  const {
    writeContract: approve,
    data: approveTxHash,
    isPending: approveLoading,
  } = useWriteContract()

  const { isLoading: approveConfirming } = useWaitForTransactionReceipt({
    hash: approveTxHash,
  })

  const {
    writeContract: purchase,
    data: purchaseTxHash,
    isPending: purchaseLoading,
  } = useWriteContract()

  const { isLoading: purchaseConfirming } = useWaitForTransactionReceipt({
    hash: purchaseTxHash,
  })

  const parsedCoverage = coverageAmount ? parseUnits(coverageAmount, 6) : 0n
  const parsedDuration = duration ? BigInt(Math.floor(Number(duration) * 86400)) : 0n

  const needsApproval =
    allowance !== undefined && parsedCoverage > 0n && (allowance as bigint) < parsedCoverage

  const handleApprove = () => {
    setError(null)
    setSuccessMsg(null)
    approve(
      {
        address: ADDRESSES.usdc,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [ADDRESSES.insurancePool, parsedCoverage],
        ...(gasPrice ? { gasPrice } : {}),
      },
      {
        onSuccess: () => setSuccessMsg('USDC approval confirmed.'),
        onError: (err) => setError(parseError(err)),
      }
    )
  }

  const handlePurchase = () => {
    setError(null)
    setSuccessMsg(null)
    purchase(
      {
        address: ADDRESSES.insurancePool,
        abi: INSURANCE_POOL_ABI,
        functionName: 'purchasePolicy',
        args: [BigInt(policyTypeId), parsedCoverage, parsedDuration],
        ...(gasPrice ? { gasPrice } : {}),
      },
      {
        onSuccess: () => setSuccessMsg('Policy purchased successfully!'),
        onError: (err) => setError(parseError(err)),
      }
    )
  }

  if (!isConnected) {
    return (
      <div className="page">
        <h1>Get Insured</h1>
        <div className="connect-prompt">
          <p>Connect your wallet to purchase insurance policies.</p>
        </div>
      </div>
    )
  }

  return (
    <div className="page insure-page">
      <h1>Get Insured</h1>

      <section className="card form-card">
        <h2>Purchase Policy</h2>

        <div className="form-group">
          <label htmlFor="policyType">Policy Type ID</label>
          <input
            id="policyType"
            type="number"
            min="0"
            value={policyTypeId}
            onChange={(e) => setPolicyTypeId(e.target.value)}
            placeholder="0"
          />
        </div>

        <div className="form-group">
          <label htmlFor="coverage">Coverage Amount (USDC)</label>
          <input
            id="coverage"
            type="number"
            min="0"
            step="0.01"
            value={coverageAmount}
            onChange={(e) => setCoverageAmount(e.target.value)}
            placeholder="1000.00"
          />
          {usdcBalance !== undefined && (
            <span className="input-hint">
              Balance: {parseFloat(formatUnits(usdcBalance as bigint, 6)).toFixed(2)} USDC
            </span>
          )}
        </div>

        <div className="form-group">
          <label htmlFor="duration">Duration (days)</label>
          <input
            id="duration"
            type="number"
            min="1"
            value={duration}
            onChange={(e) => setDuration(e.target.value)}
            placeholder="30"
          />
        </div>

        <div className="form-actions">
          {needsApproval ? (
            <button
              className="btn btn-primary"
              disabled={approveLoading || approveConfirming || parsedCoverage === 0n}
              onClick={handleApprove}
            >
              {approveLoading || approveConfirming ? 'Approving...' : 'Approve USDC'}
            </button>
          ) : (
            <button
              className="btn btn-primary"
              disabled={purchaseLoading || purchaseConfirming || parsedCoverage === 0n || parsedDuration === 0n}
              onClick={handlePurchase}
            >
              {purchaseLoading || purchaseConfirming ? 'Purchasing...' : 'Purchase Policy'}
            </button>
          )}
        </div>

        {error && <div className="alert alert-error">{error}</div>}
        {successMsg && <div className="alert alert-success">{successMsg}</div>}
      </section>

      <section className="card">
        <h2>Your Policies</h2>
        {policiesLoading && <p className="loading-text">Loading policies...</p>}
        {policiesError && <p className="error-text">Subgraph unavailable — cannot load policies.</p>}
        {policies?.policies && policies.policies.length === 0 && (
          <p className="empty-text">No policies found.</p>
        )}
        {policies?.policies && policies.policies.length > 0 && (
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Type</th>
                  <th>Coverage</th>
                  <th>Premium</th>
                  <th>Expires</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {policies.policies.map((p) => (
                  <tr key={p.id}>
                    <td>#{p.id}</td>
                    <td>{p.policyTypeId}</td>
                    <td>${parseFloat(formatUnits(BigInt(p.coverageAmount), 6)).toFixed(2)}</td>
                    <td>${parseFloat(formatUnits(BigInt(p.premium), 6)).toFixed(2)}</td>
                    <td>{new Date(Number(p.expiry) * 1000).toLocaleDateString()}</td>
                    <td>
                      <span className={`status-badge status-${p.status.toLowerCase()}`}>
                        {POLICY_STATUS_LABELS[p.status] ?? p.status}
                      </span>
                    </td>
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
