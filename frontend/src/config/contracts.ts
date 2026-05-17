import { type Address } from 'viem'

export const ADDRESSES = {
  insurancePool: (import.meta.env.VITE_INSURANCE_POOL_ADDRESS ?? '0x0000000000000000000000000000000000000001') as Address,
  governor: (import.meta.env.VITE_GOVERNOR_ADDRESS ?? '0x0000000000000000000000000000000000000002') as Address,
  vault: (import.meta.env.VITE_VAULT_ADDRESS ?? '0x0000000000000000000000000000000000000003') as Address,
  collateralManager: (import.meta.env.VITE_COLLATERAL_MANAGER_ADDRESS ?? '0x0000000000000000000000000000000000000004') as Address,
  governanceToken: (import.meta.env.VITE_GOVERNANCE_TOKEN_ADDRESS ?? '0x0000000000000000000000000000000000000005') as Address,
  usdc: (import.meta.env.VITE_USDC_ADDRESS ?? '0x0000000000000000000000000000000000000006') as Address,
} as const

export const INSURANCE_POOL_ABI = [
  {
    name: 'purchasePolicy',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'policyTypeId', type: 'uint256' },
      { name: 'coverageAmount', type: 'uint256' },
      { name: 'duration', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'triggerPolicy',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'policyId', type: 'uint256' }],
    outputs: [],
  },
  {
    name: 'processClaim',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'policyId', type: 'uint256' }],
    outputs: [],
  },
  {
    name: 'policyTypes',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '', type: 'uint256' }],
    outputs: [
      { name: 'premiumRate', type: 'uint256' },
      { name: 'maxCoverage', type: 'uint256' },
      { name: 'active', type: 'bool' },
    ],
  },
  {
    name: 'policies',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '', type: 'uint256' }],
    outputs: [
      { name: 'holder', type: 'address' },
      { name: 'policyTypeId', type: 'uint256' },
      { name: 'coverageAmount', type: 'uint256' },
      { name: 'premium', type: 'uint256' },
      { name: 'expiry', type: 'uint256' },
      { name: 'status', type: 'uint8' },
    ],
  },
  {
    name: 'nextPolicyId',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'addPolicyType',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'premiumRate', type: 'uint256' },
      { name: 'maxCoverage', type: 'uint256' },
      { name: 'minDuration', type: 'uint256' },
    ],
    outputs: [],
  },
  {
    name: 'pause',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  {
    name: 'unpause',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
] as const

export const VAULT_ABI = [
  {
    name: 'deposit',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'assets', type: 'uint256' },
      { name: 'receiver', type: 'address' },
    ],
    outputs: [{ name: 'shares', type: 'uint256' }],
  },
  {
    name: 'withdraw',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'assets', type: 'uint256' },
      { name: 'receiver', type: 'address' },
      { name: 'owner', type: 'address' },
    ],
    outputs: [{ name: 'shares', type: 'uint256' }],
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'totalAssets',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'convertToAssets',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'shares', type: 'uint256' }],
    outputs: [{ name: 'assets', type: 'uint256' }],
  },
] as const

export const COLLATERAL_MANAGER_ABI = [
  {
    name: 'depositCollateral',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'amount', type: 'uint256' }],
    outputs: [],
  },
  {
    name: 'withdrawCollateral',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'amount', type: 'uint256' }],
    outputs: [],
  },
  {
    name: 'collateralBalances',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'coverageExposure',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: '', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'healthFactor',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'user', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'totalCollateral',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'utilizationRate',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
] as const

export const GOVERNANCE_TOKEN_ABI = [
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'getVotes',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'delegate',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [{ name: 'delegatee', type: 'address' }],
    outputs: [],
  },
  {
    name: 'delegates',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'address' }],
  },
] as const

export const GOVERNOR_ABI = [
  {
    name: 'castVote',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'proposalId', type: 'uint256' },
      { name: 'support', type: 'uint8' },
    ],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'propose',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'targets', type: 'address[]' },
      { name: 'values', type: 'uint256[]' },
      { name: 'calldatas', type: 'bytes[]' },
      { name: 'description', type: 'string' },
    ],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'state',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'proposalId', type: 'uint256' }],
    outputs: [{ name: '', type: 'uint8' }],
  },
  {
    name: 'proposalThreshold',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'quorum',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'blockNumber', type: 'uint256' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
] as const

export const ERC20_ABI = [
  {
    name: 'approve',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool' }],
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ name: '', type: 'uint256' }],
  },
  {
    name: 'allowance',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
    ],
    outputs: [{ name: '', type: 'uint256' }],
  },
] as const
