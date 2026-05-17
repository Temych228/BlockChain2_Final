<<<<<<< HEAD
import { BigInt, Bytes } from "@graphprotocol/graph-ts";
=======
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
>>>>>>> 7214feb461212ed7bb27ee746c049a334683c270
import {
  Policy,
  Claim,
  UnderwriterPosition,
  GovernanceProposal,
  ProtocolStats,
} from "../generated/schema";

// ─── Helpers ──────────────────────────────────────────────

function getOrCreateStats(): ProtocolStats {
<<<<<<< HEAD
  let stats = ProtocolStats.load("global");
  if (stats == null) {
    stats = new ProtocolStats("global");
=======
  let stats = ProtocolStats.load("protocol");
  if (stats == null) {
    stats = new ProtocolStats("protocol");
>>>>>>> 7214feb461212ed7bb27ee746c049a334683c270
    stats.totalPoliciesCreated = BigInt.zero();
    stats.totalActivePolicies = BigInt.zero();
    stats.totalClaimsPaid = BigInt.zero();
    stats.totalPremiumsCollected = BigInt.zero();
    stats.totalCollateral = BigInt.zero();
    stats.lastUpdatedBlock = BigInt.zero();
  }
  return stats;
}

<<<<<<< HEAD
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

=======
>>>>>>> 7214feb461212ed7bb27ee746c049a334683c270
// ─── InsurancePool Event Handlers ─────────────────────────

export function handlePolicyPurchased(event: PolicyPurchased): void {
  let policyId = event.params.policyId.toString();
  let policy = new Policy(policyId);

  policy.holder = event.params.holder;
  policy.policyTypeId = event.params.policyTypeId;
  policy.coverageAmount = event.params.coverageAmount;
  policy.premiumPaid = event.params.premium;
<<<<<<< HEAD
  policy.expiry = BigInt.zero(); // Not emitted in event; would need contract call
=======
  policy.expiry = BigInt.zero();
>>>>>>> 7214feb461212ed7bb27ee746c049a334683c270
  policy.state = "ACTIVE";
  policy.createdAt = event.block.timestamp;
  policy.createdAtBlock = event.block.number;
  policy.save();

  let stats = getOrCreateStats();
  stats.totalPoliciesCreated = stats.totalPoliciesCreated.plus(BigInt.fromI32(1));
  stats.totalActivePolicies = stats.totalActivePolicies.plus(BigInt.fromI32(1));
<<<<<<< HEAD
  stats.totalPremiumsCollected = stats.totalPremiumsCollected.plus(
    event.params.premium
  );
=======
  stats.totalPremiumsCollected = stats.totalPremiumsCollected.plus(event.params.premium);
>>>>>>> 7214feb461212ed7bb27ee746c049a334683c270
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}

export function handlePolicyTriggered(event: PolicyTriggered): void {
  let policyId = event.params.policyId.toString();
  let policy = Policy.load(policyId);
  if (policy == null) return;

  policy.state = "TRIGGERED";
  policy.save();

<<<<<<< HEAD
  // Create a Claim entity with PENDING status
=======
>>>>>>> 7214feb461212ed7bb27ee746c049a334683c270
  let claim = new Claim(policyId);
  claim.policy = policyId;
  claim.holder = policy.holder;
  claim.amount = policy.coverageAmount;
  claim.triggeredAt = event.block.timestamp;
  claim.status = "PENDING";
  claim.save();

<<<<<<< HEAD
  // Link claim to policy
=======
>>>>>>> 7214feb461212ed7bb27ee746c049a334683c270
  policy.claim = policyId;
  policy.save();
}

export function handleClaimProcessed(event: ClaimProcessed): void {
  let policyId = event.params.policyId.toString();

<<<<<<< HEAD
  // Update Claim
=======
>>>>>>> 7214feb461212ed7bb27ee746c049a334683c270
  let claim = Claim.load(policyId);
  if (claim != null) {
    claim.status = "PAID";
    claim.processedAt = event.block.timestamp;
    claim.save();
  }

<<<<<<< HEAD
  // Update Policy
=======
>>>>>>> 7214feb461212ed7bb27ee746c049a334683c270
  let policy = Policy.load(policyId);
  if (policy != null) {
    policy.state = "CLAIMED";
    policy.save();
  }

<<<<<<< HEAD
  // Update ProtocolStats
  let stats = getOrCreateStats();
  stats.totalActivePolicies = stats.totalActivePolicies.minus(BigInt.fromI32(1));
=======
  let stats = getOrCreateStats();
  let activePolicies = stats.totalActivePolicies;
  if (activePolicies.gt(BigInt.zero())) {
    stats.totalActivePolicies = activePolicies.minus(BigInt.fromI32(1));
  }
>>>>>>> 7214feb461212ed7bb27ee746c049a334683c270
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

<<<<<<< HEAD
  // Update proposal state to ACTIVE when first vote is cast
  proposal.state = "ACTIVE";

  // support: 0 = Against, 1 = For, 2 = Abstain
=======
  proposal.state = "ACTIVE";

>>>>>>> 7214feb461212ed7bb27ee746c049a334683c270
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
<<<<<<< HEAD
  let position = getOrCreateUnderwriter(owner);

=======
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
>>>>>>> 7214feb461212ed7bb27ee746c049a334683c270
  position.sharesOwned = position.sharesOwned.plus(event.params.shares);
  position.totalDeposited = position.totalDeposited.plus(event.params.assets);
  position.lastUpdatedBlock = event.block.number;
  position.save();

<<<<<<< HEAD
  // Update protocol stats
=======
>>>>>>> 7214feb461212ed7bb27ee746c049a334683c270
  let stats = getOrCreateStats();
  stats.totalCollateral = stats.totalCollateral.plus(event.params.assets);
  stats.lastUpdatedBlock = event.block.number;
  stats.save();
}

export function handleVaultWithdraw(event: VaultWithdraw): void {
  let owner = event.params.owner;
<<<<<<< HEAD
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
=======
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
>>>>>>> 7214feb461212ed7bb27ee746c049a334683c270
