import { BigInt } from "@graphprotocol/graph-ts";
import {
  PolicyPurchased,
  PolicyTriggered,
  ClaimProcessed,
} from "../generated/InsurancePool/InsurancePool";
import {
  ProposalCreated,
  VoteCast,
  ProposalExecuted,
} from "../generated/InsuranceGovernor/InsuranceGovernor";
import {
  Deposit as VaultDeposit,
  Withdraw as VaultWithdraw,
} from "../generated/UnderwriterVault/UnderwriterVault";
import {
  Policy,
  Claim,
  UnderwriterPosition,
  GovernanceProposal,
  ProtocolStats,
} from "../generated/schema";

// ─── Helpers ──────────────────────────────────────────────

function getOrCreateStats(): ProtocolStats {
  let stats = ProtocolStats.load("protocol");
  if (stats == null) {
    stats = new ProtocolStats("protocol");
    stats.totalPoliciesCreated = BigInt.zero();
    stats.totalActivePolicies = BigInt.zero();
    stats.totalClaimsPaid = BigInt.zero();
    stats.totalPremiumsCollected = BigInt.zero();
    stats.totalCollateral = BigInt.zero();
    stats.lastUpdatedBlock = BigInt.zero();
  }
  return stats;
}

// ─── InsurancePool Event Handlers ─────────────────────────

export function handlePolicyPurchased(event: PolicyPurchased): void {
  let policyId = event.params.policyId.toString();
  let policy = new Policy(policyId);

  policy.holder = event.params.holder;
  policy.policyTypeId = event.params.policyTypeId;
  policy.coverageAmount = event.params.coverageAmount;
  policy.premiumPaid = event.params.premium;
  policy.expiry = BigInt.zero();
  policy.state = "ACTIVE";
  policy.createdAt = event.block.timestamp;
  policy.createdAtBlock = event.block.number;
  policy.save();

  let stats = getOrCreateStats();
  stats.totalPoliciesCreated = stats.totalPoliciesCreated.plus(BigInt.fromI32(1));
  stats.totalActivePolicies = stats.totalActivePolicies.plus(BigInt.fromI32(1));
  stats.totalPremiumsCollected = stats.totalPremiumsCollected.plus(event.params.premium);
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}

export function handlePolicyTriggered(event: PolicyTriggered): void {
  let policyId = event.params.policyId.toString();
  let policy = Policy.load(policyId);
  if (policy == null) return;

  policy.state = "TRIGGERED";
  policy.save();

  let claim = new Claim(policyId);
  claim.policy = policyId;
  claim.holder = policy.holder;
  claim.amount = policy.coverageAmount;
  claim.triggeredAt = event.block.timestamp;
  claim.status = "PENDING";
  claim.save();

  policy.claim = policyId;
  policy.save();
}

export function handleClaimProcessed(event: ClaimProcessed): void {
  let policyId = event.params.policyId.toString();

  let claim = Claim.load(policyId);
  if (claim != null) {
    claim.status = "PAID";
    claim.processedAt = event.block.timestamp;
    claim.save();
  }

  let policy = Policy.load(policyId);
  if (policy != null) {
    policy.state = "CLAIMED";
    policy.save();
  }

  let stats = getOrCreateStats();
  let activePolicies = stats.totalActivePolicies;
  if (activePolicies.gt(BigInt.zero())) {
    stats.totalActivePolicies = activePolicies.minus(BigInt.fromI32(1));
  }
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

  proposal.state = "ACTIVE";

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
  let id = owner.toHexString();
  let position = UnderwriterPosition.load(id);
  if (position == null) {
    position = new UnderwriterPosition(id);
    position.underwriter = owner;
    position.collateralAmount = BigInt.zero();
    position.sharesOwned = BigInt.zero();
    position.totalDeposited = BigInt.zero();
    position.totalWithdrawn = BigInt.zero();
    position.lastUpdatedBlock = BigInt.zero();
  }

  position.collateralAmount = position.collateralAmount.plus(event.params.assets);
  position.sharesOwned = position.sharesOwned.plus(event.params.shares);
  position.totalDeposited = position.totalDeposited.plus(event.params.assets);
  position.lastUpdatedBlock = event.block.number;
  position.save();

  let stats = getOrCreateStats();
  stats.totalCollateral = stats.totalCollateral.plus(event.params.assets);
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}

export function handleVaultWithdraw(event: VaultWithdraw): void {
  let owner = event.params.owner;
  let id = owner.toHexString();
  let position = UnderwriterPosition.load(id);
  if (position == null) return;

  let shares = event.params.shares;
  let assets = event.params.assets;

  if (position.sharesOwned.gt(shares)) {
    position.sharesOwned = position.sharesOwned.minus(shares);
  } else {
    position.sharesOwned = BigInt.zero();
  }

  if (position.collateralAmount.gt(assets)) {
    position.collateralAmount = position.collateralAmount.minus(assets);
  } else {
    position.collateralAmount = BigInt.zero();
  }

  position.totalWithdrawn = position.totalWithdrawn.plus(assets);
  position.lastUpdatedBlock = event.block.number;
  position.save();

  let stats = getOrCreateStats();
  if (stats.totalCollateral.gt(assets)) {
    stats.totalCollateral = stats.totalCollateral.minus(assets);
  } else {
    stats.totalCollateral = BigInt.zero();
  }
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}
