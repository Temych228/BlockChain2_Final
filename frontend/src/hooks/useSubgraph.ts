import { useQuery } from '@tanstack/react-query'
import { type Address } from 'viem'

const SUBGRAPH_URL = import.meta.env.VITE_SUBGRAPH_URL ?? ''
const isSubgraphConfigured = SUBGRAPH_URL !== '' && !SUBGRAPH_URL.includes('YOUR_ID')

interface SubgraphResponse<T> {
  data?: T
  errors?: Array<{ message: string }>
}

async function querySubgraph<T>(query: string, variables?: Record<string, unknown>): Promise<T> {
  if (!isSubgraphConfigured) {
    throw new Error('Subgraph not deployed yet')
  }
  const res = await fetch(SUBGRAPH_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ query, variables }),
  })

  if (!res.ok) {
    throw new Error('Subgraph unavailable')
  }

  const json: SubgraphResponse<T> = await res.json()

  if (json.errors?.length) {
    throw new Error(json.errors[0].message)
  }

  if (!json.data) {
    throw new Error('Subgraph returned no data')
  }

  return json.data
}

// ─── Types ───────────────────────────────────────────────

export interface Policy {
  id: string
  holder: string
  policyTypeId: string
  coverageAmount: string
  premium: string
  expiry: string
  status: string
  createdAt: string
}

export interface UnderwriterPosition {
  id: string
  underwriter: string
  collateral: string
  sharesOwned: string
}

export interface Claim {
  id: string
  policy: { id: string; holder: string }
  amount: string
  status: string
  triggeredAt: string
  paidAt: string | null
}

export interface Proposal {
  id: string
  proposalId: string
  proposer: string
  description: string
  state: string
  forVotes: string
  againstVotes: string
  abstainVotes: string
  startBlock: string
  endBlock: string
  createdAt: string
}

export interface ProtocolStats {
  protocolStat: {
    id: string
    totalPolicies: string
    totalCollateral: string
    totalClaimsPaid: string
    totalPremiums: string
  } | null
}

// ─── Hooks ───────────────────────────────────────────────

export function useProtocolStats() {
  return useQuery({
    queryKey: ['subgraph', 'protocolStats'],
    queryFn: () =>
      querySubgraph<ProtocolStats>(`{
        protocolStat: protocolStats(id: "protocol") {
          id
          totalPolicies: totalPoliciesCreated
          totalCollateral
          totalClaimsPaid
          totalPremiums: totalPremiumsCollected
          lastUpdatedBlock
        }
      }`).then((data) => ({
        protocolStat: data.protocolStat
          ? { ...data.protocolStat }
          : null,
      })),
    refetchInterval: 30_000,
    retry: 2,
    meta: { errorMessage: 'Subgraph unavailable' },
  })
}

export function usePoliciesByHolder(holder: Address | undefined) {
  return useQuery({
    queryKey: ['subgraph', 'policies', holder],
    queryFn: () =>
      querySubgraph<{ policies: Policy[] }>(
        `query PoliciesByHolder($holder: Bytes!) {
          policies(
            where: { holder: $holder }
            orderBy: createdAt
            orderDirection: desc
          ) {
            id
            holder
            policyTypeId
            coverageAmount
            premium: premiumPaid
            expiry
            status: state
            createdAt
          }
        }`,
        { holder: holder!.toLowerCase() }
      ),
    enabled: !!holder,
    refetchInterval: 30_000,
    retry: 2,
  })
}

export function usePendingClaims() {
  return useQuery({
    queryKey: ['subgraph', 'pendingClaims'],
    queryFn: () =>
      querySubgraph<{ claims: Claim[] }>(`{
        claims(
          where: { status: PENDING }
          orderBy: triggeredAt
          orderDirection: desc
        ) {
          id
          policy { id holder }
          amount
          status
          triggeredAt
          paidAt: processedAt
        }
      }`),
    refetchInterval: 30_000,
    retry: 2,
  })
}

export function useProposals(state?: string) {
  const whereClause = state
    ? `(where: { state: ${state} }, orderBy: createdAt, orderDirection: desc)`
    : '(orderBy: createdAt, orderDirection: desc)'
  return useQuery({
    queryKey: ['subgraph', 'proposals', state],
    queryFn: () =>
      querySubgraph<{ governanceProposals: Proposal[] }>(`{
        governanceProposals${whereClause} {
          proposalId: id
          id
          proposer
          description
          state
          forVotes
          againstVotes
          abstainVotes
          startBlock
          endBlock
          createdAt
        }
      }`).then((data) => ({ proposals: data.governanceProposals })),
    refetchInterval: 30_000,
    retry: 2,
  })
}

export function useTopUnderwriters() {
  return useQuery({
    queryKey: ['subgraph', 'topUnderwriters'],
    queryFn: () =>
      querySubgraph<{ underwriterPositions: UnderwriterPosition[] }>(`{
        underwriterPositions(
          orderBy: collateralAmount
          orderDirection: desc
          first: 20
        ) {
          id
          underwriter
          collateral: collateralAmount
          sharesOwned
        }
      }`),
    refetchInterval: 30_000,
    retry: 2,
  })
}
