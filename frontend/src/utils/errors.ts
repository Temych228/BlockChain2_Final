import { BaseError, ContractFunctionRevertedError } from 'viem'

const REVERT_MESSAGES: Record<string, string> = {
  InsufficientHealthFactor: 'Your health factor would drop too low.',
  ExposureLimitExceeded: 'Coverage exceeds your collateral limit.',
  PolicyTypeInactive: 'This policy type is not available.',
  PolicyExpired: 'This policy has expired.',
  PolicyNotActive: 'This policy is not active.',
  PolicyNotTriggered: 'This policy has not been triggered.',
  AlreadyClaimed: 'This policy has already been claimed.',
  InsufficientCollateral: 'Insufficient collateral balance.',
  InsufficientBalance: 'Insufficient USDC balance.',
  AmountTooLow: 'Amount is below the minimum required.',
  Unauthorized: 'You are not authorized to perform this action.',
  Paused: 'The protocol is currently paused.',
  InvalidPolicyType: 'Invalid policy type selected.',
  CoverageExceedsMax: 'Coverage amount exceeds maximum allowed.',
  DurationTooShort: 'Policy duration is too short.',
  ZeroAmount: 'Amount must be greater than zero.',
}

export function parseError(error: unknown): string {
  if (!error) return 'An unknown error occurred.'

  const message = error instanceof Error ? error.message : String(error)

  if (
    message.includes('User rejected') ||
    message.includes('user rejected') ||
    message.includes('ACTION_REJECTED') ||
    message.includes('UserRejectedRequestError')
  ) {
    return 'Transaction cancelled.'
  }

  if (
    message.includes('chain') ||
    message.includes('network') ||
    message.includes('ChainMismatchError') ||
    message.includes('SwitchChainError')
  ) {
    return 'Please switch to Arbitrum Sepolia.'
  }

  if (
    message.includes('insufficient funds') ||
    message.includes('exceeds balance') ||
    message.includes('InsufficientFundsError')
  ) {
    return 'Insufficient USDC balance.'
  }

  if (
    message.includes('nonce') ||
    message.includes('replacement')
  ) {
    return 'Transaction conflict. Please wait for pending transactions to complete.'
  }

  if (error instanceof BaseError) {
    const revertError = error.walk(
      (e) => e instanceof ContractFunctionRevertedError
    )
    if (revertError instanceof ContractFunctionRevertedError) {
      const errorName = revertError.data?.errorName
      if (errorName && REVERT_MESSAGES[errorName]) {
        return REVERT_MESSAGES[errorName]
      }
      if (revertError.reason) {
        return revertError.reason
      }
    }
  }

  for (const [key, msg] of Object.entries(REVERT_MESSAGES)) {
    if (message.includes(key)) return msg
  }

  if (message.includes('gas')) {
    return 'Transaction ran out of gas. Please try again.'
  }

  if (message.includes('timeout') || message.includes('TIMEOUT')) {
    return 'Network request timed out. Please try again.'
  }

  return 'Transaction failed. Please try again.'
}
