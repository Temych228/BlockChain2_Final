import { useGasPrice as useWagmiGasPrice } from 'wagmi'

/**
 * Arbitrum Sepolia RPC sometimes returns gas estimates that are slightly
 * below the actual baseFee by the time the tx reaches the mempool.
 * This hook returns a 2x buffered gasPrice for use in writeContract calls.
 * Using legacy gasPrice avoids the EIP-1559 maxFeePerGas issue entirely.
 */
export function useBufferedGasPrice() {
  const { data: gasPrice } = useWagmiGasPrice({ watch: true })

  const buffered = gasPrice ? (gasPrice * 200n) / 100n : undefined

  return buffered
}
