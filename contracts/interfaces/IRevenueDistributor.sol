// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

// =============================================================================
// CORE INTERFACES
// =============================================================================

interface IRevenueDistributor {
    function distributeRevenue(uint256 assetId, uint256 amount) external payable;
    function setRevenueShares(uint256 assetId, address[] calldata recipients, uint256[] calldata percentages) external;
}
