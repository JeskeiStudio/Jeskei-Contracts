// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// =============================================================================
// CORE INTERFACES
// =============================================================================

interface IPerformerAuth {
    function isVerifiedPerformer(address performer) external view returns (bool);
    function getPerformerVerificationHash(address performer) external view returns (bytes32);
}
