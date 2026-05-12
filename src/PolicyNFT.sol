// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/// @title PolicyNFT
/// @notice ERC-1155 tokens representing insurance policies. Each tokenId maps to a policy type:
///         0 = STABLECOIN_DEPEG, 1 = LIQUIDATION_PROTECTION, 2 = SMART_CONTRACT_HACK.
/// @dev MINTER_ROLE is granted to InsurancePool; BURNER_ROLE is granted to ClaimProcessor.
///      Uses AccessControl for role-based permissioning and ERC1155Supply for on-chain supply tracking.
contract PolicyNFT is ERC1155, ERC1155Supply, AccessControl {
    using Strings for uint256;

    /// @notice Role required to mint new policy tokens.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role required to burn policy tokens on claim settlement.
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Base URI prefix for token metadata.
    string private _baseURI;

    /// @notice Policy type identifiers.
    uint256 public constant STABLECOIN_DEPEG = 0;
    uint256 public constant LIQUIDATION_PROTECTION = 1;
    uint256 public constant SMART_CONTRACT_HACK = 2;

    /// @notice Deploys PolicyNFT with a metadata base URI and grants admin role to deployer.
    /// @param baseURI_ The base URI prefix (e.g. "https://api.insuredao.io/policy/").
    /// @param admin The address receiving DEFAULT_ADMIN_ROLE.
    constructor(string memory baseURI_, address admin) ERC1155(baseURI_) {
        _baseURI = baseURI_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Mints policy tokens to a holder. Only callable by MINTER_ROLE.
    /// @param to The policy holder address.
    /// @param policyTypeId The policy type tokenId (0, 1, or 2).
    /// @param amount The number of policy tokens to mint.
    /// @param data Additional data passed to the ERC-1155 receiver hook.
    function mintPolicy(address to, uint256 policyTypeId, uint256 amount, bytes memory data)
        external
        onlyRole(MINTER_ROLE)
    {
        _mint(to, policyTypeId, amount, data);
    }

    /// @notice Burns policy tokens from a holder. Only callable by BURNER_ROLE.
    /// @param from The address whose tokens are burned.
    /// @param policyTypeId The policy type tokenId to burn.
    /// @param amount The number of tokens to burn.
    function burnPolicy(address from, uint256 policyTypeId, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, policyTypeId, amount);
    }

    /// @notice Returns the metadata URI for a given policy type.
    /// @param id The tokenId (policy type).
    /// @return The full URI string: baseURI + id.
    function uri(uint256 id) public view override returns (string memory) {
        return string.concat(_baseURI, id.toString());
    }

    // ──────────────────────────────────────────────────────────────
    // Required overrides for ERC1155 + ERC1155Supply + AccessControl
    // ──────────────────────────────────────────────────────────────

    /// @inheritdoc ERC1155
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    /// @notice ERC-165 interface detection for ERC1155 + AccessControl.
    /// @param interfaceId The interface identifier to check.
    /// @return True if the interface is supported.
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
