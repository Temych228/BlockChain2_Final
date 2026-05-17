import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import {
  Policy,
  Claim,
  UnderwriterPosition,
  GovernanceProposal,
  ProtocolStats,
} from "../generated/schema";

// ─── Helpers ──────────────────────────────────────────────

function getOrCreateStats(): ProtocolStats {
  let stats = ProtocolStats.load("global");
  if (stats == null) {
    stats = new ProtocolStats("global");
    stats.totalPoliciesCreated = BigInt.zero();
    stats.totalActivePolicies = BigInt.zero();
    stats.totalClaimsPaid = BigInt.zero();
    stats.totalPremiumsCollected = BigInt.zero();
    stats.totalCollateral = BigInt.zero();
    stats.lastUpdatedBlock = BigInt.zero();
  }
  return stats;
}

function getOrCreateUnderwriter(address: Bytes): UnderwriterPosition {
  let id = address.toHexString();
  let position = UnderwriterPosition.load(id);
  if (position == null) {
    position = new UnderwriterPosition(id);
    position.underwriter = address;
    position.collateralAmount = BigInt.zero();
    position.sharesOwned = BigInt.zero();
    position.totalDeposited = BigInt.zero();
    position.totalWithdrawn = BigInt.zero();
    position.lastUpdatedBlock = BigInt.zero();
  }
  return position;
}

// ─── InsurancePool Event Handlers ─────────────────────────

export function handlePolicyPurchased(event: PolicyPurchased): void {
  let policyId = event.params.policyId.toString();
  let policy = new Policy(policyId);

  policy.holder = event.params.holder;
  policy.policyTypeId = event.params.policyTypeId;
  policy.coverageAmount = event.params.coverageAmount;
  policy.premiumPaid = event.params.premium;
  policy.expiry = BigInt.zero(); // Not emitted in event; would need contract call
  policy.state = "ACTIVE";
  policy.createdAt = event.block.timestamp;
  policy.createdAtBlock = event.block.number;
  policy.save();

  let stats = getOrCreateStats();
  stats.totalPoliciesCreated = stats.totalPoliciesCreated.plus(BigInt.fromI32(1));
  stats.totalActivePolicies = stats.totalActivePolicies.plus(BigInt.fromI32(1));
  stats.totalPremiumsCollected = stats.totalPremiumsCollected.plus(
    event.params.premium
  );
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}

export function handlePolicyTriggered(event: PolicyTriggered): void {
  let policyId = event.params.policyId.toString();
  let policy = Policy.load(policyId);
  if (policy == null) return;

  policy.state = "TRIGGERED";
  policy.save();

  // Create a Claim entity with PENDING status
  let claim = new Claim(policyId);
  claim.policy = policyId;
  claim.holder = policy.holder;
  claim.amount = policy.coverageAmount;
  claim.triggeredAt = event.block.timestamp;
  claim.status = "PENDING";
  claim.save();

  // Link claim to policy
  policy.claim = policyId;
  policy.save();
}

export function handleClaimProcessed(event: ClaimProcessed): void {
  let policyId = event.params.policyId.toString();

  // Update Claim
  let claim = Claim.load(policyId);
  if (claim != null) {
    claim.status = "PAID";
    claim.processedAt = event.block.timestamp;
    claim.save();
  }

  // Update Policy
  let policy = Policy.load(policyId);
  if (policy != null) {
    policy.state = "CLAIMED";
    policy.save();
  }

  // Update ProtocolStats
  let stats = getOrCreateStats();
  stats.totalActivePolicies = stats.totalActivePolicies.minus(BigInt.fromI32(1));
  stats.totalClaimsPaid = stats.totalClaimsPaid.plus(event.params.payoutAmount);
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}

// ─── Governor Event Handlers ──────────────────────────────

export function handleProposalCreated(event: ProposalCreated): void {
  let proposalId = event.params.proposalId.toString();
  let proposal = new GovernanceProposal(proposalId);

  proposal.proposer = event.params.proposer;
  proposal.description = event.params.description;
  proposal.state = "PENDING";
  proposal.forVotes = BigInt.zero();
  proposal.againstVotes = BigInt.zero();
  proposal.abstainVotes = BigInt.zero();
  proposal.startBlock = event.params.voteStart;
  proposal.endBlock = event.params.voteEnd;
  proposal.createdAt = event.block.timestamp;
  proposal.save();
}

