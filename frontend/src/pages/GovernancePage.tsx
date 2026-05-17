import { useState } from 'react'
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi'
import { formatUnits } from 'viem'
import {
  ADDRESSES,
  GOVERNOR_ABI,
  GOVERNANCE_TOKEN_ABI,
} from '../config/contracts'
import { useProposals } from '../hooks/useSubgraph'
import { useBufferedGasPrice } from '../hooks/useGasPrice'
import { parseError } from '../utils/errors'

const PROPOSAL_STATE_LABELS: Record<string, string> = {
  '0': 'Pending',
  '1': 'Active',
  '2': 'Canceled',
  '3': 'Defeated',
  '4': 'Succeeded',
  '5': 'Queued',
  '6': 'Expired',
  '7': 'Executed',
  Pending: 'Pending',
  Active: 'Active',
  Canceled: 'Canceled',
  Defeated: 'Defeated',
  Succeeded: 'Succeeded',
  Queued: 'Queued',
  Expired: 'Expired',
  Executed: 'Executed',
}

const STATE_BADGE_CLASS: Record<string, string> = {
  Pending: 'state-pending',
  Active: 'state-active',
  Canceled: 'state-canceled',
  Defeated: 'state-defeated',
  Succeeded: 'state-succeeded',
  Queued: 'state-queued',
  Expired: 'state-expired',
  Executed: 'state-executed',
  '0': 'state-pending',
  '1': 'state-active',
  '2': 'state-canceled',
  '3': 'state-defeated',
  '4': 'state-succeeded',
  '5': 'state-queued',
  '6': 'state-expired',
  '7': 'state-executed',
}

