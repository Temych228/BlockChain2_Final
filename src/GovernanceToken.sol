// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

/// @title GovernanceToken (IDAO)
/// @notice ERC-20 governance token with voting, delegation, permit, and burn capabilities.
/// @dev Uses OZ v5: ERC20Votes for on-chain governance snapshots, ERC20Permit for gasless
///      approvals (EIP-2612), and Ownable2Step for safe ownership transfer.
///      Hard cap: 100,000,000 IDAO. Initial mint: 10,000,000 IDAO to deployer.
contract GovernanceToken is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, Ownable2Step {
    /// @notice Maximum total supply: 100 million tokens (18 decimals).
    uint256 public constant MAX_SUPPLY = 100_000_000e18;

    /// @notice Thrown when a mint would exceed the MAX_SUPPLY hard cap.
    /// @param requested The amount requested to mint.
    /// @param available The remaining mintable supply.
    error ExceedsMaxSupply(uint256 requested, uint256 available);

    /// @notice Deploys the governance token and mints the initial supply to the deployer.
    /// @param _deployer The address that receives the initial 10M token supply and ownership.
    constructor(address _deployer) ERC20("InsureDAO", "IDAO") ERC20Permit("InsureDAO") Ownable(_deployer) {
        _mint(_deployer, 10_000_000e18);
    }

    /// @notice Mints new tokens to a recipient. Only callable by the owner.
    /// @dev Reverts with ExceedsMaxSupply if the mint would push totalSupply above MAX_SUPPLY.
    /// @param to The address to receive the minted tokens.
    /// @param amount The number of tokens to mint (18-decimal).
    function mint(address to, uint256 amount) external onlyOwner {
        if (totalSupply() + amount > MAX_SUPPLY) {
            revert ExceedsMaxSupply(amount, MAX_SUPPLY - totalSupply());
        }
        _mint(to, amount);
    }

    // ──────────────────────────────────────────────────────────────
    // EIP-6372: Timestamp-based clock mode
    // ──────────────────────────────────────────────────────────────

    /// @notice Returns the current block timestamp as the governance clock.
    /// @dev Overrides the default block-number clock to enable timestamp-based voting
    ///      checkpoints. Required for L2 compatibility where block times are variable.
    function clock() public view override returns (uint48) {
        return uint48(block.timestamp);
    }

    /// @notice Machine-readable description of the clock per EIP-6372.
    /// @return The clock mode string indicating timestamp-based operation.
    function CLOCK_MODE() public pure override returns (string memory) {
        return "mode=timestamp";
    }

    // ──────────────────────────────────────────────────────────────
    // Required overrides for ERC20 + ERC20Votes diamond
    // ──────────────────────────────────────────────────────────────

    /// @inheritdoc ERC20
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    /// @inheritdoc Nonces
    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
