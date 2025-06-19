// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// =============================================================================
// CORE INTERFACES
// =============================================================================

interface IContentAccess {
    function hasAccess(address user, uint256 assetId) external view returns (bool);
    function grantAccess(address user, uint256 assetId, uint256 duration) external;
}