export function GovernancePage() {
  const { address, isConnected } = useAccount()
  const [filterState, setFilterState] = useState<string | undefined>(undefined)
  const [voteError, setVoteError] = useState<string | null>(null)
  const [voteSuccess, setVoteSuccess] = useState<string | null>(null)
  const [delegateError, setDelegateError] = useState<string | null>(null)
  const [delegateSuccess, setDelegateSuccess] = useState<string | null>(null)

  const gasPrice = useBufferedGasPrice()

  const { data: proposals, isLoading, isError } = useProposals(filterState)

  const { data: votingPower } = useReadContract({
    address: ADDRESSES.governanceToken,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: 'getVotes',
    args: address ? [address] : undefined,
    query: { enabled: !!address, refetchInterval: 4000 },
  })

  const { data: currentDelegate } = useReadContract({
    address: ADDRESSES.governanceToken,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: 'delegates',
    args: address ? [address] : undefined,
    query: { enabled: !!address, refetchInterval: 4000 },
  })

  const { data: idaoBalance } = useReadContract({
    address: ADDRESSES.governanceToken,
    abi: GOVERNANCE_TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { enabled: !!address, refetchInterval: 4000 },
  })

  const {
    writeContract: castVote,
    data: voteTxHash,
    isPending: voteLoading,
  } = useWriteContract()

  const { isLoading: voteConfirming } = useWaitForTransactionReceipt({
    hash: voteTxHash,
  })

  const {
    writeContract: delegateTokens,
    data: delegateTxHash,
    isPending: delegateLoading,
  } = useWriteContract()

  const { isLoading: delegateConfirming } = useWaitForTransactionReceipt({
    hash: delegateTxHash,
  })

  const isSelfDelegated =
    currentDelegate !== undefined &&
    address !== undefined &&
    (currentDelegate as string).toLowerCase() === address.toLowerCase()

  const handleVote = (proposalId: string, support: number) => {
    setVoteError(null)
    setVoteSuccess(null)
    castVote(
      {
        address: ADDRESSES.governor,
        abi: GOVERNOR_ABI,
        functionName: 'castVote',
        args: [BigInt(proposalId), support],
        ...(gasPrice ? { gasPrice } : {}),
      },
      {
        onSuccess: () => setVoteSuccess(`Vote cast on proposal #${proposalId}`),
        onError: (err) => setVoteError(parseError(err)),
      }
    )
  }

  const handleDelegate = () => {
    if (!address) return
    setDelegateError(null)
    setDelegateSuccess(null)
    delegateTokens(
      {
        address: ADDRESSES.governanceToken,
        abi: GOVERNANCE_TOKEN_ABI,
        functionName: 'delegate',
        args: [address],
        ...(gasPrice ? { gasPrice } : {}),
      },
      {
        onSuccess: () => setDelegateSuccess('Successfully delegated to yourself!'),
        onError: (err) => setDelegateError(parseError(err)),
      }
    )
  }

  const isActive = (state: string) =>
    state === 'Active' || state === '1'

  return (
    <div className="page governance-page">
      <h1>Governance</h1>

      {isConnected && (
        <section className="card-grid three-cols">
          <div className="stat-card">
            <h3>IDAO Balance</h3>
            <p className="stat-value">
              {idaoBalance !== undefined
                ? parseFloat(formatUnits(idaoBalance as bigint, 18)).toFixed(2)
                : '—'}
            </p>
          </div>
          <div className="stat-card">
            <h3>Voting Power</h3>
            <p className="stat-value">
              {votingPower !== undefined
                ? parseFloat(formatUnits(votingPower as bigint, 18)).toFixed(2)
                : '—'}
            </p>
          </div>
          <div className="stat-card">
            <h3>Delegation</h3>
            <p className="stat-value stat-value-sm">
              {isSelfDelegated
                ? 'Self-delegated'
                : currentDelegate
                  ? `${(currentDelegate as string).slice(0, 6)}...${(currentDelegate as string).slice(-4)}`
                  : 'Not delegated'}
            </p>
            {!isSelfDelegated && (
              <button
                className="btn btn-primary btn-sm"
                disabled={delegateLoading || delegateConfirming}
                onClick={handleDelegate}
              >
                {delegateLoading || delegateConfirming ? 'Delegating...' : 'Delegate to Myself'}
              </button>
            )}
            {delegateError && <p className="error-text">{delegateError}</p>}
            {delegateSuccess && <p className="success-text">{delegateSuccess}</p>}
          </div>
        </section>
      )}

      <section className="card">
        <div className="card-header-row">
          <h2>Proposals</h2>
          <div className="filter-group">
            <select
              value={filterState ?? ''}
              onChange={(e) => setFilterState(e.target.value || undefined)}
            >
              <option value="">All States</option>
              <option value="Active">Active</option>
              <option value="Pending">Pending</option>
              <option value="Succeeded">Succeeded</option>
              <option value="Queued">Queued</option>
              <option value="Executed">Executed</option>
              <option value="Defeated">Defeated</option>
              <option value="Canceled">Canceled</option>
            </select>
          </div>
        </div>

        {voteError && <div className="alert alert-error">{voteError}</div>}
        {voteSuccess && <div className="alert alert-success">{voteSuccess}</div>}

        {isLoading && <p className="loading-text">Loading proposals...</p>}
        {isError && <p className="error-text">Subgraph not deployed — proposals will appear here once the subgraph is configured.</p>}
        {proposals?.proposals && proposals.proposals.length === 0 && (
          <p className="empty-text">No proposals found.</p>
        )}

        <div className="proposals-list">
          {proposals?.proposals?.map((prop) => {
            const stateLabel = PROPOSAL_STATE_LABELS[prop.state] ?? prop.state
            const stateBadgeClass = STATE_BADGE_CLASS[prop.state] ?? 'state-pending'
            const forVotes = parseFloat(formatUnits(BigInt(prop.forVotes), 18))
            const againstVotes = parseFloat(formatUnits(BigInt(prop.againstVotes), 18))
            const abstainVotes = parseFloat(formatUnits(BigInt(prop.abstainVotes), 18))
            const totalVotes = forVotes + againstVotes + abstainVotes
            const forPct = totalVotes > 0 ? (forVotes / totalVotes) * 100 : 0

            return (
              <div key={prop.id} className="proposal-card">
                <div className="proposal-header">
                  <span className={`state-badge ${stateBadgeClass}`}>{stateLabel}</span>
                  <span className="proposal-id">#{prop.proposalId.slice(0, 8)}...</span>
                </div>

                <p className="proposal-desc">{prop.description || 'No description'}</p>

                <div className="vote-bar-container">
                  <div className="vote-bar">
                    <div
                      className="vote-bar-for"
                      style={{ width: `${forPct}%` }}
                    />
                  </div>
                  <div className="vote-counts">
                    <span className="vote-for">For: {forVotes.toFixed(0)}</span>
                    <span className="vote-against">Against: {againstVotes.toFixed(0)}</span>
                    <span className="vote-abstain">Abstain: {abstainVotes.toFixed(0)}</span>
                  </div>
                </div>

                {isConnected && isActive(prop.state) && (
                  <div className="vote-actions">
                    <button
                      className="btn btn-vote-for"
                      disabled={voteLoading || voteConfirming}
                      onClick={() => handleVote(prop.proposalId, 1)}
                    >
                      Vote For
                    </button>
                    <button
                      className="btn btn-vote-against"
                      disabled={voteLoading || voteConfirming}
                      onClick={() => handleVote(prop.proposalId, 0)}
                    >
                      Vote Against
                    </button>
                    <button
                      className="btn btn-vote-abstain"
                      disabled={voteLoading || voteConfirming}
                      onClick={() => handleVote(prop.proposalId, 2)}
                    >
                      Abstain
                    </button>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      </section>

      {!isConnected && (
        <div className="connect-prompt">
          <p>Connect your wallet to vote on proposals and delegate tokens.</p>
        </div>
      )}
    </div>
  )
}
