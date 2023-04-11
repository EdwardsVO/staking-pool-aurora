// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IStakingManager {
    function auroraStaking() external view returns (address);
    function auroraToken() external view returns (address);
    function nextDepositor() external view returns (address);
    function setNextDepositor() external;
    function stAurVault() external view returns (address);
    function totalAssets() external view returns (uint256);
    function transferAurora(address _receiver, address _owner, uint256 _assets) external;
    function unstakeShares(uint256 _assets, uint256 _shares, address _receiver, address _owner) external;
}