export function handleVoteCast(event: VoteCast): void {
  let proposalId = event.params.proposalId.toString();
  let proposal = GovernanceProposal.load(proposalId);
  if (proposal == null) return;

  // Update proposal state to ACTIVE when first vote is cast
  proposal.state = "ACTIVE";

  // support: 0 = Against, 1 = For, 2 = Abstain
  let support = event.params.support;
  let weight = event.params.weight;

  if (support == 0) {
    proposal.againstVotes = proposal.againstVotes.plus(weight);
  } else if (support == 1) {
    proposal.forVotes = proposal.forVotes.plus(weight);
  } else if (support == 2) {
    proposal.abstainVotes = proposal.abstainVotes.plus(weight);
  }

  proposal.save();
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  let proposalId = event.params.proposalId.toString();
  let proposal = GovernanceProposal.load(proposalId);
  if (proposal == null) return;

  proposal.state = "EXECUTED";
  proposal.executedAt = event.block.timestamp;
  proposal.save();
}

// ─── Vault Event Handlers ─────────────────────────────────

export function handleVaultDeposit(event: VaultDeposit): void {
  let owner = event.params.owner;
  let position = getOrCreateUnderwriter(owner);

  position.sharesOwned = position.sharesOwned.plus(event.params.shares);
  position.totalDeposited = position.totalDeposited.plus(event.params.assets);
  position.lastUpdatedBlock = event.block.number;
  position.save();

  // Update protocol stats
  let stats = getOrCreateStats();
  stats.totalCollateral = stats.totalCollateral.plus(event.params.assets);
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}

export function handleVaultWithdraw(event: VaultWithdraw): void {
  let owner = event.params.owner;
  let position = getOrCreateUnderwriter(owner);

  position.sharesOwned = position.sharesOwned.minus(event.params.shares);
  position.totalWithdrawn = position.totalWithdrawn.plus(event.params.assets);
  position.lastUpdatedBlock = event.block.number;
  position.save();

  // Update protocol stats
  let stats = getOrCreateStats();
  stats.totalCollateral = stats.totalCollateral.minus(event.params.assets);
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}

// ─── Event Type Declarations (generated by graph-cli codegen) ─────
// These are placeholder types; actual types come from `graph codegen`

class PolicyPurchased {
  params: PolicyPurchasedParams;
  block: Block;
}
class PolicyPurchasedParams {
  policyId: BigInt;
  holder: Bytes;
  policyTypeId: BigInt;
  coverageAmount: BigInt;
  premium: BigInt;
}

class PolicyTriggered {
  params: PolicyTriggeredParams;
  block: Block;
}
class PolicyTriggeredParams {
  policyId: BigInt;
}

class ClaimProcessed {
  params: ClaimProcessedParams;
  block: Block;
}
class ClaimProcessedParams {
  policyId: BigInt;
  holder: Bytes;
  payoutAmount: BigInt;
}

class ProposalCreated {
  params: ProposalCreatedParams;
  block: Block;
}
class ProposalCreatedParams {
  proposalId: BigInt;
  proposer: Bytes;
  description: string;
  voteStart: BigInt;
  voteEnd: BigInt;
}

class VoteCast {
  params: VoteCastParams;
  block: Block;
}
class VoteCastParams {
  proposalId: BigInt;
  support: u8;
  weight: BigInt;
}

class ProposalExecuted {
  params: ProposalExecutedParams;
  block: Block;
}
class ProposalExecutedParams {
  proposalId: BigInt;
}

class VaultDeposit {
  params: VaultDepositParams;
  block: Block;
}
class VaultDepositParams {
  sender: Bytes;
  owner: Bytes;
  assets: BigInt;
  shares: BigInt;
}

class VaultWithdraw {
  params: VaultWithdrawParams;
  block: Block;
}
class VaultWithdrawParams {
  sender: Bytes;
  receiver: Bytes;
  owner: Bytes;
  assets: BigInt;
  shares: BigInt;
}

class Block {
  timestamp: BigInt;
  number: BigInt;
}
